/**
 * THE SLIM PLAY CATALOGUE THE BUILDERS SEE, and the one status line per sku.
 *
 * `lib/play.ts` is `server-only`, and both builders are client components, so
 * the full catalogue cannot cross to them. This module carries the four fields
 * a builder needs and nothing else, and it imports NOTHING so it can never
 * drag server code into a client bundle. `play.ts` maps into this shape with
 * [playLite]; the server pages pass the result down as a prop, the same route
 * `heroPacks` takes into the distro workspace.
 *
 * ─── ADVISORY, NEVER A GATE ─────────────────────────────────────────────────
 *
 * Every note below is information beside a field, not a publish blocker. A
 * product can legitimately be named before it exists in Play (the ID is chosen
 * here first, created there second), and Play being unreachable must not make
 * pricing uneditable. `isSafeSku` inside `signIndex` remains the shape gate,
 * and Play itself is the final word on what sells.
 *
 * The three states mirror the Commerce page's join exactly, because they are
 * the same three facts read from the same API: the product is missing, the
 * product exists but nothing about it can be bought, or it is active. The
 * middle one is the garuda failure, worded here so it is caught while the sku
 * is still a draft instead of after a buyer taps a dead button.
 */

export interface PlayLiteProduct {
  productId: string;
  /** The en-US listing title, or the first listing, or null. */
  title: string | null;
  /** The number that decides whether anyone can buy this. */
  activeOptions: number;
  /** A representative active price, formatted, or null. */
  samplePrice: string | null;
}

export type PlayLite =
  | { ok: true; products: PlayLiteProduct[] }
  | { ok: false; error: string };

export type PlayNoteTone = 'ok' | 'warn' | 'unknown';

/**
 * One sentence on whether [sku] can actually be bought, with a tone.
 *
 * 'unknown' is deliberately its own tone rather than a warning: an unreachable
 * Play is a different fact from a missing product, and conflating them is the
 * false alarm `play.ts` was written to prevent.
 */
export function playSkuNote(
  play: PlayLite,
  sku: string,
): { tone: PlayNoteTone; text: string } {
  if (!play.ok) {
    return {
      tone: 'unknown',
      text: 'Play could not be read, so whether this product can be bought is unknown.',
    };
  }
  const p = play.products.find((x) => x.productId === sku);
  if (!p) {
    return {
      tone: 'warn',
      text:
        `No product '${sku}' exists in Play. Create it in Play Console under Monetise, ` +
        'Products, One-time products, with exactly this ID. Until then a device is ' +
        'offered a price that cannot be charged.',
    };
  }
  if (p.activeOptions === 0) {
    return {
      tone: 'warn',
      text:
        `'${sku}' exists in Play but has no active purchase option, so nobody can buy it ` +
        'and ownership always resolves false. Activate it in Play Console.',
    };
  }
  return {
    tone: 'ok',
    text: `Active in Play${p.samplePrice ? ` at ${p.samplePrice}` : ''}.`,
  };
}
