#!/usr/bin/env bash
# G Server install: WireGuard + the gvpn agent, on Ubuntu 22.04 or 24.04.
#
#   sudo bash install.sh            # endpoint = this machine's public IP
#   sudo bash install.sh vpn.example.com
#   sudo GVPN_SERVER_NAME="G Server · Frankfurt" bash install.sh
#     (the name the app shows; default "G Server")
#
# Safe to re-run: keys, the agent secret and existing peers are kept.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"

WG_PORT=51820
AGENT_PORT=8443
NETWORK=10.66.0.0/16
SERVER_ADDR=10.66.0.1/16

echo "== Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q wireguard wireguard-tools qrencode python3 iptables netfilter-persistent iptables-persistent

# The interface carrying the default route: enp0s6 or ens3 on Oracle, eth0
# elsewhere. NAT must go out through it.
WAN_IF=$(ip -4 route show default | awk '{print $5; exit}')
ENDPOINT="${1:-$(curl -4 -s --max-time 10 https://api.ipify.org || true)}"
[[ -n "$ENDPOINT" ]] || { echo "Could not detect the public IP. Pass it: sudo bash install.sh <ip>"; exit 1; }
echo "   WAN interface: $WAN_IF   endpoint: $ENDPOINT"

echo "== WireGuard"
install -d -m 700 /etc/wireguard
if [[ ! -f /etc/wireguard/server.key ]]; then
  umask 077
  wg genkey > /etc/wireguard/server.key
fi
SERVER_KEY=$(cat /etc/wireguard/server.key)

# Peers are NOT in this file: the agent owns them and re-applies them at boot.
cat > /etc/wireguard/wg0.conf <<CONF
[Interface]
Address = $SERVER_ADDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_KEY
PostUp = iptables -t nat -A POSTROUTING -s $NETWORK -o $WAN_IF -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s $NETWORK -o $WAN_IF -j MASQUERADE
CONF
chmod 600 /etc/wireguard/wg0.conf

cat > /etc/sysctl.d/99-gvpn.conf <<SYS
net.ipv4.ip_forward = 1
SYS
sysctl -q --system

echo "== Firewall"
# ORACLE'S UBUNTU IMAGE ships iptables rules ending in REJECT for INPUT and
# FORWARD. Opening the port in the cloud console alone is NOT enough: these
# rules must be inserted above that REJECT, or every packet dies silently.
allow() { iptables -C "$@" 2>/dev/null || iptables -I "$@"; }
allow INPUT 1 -p udp --dport $WG_PORT -j ACCEPT
allow INPUT 1 -p tcp --dport $AGENT_PORT -j ACCEPT
allow FORWARD 1 -i wg0 -j ACCEPT
allow FORWARD 1 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
netfilter-persistent save >/dev/null

systemctl enable -q wg-quick@wg0
systemctl restart wg-quick@wg0

echo "== Agent"
install -d -m 755 /opt/gvpn-agent
install -m 755 "$HERE/agent.py" /opt/gvpn-agent/agent.py
install -m 755 "$HERE/gvpn-peer" /usr/local/bin/gvpn-peer
install -d -m 700 /var/lib/gvpn-agent

if [[ ! -f /etc/gvpn-agent.env ]]; then
  SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
  umask 077
  cat > /etc/gvpn-agent.env <<ENV
GVPN_AGENT_SECRET=$SECRET
GVPN_ENDPOINT=$ENDPOINT
GVPN_WG_PORT=$WG_PORT
GVPN_AGENT_PORT=$AGENT_PORT
GVPN_NETWORK=$NETWORK
ENV
else
  sed -i "s|^GVPN_ENDPOINT=.*|GVPN_ENDPOINT=$ENDPOINT|" /etc/gvpn-agent.env
fi
# The name the app shows for this server. Set or change it on any run.
SERVER_NAME="${GVPN_SERVER_NAME:-$(grep -s '^GVPN_SERVER_NAME=' /etc/gvpn-agent.env | cut -d= -f2-)}"
SERVER_NAME="${SERVER_NAME:-G Server}"
sed -i '/^GVPN_SERVER_NAME=/d' /etc/gvpn-agent.env
echo "GVPN_SERVER_NAME=$SERVER_NAME" >> /etc/gvpn-agent.env
chmod 600 /etc/gvpn-agent.env

cat > /etc/systemd/system/gvpn-agent.service <<UNIT
[Unit]
Description=G Server agent (WireGuard peers)
After=wg-quick@wg0.service network-online.target
Requires=wg-quick@wg0.service

[Service]
EnvironmentFile=/etc/gvpn-agent.env
ExecStart=/usr/bin/python3 /opt/gvpn-agent/agent.py
Restart=always
RestartSec=3
# Root only for CAP_NET_ADMIN (wg set); everything else is taken away.
CapabilityBoundingSet=CAP_NET_ADMIN
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/gvpn-agent

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable -q gvpn-agent
systemctl restart gvpn-agent
sleep 2

echo
echo "== Done"
systemctl is-active --quiet wg-quick@wg0 && echo "   WireGuard: running on UDP $WG_PORT" || echo "   WireGuard: NOT running"
systemctl is-active --quiet gvpn-agent && echo "   Agent:     running on TCP $AGENT_PORT" || echo "   Agent:     NOT running (journalctl -u gvpn-agent)"
echo "   Endpoint:  $ENDPOINT:$WG_PORT"
echo
echo "   The agent secret is in /etc/gvpn-agent.env. Keep it private:"
echo "   it is what lets the backend add and remove peers."
echo
echo "   Test now:  sudo gvpn-peer add phone   (then scan the QR in G VPN)"
