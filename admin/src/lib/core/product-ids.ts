import 'server-only';

import { getObject, putObject } from '@/lib/core/r2';
import type { AppId } from '@/lib/core/catalogue';
import { skuKind, type SkuKind } from '@/lib/core/skus';

/**
 * PRODUCT IDS KEPT BY HAND.
 *
 * ## Why a fourth source exists
 *
 * `sku-catalogue.ts` already merges three: Play when it answers, a snapshot of
 * the last successful read, and the ids the signed index already uses. All
 * three are DERIVED, which means none of them can know about a product that
 * exists in Play Console and has never been attached to anything here.
 *
 * That is the normal case for a new distro: the product is created in Play
 * first, because a Play product ID is permanent and has to be settled before it
 * is written into a pack. Until it is attached, nothing in this panel has heard
 * of it, so it cannot be offered, so it gets typed by hand into the one kind of
 * field where a typo is unrecoverable.
 *
 * This is the list you keep yourself: add the id when you create it in Play,
 * and it appears in the distro builder, the icon builder, Upload pack and
 * Bundles immediately.
 *
 * ## It is a convenience, never an authority
 *
 * An id here means "George says this exists in Play". It does NOT mean the
 * product is active, priced, or buyable, and `playSkuNote` must never claim
 * otherwise: those are measurements and only a live Play read produces them.
 * The source tag is what keeps that distinction visible all the way to the
 * label under the field.
 *
 * ## Read before write
 *
 * Same rule as every other list in this panel. The write is a whole-document
 * replace, so a failed read must never become its base.
 */

const KEY = (app: AppId) => `${app}/admin/product-ids.json`;

/**
 * The seven products that exist in Play Console today, so the pickers are
 * useful on the first load rather than after seven rounds of typing.
 *
 * ## SEED, NOT DEFAULT, and the distinction is the whole design
 *
 * This applies ONLY while `product-ids.json` does not exist. The first add or
 * forget writes the document, and from then on the stored list is the answer
 * and this constant is ignored entirely. Same rule the app registry follows
 * with the compiled `REGISTRY`, for the same reason: a seed that kept
 * reappearing after being removed is not a list, it is an argument.
 *
 * Transcribed from Play Console on 1 August 2026. If Play and this disagree,
 * PLAY IS RIGHT: these ids are permanent there and merely remembered here.
 */
const SEEDED: Record<string, { productId: string; note: string }[]> = {
  'g-launcher': [
    { productId: 'distro_kali', note: 'Kali' },
    { productId: 'distro_garuda_dragonized', note: 'Garuda Dr460nized' },
    { productId: 'distro_pop_cosmic', note: 'Pop!_OS COSMIC' },
    { productId: 'icons_kali', note: 'Kali icon pack' },
    { productId: 'icons_garuda', note: 'Garuda icon pack' },
    { productId: 'icons_pop_cosmic', note: 'Pop!_OS icon pack' },
    { productId: 'bundle_all_distros', note: 'Every paid distro' },
  ],
};

/** The seed for one app, sorted the way a stored list would be. */
function seedFor(app: AppId): ManualProduct[] {
  return (SEEDED[app] ?? [])
    .map((p) => ({ ...p, addedAt: 0 }))
    .sort((a, b) => a.productId.localeCompare(b.productId));
}

export interface ManualProduct {
  productId: string;
  /** What it sells, in your words. Shown beside the id in every picker. */
  note: string;
  /** Unix seconds, or 0 for a seeded id that has never been written. */
  addedAt: number;

  /**
   * What this product sells, when the prefix cannot say.
   *
   * ─── THE ONLY FIELD HERE THAT IS AN ASSERTION ABOUT MEANING ──────────────
   *
   * Everything else in this file is "George says this ID exists in Play". This
   * one says what it is FOR, and it exists because `terminal_pro` unlocks a
   * feature rather than a pack and can never gain a `feature_` prefix: a Play
   * product ID is permanent.
   *
   * Absent means "read it from the prefix", which is right for every product
   * that follows the scheme. Present overrides. See [kindOf].
   */
  kind?: SkuKind;
}

