# Authoring a theme

A theme is one `theme.json`. Everything a distro is — its palette, its desktop
metaphor, its boot log, its icon recipe, what it puts on the desktop — lives in
that file. Adding Kali or Mint should cost zero Dart.

Validate before shipping:

```
./scripts/validate_themes.sh
```

The runtime parser is deliberately **tolerant**: an unknown key is ignored, an
unknown enum value degrades to a safe default, a missing block falls back to the
shell family. That is correct for a home screen, because a downgrade must never
black-screen someone's phone. It is also why a typo in our own themes is
invisible, and why the validator is deliberately **strict**. Run it.

---

## 1. The bet

Three layers, and keeping them separate is what makes distro packs sellable.

| Layer | Lives in | Per distro? |
|---|---|---|
| **Shell** | code, one per desktop metaphor | no |
| **Kind** | code, one builder per desklet | no |
| **Theme** | `theme.json` | yes, this is the product |
| **Placement** | the user's prefs | theirs |

`shell` is a **desktop environment**, not a distro. Mint is Cinnamon, which is
structurally the Plasma shell. Pop!\_OS ships COSMIC, which genuinely is not any
of ours. Kali is a terminal. Ask which of the five it *is* before authoring.

---

## 2. Required minimum

```json
{
  "id": "mint-22",
  "name": "Linux Mint",
  "shell": "plasma",
  "palette": {
    "bgTop": "#2C2C2C", "bgBottom": "#1A1A1A", "bar": "#2F2F2F",
    "dock": "#CC2F2F2F", "accent": "#87BF3B", "onDark": "#FFFFFF"
  }
}
```

That is a complete, working theme. Everything else has a default keyed by
**shell**, so it will already have the right boot log family, the right splash
style, the right desklet skins and a 5x4 desktop grid.

**Author only where the distro genuinely differs.** `fedora-41` writes no
`desklets` block at all: it is a GNOME desktop, so it inherits GNOME's clock
face and looks right without a line of skin. That is the model working, not a
gap.

---

## 3. Every block

### `id`

Lowercase, digits and hyphens. **Never rename a shipped id.** It is the per-theme
prefs key and part of the icon cache id, so renaming orphans every override,
every hidden app and every desklet a user placed under it. If the icon block
changes, version the id (`ubuntu-24-04.v2`) instead — otherwise the native cache
serves the old shapes forever and the change looks unwired.

### `palette`

All six colours required. `#RRGGBB` or `#AARRGGBB`, **alpha first**, matching
Android rather than CSS.

`bgBottom` does more than it looks: it is the boot-log canvas, the splash
background and the drop shadow behind every bare desklet. A wrong value here
shows up as a boot screen that does not look like this distro.

### `typography`

Must match a family declared in `pubspec.yaml` **exactly**. Bundled today:
`Ubuntu`, `UbuntuMono`. An unknown family does not throw — Flutter silently
substitutes — so a typo here is invisible until someone looks closely.

### `logo`

Two variants, named for the **surface** they sit on, not for their own colour.
`light` is drawn as authored on a light surface; `dark` is tinted to
`palette.onDark`. Getting that backwards is the usual mistake.

### `layout`

`dock` is `left` | `bottom` | `off`. Ignored under the Aqua shell, which has one
dock position by definition.

`grid` is the **desktop** grid. Under the authentic decision it holds desklets
and never app icons. Omit it for 5x4 — the terminal theme does.

`iconScale` is clamped **0.7–1.4**. Distro icon sets are not drawn to one
standard: a Papirus-ish set sits well inside its keyline and reads small next to
a full-bleed Yaru icon at the same nominal size. This is the fix, and it is a
theme edit rather than a per-widget fudge.

### `icons`

Passed straight to native. The launcher never renders icons in Dart.

`backgroundColor: null` is **meaningful** and not the same as absent by
accident: it means keep the app's own adaptive background layer.

`backgroundGradientEnd` requires `backgroundColor` — that is the near end. Set
alone, the renderer ignores it.

