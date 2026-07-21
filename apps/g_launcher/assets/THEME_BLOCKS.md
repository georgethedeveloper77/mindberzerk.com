# D3 — the `desklets` block for the other five themes

`aqua/theme.json` in this drop is complete. The rest are snippets because both
uploaded theme.json files arrived at the same path and one overwrote the other,
so I can only verify aqua's. Paste these as a top-level key.

Every one of these is DATA. The clock widget is identical in all five cases;
what changes is which shell default it starts from and what this distro
overrides. That is the whole D3 exit gate.

## ubuntu-24-04 (gnome)

```json
"desklets": {
  "offers": ["clock", "monitor", "fastfetch", "network", "storage", "battery", "notes", "search"],
  "starter": [
    { "kind": "clock", "page": 0, "col": 0, "row": 0, "spanX": 3, "spanY": 1, "config": { "format": "24h" } }
  ],
  "skins": {
    "clock": { "surface": "bare", "font": "display", "timeSize": 60, "timeWeight": 200, "dateSize": 13, "letterSpacing": -2.5, "showDate": true }
  }
}
```

## fedora-41 (gnome)

Authors NOTHING for the clock, on purpose. Fedora is a GNOME desktop, so it
inherits GNOME's default face and looks right without a line of skin. This is
the case that proves the defaults are keyed by SHELL and not by theme id.

```json
"desklets": {
  "offers": ["clock", "monitor", "fastfetch", "network", "storage", "battery", "notes"],
  "starter": [
    { "kind": "clock", "page": 0, "col": 0, "row": 0, "spanX": 3, "spanY": 1 }
  ]
}
```

## kde-plasma-6 (plasma)

```json
"desklets": {
  "offers": ["clock", "monitor", "network", "storage", "battery", "notes", "search"],
  "starter": [
    { "kind": "clock", "page": 0, "col": 2, "row": 0, "spanX": 2, "spanY": 1 }
  ],
  "skins": {
    "clock": { "surface": "card", "font": "display", "timeSize": 34, "timeWeight": 500, "opacity": 0.72, "radius": 8, "showDate": true }
  }
}
```

## arch-hyprland (tiling)

```json
"desklets": {
  "offers": ["clock", "monitor", "network", "storage", "battery", "search"],
  "starter": [
    { "kind": "clock", "page": 0, "col": 0, "row": 0, "spanX": 2, "spanY": 1 }
  ],
  "skins": {
    "clock": { "surface": "panel", "font": "mono", "accent": true, "timeSize": 18, "timeWeight": 700, "radius": 3, "showDate": true }
  }
}
```

## terminal (tui)

`col`/`row`/`span` are omitted deliberately: the pane surface ignores them, and
authoring numbers that nothing reads is how a schema starts lying.

```json
"desklets": {
  "offers": ["clock", "free", "df", "monitor", "network"],
  "starter": [
    { "kind": "clock", "page": 0 }
  ],
  "skins": {
    "clock": { "surface": "terminal", "font": "mono", "timeSize": 13, "command": "date" }
  }
}
```
