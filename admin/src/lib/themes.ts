import 'server-only';

import { deleteObject, getObject, putObject } from './r2';
import { isSafePackId, isSafeSku, type IndexPack } from './sign';
import type { AppId } from './catalogue';
import type { LiveIndex } from './catalogue';

/**
 * ITEM 1 - free themes as editable data.
 *
 * ## What this file is
 *
 * The panel's editable copy of a theme. A `ThemeDraft` is the whole thing a
 * human tweaks (name, palette, layout, price) BEFORE any signing happens. It is
 * deliberately separate from the two artefacts a device ever sees:
 *
 *   1. the signed `theme.json` PAYLOAD inside a pack, produced here by
 *      `canonicalThemeJson(draft.spec)`, and
 *   2. the pack's row in the signed `index.json`, produced at publish time from
 *      the draft's storefront fields (`title`, `summary`, `sku`, `packVersion`).
 *
 * Editing is cheap and frequent, so drafts are UNSIGNED and live at one plain
 * JSON file per app, exactly the pattern `site/content.json` and the coming
 * `registry.json` follow. Publishing is deliberate and rare, so it stays in the
 * pack route (item 2), which reads the draft, builds the payload, signs, and
 * merges the index. This file never signs anything.
 *
 * ## Why the three free themes need a draft at all
 *
 * Ubuntu, KDE and Terminal ship inside the APK, so they already work with no
 * network. But George wants to CHANGE them without a Play release, and the only
 * way a bundled theme changes on a live device is a CDN pack that overrides the
 * bundled asset (the merge in theme_catalog.dart takes a floor card's identity
 * but the catalogue's version). So each free theme gets a seeded draft here; it
 * is not published until edited and pushed on purpose. Until then the device
 * keeps using the APK copy, which is the safe default.
 *
 * ## The seeds are STRUCTURALLY exact, their COLOURS are approximate
 *
 * The three seeds below are the REAL bundled theme.json, transcribed verbatim
 * from the APK assets (assets/themes/<id>/theme.json), so publishing a free
 * theme reproduces its bundled look rather than a likeness. Their asset paths
 * are the APK-relative ones (assets/themes/.../foo.webp); flattening them to
 * bare pack filenames and uploading the wallpaper/logo binaries is a PUBLISH
 * concern handled in item 2, not something a draft needs to carry.
 *
 * `spec.seededFromPreview` stays as a flag for a theme created from scratch with
 * placeholder colours (item 2 may set it); it surfaces a "verify colours" tag.
 * The three real seeds do not set it.
 */

// The one file that holds every draft for an app. Not under a pack path, so it
// is never fetched by a device (devices read index.json + listed pack paths
// only) and never collides with the signed `index.json`.
const draftsKey = (app: AppId) => `${app}/admin/theme-drafts.json`;

// ── the draft shape ──────────────────────────────────────────────────────────

export type ShellName = 'gnome' | 'plasma' | 'tiling' | 'tui' | 'aqua';
export type ChromeName = 'adwaita' | 'breeze' | 'aqua' | 'generic';
export type TierName = 'free' | 'pro';
export type DockName = 'left' | 'bottom' | 'off';

export interface ThemePaletteJson {
  bgTop: string;
  bgBottom: string;
  bar: string;
  dock: string;
  accent: string;
  onDark: string;
}

export interface ThemeTypographyJson {
  display?: string | null;
  mono?: string | null;
}

export interface ThemeLayoutJson {
  dock: DockName;
  topBar: boolean;
  /** Optional: a shell with no icon grid (the terminal) omits it, and
   *  ThemeLayout.fromJson defaults rows/cols to 5/4 when absent. */
  grid?: { rows: number; cols: number };
  iconScale?: number;
}

/**
 * The theme.json body: every field ThemeSpec.fromJson reads, no more.
 *
 * `palette` is REQUIRED because fromJson does `json['palette'] as Map` with no
 * fallback and throws on absence. Everything else has a Dart-side default, so it
 * is optional here and omitted from the payload when unset.
 *
 * `icons`, `logo`, `boot`, `splash`, `desklets` are PASS-THROUGH. The panel does
 * not need to understand their internals to store and re-emit them; it needs
 * that only to draw form fields, which is items 2 and 3. Carrying them opaque
 * means a real bundled theme.json pasted over a seed keeps its authored boot log
 * and splash untouched, and a seed that omits them lets the app fall back to
 * BootSpec/SplashSpec.defaultForShell, which is the documented graceful path.
 */
