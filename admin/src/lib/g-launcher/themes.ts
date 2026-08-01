import 'server-only';

import { deleteObject, getObject, putObject } from '@/lib/core/r2';
import { type IndexPack } from '@/lib/core/sign';
import type { AppId, LiveIndex } from '@/lib/core/catalogue';
import {
  validateDraft,
  type ThemeDraft,
  type ThemeSpecJson,
} from '@/lib/g-launcher/theme-spec';

// The shape, serializer and validators live in the client-safe schema module so
// the builder UI and this server layer can never sign different bytes than the
// preview shows. Re-exported so existing `from '@/lib/g-launcher/themes'` imports still work.
export * from '@/lib/g-launcher/theme-spec';

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

/**
 * Drafts, plus whether the bucket could be read at all.
 *
 * ─── WHY THIS IS A SECOND FUNCTION AND NOT A CHANGE TO [readMap] ────────────
 *
 * [readMap] is the merge base for [writeDraft], [deleteDraft] and
 * [ensureSeeded]. It must keep throwing, because a soft failure there hands a
 * writer an empty map and the next save replaces every draft in the bucket with
 * the one being edited. The same hazard `setListed` has, with more to lose.
 *
 * A PAGE needs the opposite. Throwing there means the whole screen dies in the
 * error boundary over a credential problem, which is what /themes has been
 * doing. So readers get a result and writers get an exception, from one
 * underlying read.
 *
 * `unreachable` is separate from an empty list on purpose. "No drafts yet" and
 * "we could not find out" look identical on screen and are not the same fact,
 * and conflating them is how the panel spent an afternoon reporting zero packs
 * on a bucket it simply could not open.
 */
export async function readAllDraftsSafe(
  app: AppId,
): Promise<{ drafts: ThemeDraft[]; unreachable: string | null }> {
  try {
    return { drafts: await readAllDrafts(app), unreachable: null };
  } catch (e) {
    return {
      drafts: [],
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
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

/**
 * [ensureSeeded], plus what to show when the bucket will not answer.
 *
 * ─── WHY THE SEEDS ARE THE FALLBACK AND NOT AN EMPTY LIST ───────────────────
 *
 * `ensureSeeded` reads and then WRITES, so a credential failure takes out both
 * halves and the whole page dies in the error boundary. Degrading to `[]` would
 * be the other mistake: the panel would report "no distros" for a launcher that
 * ships three inside its APK, which is the same lie the overview told when it
 * showed zero packs on an unreadable bucket.
 *
 * The seeds are the honest answer. They are compiled into this file, they are
 * transcribed from the APK, and they are on every device whatever R2 says. So
 * with the bucket down the page still shows Ubuntu, KDE and Terminal with real
 * previews, and the banner explains that nothing published is included.
 *
 * `unreachable` is separate from an empty list for the usual reason: "nothing
 * published yet" and "we could not find out" look identical on screen and only
 * one of them is safe to act on.
 */
export async function ensureSeededSafe(
  app: AppId,
): Promise<{ drafts: ThemeDraft[]; unreachable: string | null }> {
  try {
    return { drafts: await ensureSeeded(app), unreachable: null };
  } catch (e) {
    const seeds = app === 'g-launcher' ? [...SEED_FREE_THEMES] : [];
    return {
      drafts: seeds.sort((a, b) => a.id.localeCompare(b.id)),
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
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

/**
 * The icon packs that belong to a distro, split by whether each is actually in
 * the live index.
 *
 * EXTRACTED FROM THE DISTROS PAGE so the delete action and the page can never
 * disagree about what "this distro's icon packs" means. The entitlement is
 * authoritative where one exists: the distro's sku names exactly which packs
 * it grants, so a distro that later ships a second icon pack counts correctly
 * without anyone touching this. The `<base>-` prefix is only the fallback for
 * free distros, which have no entitlement to read.
 *
 * `pending` is a granted pack that has not shipped yet. The page counts it,
 * because the storefront advertises it and reporting zero would contradict the
 * bundle; a delete ignores it, because there is nothing in the index to pull.
 */
export function distroIconPackIds(
  live: LiveIndex,
  themePackId: string,
): { present: string[]; pending: string[] } {
  const base = themePackId.replace(/-theme$/, '');
  const grant = live.entitlements.find((e) => e.grants.includes(themePackId));
  const candidates = grant
    ? grant.grants.filter((g) => g !== themePackId)
    : live.packs
        .filter((p) => p.packId.startsWith(`${base}-`) && p.packId !== themePackId)
        .map((p) => p.packId);

  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const present: string[] = [];
  const pending: string[] = [];
  for (const id of candidates) {
    const p = live.packs.find((x) => x.packId === id);
    if (!p) pending.push(id);
    else if (iconTypes.has(p.packType)) present.push(id);
  }
  return { present, pending };
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