Lookup order, most specific first: **hero** (hand-drawn, per distro) → **brand**
(CC0, shared) → **generator** (masks the app's own icon, always succeeds).

Licensing, because it has bitten already: Simple Icons is CC0, but CC0 covers
the **files**, not the trademarks. LinkedIn, Amazon, Microsoft, Adobe and Canva
are absent from it and must come from hero packs. Papirus and Numix are GPL-3.0
and **cannot ship over the CDN**. Yaru is CC-BY-SA, which is awkward if the
theme is sold. Icons8 is unusable — link-back required, redistribution
prohibited.

### `splash`

`durationMs` is clamped **400–1500**. A CDN theme does not get to decide your
desktop takes eight seconds to appear. Omit the whole block to inherit the
shell's default: dots on GNOME, bar on Plasma and Aqua, text on tiling, none on
the terminal.

### `boot`

The verbose boot log, opt-in per theme via the `verboseBoot` preference. Line
kinds: `ok` `warn` `fail` `plain` `dim` `grub` `grubSelected` `blank`.

`delayMs` on a line pauses **after** it, which is how you get the beat before
"Started Snap Daemon" that makes the log feel real. Use it two or three times,
not everywhere.

Write a log that is actually that distro's. Ubuntu has GRUB and snapd. Fedora
relabels SELinux and has no snap. Arch runs verbose mkinitcpio hooks. Anyone who
enables this feature knows the difference.

### `desklets`

```json
"desklets": {
  "offers":  ["clock", "monitor", "storage"],
  "starter": [{ "kind": "clock", "col": 0, "row": 0, "spanX": 3 }],
  "skins":   { "clock": { "timeSize": 60 } }
}
```

**`offers`** is what appears in this distro's picker. Omit to get the shipping
set.

**`starter`** is the desktop laid out the *first* time the theme is chosen, and
never again. This is why picking Arch gives you an Arch desktop instead of an
empty screen. No ids — they are minted on apply, so two installs of the same
pack cannot collide. A starter with `col` and `row` is placed **exactly** and
refused if it does not fit (an authored layout that silently reflows is worse
than one that reports a bad cell). Omit them and it is packed wherever it fits.

**`skins`** is **merged** over the shell default, not a replacement. A theme
that wants a bigger clock writes `{"timeSize": 60}` and inherits surface, font
and everything else. Surfaces: `bare` (no chrome, conky), `card` (Breeze),
`panel` (waybar module), `terminal` (command output).

Span limits are per kind, and a span is bounded by the **grid** as well: a
3-column theme cannot host a 4-wide fastfetch however generous the kind is.

---

## 4. Checklists

This section is the reason this document exists. Each of these has silently
half-shipped at least once.

### Adding a field to `IconStyle` — EIGHT places

Missing #4 or #7 fails **silently**: the field works once, then serves stale
bitmaps forever, which looks identical to it never being wired.

1. `pigeons/launcher_api.dart` — append at the **end** of the class, never insert
2. `ThemeSpec.fromJson`, the `icons` block
3. `EffectiveTheme.resolve` — rebuilds `IconStyle` field by field and drops anything unlisted
4. `EffectiveTheme.iconCacheId`
5. `IconRenderer.IconStyle` — a **second**, hand-written data class
6. `LauncherHostApiImpl.toRenderStyle`
7. `IconCache.fingerprint()`
8. the actual drawing
9. and now: `schema/theme.schema.json`

Regenerate: `dart run pigeon --input pigeons/launcher_api.dart`

**Never add a third enum to that schema.** Pigeon numbers enums *before*
classes, so a new one takes codec 131 and shoves `AppEntry`, `AppChangeEvent`,
`IconStyle`, `DeviceStats` and `StatCapabilities` each up by one. Every
enum-shaped value there (`brandTreatment`, `netTransport`) is a string for
exactly this reason.

Current codec ids: 129 `AppChangeReason`, 130 `IconTreatment`, 131 `AppEntry`,
132 `AppChangeEvent`, 133 `IconStyle`, 134 `DeviceStats`, 135 `StatCapabilities`.

### Adding a desklet kind

1. `DeskletKinds` — the const, with span limits and config defaults
2. `DeskletKinds.all` — append
3. a widget under `features/desklets/kinds/`
4. the switch in `buildDesklet`
5. `DeskletSkin.defaultFor` if it needs more than the generic per-shell look
6. `schema/theme.schema.json` — the `kindId` enum
7. this document
8. `theme.json` `offers` for the themes that should show it

Steps 6 and 8 are the ones that fail quietly: without 6 the validator rejects a
correct theme, without 8 the kind exists but nothing offers it.

### Adding a field to `LauncherPrefs`

Constructor, field, `copyWith` param, `copyWith` body, `clearing()` body,
`toJson`, `fromJson`, `operator ==`, `hashCode`. Nine.

`clearing()` and `hashCode` are the two that have actually been missed. A field
absent from `clearing()` is **dropped**, not left alone, because the constructor
defaults it — that is how `drawerScrollStyle` was being silently reset by every
unrelated clear. A field in `==` but not `hashCode` gives objects that compare
unequal yet hash the same, which bites in a Set or as a Map key.

Additive fields do **not** bump `schemaVersion`; `fromJson` tolerating their
absence is what makes them additive.

### Adding a bundled theme

1. `assets/themes/<id>/theme.json`
2. `pubspec.yaml` — **Flutter asset directories are not recursive.** Omitting
   this shipped a terminal theme that was never bundled, so selecting it fell
   back to Ubuntu silently.
3. `theme_registry.dart` — `bundledThemes`
4. `theme_catalog.dart` — the card, with `bundled: true`
5. `./scripts/validate_themes.sh`

---

## 5. Worked example: Ubuntu

```json
{
  "id": "ubuntu-24-04",
  "name": "Ubuntu",
  "version": "24.04",
  "shell": "gnome",
  "tier": "free",
  "minAppVersion": 6,

  "palette": {
    "bgTop": "#622A4C", "bgBottom": "#220817", "bar": "#1A171B",
    "dock": "#BD201B21", "accent": "#E95420", "onDark": "#FFFFFF"
  },
  "typography": { "display": "Ubuntu", "mono": "UbuntuMono" },
  "logo": {
    "light": "assets/svg/ubuntu2410_dark.svg",
    "dark":  "assets/svg/ubuntu2410.svg"
  },

  "layout": { "dock": "left", "topBar": true, "grid": { "rows": 5, "cols": 4 } },

  "icons": {
    "treatment": "roundedSquare",
    "cornerRadius": 0.22,
    "foregroundScale": 1.0,
    "backgroundColor": null,
    "monochromeTint": null,
    "heroPack": "yaru"
  },

  "wallpapers": ["assets/themes/ubuntu-24-04/wallpapers/numbat_color.webp"],

  "splash": { "style": "dots", "logo": "assets/svg/ubuntu2410.svg", "durationMs": 1100 },

  "boot": {
    "tailMs": 700,
    "lines": [
      { "kind": "grub", "text": "GNU GRUB  version 2.12" },
      { "kind": "grubSelected", "text": "*Ubuntu", "delayMs": 520 },
      { "kind": "blank", "text": "" },
      { "kind": "plain", "text": "Loading Linux 6.8.0-31-generic ..." },
      { "kind": "ok", "text": "Started D-Bus System Message Bus" },
      { "kind": "warn", "text": "Starting Snap Daemon ...", "delayMs": 520 },
      { "kind": "ok", "text": "Started GNOME Display Manager" },
      { "kind": "ok", "text": "Reached target Graphical Interface" }
    ]
  },

  "desklets": {
    "offers": ["clock", "monitor", "fastfetch", "network", "storage", "battery", "notes", "search"],
    "starter": [
      { "kind": "clock",   "page": 0, "col": 0, "row": 0, "spanX": 3, "spanY": 1 },
      { "kind": "monitor", "page": 0, "col": 2, "row": 0, "spanX": 2, "spanY": 2 }
    ],
    "skins": {
      "clock": {
        "surface": "bare", "font": "display",
        "timeSize": 60, "timeWeight": 200, "dateSize": 13,
        "letterSpacing": -2.5, "showDate": true
      }
    }
  }
}
```

---

## 6. Every clamp, in one place

| Field | Range | Enforced by |
|---|---|---|
| `layout.iconScale` | 0.7 – 1.4 | `IconSizing.parseScale` + schema |
| `splash.durationMs` | 400 – 1500 | `SplashSpec` constructor + schema |
| `layout.grid.rows/cols` | 1 – 12 | schema |
| `icons.cornerRadius` | 0 – 0.5 | schema |
| `icons.foregroundScale` | 0.4 – 1.2 | schema |
| `boot.lines[].delayMs` | 0 – 2000 | schema |
| `boot.tailMs` | 0 – 3000 | schema |
| desklet spans | per kind, and the grid | `DeskletLayout`, clamped on write |
| desklet `config` | per kind | `DeskletKind.read`, clamped on read |
| workspace count | 1 – 5 | `WorkspaceCount` |

The rule these follow: **content that drives UI gets validated.** A downloaded
theme is content. Where the schema and the runtime both enforce a range, the
schema tells the author and the runtime protects the user.