export interface ThemeSpecJson {
  id: string;
  name: string;
  version: string; // DISPLAY string, e.g. '24.04'. Not the pack's integer version.
  shell: ShellName;
  tier: TierName;
  chromeFamily?: ChromeName | null;
  palette: ThemePaletteJson;
  typography?: ThemeTypographyJson | null;
  layout: ThemeLayoutJson;
  icons?: Record<string, unknown> | null;
  logo?: unknown; // string | {light,dark} | null
  wallpapers: string[];
  minAppVersion: number;
  boot?: unknown;
  splash?: unknown;
  desklets?: unknown;

  /** Set on a seed still carrying preview-derived colours. Cleared once a real
   *  theme.json is pasted in. Advisory only; never emitted to the payload. */
  seededFromPreview?: boolean;
}

export interface ThemeDraft {
  /** The pack id / specId, e.g. 'ubuntu-24-04'. Also the draft's key. */
  id: string;
  /** Index + card title, e.g. 'Ubuntu'. */
  title: string;
  /** Index summary line, e.g. '24.04 · GNOME'. */
  summary: string;
  /** Play product id that unlocks it, or null for free. Matches isSafeSku. */
  sku: string | null;
  /** True for the three that ship in the APK. Informational for the UI. */
  bundled: boolean;
  /** Monotonic integer pack version. Bumped on publish, never reused. */
  packVersion: number;
  /** The theme.json body. */
  spec: ThemeSpecJson;
  /** Unix seconds of the last draft write, for the listing's sort/label. */
  updatedAt: number;
}

// ── storage ──────────────────────────────────────────────────────────────────

type DraftMap = Record<string, ThemeDraft>;

async function readMap(app: AppId): Promise<DraftMap> {
  const bytes = await getObject(draftsKey(app));
  if (!bytes) return {};
  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    // A hand-corrupted file must not read as "no drafts" and get silently
    // overwritten on the next save. Anything not a plain object is refused.
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as DraftMap;
    }
    throw new Error('theme-drafts.json is not an object');
  } catch (e) {
    throw new Error(
      `theme-drafts.json for ${app} did not parse; refusing to overwrite. ${(e as Error).message}`,
    );
  }
}

async function writeMap(app: AppId, map: DraftMap): Promise<void> {
  // Pretty-printed and stable-keyed so two saves diff cleanly in the bucket.
  const ordered: DraftMap = {};
  for (const id of Object.keys(map).sort()) ordered[id] = map[id];
  await putObject(
    draftsKey(app),
    Buffer.from(JSON.stringify(ordered, null, 2) + '\n', 'utf8'),
    'application/json',
  );
}

export async function readAllDrafts(app: AppId): Promise<ThemeDraft[]> {
  const map = await readMap(app);
  return Object.values(map).sort((a, b) => a.id.localeCompare(b.id));
}

export async function readDraft(app: AppId, id: string): Promise<ThemeDraft | null> {
  const map = await readMap(app);
  return map[id] ?? null;
}

export async function writeDraft(app: AppId, draft: ThemeDraft): Promise<void> {
  const problems = validateDraft(draft);
  if (problems.length) {
    throw new Error(`theme draft '${draft.id}' is invalid:\n- ${problems.join('\n- ')}`);
  }
  const map = await readMap(app);
  map[draft.id] = { ...draft, updatedAt: Math.floor(Date.now() / 1000) };
  await writeMap(app, map);
}

export async function deleteDraft(app: AppId, id: string): Promise<void> {
  const map = await readMap(app);
  if (!(id in map)) return;
  delete map[id];
  await writeMap(app, map);
  // The unsigned draft file is the only thing removed. A published pack is left
  // on R2 and in the index on purpose: pulling a theme from the store is a
  // separate, deliberate unpublish (item 6 of an earlier phase), not a
  // side-effect of tidying the drafts list.
}

