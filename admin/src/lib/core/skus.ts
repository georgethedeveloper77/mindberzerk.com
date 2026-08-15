/**
 * THE SKU NAMING RULES, AS CODE.
 *
 * Play product IDs are PERMANENT AND NON-REUSABLE. Delete `distro_kali` and
 * that string is burned for the lifetime of the app; the next Kali has to be
 * `distro_kali_2`, forever, in the store listing, in the signed index, and in
 * every support reply. So the scheme was settled up front, and this file is the
 * only place it is written down in a form the panel can enforce.
 *
 *   distro_<slug>   the whole distro: theme pack + icon pack
 *   icons_<slug>    that distro's icon pack, sold alone
 *   bundle_<slug>   a named set of packs
 *
 * ─── UNDERSCORES HERE, HYPHENS IN PLAY'S OTHER FIELD ────────────────────────
 *
 * Play has two identifiers on a one-time product and they have DIFFERENT
 * character rules, which is a trap worth naming:
 *
 *   productId         numbers, lowercase, underscores, periods   ← what we use
 *   purchaseOptionId  numbers, lowercase, HYPHENS                ← Play's own
 *
 * The app checks the PRODUCT ID. `isSafeSku` in `sign.ts` refuses anything else
 * at signing time, so a hyphenated sku cannot reach a device. But pack IDs are
 * hyphenated (`kali-2024`), so deriving a sku from a pack id must convert, and
 * [slugFor] is the one function that does it.
 *
 * NO `server-only` HERE, deliberately, same reasoning as `registry.ts`: the
 * builders are client components and need to validate a sku as it is typed.
 * `sign.ts` keeps its own copy of the regex because that copy is the one that
 * actually gates a publish, and a validator the browser can reach is not a gate.
 */

export const SKU_PREFIX = {
  distro: 'distro_',
  icons: 'icons_',
  bundle: 'bundle_',
} as const;

/**
 * ─── `feature` HAS NO PREFIX, AND CANNOT GET ONE ────────────────────────────
 *
 * `terminal_pro` unlocks behaviour in the app rather than a downloadable pack.
 * It was created in Play before this kind existed, and a Play product ID is
 * PERMANENT, so it can never become `feature_terminal_pro`.
 *
 * [skuKind] therefore cannot infer it, and does not try. A feature is DECLARED,
 * on the hand-kept entry, and the declaration overrides the prefix. Without
 * that, `commerceReport` warns "this product unlocks nothing" forever on a
 * product that is working exactly as intended, and a warning that can never be
 * cleared is one people learn to scroll past.
 */
export type SkuKind = 'distro' | 'icons' | 'bundle' | 'feature' | 'other';

/** Play's own product-ID rule. Mirrors `isSafeSku` in sign.ts. */
const SKU = /^[a-z0-9][a-z0-9_]{0,63}$/;

export function isSafeSku(sku: string): boolean {
  return SKU.test(sku);
}

export function skuKind(sku: string): SkuKind {
  if (sku.startsWith(SKU_PREFIX.distro)) return 'distro';
  if (sku.startsWith(SKU_PREFIX.icons)) return 'icons';
  if (sku.startsWith(SKU_PREFIX.bundle)) return 'bundle';
  return 'other';
}

/**
 * Pack id to sku slug: `kali-2024` becomes `kali_2024`.
 *
 * Runs of non-alphanumerics collapse to ONE underscore and the ends are
 * trimmed, because `distro_kali__2024_` is a legal product id and would be
 * permanent.
 */
export function slugFor(packId: string): string {
  return packId
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

export const distroSkuFor = (packId: string) => `${SKU_PREFIX.distro}${slugFor(packId)}`;
export const iconsSkuFor = (packId: string) => `${SKU_PREFIX.icons}${slugFor(packId)}`;
export const bundleSkuFor = (name: string) => `${SKU_PREFIX.bundle}${slugFor(name)}`;

/**
 * Problems with a sku, as sentences. Empty means it is fine.
 *
 * [expect] is advisory: a sku with the wrong prefix still WORKS, it is just
 * unreadable in a Play export three years from now, so it is reported and not
 * refused. The hard failures are the shape rules, which Play itself enforces.
 */
export function skuProblems(sku: string, expect?: SkuKind): string[] {
  const out: string[] = [];
  if (!sku) return ['No product ID set.'];

  if (!isSafeSku(sku)) {
    out.push(
      sku.includes('-')
        ? `'${sku}' contains a hyphen. Product IDs take underscores; hyphens belong to Play's purchase option ID.`
        : `'${sku}' is not a valid Play product ID (lowercase, digits and underscores, starting with a letter or digit).`,
    );
  }
  if (sku.length > 64) out.push(`'${sku}' is longer than 64 characters.`);

  // A FEATURE IS EXEMPT from the prefix check. There is no `feature_` prefix to
  // match, and the whole point of the kind is that it was declared rather than
  // inferred.
  if (expect && expect !== 'other' && expect !== 'feature' && skuKind(sku) !== expect) {
    out.push(`'${sku}' does not start with '${SKU_PREFIX[expect]}'. Product IDs cannot be renamed later.`);
  }
  return out;
}

/** Human label for a kind, for table cells. */
export function skuKindLabel(kind: SkuKind): string {
  switch (kind) {
    case 'distro':
      return 'Distro';
    case 'icons':
      return 'Icon pack';
    case 'bundle':
      return 'Bundle';
    case 'feature':
      return 'Feature';
    default:
      return 'Other';
  }
}
