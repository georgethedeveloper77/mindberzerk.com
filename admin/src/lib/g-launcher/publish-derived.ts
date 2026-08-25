import 'server-only';

import { readLiveIndex, type AppId, type LiveIndex } from '@/lib/core/catalogue';
import { isListed, readListingResult, setListed } from '@/lib/core/listing';
import {
  commitIndex,
  guardIndex,
  nextVersionFor,
  packKeyId,
  uploadPack,
} from '@/lib/core/publish-core';
import type { IndexEntitlement, IndexPack } from '@/lib/core/sign';
import {
  BASE_PACK_ID,
  DISTRO_RECIPES,
  type DistroRecipe,
} from '@/lib/g-launcher/distro-recipes';
import {
  DERIVED_MIN_APP_VERSION,
  derivedPack,
  derivedPackJson,
} from '@/lib/g-launcher/derived-pack';

/**
 * PUBLISH ALL FOURTEEN OFFICIAL ICON PACKS IN ONE WRITE.
 *
 * ─── WHAT ACTUALLY GOES UP ──────────────────────────────────────────────────
 *
 * Fourteen files of about 207 bytes each, roughly 2.9 KB in total. Every one is
 * a colour and a pointer at `arcticons-line`, which carries the 13,622 drawings
 * they share. Publishing the colour baked in would be 148 MB to say the same
 * thing fourteen times, and a fifteenth distro would cost another 10.58 MB
 * instead of another row in a table.
 *
 * ─── ONE INDEX WRITE, NOT FOURTEEN ──────────────────────────────────────────
 *
 * `commitIndex` is called once with all fourteen entries. Fourteen separate
 * publishes would each read the live index, merge one entry and sign, and any
 * two overlapping would drop whichever entry the loser had just added. It would
 * also advertise the packs one at a time over several seconds, so a device
 * polling in the middle would install a partial catalogue.
 *
 * ─── AND WHY THE BASE IS CHECKED FIRST ──────────────────────────────────────
 *
 * `signIndex` refuses an entry whose `requires` names a pack absent from the
 * same index, so publishing without the base fails loudly at signing. That is
 * the backstop. Checking here first turns a signing exception into a sentence
 * that says which command to run.
 */

export interface DerivedPublishOutcome {
  ok: boolean;
  /** Pack ids written, with the version each landed at. */
  published: { packId: string; version: number; sku: string }[];
  /** Recipes whose Play product does not exist yet. Advisory, not fatal. */
  missingSkus: string[];
  /** Skus whose entitlement gained one of these packs. */
  granted: string[];
  /** True when this run hid the base pack from the storefront. */
  hidBase: boolean;
  generatedAt: number;
  totalBytes: number;
  error?: string;
  status?: number;
}

/**
 * [app] is passed in rather than hardcoded here.
 *
 * The caller is a route that already holds it, and it is the single value that
 * decides which bucket prefix everything below writes to. Inlining a literal
 * would put the one string capable of publishing into the wrong catalogue in a
 * file that never has to think about which app it is serving.
 */
