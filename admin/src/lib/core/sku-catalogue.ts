import 'server-only';

import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { listPlayProducts, playLite } from '@/lib/core/play';
import { getObject, putObject } from '@/lib/core/r2';
import type { PlayLite, PlayLiteProduct } from '@/lib/core/play-lite';

/**
 * EVERY PRODUCT ID WE COULD OFFER, FROM WHICHEVER SOURCES ANSWER.
 *
 * ## The problem this solves
 *
 * `SkuField` in the distro workspace already renders a picker when `play.ok`
 * and a plain text input when it does not. Play currently answers 403, so the
 * picker has never appeared and every product ID is typed by hand. A product ID
 * is PERMANENT and non-reusable in Play, so a typo is not a typo, it is a
 * burned identifier and a store listing that has to be rebuilt.
 *
 * The 403 is an ops problem with an ops fix. This is the code half: the picker
 * should not depend on one system being reachable, because those ids exist in
 * two other places we can read.
 *
 * ## Three sources, most authoritative first
 *
 *   1. PLAY. When it answers, it is the only source that knows whether a
 *      product can actually be bought, and a successful read is SNAPSHOTTED so
 *      the next failure degrades to memory rather than to nothing.
 *   2. THE SNAPSHOT on R2, from the last successful read. Ids that were real
 *      then, with the date attached so the reader can weigh it.
 *   3. THE SIGNED INDEX. Every paid pack carries its own `sku` and every
 *      entitlement carries one. These are ids WE published, so they certainly
 *      exist in our catalogue, and may not exist in Play at all. This source
 *      works today, with the 403 in place and nothing configured.
 *
 * Deduplicated by id, first source wins. `source` travels with each product so
 * `playSkuNote` can say what is actually known rather than implying Play
 * confirmed something it never saw.
 *
 * ## The snapshot write is fire and forget
 *
 * If R2 refuses it, the caller still gets a live Play list, which is strictly
 * better than the snapshot would have been. Failing the whole read because the
 * cache could not be updated would trade the good case for the worse one.
 */

const snapshotKey = (app: AppId) => `${app}/admin/play-products.json`;

interface Snapshot {
  updatedAt: number;
  products: PlayLiteProduct[];
}

async function readSnapshot(app: AppId): Promise<Snapshot | null> {
  let bytes: Buffer | null;
  try {
    bytes = await getObject(snapshotKey(app));
  } catch {
    // The bucket being unreadable is exactly the situation this is meant to
    // survive, so it degrades to the index source rather than throwing.
    return null;
  }
  if (!bytes) return null;
  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as Partial<Snapshot>;
    if (!Array.isArray(parsed.products)) return null;
    return {
      updatedAt: Number(parsed.updatedAt) || 0,
      products: parsed.products
        .filter((p): p is PlayLiteProduct => !!p && typeof p.productId === 'string')
        // Stamped on READ rather than trusted from the file, so a snapshot
        // written before this field existed cannot claim to be live Play data.
        .map((p) => ({ ...p, source: 'snapshot' as const })),
    };
  } catch {
    return null;
  }
}

async function writeSnapshot(app: AppId, products: PlayLiteProduct[]): Promise<void> {
  try {
    const doc: Snapshot = { updatedAt: Math.floor(Date.now() / 1000), products };
    await putObject(
      snapshotKey(app),
      Buffer.from(JSON.stringify(doc, null, 2) + '\n', 'utf8'),
      'application/json',
    );
  } catch {
    // Deliberately silent. See the note above: a failed cache write must not
    // cost the caller a live Play read.
  }
}

/**
 * Product ids the published catalogue already uses.
 *
 * A pack's own `sku` and every entitlement's. Titles come from the pack or the
 * entitlement, which is the same title the storefront shows, so the picker
 * reads the same way the store does.
 */
function fromIndex(packs: { packId: string; title: string; sku?: string | null }[], entitlements: { sku: string; title: string }[]): PlayLiteProduct[] {
  const out = new Map<string, PlayLiteProduct>();
  for (const p of packs) {
    if (!p.sku) continue;
    if (!out.has(p.sku)) {
      out.set(p.sku, {
        productId: p.sku,
        title: p.title || p.packId,
        // NOT a measurement, and the source field is what stops it being read
        // as one. Zero here means "unknown", never "nobody can buy it".
        activeOptions: 0,
        samplePrice: null,
        source: 'index',
      });
    }
  }
  for (const e of entitlements) {
    if (!out.has(e.sku)) {
      out.set(e.sku, {
        productId: e.sku,
        title: e.title || e.sku,
        activeOptions: 0,
        samplePrice: null,
        source: 'index',
      });
    }
  }
  return [...out.values()];
}

/**
 * The catalogue a builder should receive as its `play` prop.
 *
 * Returns `ok: false` ONLY when there is genuinely nothing to offer, so the
 * text-input fallback in `SkuField` now means "we know of no ids at all" rather
 * than "Play is down", which are very different situations for someone about to
 * choose a permanent identifier.
 */
export async function skuCatalogue(app: AppId, pkg: string | null): Promise<PlayLite> {
  const live = await listPlayProducts(pkg);

  if (live.ok) {
    const lite = playLite(live);
    if (lite.ok) {
      await writeSnapshot(app, lite.products);
      return lite;
    }
  }

  const reason = live.ok ? 'Play returned an unreadable catalogue.' : live.error;

  const [snapshot, index] = await Promise.all([readSnapshot(app), readLiveIndex(app)]);

  const merged = new Map<string, PlayLiteProduct>();
  for (const p of snapshot?.products ?? []) merged.set(p.productId, p);
  for (const p of fromIndex(index.packs, index.entitlements)) {
    if (!merged.has(p.productId)) merged.set(p.productId, p);
  }

  if (merged.size === 0) return { ok: false, error: reason };

  return {
    ok: true,
    products: [...merged.values()].sort((a, b) => a.productId.localeCompare(b.productId)),
    degraded: { reason, snapshotAt: snapshot?.updatedAt ?? null },
  };
}
