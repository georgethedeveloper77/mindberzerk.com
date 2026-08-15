import 'server-only';

import { deleteObject, getObject, listPrefix, putObject } from '@/lib/core/r2';
import type { AppId } from '@/lib/core/catalogue';

/**
 * ICON PACK DRAFTS, so a pack does not have to be finished in one sitting.
 *
 * ## The problem
 *
 * `IconBuilder` holds everything in `useState`, image blobs included, and its
 * only exit is publish. Close the tab and an afternoon of matching icons to
 * packages is gone. A pack of 200 icons is not a one-sitting job.
 *
 * ## Where the images live, and why not inline
 *
 * Assets go to `<app>/admin/icon-drafts/<packId>/<file>` and the metadata to
 * `<app>/admin/icon-drafts.json`, mirroring theme drafts.
 *
 * The alternative was base64 inside the JSON, which is one object and no
 * cleanup, but turns a 200-icon draft into a multi-megabyte document that must
 * be read and rewritten in full on every save, against the one service in this
 * stack that is currently unreliable. Separate assets also mean REOPENING A
 * DRAFT IS THE SAME CODE AS REOPENING A PUBLISHED PACK: both fetch images over
 * public HTTPS by URL, which `readPublishedHeroPack` already does.
 *
 * ## Nothing here is ever swept
 *
 * `orphanReport` never lists anything under `admin/`, so a half-finished draft
 * cannot be deleted by the orphan sweep. Draft assets are removed only when the
 * draft is deleted or replaced, which this module does explicitly.
 *
 * ## Read before write, always
 *
 * `readDrafts` THROWS when the bucket cannot be read, and the writer does not
 * catch it. That is deliberate and is the same rule the theme drafts follow: a
 * failed read must never become the merge base for a write, because the write
 * is a whole-document replace and would erase every other draft. A save that
 * fails loudly is recoverable; one that succeeds against an empty base is not.
 */

const KEY = (app: AppId) => `${app}/admin/icon-drafts.json`;
const ASSET_DIR = (app: AppId, packId: string) => `${app}/admin/icon-drafts/${packId}`;

export interface IconDraftIcon {
  /** The Android package this icon is for. */
  pkg: string;
  /** The bare filename inside the draft's asset directory. */
  file: string;
}

export interface IconDraft {
  packId: string;
  name: string;
  minAppVersion: number;
  masked: boolean;
  /** Blank means free, same as the published pack. */
  sku: string;
  /** Preview-only, not part of pack.json. Kept so a reopened draft looks the
   *  same as the one you left. */
  plate: string;
  radius: number;
  /**
   * The mask previewed behind the art. One of ICON_TREATMENTS.
   *
   * ─── PREVIEW-ONLY, AND THAT IS NOT A LIMITATION ─────────────────────────
   *
   * A hero pack cannot carry a shape. `HeroIconResolver` reads an id, a name,
   * one `masked` flag and a package-to-filename map, and nothing else; the
   * SHAPE comes from the theme's `icons.treatment`, which is a property of the
   * distro wearing the pack rather than of the pack itself. The same art is
   * clipped to a circle under one distro and a squircle under another, and
   * that is the design.
   *
   * So this joins `plate` and `radius` as an author's-eye setting: it says
   * which distro's mask you want to LOOK at while you work. Naming the six
   * real treatments rather than offering a free-form percentage means what you
   * preview is a shape the device can actually apply.
   *
   * Optional so a draft written before this field existed still parses; the
   * reader below fills it.
   */
  shape?: string;
  icons: IconDraftIcon[];
  updatedAt: number;
  /**
   * The pack version this draft's content was last published as, or absent.
   *
   * ─── WHY A DRAFT HAS TO KNOW THIS ───────────────────────────────────────
   *
   * Publishing does not touch the draft store. `IconBuilder.publish` writes a
   * pack and leaves `icon-drafts.json` exactly as it was, which is correct:
   * the draft carries `plate`, `radius` and `shape`, and `pack.json` carries
   * none of them, so deleting the draft on publish would throw away the
   * preview settings the draft exists to preserve.
   *
   * The cost was that "a draft exists" and "a draft is AHEAD of what is live"
   * became the same fact. Every screen read the first and reported the second,
   * so the moment a pack was published its own builder said "draft ahead of
   * v8, publishing writes v9" against a v8 it had just written, permanently.
   *
   * This is the missing bit: the version the draft's content became. Equal to
   * the live version means the draft MATCHES what devices have; absent or
   * lower means there is genuinely newer work here.
   *
   * CLEARED BY EVERY SAVE, which falls out of [writeIconDraft] taking the
   * field from its caller rather than merging it: pressing Save draft is a
   * statement that this content is not what was published, whether or not the
   * bytes happen to differ. Honest in the direction that matters, since the
   * failure it replaces was claiming unpublished work that did not exist.
   */
  publishedAtVersion?: number;
}

type DraftMap = Record<string, IconDraft>;

/** THROWS on an unreadable bucket. See the note above; this is load-bearing. */
async function readDrafts(app: AppId): Promise<DraftMap> {
  const bytes = await getObject(KEY(app));
  if (!bytes) return {};
  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as { drafts?: DraftMap };
    return parsed.drafts && typeof parsed.drafts === 'object' ? parsed.drafts : {};
  } catch {
    // A corrupt document is NOT an empty one. Refusing here means a save cannot
    // silently replace an unparseable file that may still hold real work.
    throw new Error('icon-drafts.json is present but does not parse. Fix it in the bucket first.');
  }
}

