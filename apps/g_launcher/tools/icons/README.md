# Icon tooling

**For the full download-to-CDN sequence, see [RUNBOOK.md](RUNBOOK.md).**
This file covers the individual tools.

## sync-arcticons.mjs

Turns a local icon-set clone into two artifacts the admin panel reads. Runs on
this machine, never on App Hosting, which has no shell and no clone.

## Run

```bash
cd apps/g_launcher
node tools/icons/sync-arcticons.mjs \
  --set "$HOME/Documents/icon packs/Arcticons-main" \
  --packages tools/icons/packages.txt
```

`--packages` is a newline-delimited list of Android package ids. It scopes the
glyph bundle. Without it the whole set is bundled, which is 12.8 MB and is not
what the panel should fetch.

## Output

| file | contents | size |
|---|---|---|
| `out/index.json` | 32,951 packages to 13,623 drawing names | 1.25 MB, 0.40 MB gzipped |
| `out/glyphs.json` | art for the scoped slug set only | ~180 KB for a 193-icon pack |
| `out/glyphs-all.json` | every drawing, only with `--all` | 12.8 MB |

## Upload

```bash
npx wrangler@latest r2 object put \
  mindberzerk-cdn/g-launcher/icons/arcticons/index.json \
  --file tools/icons/out/index.json --remote \
  --content-type application/json --cache-control "public, max-age=300"
```

The `--remote` flag is required for wrangler v4 to act on the real bucket. This
uses account OAuth, so the rejected R2 S3 token does not block it.

## Licence

Arcticons ships its **app** under GPL-3.0 and its **icons** under CC BY-SA 4.0.
Only the second governs what is imported. BY-SA permits commercial use and
selling; it requires attribution to travel with the art and forces the same
licence onto derivatives, so a recoloured set is redistributable by whoever
receives it.

The scanner in `bulk-icons.ts` will not catch this on its own, because these
SVGs are bare geometry with no licence text. The attribution is therefore
written into `index.json` by this script and must reach `pack.json` through the
`attributed` lane.


---

# Taking a set off the internet

You downloaded a zip. Four questions, in order of how expensive they are to get
wrong.

```bash
node tools/icons/inspect-iconset.mjs --set ~/Downloads/iconpacks/Whatever \
  --packages tools/icons/packages.txt
```

## 1. Can it ship

**GPL and LGPL sets cannot, at any price, in any form.** Not recoloured, not
re-rendered, not converted to path data. A conversion is a derivative work and
inherits the licence. That covers **Papirus, Numix, Numix Circle and Flat
Remix**, so those four are dead ends no matter how good they look.

| licence | verdict |
|---|---|
| CC0, MIT, Apache-2.0 | ships freely |
| CC BY, CC BY-SA | ships with attribution in `pack.json` |
| GPL, LGPL, AGPL | cannot ship |
| none found | check by hand before doing anything |

## 2. Where its files are

The inspector finds the art directory by counting SVGs, not by name, because
every set names it differently: `icons`, `res/drawable`, `svg`, `scalable/apps`,
or the repository root.

## 3. What kind of art it is

- **Outlines** are what a tinted vector pack is for. Build it.
- **Multi-colour logos** are not. Tinting flattens every drawing to one colour,
  which loses the thing that makes the set look like itself. Ship it as a hero
  pack, as authored.
- **Raster only** cannot become a vector pack. Roughly 3.5 KB per icon per
  distro instead of 0.8 KB once.
- **More than one viewBox** needs splitting or normalising first. Drawings from
  different boxes render at different sizes with no error anywhere.

## 4. Then build it

With an appfilter, which is the set stating which app each drawing is for:

```bash
node tools/icons/build-vector-pack.mjs \
  --set ~/Downloads/iconpacks/Whatever --id whatever-line --name "Whatever"
```

Without one, which is every desktop icon theme:

```bash
node tools/icons/build-vector-pack.mjs \
  --set ~/Downloads/iconpacks/Whatever --id whatever-line \
  --match-index tools/icons/out/index.json
```

`--match-index` borrows the Arcticons mapping by drawing NAME. Icon sets
overwhelmingly agree on those names, so `whatsapp.svg` is WhatsApp everywhere.
It is a guess where an appfilter is a statement, and a name collision puts the
wrong drawing on an app silently, so review the result before publishing.

`--icons` and `--appfilter` override the auto-detection when a set ships two art
directories and the larger one is not the one you want.

Always finish with the contract check:

```bash
node tools/icons/pack-shape.test.mjs tools/icons/out/pack.json
```
