# D7 — schema contract

```
schema/theme.schema.json      the contract
docs/theme_authoring.md       the guide, and the checklists
scripts/validate_themes.sh    fourth in the family
```

`assets/` is NOT in this zip: the six theme.json files are already correct and
unchanged. They were reconstructed here only to run the validator against them.

## Verified, not asserted

Ran against all six bundled themes:

```
  ok    themes/aqua/theme.json
  ok    themes/arch-hyprland/theme.json
  ok    themes/fedora-41/theme.json
  ok    themes/kde-plasma-6/theme.json
  ok    themes/terminal/theme.json
  ok    themes/ubuntu-24-04/theme.json

all 6 themes valid
```

And against nine deliberately broken copies, all nine caught with the exact
path named:

| mistake | reported as |
|---|---|
| `"splsh"` typo | `(root): Additional properties are not allowed ('splsh' was unexpected)` |
| `"E95420"` (no `#`) | `palette.accent: does not match '^#(...)$'` |
| `"shell": "cosmic"` | `shell: not one of [gnome, plasma, tiling, tui, aqua]` |
| `durationMs: 8000` | `splash.durationMs: greater than the maximum of 1500` |
| `"kind": "okay"` | `boot.lines.0.kind: not one of [ok, warn, ...]` |
| `"offers": ["clcok"]` | `desklets.offers.0: not one of [clock, monitor, ...]` |
| `iconScale: 2.5` | `layout.iconScale: greater than the maximum of 1.4` |
| `/sdcard/pic.webp` | `wallpapers.0: does not match '^assets/.+'` |
| starter with no kind | `desklets.starter.0: 'kind' is a required property` |

## The one design decision

`additionalProperties: false` everywhere, which is the OPPOSITE of what the app
does. The runtime must ignore an unknown key so a downgrade cannot black-screen
a home screen. The validator runs over files we wrote, where that same tolerance
is what makes a typo invisible for a month.

Strict where the app is lenient, and only over our own files.

The one exception is `desklets.skins.*`, which stays open: skin props are
free-form by design (`num_`/`flag`/`text` read with fallbacks), and that is the
single place where a new key must not need a schema edit.

## Requires

`pip install jsonschema`. The script checks and prints the install line rather
than failing obscurely. If you would rather it ran on node like the admin panel,
ajv-cli is a drop-in swap; the schema is plain Draft 2020-12.

## Two loose ends spotted in the tree

1. `assets/THEME_BLOCKS.md` is sitting in `assets/`. It was a note, not an
   asset. Move it to `docs/` — and check whether `pubspec.yaml` lists `assets/`
   itself, because if it does that markdown is being shipped inside the APK.

2. The uploaded `ubuntu-24-04/theme.json` still has no `desklets` block, so the
   D3/D5 snippets have not been applied yet. The validator passes either way
   (the block is optional), but Ubuntu will come up with an empty desktop until
   it lands.

## And one that keeps recurring

The literal `{schema,docs,scripts}` directory appeared in this container twice
while building this, for the same reason `lib/features/{setup,themes}` and the
Kotlin `{apps,icons}` exist in your repo: `mkdir -p` run under `sh` does not
expand braces, only `bash` does. Worth a `#!/usr/bin/env bash` shebang on any
script that uses them.
