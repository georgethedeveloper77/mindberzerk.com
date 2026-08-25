# From a downloaded zip to a live CDN pack

Every step, in order, with what to check before moving on. Nothing here is
optional; the checks exist because each one has caught something real.

Assumes you keep sets in `~/Downloads/iconpacks/` and run from
`~/Documents/Projects/mindberzerk/apps/g_launcher`.

---

## 0. Once, before any of this

Refresh the device package list. Coverage numbers are meaningless without it.

```bash
./tools/icons/pull-packages.sh
```

It asks the device for everything with a **launcher entry**, not everything
installed. On a Samsung those differ enormously: a real S22 reports 499 packages,
of which most are overlays, shims and providers like
`com.android.internal.display.cutout.emulation.corner` or `com.android.cts.ctsshim`.
No icon set has a drawing for a display-cutout overlay and no launcher shows
one, so measuring coverage against them answers a question nobody asked.

**Do not use a raw redirect for this.** The obvious one-liner destroyed the list
twice:

```bash
adb shell pm list packages | sed 's/^package://' > tools/icons/packages.txt
```

The shell truncates the redirect target *before* running anything, so every
failure downstream leaves a zero-byte file and the error scrolls past above it.
The list is gone whether adb succeeded or not.

The script writes to a temp file, checks it, and only then moves it into place,
so a failed pull leaves the previous list untouched. It also handles three
things the one-liner does not:

- **`--user 0`.** On a Samsung with Secure Folder, a work profile or Dual
  Messenger, the foreground user is not 0 and adb has no permission there:
  `SecurityException: Shell does not have permission to access user 150`.
- **CRLF.** `adb shell` on macOS emits it, and a surviving carriage return makes
  every id miss the map, which reads as "the index is broken" rather than "the
  file has invisible characters in it".
- **Output that is not a package list.** A captured shell error is still a
  non-empty file, and would be reported downstream as malformed ids rather than
  as a failed pull.

---

## 1. Unpack it

```bash
cd ~/Downloads/iconpacks
unzip -o Whatever-main.zip -d .
```

Use `unzip` explicitly. Extracting through Finder creates a nested
`Whatever-main/Whatever-main/`, and every tool below then reports an empty set.

---

## 2. Inspect before you build

```bash
cd ~/Documents/Projects/mindberzerk/apps/g_launcher
node tools/icons/inspect-iconset.mjs \
  --set ~/Downloads/iconpacks/Whatever-main \
  --packages tools/icons/packages.txt
```

Read the **art licence** line first and stop if it says **CANNOT SHIP**. GPL,
LGPL and AGPL sets cannot go on the CDN in any form, including converted to path
data, because a conversion is a derivative work and inherits the licence. That
rules out **Papirus, Numix, Numix Circle and Flat Remix** permanently, however
good they look.

**Art licence and repo licence are different things.** Icon repositories
routinely license their build scripts and their drawings separately, and only
the drawings are being shipped. Arcticons is the example: the repo is GPL-3.0
and its README says plainly that all icons are CC BY-SA 4.0. The inspector looks
for the art licence in three places, most specific first: a licence file beside
the drawings, a README sentence naming both a licence and the art, then the root
file. When it falls back to the root it says so, and that is the case to check
by hand before abandoning a set.

Then read the art type:

| what it says | what to do |
|---|---|
| A line set | continue, this is the good case |
| Mostly multi-colour | not a vector pack; tinting flattens it to one colour |
| No vector art | hero pack of PNGs only, ~3.5 KB per icon per distro |
| More than one viewBox | normalise or split first, or half the set renders double size |

---

## 3. Build

With an appfilter, which is the set stating which app each drawing is for:

```bash
node tools/icons/build-vector-pack.mjs \
  --set ~/Downloads/iconpacks/Whatever-main \
  --id whatever-line --name "Whatever"
```

Without one, which is every desktop icon theme:

```bash
node tools/icons/build-vector-pack.mjs \
  --set ~/Downloads/iconpacks/Whatever-main \
  --id whatever-line --name "Whatever" \
  --match-index tools/icons/out/index.json
```

`--match-index` borrows the Arcticons mapping by drawing name. It is a guess
where an appfilter is a statement, and the report labels it as one. A name
collision puts the wrong drawing on an app silently, so review before
publishing.

**Read `dropped, no file` and the problem lines.** A handful is normal. Hundreds
means `--set` points at a partial clone.

---

## 4. Check the wire contract

```bash
node tools/icons/pack-shape.test.mjs tools/icons/out/pack.json
```