/**
 * Ensure the three free themes have a draft, writing any that are missing.
 *
 * Idempotent and additive: an existing draft is never touched (George may have
 * already edited Ubuntu's summary), only absent ones are seeded. Returns the
 * full draft list so the page makes one round trip, not two.
 */
export async function ensureSeeded(app: AppId): Promise<ThemeDraft[]> {
  if (app !== 'g-launcher') return readAllDrafts(app);
  const map = await readMap(app);
  let changed = false;
  for (const seed of SEED_FREE_THEMES) {
    if (!map[seed.id]) {
      map[seed.id] = seed;
      changed = true;
    }
  }
  if (changed) await writeMap(app, map);
  return Object.values(map).sort((a, b) => a.id.localeCompare(b.id));
}

// ── the canonical theme.json serializer ──────────────────────────────────────

/**
 * The exact bytes that become the `theme.json` payload inside a theme pack.
 *
 * Fixed key order and two-space indent so identical content always produces
 * identical bytes, which keeps the manifest sha256 stable across re-publishes.
 * Only keys ThemeSpec.fromJson reads are emitted; optional blocks are dropped
 * when unset so a free theme's payload stays as lean as its bundled original.
 *
 * `seededFromPreview` is stripped: it is an editor hint, not part of the theme.
 */
export function canonicalThemeJson(spec: ThemeSpecJson): string {
  const out: Record<string, unknown> = {};
  out.id = spec.id;
  out.name = spec.name;
  if (spec.version) out.version = spec.version;
  out.shell = spec.shell;
  out.tier = spec.tier;
  if (spec.chromeFamily) out.chromeFamily = spec.chromeFamily;

  out.palette = {
    bgTop: spec.palette.bgTop,
    bgBottom: spec.palette.bgBottom,
    bar: spec.palette.bar,
    dock: spec.palette.dock,
    accent: spec.palette.accent,
    onDark: spec.palette.onDark,
  };

  if (spec.typography && (spec.typography.display || spec.typography.mono)) {
    const t: Record<string, string> = {};
    if (spec.typography.display) t.display = spec.typography.display;
    if (spec.typography.mono) t.mono = spec.typography.mono;
    out.typography = t;
  }

  out.layout = {
    dock: spec.layout.dock,
    topBar: spec.layout.topBar,
    ...(spec.layout.grid
      ? { grid: { rows: spec.layout.grid.rows, cols: spec.layout.grid.cols } }
      : {}),
    ...(spec.layout.iconScale != null ? { iconScale: spec.layout.iconScale } : {}),
  };

  if (spec.icons && Object.keys(spec.icons).length) out.icons = spec.icons;
  if (spec.logo != null) out.logo = spec.logo;
  // Omit at their parse-time defaults so a generated theme.json diffs cleanly
  // against a hand-authored one: fromJson reads absent wallpapers as [] and
  // absent minAppVersion as 0, so emitting them adds noise, not meaning.
  if (spec.wallpapers && spec.wallpapers.length) out.wallpapers = spec.wallpapers;
  if (spec.minAppVersion) out.minAppVersion = spec.minAppVersion;
  if (spec.boot != null) out.boot = spec.boot;
  if (spec.splash != null) out.splash = spec.splash;
  if (spec.desklets != null) out.desklets = spec.desklets;

  return JSON.stringify(out, null, 2) + '\n';
}

// ── validation, failing at edit time so publish never sees a bad draft ────────

const HEX = /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
const SHELLS: ShellName[] = ['gnome', 'plasma', 'tiling', 'tui', 'aqua'];

function colourProblem(label: string, v: string): string | null {
  return HEX.test(v) ? null : `${label} '${v}' is not #RRGGBB or #AARRGGBB`;
}

