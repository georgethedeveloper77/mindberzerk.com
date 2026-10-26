#!/usr/bin/env python3
"""Build assets/map/meridian_{dark,light}.json from OpenFreeMap's Dark style.

The layer structure (water, land use, roads, borders, place names) comes
from OpenFreeMap's fork of the OpenMapTiles Dark Matter style (BSD-3).
Every colour is replaced with Meridian's, so the map reads as G VPN, not as
any stock map. Tiles, fonts and sprites are served free by OpenFreeMap with
no key; the data is OpenStreetMap (ODbL), credited in the map's attribution.

Usage (from apps/g_vpn):
    python3 tool/build_map_style.py
"""

from __future__ import annotations

import copy
import json
import sys
import urllib.request
from pathlib import Path

SOURCE_URL = 'https://raw.githubusercontent.com/hyperknot/openfreemap-styles/main/styles/dark/style.json'
DOMAIN = 'tiles.openfreemap.org'
OUT_DIR = Path(__file__).resolve().parent.parent / 'assets' / 'map'

ATTRIBUTION = (
    '<a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> '
    '<a href="https://www.openmaptiles.org/" target="_blank">&copy; OpenMapTiles</a> '
    'Data from <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>'
)

# Meridian map palettes. Land is a touch lighter than the page so the
# coastline reads; roads are quiet so the pin and markers lead.
# Label layers kept, with the zoom they appear from.
KEEP_LABELS = {
    'place_city_large': 7,
    'place_city': 8,
    'place_town': 10,
    'place_suburb': 11,
}

PALETTES = {
    'dark': {
        'land': '#161B27', 'water': '#06080C', 'waterway': '#0B1426',
        'park': '#0E1A17', 'residential': '#121620', 'ice': '#161B26',
        'building': '#161B27', 'building_edge': '#1D2333',
        'road_minor': '#1A2030', 'road_major': '#232B3E', 'road_motorway': '#2C3650',
        'road_casing': '#10131B', 'rail': '#1C2232', 'aeroway': '#1A2030',
        'border_country': '#46526E', 'border_state': '#262E40',
        'label': '#8A93A6', 'label_strong': '#C9CFDB', 'label_water': '#3E5A8A', 'halo': '#0A0B0F',
    },
    'light': {
        'land': '#F6F8FC', 'water': '#C9D7F0', 'waterway': '#BFD0EE',
        'park': '#E1F0E5', 'residential': '#EDF0F6', 'ice': '#F8FAFD',
        'building': '#E6EAF2', 'building_edge': '#D9DEE8',
        'road_minor': '#FFFFFF', 'road_major': '#FFFFFF', 'road_motorway': '#FFFFFF',
        'road_casing': '#DCE1EA', 'rail': '#CDD3DF', 'aeroway': '#E3E7EF',
        'border_country': '#A7B1C7', 'border_state': '#C5CCDA',
        'label': '#5B6478', 'label_strong': '#0F172A', 'label_water': '#6A86BC', 'halo': '#F3F5FA',
    },
}


def colour_for(layer: dict, p: dict) -> dict[str, str]:
    """Paint colours for one layer, chosen by its id and source layer."""
    lid = layer['id']
    src = layer.get('source-layer', '')
    kind = layer['type']

    if kind == 'background':
        return {'background-color': p['land']}
    if src == 'water' and kind == 'fill':
        return {'fill-color': p['water']}
    if src == 'waterway':
        return {'line-color': p['waterway']}
    if src == 'landcover' and ('ice' in lid or 'glacier' in lid):
        return {'fill-color': p['ice']}
    if src in ('landcover', 'park') or lid == 'landuse_park':
        return {'fill-color': p['park']}
    if src == 'landuse':
        return {'fill-color': p['residential']}
    if src == 'building':
        return {'fill-color': p['building'], 'fill-outline-color': p['building_edge']}
    if src == 'aeroway':
        key = 'fill-color' if kind == 'fill' else 'line-color'
        return {key: p['aeroway']}
    if src == 'transportation':
        if kind == 'fill':
            return {'fill-color': p['road_minor']}
        if 'rail' in lid:
            return {'line-color': p['rail']}
        if 'casing' in lid:
            return {'line-color': p['road_casing']}
        if 'motorway' in lid:
            return {'line-color': p['road_motorway']}
        if 'major' in lid:
            return {'line-color': p['road_major']}
        return {'line-color': p['road_minor']}
    if src == 'boundary':
        return {'line-color': p['border_country'] if 'country' in lid else p['border_state']}
    if kind == 'symbol':
        if src == 'water_name':
            text = p['label_water']
        elif src == 'place' and ('city' in lid or 'country' in lid):
            text = p['label_strong']
        else:
            text = p['label']
        return {'text-color': text, 'text-halo-color': p['halo']}
    return {}


def build(base: dict, palette: dict) -> dict:
    style = copy.deepcopy(base)
    style['name'] = 'Meridian'
    style['glyphs'] = style['glyphs'].replace('__TILEJSON_DOMAIN__', DOMAIN)
    style['sprite'] = style['sprite'].replace('__TILEJSON_DOMAIN__', DOMAIN)
    # Only the vector tiles are used; the shaded-relief raster is dropped.
    style['sources'] = {
        'openmaptiles': {
            'type': 'vector',
            'url': f'https://{DOMAIN}/planet',
            'attribution': ATTRIBUTION,
        }
    }
    layers = []
    for layer in style['layers']:
        if layer.get('source') not in (None, 'openmaptiles'):
            continue
        # A quiet map: G VPN draws its own story on top, so stock labels go.
        # Only town and neighbourhood names stay, and only up close.
        if layer['type'] == 'symbol':
            if layer['id'] not in KEEP_LABELS:
                continue
            layer['minzoom'] = max(layer.get('minzoom', 0), KEEP_LABELS[layer['id']])
        paint = layer.setdefault('paint', {})
        paint.update(colour_for(layer, palette))
        # Stock halos are hairline; a firmer halo keeps labels legible over roads.
        if layer['type'] == 'symbol' and 'text-halo-color' in paint:
            paint['text-halo-width'] = 1.2
            paint.pop('text-halo-blur', None)
        layers.append(layer)
    style['layers'] = layers
    return style


def main() -> int:
    print(f'Downloading {SOURCE_URL}')
    with urllib.request.urlopen(SOURCE_URL, timeout=60) as response:
        base = json.load(response)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, palette in PALETTES.items():
        out = OUT_DIR / f'meridian_{name}.json'
        out.write_text(json.dumps(build(base, palette), separators=(',', ':')), encoding='utf-8')
        print(f'Wrote {out} ({out.stat().st_size // 1024} KB)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