export async function publishDerivedPacks(
  app: AppId,
  recipes: DistroRecipe[] = DISTRO_RECIPES,
): Promise<DerivedPublishOutcome> {
  const empty = {
    ok: false,
    published: [],
    missingSkus: [],
    granted: [],
    hidBase: false,
    generatedAt: 0,
    totalBytes: 0,
  };

  const live: LiveIndex = await readLiveIndex(app);

  // The same arithmetic every write in this file starts from: a read that
  // failed to an empty list would replace the whole catalogue with its absence.
  const guard = guardIndex(app, live);
  if (guard) return { ...empty, status: 503, error: guard };

  // ─── THE BASE MUST ALREADY BE LIVE ────────────────────────────────────────
  //
  // Fourteen pointers at geometry nobody published is fourteen paid packs that
  // install and draw nothing. `signIndex` would refuse it, but its message
  // names a field; this one names the fix.
  if (!live.packs.some((p) => p.packId === BASE_PACK_ID)) {
    return {
      ...empty,
      status: 409,
      error:
        `${BASE_PACK_ID} is not in the catalogue, and all fourteen packs are pointers at it. ` +
        'Publish it first: build-vector-pack.mjs then publish-pack.sh.',
    };
  }

  const keyId = packKeyId();
  const entries: IndexPack[] = [];
  const published: DerivedPublishOutcome['published'] = [];
  let totalBytes = 0;

  // ─── UPLOADS FIRST, INDEX LAST ────────────────────────────────────────────
  //
  // The index is what tells a device a pack exists. Writing it before the
  // objects are up advertises files that are not there, and every device that
  // polls in the gap records a failed install rather than retrying later.
  for (const recipe of recipes) {
    const pack = derivedPack(recipe);
    const json = derivedPackJson(pack);
    const bytes = Buffer.from(json, 'utf8');
    totalBytes += bytes.length;

    const version = nextVersionFor(live, recipe.packId);

    const entry = await uploadPack(
      app,
      {
        packType: 'brand',
        packId: recipe.packId,
        version,
        // NOT 6. A build that does not know about `requires` ignores it and
        // installs the pointer alone, which is the exact failure the field
        // exists to prevent. The field describes the dependency; this number is
        // what enforces it.
        minAppVersion: DERIVED_MIN_APP_VERSION,
        title: recipe.iconName,
        summary: `${recipe.title} outline icons, over 13,000 apps`,
        sku: recipe.sku,
        requires: [BASE_PACK_ID],
        files: [{ path: 'pack.json', bytes }],
      },
      keyId,
    );

    entries.push(entry);
    published.push({ packId: recipe.packId, version, sku: recipe.sku });
  }

  // ─── GRANTS ───────────────────────────────────────────────────────────────
  //
  // Buying a paid distro includes its icon pack, and `withShelfGrant` in
  // publish-core already does exactly that, resolved from the entitlement whose
  // grants contain the distro's theme id rather than from a naming convention.
  //
  // It is applied here in ONE pass over a single accumulating list, not fourteen
  // times against `live`. Each call returns a fresh entitlement array, so
  // calling it repeatedly against the original would keep only the last change.
  //
  // The three BUNDLED distros get nothing from this, deliberately and correctly:
  // they are free, so they have no entitlement to append to. Their icon packs
  // are covered on device by `CdnIndex.isIncludedWith`, which is inclusion
  // rather than ownership and does not belong in a signed grant.
  let entitlements: IndexEntitlement[] = live.entitlements;
  const granted: string[] = [];
  for (const recipe of recipes) {
    const next = applyShelfGrant(entitlements, recipe);
    if (next.grantedTo) granted.push(next.grantedTo);
    entitlements = next.entitlements;
  }

  const generatedAt = await commitIndex(app, live, entries, entitlements);

  /**
   * ─── HIDE THE BASE, AFTER THE INDEX IS WRITTEN ────────────────────────────
   *
   * `arcticons-line` carries the drawings all fourteen point at and has no
   * colour of its own. Listed, it is a fifteenth row on the icons screen that
   * nobody would choose and that explains nothing, and it reads as NO ART
   * because the storefront expects a hero pack's file map.
   *
   * It is a dependency, not a product, so nothing about publishing these
   * fourteen is complete while it is still on the shelf. Doing it by hand was a
   * step to remember forever, and a step to remember forever is a step that
   * eventually is not taken.
   *
   * AFTER `commitIndex`, deliberately. Listing is a presentation flag outside
   * the signed pipeline; hiding a pack whose publish then failed would leave
   * the catalogue in a state nobody chose.
   *
   * `setListed` refuses on an unreadable bucket rather than merging into an
   * empty map, so a credential failure here cannot unhide every other pack. It
   * is caught rather than thrown: the fourteen ARE published at this point, and
   * turning a completed publish into an error over a merchandising flag would
   * be the wrong trade. Reported instead.
   */
  let hidBase = false;
  try {
    const { listing, unreachable } = await readListingResult(app);
    if (!unreachable && isListed(listing, BASE_PACK_ID)) {
      await setListed(app, BASE_PACK_ID, false);
      hidBase = true;
    }
  } catch {
    // Left listed. The card on the icons page says so and offers the toggle,
    // which is the same place it lived before this was automatic.
  }

  return {
    ok: true,
    hidBase,
    published,
    missingSkus: recipes.filter((r) => !r.skuLive).map((r) => r.sku),
    granted,
    generatedAt,
    totalBytes,
  };
}

/**
 * `withShelfGrant`, threaded over an accumulating list rather than over `live`.
 *
 * The shared version takes a whole `LiveIndex` and reads `live.entitlements`
 * from it, which is right for a single publish and wrong for fourteen in a row:
 * every call would start from the original list and the result would carry only
 * the final distro's grant. This passes the running list instead and keeps the
 * rule itself, including its narrowness, identical.
 *
 * APPEND ONLY. Ownership scope grows here and never shrinks.
 */
function applyShelfGrant(
  entitlements: IndexEntitlement[],
  recipe: DistroRecipe,
): { entitlements: IndexEntitlement[]; grantedTo: string | null } {
  const unchanged = { entitlements, grantedTo: null };

  // A free pack is unlocked for everyone already; granting it would be signed
  // noise. Every recipe has a sku, so this is a guard rather than a filter.
  if (!recipe.sku) return unchanged;

  // Ground truth, not a naming convention: the distro's entitlement is the one
  // that already grants its theme pack. A free distro has none, and this will
  // not invent one.
  const themeIds = new Set([recipe.themeId, `${recipe.themeId}-theme`]);
  const owner = entitlements.find((e) => e.grants.some((g) => themeIds.has(g)));
  if (!owner) return unchanged;
  if (owner.grants.includes(recipe.packId)) return unchanged;

  return {
    entitlements: entitlements.map((e) =>
      e === owner ? { ...e, grants: [...e.grants, recipe.packId] } : e,
    ),
    grantedTo: owner.sku,
  };
}
