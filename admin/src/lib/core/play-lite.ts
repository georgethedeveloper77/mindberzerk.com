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

/**
 * WHERE A PRODUCT ID CAME FROM, which decides what may be claimed about it.
 *
 *   play      read from Play just now. `activeOptions` is a measurement.
 *   snapshot  the last successful Play read, cached on R2. The id is real and
 *             was real then; whether it is active NOW is unknown.
 *   index     derived from the signed index: a pack's own sku, or an
 *             entitlement's. The id is one WE published, so it certainly
 *             exists in our catalogue and may not exist in Play at all.
 *
 * The distinction is the whole point of the merge. Without it a picker offering
 * an id it inferred would read exactly like one Play confirmed, and the status
 * line under it would be a guess dressed as a fact.
 */
export type SkuSource = 'play' | 'snapshot' | 'index';

export interface PlayLiteProduct {
  productId: string;
  /** The en-US listing title, or the first listing, or null. */
  title: string | null;
  /** The number that decides whether anyone can buy this. Meaningless unless
   *  `source` is 'play'. */
  activeOptions: number;
  /** A representative active price, formatted, or null. */
  samplePrice: string | null;
  source: SkuSource;
}

export type PlayLite =
  | {
      ok: true;
      products: PlayLiteProduct[];
      /**
       * Present when Play itself could not be read and these options came from
       * a snapshot or the index instead. The picker still works; it just must
       * not pretend the list is authoritative.
       */
      degraded?: { reason: string; snapshotAt: number | null };
    }
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

  // A DEGRADED LIST CANNOT SAY A PRODUCT IS MISSING. With Play unread, the
  // only honest statements are "we have seen this id before" and "we have
  // not", and neither is a verdict on whether it sells.
  if (play.degraded) {
    const at = play.degraded.snapshotAt
      ? new Date(play.degraded.snapshotAt * 1000).toISOString().slice(0, 10)
      : null;
    if (!p) {
      return {
        tone: 'unknown',
        text: `Play could not be read, and '${sku}' is not in anything we have cached, so whether it exists is unknown.`,
      };
    }
    if (p.source === 'snapshot') {
      return {
        tone: 'unknown',
        text: `Play could not be read. '${sku}' existed in Play${at ? ` as of ${at}` : ''}; whether it is still active is unknown.`,
      };
    }
    return {
      tone: 'unknown',
      text: `Play could not be read. '${sku}' is used by the published catalogue, so the ID is real, but whether Play can charge for it is unknown.`,
    };
  }

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
