import 'server-only';

import { deleteObject, getObject, listPrefix, putObject } from '@/lib/core/r2';
import type { AppId } from '@/lib/core/catalogue';

/**
 * THE IMAGE HALF OF A DISTRO DRAFT.
 *
 * ## What was already there, and what was not
 *
 * `themes.ts` has had `writeDraft` and `readDraft` all along, and they validate
 * properly. What they store is the SPEC: a `theme.json` that references
 * wallpapers and logos BY FILENAME. The bytes behind those filenames lived only
 * in the browser, in `DistroWorkspace`'s `Asset[]` state, until publish walked
 * them into a signed pack.
 *
 * So a distro draft could always be saved and could never be resumed with its
 * art. Reopening one gave a spec naming five wallpapers and no wallpapers,
 * which is why `requiredAssets` and `missingAssets` exist at all: the workspace
 * has been compensating for a gap rather than reading from a store.
 *
 * This is that store, and it is deliberately the same shape as
 * `icon-drafts.ts`: assets under `<app>/admin/distro-drafts/<id>/`, reopened by
 * public URL, never swept because nothing under `admin/` is.
 *
 * ## It stores ONLY the assets
 *
 * The spec still goes through `writeDraft`, which validates and merges against
 * a read that throws. Duplicating the spec here would create a second source of
 * truth for `theme.json`, which is the one thing this panel has consistently
 * refused to do.
 *
 * ## Read before write, again
 *
 * Same rule as everywhere else: the index of which files belong to which draft
 * is a whole-document replace, so a failed read must never become its base.
 */

const KEY = (app: AppId) => `${app}/admin/distro-draft-assets.json`;
const ASSET_DIR = (app: AppId, draftId: string) => `${app}/admin/distro-drafts/${draftId}`;

/** Filenames only. The bytes are objects; this is the index of them. */
type AssetMap = Record<string, string[]>;

async function readMap(app: AppId): Promise<AssetMap> {
  const bytes = await getObject(KEY(app));
  if (!bytes) return {};
  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as { assets?: AssetMap };
    return parsed.assets && typeof parsed.assets === 'object' ? parsed.assets : {};
  } catch {
    throw new Error(
      'distro-draft-assets.json is present but does not parse. Fix it in the bucket first.',
    );
  }
}

export interface DraftAsset {
  /** A BARE filename, matching the flat-path rule the device enforces. */
  name: string;
  bytes: Buffer;
  contentType: string;
}

/** Public URL for one draft asset, for rehydrating the workspace. */
export function draftAssetUrl(app: AppId, draftId: string, name: string): string {
  const base = (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
  return `${base}/${ASSET_DIR(app, draftId)}/${encodeURIComponent(name)}`;
}

/** The asset names stored for one draft, or an empty list. Never throws. */
export async function readDraftAssets(app: AppId, draftId: string): Promise<string[]> {
  try {
    const map = await readMap(app);
    return map[draftId] ?? [];
  } catch {
    return [];
  }
}

/**
 * Replace the asset set for one draft.
 *
 * ASSETS FIRST, INDEX LAST, the opposite of publish and the same as icon
 * drafts: a half-finished save then leaves an index whose files all exist,
 * rather than one naming files that were never uploaded.
 */
export async function writeDraftAssets(
  app: AppId,
  draftId: string,
  assets: DraftAsset[],
): Promise<{ ok: true; count: number } | { ok: false; error: string }> {
  let map: AssetMap;
  try {
    map = await readMap(app);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  const dir = ASSET_DIR(app, draftId);
  try {
    for (const a of assets) {
      if (a.name.includes('/') || a.name.includes('\\')) {
        return { ok: false, error: `Asset name contains a path separator: ${a.name}` };
      }
      await putObject(`${dir}/${a.name}`, a.bytes, a.contentType);
    }

    map[draftId] = assets.map((a) => a.name);
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ assets: map }, null, 2) + '\n', 'utf8'),
      'application/json',
    );

    // Best effort. A leftover object costs bytes in a directory nothing else
    // reads; a failed sweep must not fail a save that already succeeded.
    try {
      const keep = new Set(assets.map((a) => `${dir}/${a.name}`));
      for (const key of await listPrefix(`${dir}/`)) {
        if (!keep.has(key)) await deleteObject(key);
      }
    } catch {
      // Ignored on purpose.
    }

    return { ok: true, count: assets.length };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

/**
 * Copy every asset from one draft to another.
 *
 * For DUPLICATE, which without this produces a spec naming five wallpapers and
 * a draft directory holding none: the copy would open looking exactly like the
 * vanished-assets bug `readDraftAssets` exists to fix. The bytes are read and
 * REWRITTEN rather than the new draft being pointed at the original's
 * directory, because two drafts sharing one directory means editing either one
 * silently rewrites the other's art.
 *
 * Never throws. A duplicate whose art fails to copy is still a usable draft
 * with a complete spec, and the caller reports how many files landed.
 */
export async function copyDraftAssets(
  app: AppId,
  fromId: string,
  toId: string,
): Promise<number> {
  const names = await readDraftAssets(app, fromId);
  if (names.length === 0) return 0;

  const from = ASSET_DIR(app, fromId);
  const copied: DraftAsset[] = [];
  for (const name of names) {
    try {
      const bytes = await getObject(`${from}/${name}`);
      if (!bytes) continue;
      copied.push({ name, bytes, contentType: 'application/octet-stream' });
    } catch {
      // One unreadable asset costs its own file and nothing else.
    }
  }
  if (copied.length === 0) return 0;

  const stored = await writeDraftAssets(app, toId, copied);
  return stored.ok ? stored.count : 0;
}

/**
 * Drop a draft's assets.
 *
 * Called when the DRAFT is deleted, never when it is published: publishing
 * copies the bytes into a signed pack, and someone who publishes then keeps
 * editing still needs the art in the workspace.
 */
export async function deleteDraftAssets(app: AppId, draftId: string): Promise<void> {
  let map: AssetMap;
  try {
    map = await readMap(app);
  } catch {
    return;
  }
  if (!(draftId in map)) return;

  delete map[draftId];
  try {
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ assets: map }, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    for (const key of await listPrefix(`${ASSET_DIR(app, draftId)}/`)) {
      await deleteObject(key);
    }
  } catch {
    // The index write is what matters; orphaned bytes under admin/ are never
    // served and never swept.
  }
}
