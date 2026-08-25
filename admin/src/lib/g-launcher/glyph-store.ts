'use client';

/**
 * THE LINE-ART INDEX: 32,951 packages mapped to 13,623 drawings.
 *
 * ─── WHAT WAS ACTUALLY IMPORTED, AND WHAT WAS NOT ───────────────────────────
 *
 * Not code. Arcticons has no algorithm that invents an icon for an app it has
 * never seen, and the belief that it does is what this file exists to settle.
 * What it has is a hand-curated mapping table built over years of pull
 * requests, and that table is the asset. Their build scripts convert SVG to
 * VectorDrawable, which is a step this pipeline does not take, because the
 * launcher composes PNGs.
 *
 * Measured on the real `appfilter.xml` (6.35 MB):
 *
 *     item elements       48,132
 *     unique packages     32,951
 *     unique drawings     13,623
 *
 * So an app the set does not draw falls through, exactly as it does here. The
 * Kenyan apps in the target market are the ones that fall through: `ke.co.jiji`
 * is absent, and so are HouseHunt and Houzi. Coverage is not magic, it is
 * thirty thousand hand-written lines.
 *
 * ─── WHY TWO ARTIFACTS AND NOT ONE ──────────────────────────────────────────
 *
 * The MAP compacts to 1.25 MB, 0.40 MB over the wire gzipped. That is small
 * enough to load once and hold, and it is what search and matching need.
 *
 * The GLYPHS do not. Normalised, the full set is 12.78 MB, about 5.5 MB
 * gzipped, which is not something a panel should fetch to let somebody pick
 * forty icons. So the sync script emits a glyph bundle scoped to a named slug
 * set: the roles, the app registry, and anything explicitly listed. For a
 * 193-icon pack that is roughly 180 KB raw and well under 100 KB gzipped.
 *
 * If the whole set is ever wanted for browsing, `sync-arcticons.mjs --all`
 * emits `glyphs-all.json` and this module will load it behind an explicit
 * action. It must never be the default: a 5.5 MB fetch on panel open is a
 * regression nobody would connect back to this decision.
 */

/** Shape of `arcticons/index.json`, as `sync-arcticons.mjs` writes it. */
export interface GlyphIndex {
  v: 1;
  /** Which set this came from, e.g. `arcticons`. */
  source: string;
  /** Upstream commit or release the index was built from. */
  revision: string;
  /** SPDX id for the ART, which is not the id for the upstream app. */
  license: string;
  /** Credit line that must travel with any pack built from this. */
  attribution: string;
  /** viewBox extent every drawing in this set is authored against. */
  box: number;
  /** Declared stroke width, or 0 when the set relies on the SVG default. */
  strokeWidth: number;
  /** Every drawing name, sorted. Indices into this are the map's values. */
  slugs: string[];
  /** Android package id to an index into [slugs]. */
  map: Record<string, number>;
}

/** Shape of a glyph bundle. Minimal SVG text, keyed by slug. */
export type GlyphBundle = Record<string, string>;

export interface GlyphMatch {
  pkg: string;
  slug: string;
  svg: string | null;
}

/**
 * A loaded set, ready to match against.
 *
 * Holds the index and whatever glyph bundles have been fetched so far, so a
 * caller can ask for art without knowing which bundle it came from.
 */
export class GlyphStore {
  private constructor(
    readonly index: GlyphIndex,
    private readonly glyphs: GlyphBundle,
  ) {}

  static async load(baseUrl: string, bundle = 'glyphs.json'): Promise<GlyphStore> {
    const [index, glyphs] = await Promise.all([
      fetchJson<GlyphIndex>(`${baseUrl}/index.json`),
      fetchJson<GlyphBundle>(`${baseUrl}/${bundle}`).catch(() => ({})),
    ]);
    if (!index || !Array.isArray(index.slugs)) {
      throw new Error('Glyph index is missing or malformed. Run sync-arcticons.mjs.');
    }
    return new GlyphStore(index, glyphs ?? {});
  }

  /** Construct from artifacts already in hand. For tests and for a local dir. */
  static from(index: GlyphIndex, glyphs: GlyphBundle): GlyphStore {
    return new GlyphStore(index, glyphs);
  }

  get size(): number {
    return this.index.slugs.length;
  }

  get mapped(): number {
    return Object.keys(this.index.map).length;
  }

  /** How many glyph bodies are actually in hand, as opposed to merely mapped. */
  get loaded(): number {
    return Object.keys(this.glyphs).length;
  }

  /** The drawing name for a package, or null when the set does not draw it. */
  slugFor(pkg: string): string | null {
    const i = this.index.map[pkg];
    return i === undefined ? null : this.index.slugs[i] ?? null;
  }

  /** The art for a drawing name, or null when its bundle was not fetched. */
  svgFor(slug: string): string | null {
    return this.glyphs[slug] ?? null;
  }

  /**
   * Resolve a list of packages in one pass.
   *
   * Returns a row for EVERY package asked about, including the misses, because
   * the misses are the work. A caller that only wanted the hits would filter,
   * and a caller that dropped them silently would never build the screen that
   * tells the author which 56 apps need drawing.
   */
  match(packages: string[]): GlyphMatch[] {
    return packages.map((pkg) => {
      const slug = this.slugFor(pkg);
      return { pkg, slug: slug ?? '', svg: slug ? this.svgFor(slug) : null };
    });
  }

  /**
   * Drawing names matching [query], best first.
   *
   * Exact, then prefix, then substring, the same ranking `glyph-search.ts`
   * applies to Simple Icons and for the same reason: a plain `includes` sorts
   * "samsung_pay" above "samsung" for the query "sam", which makes a set of
   * thirteen thousand feel unusable rather than merely large.
   */
  search(query: string, limit = 60): string[] {
    const q = query.trim().toLowerCase();
    if (!q) return this.index.slugs.slice(0, limit);

    const exact: string[] = [];
    const prefix: string[] = [];
    const inner: string[] = [];
    for (const slug of this.index.slugs) {
      if (slug === q) exact.push(slug);
      else if (slug.startsWith(q)) prefix.push(slug);
      else if (slug.includes(q)) inner.push(slug);
      if (exact.length + prefix.length >= limit) break;
    }
    return [...exact, ...prefix, ...inner].slice(0, limit);
  }
}

async function fetchJson<T>(url: string): Promise<T | null> {
  const res = await fetch(url, { cache: 'force-cache' });
  if (!res.ok) return null;
  return (await res.json()) as T;
}

/**
 * Coverage of a package list against the set.
 *
 * The number the author acts on. Not a percentage in isolation: the misses come
 * back named, because "77% covered" is a fact and "these 56 apps need drawing"
 * is a task.
 */
export function coverage(
  store: GlyphStore,
  packages: string[],
): { hit: string[]; miss: string[]; pct: number } {
  const hit: string[] = [];
  const miss: string[] = [];
  for (const p of packages) (store.slugFor(p) ? hit : miss).push(p);
  return {
    hit,
    miss,
    pct: packages.length ? (hit.length / packages.length) * 100 : 0,
  };
}
