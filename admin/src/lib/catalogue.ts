import 'server-only';

import { getObject, listPrefix } from './r2';
import {
  INDEX_NAME,
  INDEX_SIGNATURE_NAME,
  type IndexEntitlement,
  type IndexPack,
} from './sign';

/**
 * PHASE C4 - reading what is actually deployed.
 *
 * ## The rule this file exists to enforce
 *
 * **Always read the LIVE index before writing a new one.** Never build the next
 * index from something the panel remembered, a database row, or a file in the
 * repo.
 *
 * Two reasons, and the second one is the sharp one:
 *
 *  1. `generatedAt` must strictly increase or every device that has already
 *     synced silently ignores the new index. Deriving it from the live value is
 *     the only way to be sure, because the panel does not know what else has
 *     published - `tools/publish-index.sh` exists and you will use it.
 *  2. A publish is additive. If the panel rebuilt the index from its own idea of
 *     the catalogue, anything published by the CLI, by a second admin, or by an
 *     older deploy would be silently DROPPED. Devices would then see those packs
 *     vanish from the store while remaining installed, which is a support
 *     conversation nobody can diagnose.
 *
 * So: read, merge, bump, sign, write.
 */

/**
 * PHASE C5 - APPS MOVED, and this is a re-export so nothing importing it broke.
 *
 * The nav is a client component and needs the app list. This module is
 * `server-only`, so importing `AppId` from here into a client component fails
 * the build - correctly, since it would drag the R2 client into the browser
 * bundle. The list therefore lives in `lib/registry.ts`, which has no such
 * marker, and is re-exported here so every existing `from '@/lib/catalogue'`
 * still resolves.
 *
 * DO NOT re-declare APPS below. Two lists in two files drift, and the failure is
 * a nav item that links to a 404 for one app only.
 */
export { APPS, type AppId } from './registry';
import type { AppId } from './registry';

export interface LiveIndex {
  generatedAt: number;
  keyId: string;
  packs: IndexPack[];
  entitlements: IndexEntitlement[];
  /** False when the bucket has no index yet, i.e. a first publish. */
  exists: boolean;
  /** True when the file is there but did not parse. Do NOT merge into this. */
  corrupt: boolean;
  /**
   * Why the bucket could not be read at all, or null.
   *
   * A THIRD STATE, separate from `exists` and `corrupt`, because it means
   * something different from both and the difference is destructive.
   *
   *   exists: false     nothing published yet. Merging into it is correct.
   *   corrupt: true     something is there and unreadable. Refuse.
   *   unreachable       we have NO IDEA what is there. Refuse, harder.
   *
   * Collapsing this into `exists: false` is the dangerous version: a publish
   * would then merge the new pack into an empty catalogue and overwrite a live
   * index holding every other pack, because a credential expired. See the guard
   * in api/publish/pack/route.ts.
   */
  unreachable: string | null;
}

export async function readLiveIndex(app: AppId): Promise<LiveIndex> {
  const empty: LiveIndex = {
    generatedAt: 0,
    keyId: process.env.PACK_KEY_ID ?? 'mh-2026-07',
    packs: [],
    entitlements: [],
    exists: false,
    corrupt: false,
    unreachable: null,
  };

  // WRAPPED, because `getObject` rethrows anything that is not a missing key.
  // Every page in the panel calls this, none of them caught it, and a single
  // expired R2 credential therefore took out the whole console with a stack
  // trace instead of a sentence. A read failure is a fact about the bucket, not
  // an exception the caller asked for.
  let bytes: Buffer | null;
  try {
    bytes = await getObject(`${app}/${INDEX_NAME}`);
  } catch (e) {
    return { ...empty, unreachable: (e as Error).message || 'The bucket could not be read.' };
  }
  if (!bytes) return empty;

  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    return {
      generatedAt: Number(parsed.generatedAt) || 0,
      keyId: String(parsed.keyId ?? empty.keyId),
      packs: Array.isArray(parsed.packs) ? parsed.packs : [],
      entitlements: Array.isArray(parsed.entitlements) ? parsed.entitlements : [],
      exists: true,
      corrupt: false,
      unreachable: null,
    };
  } catch {
    // Present but unparseable. Returning `empty` here would look like a first
    // publish and quietly wipe the catalogue, so it is flagged instead and the
    // caller refuses. Someone has to look at the bucket.
    return { ...empty, exists: true, corrupt: true, unreachable: null };
  }
}

/** Is the live index signed? An unsigned one is refused by every device. */
export async function indexIsSigned(app: AppId): Promise<boolean> {
  // False on an unreachable bucket, deliberately. The caller renders "unsigned",
  // which beside the unreachable banner reads as unknown; throwing here would
  // undo the whole point of the guard above one line after it.
  try {
    return (await getObject(`${app}/${INDEX_SIGNATURE_NAME}`)) !== null;
  } catch {
    return false;
  }
}

/**
 * Merge one pack into the catalogue, replacing any entry with the same id.
 *
 * Sorted by packId so the file is diffable between publishes. The device does
 * not care about order; a human comparing two versions does.
 */
export function upsertPack(packs: IndexPack[], next: IndexPack): IndexPack[] {
  const rest = packs.filter((p) => p.packId !== next.packId);
  return [...rest, next].sort((a, b) => a.packId.localeCompare(b.packId));
}

/**
 * The next `generatedAt`.
 *
 * Normally "now". But if the live index somehow carries a FUTURE timestamp -
 * a machine with a wrong clock published once - then "now" would be lower and
 * every device would refuse the new index while reporting nothing. So take
 * whichever is greater and move on, rather than publishing something that
 * silently does not apply.
 */
export function nextGeneratedAt(live: LiveIndex): number {
  const now = Math.floor(Date.now() / 1000);
  return now > live.generatedAt ? now : live.generatedAt + 1;
}

/** Everything under an app prefix, for the dashboard's "what is up there" view. */
export async function listApp(app: AppId): Promise<string[]> {
  return listPrefix(`${app}/`);
}