/**
 * What a hand-kept product sells: the declaration if there is one, else the
 * prefix.
 *
 * One function so the panel, the report and the pickers cannot disagree about
 * whether a given ID is a feature.
 */
export function kindOf(p: ManualProduct): SkuKind {
  return p.kind ?? skuKind(p.productId);
}

async function read(app: AppId): Promise<ManualProduct[]> {
  const bytes = await getObject(KEY(app));
  // ABSENT means never touched, so the seed stands in. An EMPTY stored list is
  // a different fact: it means every seeded id was forgotten deliberately, and
  // re-adding them would undo that.
  if (!bytes) return seedFor(app);
  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as { products?: unknown };
    if (!Array.isArray(parsed.products)) return [];
    return (parsed.products as Record<string, unknown>[])
      .filter((p) => typeof p?.productId === 'string' && p.productId)
      .map((p) => ({
        productId: String(p.productId),
        note: String(p.note ?? ''),
        addedAt: Number(p.addedAt) || 0,
        // Unknown or absent falls back to the prefix rather than being stored
        // as a wrong answer. A document written before this field existed is
        // the common case, not an error.
        kind: isKind(p.kind) ? p.kind : undefined,
      }));
  } catch {
    throw new Error('product-ids.json is present but does not parse. Fix it in the bucket first.');
  }
}

export interface ManualProductsResult {
  products: ManualProduct[];
  /** Distinct from an empty list: one means none, the other means unknown. */
  unreachable: string | null;
}

/** For pages and for the merge. Never throws. */
export async function readManualProducts(app: AppId): Promise<ManualProductsResult> {
  try {
    return { products: await read(app), unreachable: null };
  } catch (e) {
    return { products: [], unreachable: (e as Error).message };
  }
}

/**
 * The same shape Play uses, so `isSafeSku` and the signed index agree with it.
 * Underscores, because Play's Product ID uses them; the hyphenated form is the
 * Purchase option ID, which is a different field the app never reads.
 */
const ID_RE = /^[a-z][a-z0-9_]{2,60}$/;

const KINDS: readonly SkuKind[] = ['distro', 'icons', 'bundle', 'feature', 'other'];
const isKind = (v: unknown): v is SkuKind =>
  typeof v === 'string' && (KINDS as readonly string[]).includes(v);

export async function addManualProduct(
  app: AppId,
  productId: string,
  note: string,
  /**
   * Optional, and only worth passing for a feature. Everything else reads
   * correctly from its prefix, and storing a kind that merely repeats the
   * prefix is a second copy of the same fact.
   */
  kind?: SkuKind,
): Promise<{ ok: true; products: ManualProduct[] } | { ok: false; error: string }> {
  const id = productId.trim();
  if (!ID_RE.test(id)) {
    return {
      ok: false,
      error: `'${id}' is not a usable product ID. Lowercase letters, digits and underscores, at least three characters.`,
    };
  }

  let products: ManualProduct[];
  try {
    products = await read(app);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  if (products.some((p) => p.productId === id)) {
    // Not an error worth blocking on: the id is already offered, which is the
    // outcome the caller wanted.
    return { ok: true, products };
  }

  products.push({
    productId: id,
    note: note.trim(),
    addedAt: Math.floor(Date.now() / 1000),
    // Stored only when it says something the prefix does not.
    kind: kind && kind !== skuKind(id) ? kind : undefined,
  });
  products.sort((a, b) => a.productId.localeCompare(b.productId));

  try {
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ products }, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    return { ok: true, products };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

/**
 * Forget an id.
 *
 * REMOVES IT FROM THIS LIST AND NOTHING ELSE. It does not touch Play, and it
 * does not touch a pack that already carries it: a pack's `sku` lives in the
 * signed index, so a product removed here still sells whatever already
 * references it. This list only decides what the pickers offer.
 */
export async function removeManualProduct(
  app: AppId,
  productId: string,
): Promise<{ ok: true; products: ManualProduct[] } | { ok: false; error: string }> {
  let products: ManualProduct[];
  try {
    products = await read(app);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  const next = products.filter((p) => p.productId !== productId);
  if (next.length === products.length) return { ok: true, products };

  try {
    await putObject(
      KEY(app),
      Buffer.from(JSON.stringify({ products: next }, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    return { ok: true, products: next };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
