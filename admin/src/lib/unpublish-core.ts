import 'server-only';

import { nextGeneratedAt, readLiveIndex, type AppId } from '@/lib/catalogue';
import { putObject } from '@/lib/r2';
import {
  INDEX_NAME,
  INDEX_SIGNATURE_NAME,
  signIndex,
  type IndexPack,
} from '@/lib/sign';

/**
 * ONE UNPUBLISH PATH.
 *
 * `api/publish/unpublish/route.ts` could pull one pack. Deleting a distro has
 * to pull the theme pack AND its icon pack in ONE index write, because the
 * index is what devices sync: two writes means a window where a granted icon
 * pack exists with no theme naming it, or a theme whose icons vanished first.
 * The same reasoning that made publishing a distro atomic makes unpublishing
 * one atomic.
 *
 * Duplicating the route's guards inside the delete action would recreate the
 * exact two-copies problem `publish-core.ts` exists to prevent, so the logic
 * lives here and the route is now a wrapper over the single-pack case.
 *
 * ## THE OBJECTS ARE LEFT IN PLACE, AND THAT IS NOT AN OVERSIGHT
 *
 * A device that read the index thirty seconds ago is holding a path and may be
 * halfway through downloading it. Deleting the bucket objects turns that into
 * a failed install and, because the manifest goes with them, one that reports
 * as a verification failure rather than a 404. Removing the index entry is
 * enough: nothing new discovers the pack, in-flight installs finish, and the
 * storage cost of a few MB is not worth the alarm. The orphaned-object sweep
 * is a separate, deliberate pass where what is orphaned is visible before
 * anything is destroyed.
 *
 * ## The two entitlement behaviours, and why both exist
 *
 * Pulling a pack from a BUNDLE someone still sells must not quietly leave that
 * bundle granting nothing, so the route refuses and names the sku: editing the
 * bundle is a decision its owner makes on the Bundles page.
 *
 * DELETING A DISTRO is that decision. The distro's own entitlement exists only
 * to serve the packs being pulled, so an entitlement whose every grant is in
 * the pulled set is removed with them, and its sku is reported back so the UI
 * can say that Play still holds the product and every buyer keeps it.
 * [removeEmptiedEntitlements] selects between the two.
 */

/**
 * Pack ids that ship inside the launcher APK and whose CDN copy supersedes the
 * seed. Mirrors `PackPaths.bundledPackIds` in the launcher.
 *
 * KEEP THIS IN SYNC WITH THE KOTLIN. Pulling one of these strands every device
 * on the frozen in-APK seed with no way forward, so they are refused here at
 * the shared layer rather than per caller.
 */
export const BUNDLED_PACK_IDS = new Set(['simple-icons', 'yaru']);

export type UnpublishOutcome =
  | {
      ok: true;
      /** The index entries that were removed, for reporting paths and versions. */
      pulled: IndexPack[];
      /** Skus of entitlements removed because everything they granted was pulled. */
      removedSkus: string[];
      /** How many packs remain in the catalogue. */
      packsLeft: number;
      generatedAt: number;
    }
  | { ok: false; status: number; error: string };

/**
 * Remove [packIds] from the signed index in one write.
 *
 * Every id must currently be in the catalogue; callers filter before calling.
 * Nothing is deleted from the bucket, see the note above.
 */
export async function unpublishPacks(
  app: AppId,
  packIds: string[],
  opts: { removeEmptiedEntitlements: boolean },
): Promise<UnpublishOutcome> {
  if (packIds.length === 0) {
    return { ok: false, status: 400, error: 'Nothing to unpublish.' };
  }

  const live = await readLiveIndex(app);

  // The same arithmetic as guardIndex in publish-core: every write below
  // starts from `live.packs`, so a read that failed to an empty list would
  // replace the whole catalogue with its own absence.
  if (live.unreachable) {
    return {
      ok: false,
      status: 503,
      error:
        `Could not read ${app}/${INDEX_NAME}: ${live.unreachable}. ` +
        'Refusing to unpublish, because rewriting a catalogue we could not read would overwrite it.',
    };
  }
  if (live.corrupt) {
    return {
      ok: false,
      status: 409,
      error: `${app}/${INDEX_NAME} exists but does not parse. Refusing to overwrite it.`,
    };
  }

  const targets = new Set(packIds);
  const pulled = live.packs.filter((p) => targets.has(p.packId));
  const missing = packIds.filter((id) => !pulled.some((p) => p.packId === id));
  if (missing.length > 0) {
    return {
      ok: false,
      status: 404,
      error: `${missing.join(', ')} is not in the catalogue.`,
    };
  }

  const bundled = packIds.filter((id) => BUNDLED_PACK_IDS.has(id));
  if (bundled.length > 0) {
    return {
      ok: false,
      status: 409,
      error:
        `${bundled.join(', ')} ships inside the app, so pulling it would strand every ` +
        'device on the bundled seed with no way to update. Publish a higher ' +
        'version instead.',
    };
  }

  const packs = live.packs.filter((p) => !targets.has(p.packId));
  if (packs.length === 0) {
    return {
      ok: false,
      status: 409,
      error:
        'This is the only pack. An index with no packs cannot be signed, and ' +
        'an unsigned index is refused by every device.',
    };
  }

  // Trim the pulled ids out of every named grant. `*` passes through untouched,
  // as everywhere else in the pipeline.
  const trimmed = live.entitlements.map((e) => ({
    ...e,
    grants: e.grants.includes('*') ? e.grants : e.grants.filter((g) => !targets.has(g)),
  }));

  const emptied = trimmed.filter((e) => e.grants.length === 0);
  let entitlements = trimmed;
  let removedSkus: string[] = [];
  if (emptied.length > 0) {
    if (!opts.removeEmptiedEntitlements) {
      return {
        ok: false,
        status: 409,
        error:
          `${emptied.map((e) => e.sku).join(', ')} would be left granting nothing. ` +
          'Edit the bundle first, or delete it.',
      };
    }
    removedSkus = emptied.map((e) => e.sku).sort();
    entitlements = trimmed.filter((e) => e.grants.length > 0);
  }

  const keyId = process.env.PACK_KEY_ID ?? 'mh-2026-07';
  const generatedAt = nextGeneratedAt(live);

  let index;
  try {
    index = signIndex({ generatedAt, keyId, packs, entitlements });
  } catch (e) {
    return { ok: false, status: 400, error: (e as Error).message };
  }

  await putObject(`${app}/${INDEX_NAME}`, index.index, 'application/json');
  await putObject(
    `${app}/${INDEX_SIGNATURE_NAME}`,
    index.signature,
    'application/octet-stream',
  );

  return { ok: true, pulled, removedSkus, packsLeft: packs.length, generatedAt };
}
