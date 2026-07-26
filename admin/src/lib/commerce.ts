import 'server-only';

import { readLiveIndex, type AppId, type LiveIndex } from './catalogue';
import { isListed, readListing } from './listing';
import { listPlayProducts, type PlayCatalogue, type PlayProduct } from './play';
import { appMeta } from './registry';
import { skuKind, skuProblems, type SkuKind } from './skus';

/**
 * THE THREE SYSTEMS THAT HAVE TO AGREE, JOINED IN ONE PLACE.
 *
 *   the signed index   which packs exist, what each costs, what a bundle grants
 *   listing.json       which of them the storefront currently shows
 *   Play               whether the product behind a price can actually be bought
 *
 * Each is edited on its own screen and none of them validates the others, so
 * every disagreement between them is invisible until a user taps Buy. There are
 * only about a dozen products, which is precisely why this has gone unnoticed:
 * a dozen things are easy to believe you are holding in your head.
 *
 * ─── WHY THE SKU IS THE ROW, NOT THE PACK ───────────────────────────────────
 *
 * A pack is not the unit of sale. `distro_kali` unlocks two packs, `icons_kali`
 * unlocks one of them, and a bundle unlocks six. Listing packs would show the
 * Kali icon pack twice with two different prices and no way to say which one is
 * broken. The sku is the thing Play knows about and the thing a user pays for,
 * so it is the row, and the packs it unlocks are a column.
 *
 * ─── FREE IS NOT A PROBLEM ──────────────────────────────────────────────────
 *
 * A pack with no sku is free, deliberately and permanently for the three
 * bundled distros. Nothing here treats an absent sku as missing configuration.
 */

export type Tone = 'bad' | 'warn' | 'info';

export interface Problem {
  tone: Tone;
  text: string;
}

export interface SkuRow {
  sku: string;
  kind: SkuKind;
  /** Title from the entitlement, or from the single pack that carries it. */
  title: string;
  /** Packs whose own `sku` field is this one. */
  packs: string[];
  /** Packs this sku grants through an entitlement. */
  grants: string[];
  /** Everything this sku unlocks, packs and grants merged, de-duplicated. */
  unlocks: string[];
  play: PlayProduct | null;
  /** Play has this product AND at least one purchase option is ACTIVE. */
  sellable: boolean;
  problems: Problem[];
}

export interface CommerceReport {
  app: AppId;
  packageName: string | null;
  play: PlayCatalogue;
  rows: SkuRow[];
  /** Products configured in Play that nothing in the index references. */
  orphans: PlayProduct[];
  paidPackCount: number;
  freePackCount: number;
  /** Paid packs currently hidden from the storefront. Not an error. */
  unlistedPaid: string[];
  /** Whether the live index exists, was readable, and parsed. */
  indexOk: boolean;
  /**
   * Why the index could not be read, or null.
   *
   * SEPARATE FROM `indexOk` because the two mean different things to a reader.
   * `indexOk: false` with no error is "nothing published yet", which is a normal
   * state on a fresh bucket. An error is "the bucket refused us", which means
   * every row below is missing rather than absent.
   */
  indexError: string | null;
}

