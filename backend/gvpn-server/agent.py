#!/usr/bin/env python3
"""G Server agent: the ONLY thing on a G Server that changes WireGuard peers.

It can add a peer, remove a peer and report health. Nothing else: no shell,
no file access, no traffic inspection. The Firebase backend is its only
intended caller and proves itself with an HMAC signature over every request.

PRIVACY, BY CONSTRUCTION
  * Requests carry PUBLIC keys only. A phone's private key is generated on
    the phone and never travels.
  * No client IP addresses are logged: log_message is silenced below, and
    WireGuard itself keeps no logs (only the last handshake time, in memory).
  * The peer store maps public key -> tunnel address. Nothing about who the
    user is, where they connect from, or what they do.

Standard library only, so the server needs nothing beyond python3 and
wireguard-tools.
"""

import base64
import binascii
import hashlib
import hmac
import ipaddress
import json
import os
import re
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET = os.environ["GVPN_AGENT_SECRET"].encode()
ENDPOINT = os.environ["GVPN_ENDPOINT"]  # public IP or hostname, without port
PORT = int(os.environ.get("GVPN_WG_PORT", "51820"))
LISTEN = int(os.environ.get("GVPN_AGENT_PORT", "8443"))
IFACE = os.environ.get("GVPN_WG_IFACE", "wg0")
NETWORK = ipaddress.ip_network(os.environ.get("GVPN_NETWORK", "10.66.0.0/16"))
DNS = os.environ.get("GVPN_DNS", "9.9.9.9, 149.112.112.112")
STORE = os.environ.get("GVPN_STORE", "/var/lib/gvpn-agent/peers.json")

# A signed request older or newer than this is refused, so a captured
# request cannot be replayed later.
MAX_SKEW_SECONDS = 60

KEY_RE = re.compile(r"^[A-Za-z0-9+/]{43}=$")
LOCK = threading.Lock()
STARTED = time.time()


def sign(method: str, path: str, timestamp: str, body: bytes) -> str:
    """HMAC-SHA256 over method, path, timestamp and body, newline-joined."""
    message = b"\n".join([method.encode(), path.encode(), timestamp.encode(), body])
    return hmac.new(SECRET, message, hashlib.sha256).hexdigest()