This is not a formality. It asserts that `icons` precedes `glyphs` in the file,
and that ordering is what lets the device stream the package map, intersect it
with what is installed, and skip the 13,000 drawings it has no app for.
Reversing those two keys is a one-line change that looks like formatting and
forces the whole pack resident in RAM on every device that installs it.

For a set you have not built before, also run the converter against all of it:

```bash
node tools/icons/svg-to-path.test.mjs ~/Downloads/iconpacks/Whatever-main/icons/white
```

`skipped elements: none` is the line that matters. A skipped element costs a
stroke silently, and there is no way to notice that across thousands of drawings
except by counting.

---

## 5. Sign, upload, publish

```bash
./tools/icons/publish-pack.sh tools/icons/out/arcticons-line --version 1
```

Eight steps, and every failure aborts **before** anything is uploaded. A
half-published pack is worse than an unpublished one: the bytes are live, the
index does not name them, and nothing on a device or in the panel explains why.

1. shape contract
2. sign the directory
3. verify, against the public key **derived from the key actually used**
4. read the **live** index
5. merge one entry in
6. re-sign the index
7. upload the pack
8. upload the index, last

`--dry-run` does everything except the two uploads and leaves the merged index
where you can read it.

### Why the merge is the step that matters

The index is one object naming every pack. Writing a fresh one instead of
merging into the live one unpublishes everything else, silently, and devices
that already downloaded those packs keep working so nobody notices for a while.

The script refuses to write an index it could not read. The only case where a
fresh one is correct is a genuine 404, and it says so out loud, because that is
indistinguishable from a typo in the URL until it has unpublished the catalogue.

### Flags

| flag | default |
|---|---|
| `--version` | required, must exceed what is published |
| `--type` | `brand` |
| `--min-app` | `6` |
| `--key` | `@$HOME/.mindberzerk/pack-signing.key` |
| `--key-id` | `mh-2026-07` |
| `--sku` | omit for free |

`MB_CDN`, `MB_BUCKET` and `MB_PREFIX` override the endpoints for staging.

`packType` is **`brand`**, not a new type. `PackManifest.KNOWN_PACK_TYPES`
already contains it, and a line pack IS a brand pack: path data resolved by
package id. Nothing about the manifest or the CDN index changes.

### On size

10.58 MB is fine. `PackVerifier` hashes with a stream rather than `readBytes()`,
and `BrandIconResolver` parses with `JsonReader`, so nothing in the chain ever
holds the whole file. Only `manifest.json` has a cap, at 256 KB, and it is a
handful of lines.

## 6. Point a distro at it

In the distro's `theme.json`:

```json
"icons": {
  "brandPack": "arcticons-line",
  "monochromeTint": "#367BF0"
}
```

`brandPack` selects the pack, `monochromeTint` colours it. Both are already in
`iconCacheId` and in `IconCache.fingerprint()`, so changing the tint re-keys
every cached bitmap for free. That is why a line pack needed no new `IconStyle`
field and no Pigeon regeneration.

Six distros, one pack, six hex values:

| distro | tint |
|---|---|
| Kali | `#367BF0` |
| Garuda | `#BD93F9` |
| Pop!_OS | `#48B9C7` |
| Ubuntu | `#E95420` |
| Mint | `#87CF3E` |
| Deepin | `#0081FF` |

---

## 7. Verify on the device

```bash
./gradlew assembleDebug
flutter run
adb shell cmd package set-home-activity com.mindhunter.g_launcher/.LauncherActivity
```

`flutter run` resets the default home app on every reinstall, so the last line
is not optional.

Then, in order:

1. **Clear the icon cache**, or the old bitmaps are served from disk and it
   looks exactly like the pack never arrived.
2. Check an app the set covers and an app it does not. The second should fall
   through to the generator, not go blank.
3. Check the **dock**, where icons render largest and thin strokes fail last.
4. Check on the cheapest device you have. The panel's Set health card says what
   the stroke lands at per density bucket; the phone is the only thing that
   confirms it.

---

## When something looks wrong

| symptom | first thing to check |
|---|---|
| Icons unchanged after publishing | version not bumped, or icon cache not cleared |
| Every icon square-ended and sharp-cornered | stroke cap and join not set; the pack is being drawn as a fill |
| Icons invisible on the wallpaper | no plate and the tint is close to the wallpaper; the panel warns on this |
| A few apps blank | that glyph failed to parse and fell through; check `pack-shape.test.mjs` |
| Launcher slow or killed on a budget phone | `icons` and `glyphs` reversed in the pack, forcing it resident |