export async function commerceReport(app: AppId): Promise<CommerceReport> {
  const pkg = appMeta(app)?.pkg ?? null;

  // In parallel. R2 and Play are unrelated services and the page waits on the
  // slower one either way; serialising them would just add the faster one's
  // latency to every load.
  //
  // THE R2 HALF IS WRAPPED AND PLAY'S IS NOT, because they fail differently.
  // `listPlayProducts` already returns a result object and never throws, while
  // `getObject` RETHROWS anything that is not a missing key — so bad R2
  // credentials propagate out of `readLiveIndex`, out of this function, and
  // into the error boundary, blanking a whole page because one of its three
  // inputs was unreachable. That is precisely the failure this screen exists to
  // report, so it must survive it.
  const [r2, play] = await Promise.all([readIndexAndListing(app), listPlayProducts(pkg)]);
  const { live, listing, indexError } = r2;

  const playById = new Map<string, PlayProduct>();
  if (play.ok) for (const p of play.products) playById.set(p.productId, p);

  const packIds = new Set(live.packs.map((p) => p.packId));

  // ── collect every sku the index mentions, from either side ────────────────
  const rows = new Map<string, SkuRow>();
  const row = (sku: string): SkuRow => {
    const existing = rows.get(sku);
    if (existing) return existing;
    const fresh: SkuRow = {
      sku,
      kind: skuKind(sku),
      title: sku,
      packs: [],
      grants: [],
      unlocks: [],
      play: playById.get(sku) ?? null,
      sellable: (playById.get(sku)?.activeOptions ?? 0) > 0,
      problems: [],
    };
    rows.set(sku, fresh);
    return fresh;
  };

  for (const p of live.packs) {
    if (!p.sku) continue;
    const r = row(p.sku);
    r.packs.push(p.packId);
    if (r.title === r.sku) r.title = p.title || p.packId;
  }

  for (const e of live.entitlements) {
    const r = row(e.sku);
    r.grants.push(...e.grants);
    // The entitlement's title wins: it is the one authored as a store listing,
    // whereas a pack title is the name of one component of the thing being sold.
    if (e.title) r.title = e.title;
  }

  // ── per-sku checks ────────────────────────────────────────────────────────
  for (const r of rows.values()) {
    r.unlocks = [...new Set([...r.packs, ...r.grants])].sort();

    for (const text of skuProblems(r.sku, r.kind === 'other' ? undefined : r.kind)) {
      out(r, 'info', text);
    }

    if (r.unlocks.length === 0) {
      out(r, 'warn', 'This product unlocks nothing. A buyer pays and receives no pack.');
    }

    for (const g of r.grants) {
      if (g === '*') {
        // Deliberately hard. A wildcard grant is a promise that every pack
        // shipped from now until the app dies is included, which cannot be
        // withdrawn from anyone who already bought it.
        out(
          r,
          'bad',
          'Grants "*", which includes every pack published from now on, forever. Name the packs instead.',
        );
      } else if (!packIds.has(g)) {
        // Allowed on purpose: a bundle may be announced before its contents
        // land, and signIndex permits it for that reason.
        out(r, 'info', `Grants '${g}', which is not published yet.`);
      }
    }

    if (!play.ok) {
      // Not a per-sku fault. The page shows the reason once, as a banner.
      continue;
    }

    if (!r.play) {
      out(
        r,
        'bad',
        `No product '${r.sku}' exists in Play. Devices are offered a price that cannot be charged.`,
      );
      continue;
    }

    if (r.play.activeOptions === 0) {
      const drafts = r.play.purchaseOptions.filter((o) => o.state === 'DRAFT').length;
      out(
        r,
        'bad',
        drafts > 0
          ? `The product exists but its ${drafts === 1 ? 'purchase option is' : `${drafts} purchase options are`} still a draft. ` +
              'Finish Availability and pricing and activate it, or this never sells and ownership always resolves false.'
          : 'The product exists but has no active purchase option, so nobody can buy it and ownership always resolves false.',
      );
    } else {
      const active = r.play.purchaseOptions.filter((o) => o.state === 'ACTIVE');

      if (!active.some((o) => o.legacyCompatible)) {
        out(
          r,
          'warn',
          'No active purchase option is marked legacy-compatible. Older Play Billing flows will not see this product.',
        );
      }
      if (active.every((o) => o.pricedRegions === 0)) {
        out(r, 'warn', 'Active, but priced in no region, so it is unavailable everywhere.');
      }
      if (active.some((o) => o.kind === 'rent')) {
        out(r, 'warn', 'A rental purchase option is active. Packs are meant to be bought once, not rented.');
      }
    }
  }

  // ── the other direction: Play products nothing references ─────────────────
  const orphans = play.ok
    ? play.products.filter((p) => !rows.has(p.productId)).sort((a, b) => a.productId.localeCompare(b.productId))
    : [];

  const paid = live.packs.filter((p) => !!p.sku);

  return {
    app,
    packageName: pkg,
    play,
    rows: [...rows.values()].sort((a, b) => a.sku.localeCompare(b.sku)),
    orphans,
    paidPackCount: paid.length,
    freePackCount: live.packs.length - paid.length,
    unlistedPaid: paid.filter((p) => !isListed(listing, p.packId)).map((p) => p.packId),
    indexOk: !indexError && live.exists && !live.corrupt,
    indexError,
  };
}

/**
 * The two R2 reads, or an explanation.
 *
 * An empty index rather than a partial one: if the bucket is unreachable, we
 * know nothing about what is published, and inventing "zero packs" would render
 * every Play product as an orphan and read as a catastrophe rather than a
 * credential problem. The caller branches on [indexError] and says so.
 */
async function readIndexAndListing(
  app: AppId,
): Promise<{ live: LiveIndex; listing: Record<string, boolean>; indexError: string | null }> {
  try {
    const [live, listing] = await Promise.all([readLiveIndex(app), readListing(app)]);
    // readLiveIndex now reports an unreachable bucket rather than throwing, so
    // the flag is the primary signal and this catch is the backstop for
    // readListing and for anything that starts throwing later.
    return { live, listing, indexError: live.unreachable };
  } catch (e) {
    return {
      live: {
        generatedAt: 0,
        keyId: '',
        packs: [],
        entitlements: [],
        exists: false,
        corrupt: false,
        unreachable: null,
      },
      listing: {},
      indexError: (e as Error).message || 'The CDN bucket could not be read.',
    };
  }
}

/** Append a problem, keeping the worst tone first so a table can show one. */
function out(r: SkuRow, tone: Tone, text: string): void {
  r.problems.push({ tone, text });
  const rank: Record<Tone, number> = { bad: 0, warn: 1, info: 2 };
  r.problems.sort((a, b) => rank[a.tone] - rank[b.tone]);
}

/** The worst tone across a row, or null when it is clean. */
export function worstTone(problems: Problem[]): Tone | null {
  if (problems.some((p) => p.tone === 'bad')) return 'bad';
  if (problems.some((p) => p.tone === 'warn')) return 'warn';
  if (problems.some((p) => p.tone === 'info')) return 'info';
  return null;
}
