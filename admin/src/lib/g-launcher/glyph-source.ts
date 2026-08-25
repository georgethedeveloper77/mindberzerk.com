'use client';

import { GlyphStore, type GlyphIndex, type GlyphBundle } from '@/lib/g-launcher/glyph-store';
import type { CoreRole } from '@/lib/g-launcher/icon-pack';

/**
 * FINDING A DRAWING FOR AN APP THAT HAS NONE.
 *
 * ─── WHY THE INDEX IS BETTER THAN A SEARCH BOX ──────────────────────────────
 *
 * The obvious way to fill a gap is to type the app's name and see what comes
 * back. That is a name match, and name matches are where `guessPackage` already
 * went wrong: `google_maps` lands on Search because `google` is a hint on
 * Search and first match wins, `play_store` and `playstation` collapse onto the
 * same package, `keeper` and `keepassdx` both look like Keep.
 *
 * The index does not match names. It carries 32,951 Android package ids mapped
 * to drawings by hand, over years of pull requests. So for a CORE ROLE, which
 * already knows its real package ids, the lookup is exact:
 *
 *     com.sec.android.app.voicenote  ->  the drawing whoever wrote that entry
 *                                        chose for Samsung's recorder
 *
 * No guessing, no ranking, no ambiguity to resolve. The hint search below is a
 * fallback for roles whose packages the set has never seen, and it is clearly
 * marked as the weaker answer.
 */

const DEFAULT_BASE = 'https://cdn.mindberzerk.com/g-launcher/icons/arcticons';

export interface GlyphCandidate {
  slug: string;
  svg: string;
  /**
   * How this candidate was found. `package` means an exact id lookup in the
   * hand-written map and is worth trusting; `hint` is a name match and is worth
   * looking at. Surfaced to the UI rather than flattened into a score, because
   * "an exact map entry" and "a word that appeared in the filename" are
   * different KINDS of answer and a number would hide that.
   */
  via: 'package' | 'hint';
  /** The package that produced a `package` match, for display. */
  matched?: string;
}

/**
 * The store, loaded once per page.
 *
 * A module-level promise rather than component state: several gap rows will ask
 * for it at once when the panel opens, and a per-component fetch would pull the
 * index six times. Caching the PROMISE rather than the result means the
 * concurrent callers share one request rather than racing to start six.
 */
let pending: Promise<GlyphStore | null> | null = null;

export function loadGlyphStore(base = DEFAULT_BASE): Promise<GlyphStore | null> {
  if (!pending) {
    pending = GlyphStore.load(base).catch(() => {
      // A missing index is not an error worth stopping for. The panel degrades
      // to Simple Icons plus a file picker, which is what it had before this
      // existed. Cleared so a later attempt can retry rather than being stuck
      // with a rejected promise for the life of the page.
      pending = null;
      return null;
    });
  }
  return pending;
}

/** For tests and for a panel that already holds the artifacts. */
export function primeGlyphStore(index: GlyphIndex, glyphs: GlyphBundle): void {
  pending = Promise.resolve(GlyphStore.from(index, glyphs));
}

/**
 * Drawings that could fill [role], best first.
 *
 * Package matches come first and are deduplicated against each other, because a
 * role with three vendor packages will often map all three to one drawing and
 * showing it three times is noise. Hint matches follow and are excluded if a
 * package match already found them.
 */
export function candidatesFor(
  store: GlyphStore,
  role: CoreRole,
  limit = 8,
): GlyphCandidate[] {
  const out: GlyphCandidate[] = [];
  const seen = new Set<string>();

  for (const pkg of role.packages) {
    const slug = store.slugFor(pkg);
    if (!slug || seen.has(slug)) continue;
    const svg = store.svgFor(slug);
    if (!svg) continue;
    seen.add(slug);
    out.push({ slug, svg, via: 'package', matched: pkg });
  }

  for (const hint of role.hints) {
    for (const slug of store.search(hint, limit)) {
      if (seen.has(slug) || out.length >= limit) continue;
      const svg = store.svgFor(slug);
      if (!svg) continue;
      seen.add(slug);
      out.push({ slug, svg, via: 'hint' });
    }
  }

  return out.slice(0, limit);
}

/**
 * Whether the store has art in hand, as opposed to merely a map.
 *
 * The index and the glyph bundle are separate objects and the bundle is scoped
 * to a named slug set, so a store can legitimately know that `voicenote` is the
 * right drawing while holding no bytes for it. That is a different message to
 * the author than "no drawing exists", and conflating the two would send
 * somebody off to draw an icon that is already sitting on the CDN.
 */
export function storeHasArt(store: GlyphStore): boolean {
  return store.loaded > 0;
}
