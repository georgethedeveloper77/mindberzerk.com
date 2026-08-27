import 'server-only';

import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import {
  commitIndex,
  guardIndex,
  shelfOwnerBase,
} from '@/lib/publish-core';
import type { IndexEntitlement } from '@/lib/core/sign';

/**
 * Rewrite every entitlement's grants from the catalogue, without republishing.
 *
 * ─── WHY THIS EXISTS ────────────────────────────────────────────────────────
 *
 * Eleven of fourteen entitlements granted the theme and nothing else, so every
 * buyer of a paid distro owned half of what they paid for and the icons screen
 * said Buy on a pack they had already bought.
 *
 * The cause was two lines in `distro-publish`: the shelf sweep tested
 * `packType === 'hero'` when all fourteen icon packs are `brand`, and the named
 * fallback read `icons.heroPack` when every distro names its pack in
 * `brandPack`. Both are fixed, but the fix only takes effect on a publish that
 * REBUILDS the entitlement, and `republishDistroAction` deliberately passes a
 * null sku so it never does.
 *
 * The alternative was opening eleven workspaces and pressing publish, which
 * uploads eleven packs to change a string in the index. This reads the index,
 * recomputes, signs and writes. No pack moves.
 *
 * ─── ADDITIVE. IT NEVER TAKES A GRANT AWAY ──────────────────────────────────
 *
 * `withShelfGrant` states the rule and it holds here: ownership scope can grow
 * and must never shrink. A grant someone already has may have been added by a
 * route this function knows nothing about, and a "repair" that recomputes from
 * scratch would revoke it. So this only ever appends what is missing.
 *
 * That also makes it safe to run twice: the second run finds nothing to add.
 */
export interface EntitlementRepair {
  /** What changed, one line per entitlement, for the caller to show. */
  changes: string[];
  /** Entitlements whose sku no pack carries. Reported, deleted only on ask. */
  orphans: string[];
  ok: boolean;
  error?: string;
}

export async function repairEntitlements(
  app: AppId,
  opts: { deleteOrphans?: boolean } = {},
): Promise<EntitlementRepair> {
  const live = await readLiveIndex(app);

  const refusal = guardIndex(app, live);
  if (refusal) return { changes: [], orphans: [], ok: false, error: refusal };

  const changes: string[] = [];

  // ── ORPHANS ────────────────────────────────────────────────────────────
  //
  // An entitlement whose sku is carried by no pack in the catalogue. Nothing
  // can be bought under it, because the sku on a pack entry is what the store
  // sells; an entitlement alone is only a grant list waiting for a purchase
  // that can no longer happen.
  //
  // `distro_kali_2024` and `distro_pop_os_2204` are the two: earlier product
  // ids for distros now sold as `distro_kali` and `distro_pop_cosmic`. They are
  // also, confusingly, the only two entitlements that LOOK correct, because
  // they were written when the icon pack was still built inline.
  const carried = new Set(
    live.packs.map((p) => p.sku).filter((s): s is string => !!s),
  );
  const orphans = live.entitlements
    .filter((e) => !carried.has(e.sku))
    .map((e) => e.sku);

  const kept = opts.deleteOrphans
    ? live.entitlements.filter((e) => carried.has(e.sku))
    : live.entitlements;

  if (opts.deleteOrphans && orphans.length > 0) {
    changes.push(`removed ${orphans.join(', ')}: no pack carries them`);
  }

  const next: IndexEntitlement[] = kept.map((e) => {
    // The distro this entitlement is for, found by the theme pack it grants
    // rather than by parsing the sku. Ground truth, and the same rule
    // `withShelfGrant` uses.
    const themeId = e.grants.find((g) =>
      live.packs.some((p) => p.packId === g && p.packType === 'theme'),
    );
    if (!themeId) return e;

    const base = themeId.endsWith('-theme')
      ? themeId.slice(0, -'-theme'.length)
      : themeId;

    // Every PAID icon pack this distro's base owns. `hero` or `brand`: the
    // original swept `hero` alone, and `papirus-icon-theme` is the only hero
    // pack in the catalogue, so that branch never matched a real distro.
    const owned = live.packs
      .filter(
        (p) =>
          (p.packType === 'hero' || p.packType === 'brand') &&
          p.sku &&
          shelfOwnerBase(p.packId, live) === base,
      )
      .map((p) => p.packId);

    const missing = owned.filter((id) => !e.grants.includes(id));
    if (missing.length === 0) return e;

    changes.push(`${e.sku}: added ${missing.join(', ')}`);
    return { ...e, grants: [...e.grants, ...missing] };
  });

  if (changes.length === 0) {
    return { changes: [], orphans, ok: true };
  }

  // COMMIT with the entitlements replaced and the packs untouched. `commitIndex`
  // takes an empty entry list, so `upsertPack` runs zero times and its
  // never-subtract guard sees the pack ids unchanged, which is exactly right: a
  // grant repair must not be able to move a pack.
  await commitIndex(app, live, [], next);

  return { changes, orphans, ok: true };
}