/** Everything the device or the signer would reject, caught here first. */
export function validateDraft(draft: ThemeDraft): string[] {
  const p: string[] = [];
  const s = draft.spec;

  if (!isSafePackId(draft.id)) p.push(`id '${draft.id}' is not a safe pack id`);
  if (draft.id !== s.id) p.push(`draft id '${draft.id}' != spec.id '${s.id}'`);
  if (!draft.title.trim()) p.push('title is empty');
  if (draft.sku != null && !isSafeSku(draft.sku)) p.push(`sku '${draft.sku}' is unsafe`);
  if (!Number.isInteger(draft.packVersion) || draft.packVersion < 1) {
    p.push('packVersion must be an integer >= 1');
  }

  if (!s.name.trim()) p.push('spec.name is empty');
  if (!SHELLS.includes(s.shell)) p.push(`shell '${s.shell}' is unknown`);
  if (s.tier !== 'free' && s.tier !== 'pro') p.push(`tier '${s.tier}' is unknown`);

  if (!s.palette) {
    // The one field with no Dart fallback; its absence throws at parse.
    p.push('palette is required (ThemeSpec.fromJson throws without it)');
  } else {
    for (const [k, v] of Object.entries(s.palette)) {
      const problem = colourProblem(`palette.${k}`, v as string);
      if (problem) p.push(problem);
    }
  }

  if (s.minAppVersion != null && (!Number.isInteger(s.minAppVersion) || s.minAppVersion < 0)) {
    p.push('minAppVersion must be a non-negative integer');
  }
  if (s.layout?.iconScale != null && (s.layout.iconScale < 0.7 || s.layout.iconScale > 1.4)) {
    // Mirrors IconSizing.parseScale so a slider the app will silently clamp is
    // flagged here instead of quietly changing on the device.
    p.push('layout.iconScale must be within 0.7-1.4');
  }
  return p;
}

// ── the listing merge (pure) ─────────────────────────────────────────────────

export interface ThemeRow {
  id: string;
  title: string;
  summary: string;
  sku: string | null;
  free: boolean;
  bundled: boolean;
  hasDraft: boolean;
  draftVersion: number | null;
  publishedVersion: number | null;
  /** Draft exists and is unpublished, or ahead of what is live. */
  needsPublish: boolean;
  /** Short labels for the row's tag strip. */
  tags: string[];
}

/**
 * One row per theme, unioning the editable drafts with whatever theme packs are
 * actually live in the signed index. A theme published out-of-band (the CLI, a
 * second admin) shows up even with no local draft, so the page can never claim
 * a live theme does not exist.
 */
export function mergeThemeRows(drafts: ThemeDraft[], live: LiveIndex): ThemeRow[] {
  const livePacks = new Map<string, IndexPack>();
  for (const pk of live.packs) if (pk.packType === 'theme') livePacks.set(pk.packId, pk);

  const rows = new Map<string, ThemeRow>();

  for (const d of drafts) {
    const pub = livePacks.get(d.id) ?? null;
    const free = d.sku == null;
    rows.set(d.id, {
      id: d.id,
      title: d.title,
      summary: d.summary,
      sku: d.sku,
      free,
      bundled: d.bundled,
      hasDraft: true,
      draftVersion: d.packVersion,
      publishedVersion: pub ? pub.version : null,
      needsPublish: !pub || d.packVersion > pub.version,
      tags: rowTags({
        bundled: d.bundled,
        free,
        publishedVersion: pub ? pub.version : null,
        needsPublish: !pub || d.packVersion > pub.version,
        seeded: d.spec.seededFromPreview === true,
      }),
    });
  }

  // Live theme packs with no draft: surface them read-only so nothing is hidden.
  for (const [id, pk] of livePacks) {
    if (rows.has(id)) continue;
    const free = !pk.sku;
    rows.set(id, {
      id,
      title: pk.title || id,
      summary: pk.summary ?? '',
      sku: pk.sku ?? null,
      free,
      bundled: false,
      hasDraft: false,
      draftVersion: null,
      publishedVersion: pk.version,
      needsPublish: false,
      tags: rowTags({ bundled: false, free, publishedVersion: pk.version, needsPublish: false, seeded: false }),
    });
  }

  return [...rows.values()].sort((a, b) => {
    // Bundled first (they head the app's own grid), then by title.
    if (a.bundled !== b.bundled) return a.bundled ? -1 : 1;
    return a.title.localeCompare(b.title);
  });
}

function rowTags(o: {
  bundled: boolean;
  free: boolean;
  publishedVersion: number | null;
  needsPublish: boolean;
  seeded: boolean;
}): string[] {
  const t: string[] = [];
  t.push(o.free ? 'Free' : 'Paid');
  if (o.bundled) t.push('Bundled');
  t.push(o.publishedVersion == null ? 'Not published' : `Live v${o.publishedVersion}`);
  if (o.needsPublish && o.publishedVersion != null) t.push('Draft ahead');
  if (o.seeded) t.push('Seed - verify colours');
  return t;
}