export interface IconDraftsResult {
  drafts: IconDraft[];
  /** Distinct from an empty list: one means none exist, the other unknown. */
  unreachable: string | null;
}

/** For pages. Never throws, so an unreadable bucket does not take a list down. */
export async function readIconDraftsSafe(app: AppId): Promise<IconDraftsResult> {
  try {
    const map = await readDrafts(app);
    return {
      drafts: Object.values(map).sort((a, b) => b.updatedAt - a.updatedAt),
      unreachable: null,
    };
  } catch (e) {
    return { drafts: [], unreachable: (e as Error).message || 'The bucket could not be read.' };
  }
}

export async function readIconDraft(app: AppId, packId: string): Promise<IconDraft | null> {
  try {
    const map = await readDrafts(app);
    return map[packId] ?? null;
  } catch {
    return null;
  }
}

/**
 * Bucket key for one draft asset.
 *
 * EXPORTED because `pack-rename.ts` reads draft bytes back out of R2 directly
 * rather than over public HTTPS, and a second literal of this path in that file
 * is exactly the two-copies problem `publish-core.ts` exists to prevent: change
 * the directory here and the rename would silently read nothing.
 */
export function draftAssetKey(app: AppId, packId: string, file: string): string {
  return `${ASSET_DIR(app, packId)}/${file}`;
}

/** Public URL for one draft asset, for rehydrating the builder in the browser. */
export function draftAssetUrl(app: AppId, packId: string, file: string): string {
  const base = (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
  return `${base}/${ASSET_DIR(app, packId)}/${encodeURIComponent(file)}`;
}

export interface DraftAsset {
  file: string;
  bytes: Buffer;
  contentType: string;
}

/**
 * Save one draft, replacing its assets.
 *
 * ORDER MATTERS, and it is the opposite of publish. Assets are written FIRST
 * and the metadata LAST, so a half-finished save leaves a draft whose recorded
 * icons all exist. The reverse would record icons that had not been uploaded
 * yet, and reopening it would show broken images with no way to tell which were
 * real.
 *
 * Assets no longer named by the draft are deleted after the metadata is
 * written, for the same reason: a file that is still listed must still exist.
 */
export async function writeIconDraft(
  app: AppId,
  draft: Omit<IconDraft, 'updatedAt'>,
  assets: DraftAsset[],
): Promise<{ ok: true; updatedAt: number } | { ok: false; error: string }> {
  if (!/^[a-z][a-z0-9-]{1,60}$/.test(draft.packId)) {
    return { ok: false, error: 'A pack id is required. Lowercase letters, digits and hyphens.' };
  }

  let map: DraftMap;
  try {
    map = await readDrafts(app);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  const dir = ASSET_DIR(app, draft.packId);

  try {
    for (const a of assets) {
      // Bare filenames only, matching the flat-path rule the device enforces on
      // a real pack. A draft that could not be published is not a draft.
      if (a.file.includes('/') || a.file.includes('\\')) {
        return { ok: false, error: `Asset name contains a path separator: ${a.file}` };
      }
      await putObject(`${dir}/${a.file}`, a.bytes, a.contentType);
    }

    const updatedAt = Math.floor(Date.now() / 1000);
    map[draft.packId] = { ...draft, updatedAt };
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ drafts: map }, null, 2) + '\n', 'utf8'),
      'application/json',
    );

    // Sweep assets this save orphaned. Best effort: a leftover file costs bytes
    // in a directory nothing else reads, while a failed sweep must not fail a
    // save that already succeeded.
    try {
      const keep = new Set(assets.map((a) => `${dir}/${a.file}`));
      for (const key of await listPrefix(`${dir}/`)) {
        if (!keep.has(key)) await deleteObject(key);
      }
    } catch {
      // Ignored on purpose.
    }

    return { ok: true, updatedAt };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

/**
 * Record that this draft's content is now live at [version].
 *
 * A NARROW WRITE: metadata only, assets untouched, and it refuses to create a
 * draft that does not exist. Called after a successful publish, and a failure
 * here leaves the banner stale rather than breaking anything, which is why the
 * caller does not await it as part of the publish result.
 */
export async function stampIconDraftPublished(
  app: AppId,
  packId: string,
  version: number,
): Promise<{ ok: boolean }> {
  if (!Number.isInteger(version) || version < 1) return { ok: false };
  let map: DraftMap;
  try {
    map = await readDrafts(app);
  } catch {
    return { ok: false };
  }
  const draft = map[packId];
  if (!draft) return { ok: false };

  map[packId] = { ...draft, publishedAtVersion: version };
  try {
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ drafts: map }, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    return { ok: true };
  } catch {
    return { ok: false };
  }
}

export async function deleteIconDraft(
  app: AppId,
  packId: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  let map: DraftMap;
  try {
    map = await readDrafts(app);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
  if (!map[packId]) return { ok: true };

  delete map[packId];
  try {
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ drafts: map }, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    // Metadata first here, unlike the save: once the draft is gone from the
    // index, its assets are unreferenced and a failed delete is only wasted
    // bytes rather than a draft pointing at files that no longer exist.
    for (const key of await listPrefix(`${ASSET_DIR(app, packId)}/`)) {
      await deleteObject(key);
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