def load_peers() -> dict:
    try:
        with open(STORE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_peers(peers: dict) -> None:
    # Write then rename: a crash mid-write never leaves a half-written store.
    tmp = STORE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(peers, f)
    os.replace(tmp, STORE)


def wg(*args: str) -> str:
    return subprocess.run(["wg", *args], check=True, capture_output=True, text=True).stdout


def server_public_key() -> str:
    return wg("show", IFACE, "public-key").strip()


def apply_peer(public_key: str, address: str) -> None:
    wg("set", IFACE, "peer", public_key, "allowed-ips", f"{address}/32")


def next_free_address(peers: dict) -> str:
    used = set(peers.values())
    hosts = NETWORK.hosts()
    next(hosts)  # .1 is the server itself
    for host in hosts:
        if str(host) not in used:
            return str(host)
    raise RuntimeError("address pool exhausted")


def restore_all() -> None:
    """Re-apply every stored peer. wg0 starts empty after a reboot."""
    for public_key, address in load_peers().items():
        apply_peer(public_key, address)


def health() -> dict:
    rx = tx = active = 0
    now = time.time()
    for line in wg("show", IFACE, "dump").splitlines()[1:]:
        fields = line.split("\t")
        handshake, peer_rx, peer_tx = int(fields[4]), int(fields[5]), int(fields[6])
        rx += peer_rx
        tx += peer_tx
        # "Active" = handshake in the last 3 minutes. A count, never a list.
        if handshake and now - handshake < 180:
            active += 1
    with open("/proc/loadavg") as f:
        loads = [float(x) for x in f.read().split()[:3]]
    mem = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, value = line.split(":", 1)
            mem[key] = int(value.split()[0]) * 1024  # kB -> bytes
    disk = os.statvfs("/")
    with open("/proc/uptime") as f:
        machine_uptime = float(f.read().split()[0])
    return {
        "ok": True,
        "name": os.environ.get("GVPN_SERVER_NAME", "G Server"),
        "peers": len(load_peers()),
        "active": active,
        "rxBytes": rx,
        "txBytes": tx,
        "load1": loads[0],
        "load5": loads[1],
        "load15": loads[2],
        "cpus": os.cpu_count(),
        "memTotal": mem.get("MemTotal", 0),
        "memAvailable": mem.get("MemAvailable", 0),
        "diskTotal": disk.f_blocks * disk.f_frsize,
        "diskFree": disk.f_bavail * disk.f_frsize,
        "uptimeSeconds": int(time.time() - STARTED),
        "machineUptimeSeconds": int(machine_uptime),
        # Oldest first, one value per 15 minutes, 0 to 100.
        "history": list(HISTORY),
    }


def activity() -> dict:
    """Each peer's public key and last handshake (Unix seconds, 0 = never).

    For the broker's idle cleanup only. Keys, never addresses or traffic.
    """
    peers = []
    for line in wg("show", IFACE, "dump").splitlines()[1:]:
        fields = line.split("\t")
        peers.append({"publicKey": fields[0], "lastHandshake": int(fields[4])})
    return {"peers": peers}


class Handler(BaseHTTPRequestHandler):
    server_version = "gvpn-agent"
    sys_version = ""

    def log_message(self, *_args) -> None:
        # Deliberately silent: the default handler logs every client IP.
        pass

    def _reply(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorised(self, body: bytes) -> bool:
        timestamp = self.headers.get("X-GVPN-Time", "")
        signature = self.headers.get("X-GVPN-Sig", "")
        if not timestamp.isdigit() or abs(time.time() - int(timestamp)) > MAX_SKEW_SECONDS:
            return False
        expected = sign(self.command, self.path, timestamp, body)
        return hmac.compare_digest(expected, signature)

    def _body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or 0)
        return self.rfile.read(min(length, 4096)) if length else b""

    def do_GET(self) -> None:
        if not self._authorised(b""):
            return self._reply(401, {"error": "unauthorised"})
        if self.path == "/health":
            return self._reply(200, health())
        if self.path == "/peers/activity":
            return self._reply(200, activity())
        self._reply(404, {"error": "not found"})

    def do_POST(self) -> None:
        body = self._body()
        if not self._authorised(body):
            return self._reply(401, {"error": "unauthorised"})
        if self.path != "/peers":
            return self._reply(404, {"error": "not found"})
        try:
            public_key = json.loads(body or b"{}").get("publicKey", "")
        except json.JSONDecodeError:
            return self._reply(400, {"error": "bad json"})
        if not KEY_RE.match(public_key):
            return self._reply(400, {"error": "bad public key"})
        with LOCK:
            peers = load_peers()
            # Idempotent: the same phone asking twice gets the same address.
            address = peers.get(public_key) or next_free_address(peers)
            peers[public_key] = address
            apply_peer(public_key, address)
            save_peers(peers)
        self._reply(200, {
            "address": f"{address}/32",
            "serverPublicKey": server_public_key(),
            "endpoint": f"{ENDPOINT}:{PORT}",
            "dns": DNS,
            "allowedIps": "0.0.0.0/0, ::/0",
        })

    def do_DELETE(self) -> None:
        body = self._body()
        if not self._authorised(body):
            return self._reply(401, {"error": "unauthorised"})
        prefix = "/peers/"
        if not self.path.startswith(prefix):
            return self._reply(404, {"error": "not found"})
        # Keys contain '/' and '+', so the caller URL-safe base64s them.
        try:
            public_key = base64.b64encode(base64.urlsafe_b64decode(self.path[len(prefix):])).decode()
        except (ValueError, binascii.Error):
            return self._reply(400, {"error": "bad public key"})
        with LOCK:
            peers = load_peers()
            if peers.pop(public_key, None) is not None:
                wg("set", IFACE, "peer", public_key, "remove")
                save_peers(peers)
        self._reply(200, {"removed": True})


# ── 24-hour load history ────────────────────────────────────────────────
# How busy the server was, every 15 minutes for the last 24 hours (96
# samples), as a share of the CPUs. Saved beside the peer store so a restart
# keeps the chart. Numbers only: nothing about any phone.

HISTORY_FILE = os.path.join(os.path.dirname(STORE), "load-history.json")
SAMPLE_SECONDS = 15 * 60
HISTORY_LEN = 96
HISTORY: list = []


def busy_now() -> int:
    with open("/proc/loadavg") as f:
        load = float(f.read().split()[0])
    return max(0, min(100, round(load / (os.cpu_count() or 1) * 100)))


def sample_forever() -> None:
    global HISTORY
    try:
        with open(HISTORY_FILE) as f:
            HISTORY = [int(x) for x in json.load(f)][-HISTORY_LEN:]
    except (OSError, ValueError, TypeError):
        HISTORY = []
    while True:
        HISTORY = (HISTORY + [busy_now()])[-HISTORY_LEN:]
        try:
            tmp = HISTORY_FILE + ".tmp"
            with open(tmp, "w") as f:
                json.dump(HISTORY, f)
            os.replace(tmp, HISTORY_FILE)
        except OSError:
            pass
        time.sleep(SAMPLE_SECONDS)


def main() -> None:
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    restore_all()
    threading.Thread(target=sample_forever, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", LISTEN), Handler).serve_forever()


if __name__ == "__main__":
    main()