// ── the three free-theme seeds ───────────────────────────────────────────────
//
// Transcribed verbatim from the APK's assets/themes/<id>/theme.json. Asset paths
// are the APK-relative originals; publish (item 2) flattens them to bare pack
// filenames and uploads the referenced binaries. No seededFromPreview flag: these
// are the real themes, not placeholders.

const SEED_FREE_THEMES: ThemeDraft[] = [
  {
    id: 'ubuntu-24-04',
    title: "Ubuntu",
    summary: "24.04 · GNOME",
    sku: null,
    bundled: true,
    packVersion: 1,
    updatedAt: 0,
    spec: {
          "id": "ubuntu-24-04",
          "name": "Ubuntu",
          "version": "24.04",
          "shell": "gnome",
          "tier": "free",
          "minAppVersion": 6,
          "palette": {
            "bgTop": "#622A4C",
            "bgBottom": "#220817",
            "bar": "#1A171B",
            "dock": "#BD201B21",
            "accent": "#E95420",
            "onDark": "#FFFFFF"
          },
          "typography": {
            "display": "Ubuntu",
            "mono": "UbuntuMono"
          },
          "logo": {
            "light": "assets/themes/ubuntu-24-04/logo_light.svg",
            "dark": "assets/themes/ubuntu-24-04/logo_dark.svg"
          },
          "layout": {
            "dock": "left",
            "topBar": true,
            "grid": {
              "rows": 5,
              "cols": 4
            }
          },
          "icons": {
            "treatment": "roundedSquare",
            "cornerRadius": 0.22,
            "foregroundScale": 1,
            "backgroundColor": null,
            "monochromeTint": null,
            "heroPack": "yaru"
          },
          "wallpapers": [
            "assets/themes/ubuntu-24-04/wallpapers/numbat_color.webp",
            "assets/themes/ubuntu-24-04/wallpapers/numbat_dark.webp",
            "assets/themes/ubuntu-24-04/wallpapers/noble_light.webp"
          ],
          "splash": {
            "style": "dots",
            "durationMs": 1100
          },
          "desklets": {
            "offers": [
              "clock",
              "monitor",
              "fastfetch",
              "network",
              "storage",
              "battery",
              "notes",
              "search"
            ],
            "starter": [
              {
                "kind": "clock",
                "page": 0,
                "col": 0,
                "row": 0,
                "spanX": 3,
                "spanY": 1
              },
              {
                "kind": "monitor",
                "page": 0,
                "col": 2,
                "row": 1,
                "spanX": 2,
                "spanY": 3
              }
            ],
            "skins": {
              "monitor": {
                "surface": "bare",
                "font": "mono",
                "showTitle": true
              }
            }
          },
          "boot": {
            "tailMs": 700,
            "lines": [
              {
                "kind": "grub",
                "text": "GNU GRUB  version 2.12"
              },
              {
                "kind": "grubSelected",
                "text": "*Ubuntu",
                "delayMs": 520
              },
              {
                "kind": "blank",
                "text": ""
              },
              {
                "kind": "plain",
                "text": "Loading Linux 6.8.0-31-generic ..."
              },
              {
                "kind": "plain",
                "text": "Loading initial ramdisk ..."
              },
              {
                "kind": "blank",
                "text": ""
              },
              {
                "kind": "ok",
                "text": "Started Load Kernel Modules"
              },
              {
                "kind": "ok",
                "text": "Mounted /boot/efi"
              },
              {
                "kind": "ok",
                "text": "Reached target Local File Systems"
              },
              {
                "kind": "ok",
                "text": "Started udev Kernel Device Manager"
              },
              {
                "kind": "ok",
                "text": "Started D-Bus System Message Bus"
              },
              {
                "kind": "ok",
                "text": "Started Network Manager"
              },
              {
                "kind": "warn",
                "text": "Starting Snap Daemon ...",
                "delayMs": 520
              },
              {
                "kind": "ok",
                "text": "Started Snap Daemon"
              },
              {
                "kind": "ok",
                "text": "Started User Login Management"
              },
              {
                "kind": "ok",
                "text": "Started GNOME Display Manager"
              },
              {
                "kind": "ok",
                "text": "Reached target Graphical Interface"
              }
            ]
          }
        } as ThemeSpecJson,
  },
  {
    id: 'terminal',
    title: "Terminal",
    summary: "type-to-launch",
    sku: null,
    bundled: true,
    packVersion: 1,
    updatedAt: 0,
    spec: {
          "id": "terminal",
          "name": "Terminal",
          "version": "type-to-launch",
          "shell": "tui",
          "tier": "free",
          "palette": {
            "bgTop": "#080D08",
            "bgBottom": "#080D08",
            "bar": "#0E1A0E",
            "dock": "#0E1A0E",
            "accent": "#FFB000",
            "onDark": "#C8D8C8"
          },
          "typography": {
            "display": "Ubuntu",
            "mono": "UbuntuMono"
          },
          "layout": {
            "dock": "off",
            "topBar": false
          },
          "boot": {
            "tailMs": 500,
            "lines": [
              {
                "kind": "dim",
                "text": "[    0.000000] booting g_launcher tty ..."
              },
              {
                "kind": "ok",
                "text": "mounted /proc /sys /dev"
              },
              {
                "kind": "ok",
                "text": "started device stats collector"
              },
              {
                "kind": "ok",
                "text": "started battery monitor"
              },
              {
                "kind": "ok",
                "text": "loaded UbuntuMono glyphs"
              },
              {
                "kind": "ok",
                "text": "reached target multi-user"
              },
              {
                "kind": "blank",
                "text": ""
              },
              {
                "kind": "plain",
                "text": "g-tty login: user (automatic)"
              },
              {
                "kind": "plain",
                "text": "Last login: now on tty1"
              }
            ]
          }
        } as ThemeSpecJson,
  },
  {
    id: 'kde-plasma-6',
    title: "KDE Plasma",
    summary: "6 · Breeze",
    sku: null,
    bundled: true,
    packVersion: 1,
    updatedAt: 0,
    spec: {
          "id": "kde-plasma-6",
          "name": "KDE Plasma",
          "version": "6",
          "shell": "plasma",
          "tier": "free",
          "minAppVersion": 6,
          "palette": {
            "bgTop": "#1B2733",
            "bgBottom": "#151A1F",
            "bar": "#31363B",
            "dock": "#CC2A2E32",
            "accent": "#3DAEE9",
            "onDark": "#FCFCFC"
          },
          "typography": {
            "display": "Ubuntu",
            "mono": "UbuntuMono"
          },
          "layout": {
            "dock": "bottom",
            "topBar": false,
            "grid": {
              "rows": 5,
              "cols": 4
            }
          },
          "icons": {
            "treatment": "squircle",
            "cornerRadius": 0.28,
            "foregroundScale": 1,
            "backgroundColor": "#31363B"
          },
          "wallpapers": [
            "assets/themes/kde-plasma-6/wallpapers/kde_breeze.webp"
          ],
          "boot": {
            "tailMs": 600,
            "lines": [
              {
                "kind": "plain",
                "text": "Loading Linux ..."
              },
              {
                "kind": "plain",
                "text": "Loading initial ramdisk ..."
              },
              {
                "kind": "blank",
                "text": ""
              },
              {
                "kind": "ok",
                "text": "Started Load Kernel Modules"
              },
              {
                "kind": "ok",
                "text": "Reached target Local File Systems"
              },
              {
                "kind": "ok",
                "text": "Started udev Kernel Device Manager"
              },
              {
                "kind": "ok",
                "text": "Started D-Bus System Message Bus"
              },
              {
                "kind": "ok",
                "text": "Started NetworkManager"
              },
              {
                "kind": "ok",
                "text": "Started Bluetooth Service"
              },
              {
                "kind": "warn",
                "text": "Starting Simple Desktop Display Manager ...",
                "delayMs": 500
              },
              {
                "kind": "ok",
                "text": "Started Simple Desktop Display Manager"
              },
              {
                "kind": "ok",
                "text": "Reached target Graphical Interface"
              }
            ]
          }
        } as ThemeSpecJson,
  },
];