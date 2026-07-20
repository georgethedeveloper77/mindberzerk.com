# Theme spec — the contract

A distro is a JSON file. That's the whole trick.

```json
{
  "id": "ubuntu-24-04",
  "name": "Ubuntu",
  "version": "24.04",
  "shell": "gnome",
  "tier": "free",
  "palette": {
    "bgTop": "#622A4C", "bgBottom": "#220817", "bar": "#1A171B",
    "dock": "#BD201B21", "accent": "#E95420", "onDark": "#FFFFFF"
  },
  "typography": { "display": "Ubuntu", "mono": "UbuntuMono" },
  "layout": { "dock": "left", "topBar": true, "grid": { "rows": 5, "cols": 4 } },
  "icons": { "treatment": "squircle", "heroPack": "yaru", "tint": null },
  "wallpaper": { "url": "https://cdn.../wallpaper.webp" },
  "minAppVersion": 20000,
  "signature": "ed25519:..."
}
```

| Field | Notes |
|---|---|
| `version` | **Always name the real version.** "Ubuntu 24.04" is the pitch; "Ubuntu-ish" is not. |
| `shell` | `gnome` / `plasma` / `tiling` / `tui`. Four, and only four. |
| `tier` | `free` or `pro` — this is the monetization surface. |
| `layout` | The theme's *default*. User overrides win. |
| `minAppVersion` | Lets a new pack refuse to load on an old client instead of breaking it. |
| `signature` | Verified before load. Non-negotiable. |

## Adding a distro

1. Write `theme.json` + wallpaper + a 40–60 icon hero pack.
2. Sign it in CI.
3. Publish to the CDN.
4. It appears in the Themes gallery on phones that were never updated.

No app release. That's the payoff for keeping shells generic.
