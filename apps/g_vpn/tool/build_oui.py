#!/usr/bin/env python3
"""Build assets/oui/oui.tsv.gz: hardware address prefix -> maker, from IEEE.

The IEEE registration authority publishes every manufacturer prefix (OUI)
for free. The Wi-Fi scanner uses it to name the maker of each network's
router from its hardware address, entirely on the phone.

Output: gzip of lines "AABBCC<TAB>Maker", sorted, makers shortened to how
people say them ("Huawei", not "HUAWEI TECHNOLOGIES CO.,LTD").

Usage (from apps/g_vpn):
    python3 tool/build_oui.py
"""

from __future__ import annotations

import csv
import gzip
import io
import re
import sys
import urllib.request
from pathlib import Path

SOURCE_URL = 'https://standards-oui.ieee.org/oui/oui.csv'
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'oui' / 'oui.tsv.gz'

# Legal-form words dropped from the end of a maker's name.
_SUFFIXES = re.compile(
    r'(?:[\s,.]+(?:co|corp|corporation|inc|incorporated|ltd|limited|llc|gmbh|ag|sa|s\.a|srl|bv|b\.v|oy|ab|as|nv|plc|pte|pty|'
    r'kk|k\.k|spa|sas|s\.p\.a|company|group|holdings?|international|technolog(?:y|ies)|electronics?|communications?|'
    r'networks?|systems?|telecom(?:munications?)?|devices?|industr(?:y|ies)|manufacturing|enterprises?|'
    r'information|digital|tech|co\.,?\s*ltd)\.?)+\s*$',
    re.IGNORECASE,
)

# Makers whose registered names read badly however they are trimmed.
_KNOWN = {
    'HUAWEI': 'Huawei', 'ZTE': 'ZTE', 'TP-LINK': 'TP-Link', 'TP-Link': 'TP-Link', 'XIAOMI': 'Xiaomi',
    'SAMSUNG': 'Samsung', 'APPLE': 'Apple', 'NETGEAR': 'Netgear', 'UBIQUITI': 'Ubiquiti', 'MIKROTIK': 'MikroTik',
    'D-LINK': 'D-Link', 'TENDA': 'Tenda', 'ASUSTEK': 'ASUS', 'CISCO': 'Cisco', 'ARRIS': 'Arris', 'SAGEMCOM': 'Sagemcom',
    'NOKIA': 'Nokia', 'FIBERHOME': 'FiberHome', 'ZYXEL': 'Zyxel', 'HIKVISION': 'Hikvision', 'DAHUA': 'Dahua',
    'GOOGLE': 'Google', 'AMAZON': 'Amazon', 'SONY': 'Sony', 'LG ELECTRONICS': 'LG', 'TCL': 'TCL', 'HISENSE': 'Hisense',
    'OPPO': 'OPPO', 'VIVO': 'vivo', 'REALME': 'realme', 'INFINIX': 'Infinix', 'TECNO': 'TECNO', 'TRANSSION': 'Transsion',
    'INTEL': 'Intel', 'REALTEK': 'Realtek', 'MEDIATEK': 'MediaTek', 'QUALCOMM': 'Qualcomm', 'BROADCOM': 'Broadcom',
    'MURATA': 'Murata', 'ESPRESSIF': 'Espressif', 'TUYA': 'Tuya', 'RUIJIE': 'Ruijie', 'H3C': 'H3C', 'ARUBA': 'Aruba',
    'LINKSYS': 'Linksys', 'BELKIN': 'Belkin', 'MERCUSYS': 'Mercusys', 'TOTOLINK': 'TOTOLINK', 'NETIS': 'Netis',
}


def short_name(name: str) -> str:
    """How people say a maker's name."""
    raw = ' '.join(name.replace('\u00a0', ' ').split())
    upper = raw.upper()
    for key, nice in _KNOWN.items():
        if upper.startswith(key.upper()):
            return nice
    trimmed = raw
    for _ in range(3):
        trimmed = _SUFFIXES.sub('', trimmed).strip(' ,.-')
    trimmed = trimmed or raw
    # Registered in capitals: give it ordinary case, keeping short acronyms.
    if trimmed.isupper():
        trimmed = ' '.join(w if len(w) <= 3 else w.capitalize() for w in trimmed.split())
    return trimmed[:32]


def build(csv_text: str) -> bytes:
    rows = {}
    for row in csv.DictReader(io.StringIO(csv_text)):
        prefix = (row.get('Assignment') or '').strip().upper()
        org = (row.get('Organization Name') or '').strip()
        if len(prefix) == 6 and org and org.lower() != 'private':
            rows[prefix] = short_name(org)
    text = ''.join(f'{p}\t{n}\n' for p, n in sorted(rows.items()))
    return gzip.compress(text.encode('utf-8'), compresslevel=9, mtime=0)


def main() -> int:
    print(f'Downloading {SOURCE_URL}')
    req = urllib.request.Request(SOURCE_URL, headers={'User-Agent': 'G-VPN-build'})
    with urllib.request.urlopen(req, timeout=120) as response:
        data = build(response.read().decode('utf-8', errors='replace'))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print(f'Wrote {OUT} ({len(data) // 1024} KB)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
