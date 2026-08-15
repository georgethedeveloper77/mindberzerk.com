import 'server-only';

import * as simpleIcons from 'simple-icons';

/**
 * SIMPLE ICONS, SEARCHED ON THE SERVER.
 *
 * ## Why the server and not the client
 *
 * The package is 3,453 icons and several megabytes of path data. Importing it
 * into a client component puts all of it in the browser bundle so that someone
 * can type "whats" and see one result. A dynamic import would defer the cost
 * rather than remove it, and the panel already has a route layer that costs
 * nothing to add to.
 *
 * So the dataset stays here, the wire carries at most [LIMIT] matches, and the
 * builder receives exactly what it draws.
 *
 * ## THE LICENCE, WHICH IS TWO LICENCES
 *
 * The Simple Icons FILES are CC0, which is why this pipeline can use them at
 * all and why `bulk-icons.ts` deliberately does not trip its scanner on the CC0
 * marker. That covers copyright and it is the reason the composed PNG is yours.
 *
 * The TRADEMARKS are not CC0 and cannot be. WhatsApp's mark is WhatsApp's
 * whatever licence the drawing carries, and no icon pack anywhere has ever had
 * permission for every brand it depicts. This is the ordinary position of every
 * icon pack on Play and it is a trademark question rather than a copyright one,
 * which is a different kind of risk with a different remedy: a takedown for one
 * icon, not a claim over the pack. Worth knowing rather than worth stopping
 * for, and worth avoiding entirely for a brand that is litigious about it.
 *
 * ## The path is 24x24
 *
 * Every icon in the set is authored in a 24 unit square with no viewBox of its
 * own, so the caller wraps it in one. `glyph-blob.ts` does that in one place so
 * the number does not get retyped.
 */

export interface Glyph {
  slug: string;
  title: string;
  /** Brand hex WITHOUT the leading hash, as the package stores it. */
  hex: string;
  /** SVG path data, authored against a 24x24 box. */
  path: string;
}

/** Enough to choose from, few enough that the list does not need paging. */
const LIMIT = 60;

interface RawIcon {
  title?: unknown;
  slug?: unknown;
  hex?: unknown;
  path?: unknown;
}

/**
 * Every icon, once, as a flat list.
 *
 * BUILT ONCE PER PROCESS. The package exports 3,453 named bindings and turning
 * them into an array is cheap but not free, and this module is hit on every
 * keystroke in the picker. A module-level constant is the right lifetime: the
 * dataset cannot change without a deploy.
 */
const ALL: Glyph[] = (() => {
  const out: Glyph[] = [];
  for (const value of Object.values(simpleIcons as Record<string, unknown>)) {
    const i = value as RawIcon;
    if (
      typeof i?.title !== 'string' ||
      typeof i?.slug !== 'string' ||
      typeof i?.path !== 'string'
    ) {
      // The package also exports helpers alongside the icons. Shape-checking
      // rather than name-checking means a future export cannot break this by
      // being called something unexpected.
      continue;
    }
    out.push({
      slug: i.slug,
      title: i.title,
      hex: typeof i.hex === 'string' ? i.hex : '000000',
      path: i.path,
    });
  }
  out.sort((a, b) => a.title.localeCompare(b.title));
  return out;
})();

/**
 * Icons matching [query], best first.
 *
 * ─── PREFIX BEFORE SUBSTRING, AND IT MATTERS HERE ──────────────────────────
 *
 * A plain `includes` puts "Samsung Pay" above "Samsung" for the query "sam",
 * because it sorts alphabetically and both match equally. Ranking exact, then
 * prefix, then substring puts the thing someone typed the start of at the top,
 * which is the only ordering that makes a 3,453-item set feel small.
 *
 * An empty query returns the first [LIMIT] alphabetically rather than nothing,
 * so the picker has something to show before anyone types.
 */
export function searchGlyphs(query: string): Glyph[] {
  const q = query.trim().toLowerCase();
  if (!q) return ALL.slice(0, LIMIT);

  const exact: Glyph[] = [];
  const prefix: Glyph[] = [];
  const inner: Glyph[] = [];

  for (const g of ALL) {
    const t = g.title.toLowerCase();
    if (t === q || g.slug === q) exact.push(g);
    else if (t.startsWith(q) || g.slug.startsWith(q)) prefix.push(g);
    else if (t.includes(q) || g.slug.includes(q)) inner.push(g);
    if (exact.length + prefix.length >= LIMIT) break;
  }

  return [...exact, ...prefix, ...inner].slice(0, LIMIT);
}

/** One icon by slug, or null. For rehydrating a saved choice. */
export function glyphBySlug(slug: string): Glyph | null {
  return ALL.find((g) => g.slug === slug) ?? null;
}
