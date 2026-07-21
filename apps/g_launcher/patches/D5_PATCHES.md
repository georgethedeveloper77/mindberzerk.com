# D5 — two deletions and a theme block

## 1. DELETE `lib/features/home/gnome/conky_tile.dart`

The monitor desklet replaces it. Same information, but placeable, resizable and
skinned per distro instead of nailed to the top right of one shell.

It also removes seven direct token reads (`Ubuntu.mono`, `Ubuntu.conkyPrimary`,
`Ubuntu.conkyDate`, `Ubuntu.conkyStat`, `Ubuntu.conkyRule`, `Ubuntu.orange`,
`Ubuntu.desktopTextShadow`). The copy in this thread carries all of them with no
`// theme-exempt:` marker, which `no_constants.sh` covers under `home/`. If your
working copy has already been converted, this deletion is still the right move;
if it has not, this closes it.

## 2. `lib/shells/gnome_shell.dart` — remove the hardcoded conky

```dart
const Positioned(top: 18, right: 18, child: ConkyTile()),
```

Delete that line and the `conky_tile.dart` import. The conky is now something
the user places, and the Ubuntu starter desktop can put one in that exact spot
if you want the out-of-box look unchanged:

```json
{ "kind": "monitor", "page": 0, "col": 2, "row": 0, "spanX": 2, "spanY": 2 }
```

## 3. `deviceInfoProvider` lives in the wrong file

`fastfetch` imports it from `design/terminal_tokens.dart` with a `show` clause,
because that is where it is. It is not a terminal concern: it is device info,
and now two shells read it. Worth moving to `system/` at some point. The `show`
keeps `Term.*` out of scope in the meantime so nothing here can read a token by
accident.

## 4. Theme blocks

`offers` already lists these kinds in the D3 snippets, so the picker picks them
up with no edit. Skins are optional — every new kind falls back to
`DeskletSkin._genericFor(shell)`, which gives bare on GNOME and Aqua, card on
Plasma, panel on tiling and terminal on TUI. That is already five different
looks per kind without authoring a line.

Author only where a distro genuinely differs. Two worth adding:

```json
"skins": {
  "monitor": { "surface": "bare", "alignRight": true, "rowSize": 11.5 },
  "storage": { "surface": "bare", "showTitle": true }
}
```

`alignRight` defaults true on the bare surface, which is what makes the monitor
read as a conky against the screen edge.
