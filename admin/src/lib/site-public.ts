import { REGISTRY, type AppMeta } from '@/lib/registry';
import type { SiteContent, Stat } from '@/lib/site-content';

/**
 * The READ side of the site-content track, for the public landing.
 *
 * ## Why this is not just `readSiteContent` from site-content.ts
 *
 * That function reads R2 with the panel's S3 credentials. The landing is served
 * to anyone, must render when those credentials are broken (they are, right
 * now), and should be cacheable at the edge. So it reads the SAME document over
 * the public CDN instead, with no credential involved. One writer, two readers,
 * for two different audiences.
 *
 * ## The types come from the writer, deliberately
 *
 * `import type` is erased at compile time, so importing from site-content.ts
 * does NOT pull `server-only` or the R2 client into this module. What it does
 * buy is a compile error the moment the published shape and the rendered shape
 * disagree, which no amount of comment discipline achieves.
 */

const CDN_BASE = (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/$/, '');
const CONTENT_URL = `${CDN_BASE}/site/content.json`;

/**
 * Where the launcher's live catalogue is, for the one stat the site computes.
 * Overridable because the site does not own this path; if the publish layout
 * ever moves the index, this is an env change rather than a deploy.
 */
const INDEX_URL = process.env.SITE_INDEX_URL ?? `${CDN_BASE}/cdn/index.json`;

/** Mirrors the panel's seed so an unpublished site and the panel preview agree. */
function seed(): SiteContent {
  return {
    featured: REGISTRY.filter((a) => a.state === 'live' || a.state === 'build').map((a) => a.id),
    hero: {
      eyebrow: 'Android launcher, no ads, no account',
      headline: 'Your phone, running a real desktop.',
      lede: 'Pick a Linux distro for your home screen, watch it boot, get on with your day.',
    },
    stats: [
      { label: 'Play rating', value: '4.6' },
      { label: 'Installs', value: '2.1M' },
      { label: 'Distros', value: 'auto' },
      { label: 'Ads, ever', value: '0' },
    ],
    updatedAt: 0,
  };
}

export async function readPublishedSite(): Promise<SiteContent> {
  let parsed: Partial<SiteContent>;
  try {
    const res = await fetch(CONTENT_URL, { next: { revalidate: 300 } });
    if (!res.ok) return seed();
    parsed = (await res.json()) as Partial<SiteContent>;
  } catch {
    return seed();
  }
  // Field-by-field with seed fallbacks, matching the panel's own reader, so a
  // document written by an older version still renders rather than throwing.
  const s = seed();
  return {
    featured: Array.isArray(parsed.featured)
      ? parsed.featured.filter((x): x is string => typeof x === 'string')
      : s.featured,
    hero: { ...s.hero, ...(parsed.hero ?? {}) },
    stats: Array.isArray(parsed.stats)
      ? (parsed.stats as Stat[]).map((x) => ({ label: String(x.label ?? ''), value: String(x.value ?? '') }))
      : s.stats,
    updatedAt: Number(parsed.updatedAt) || 0,
  };
}

/** Same resolution the panel previews with: given order, unknown ids skipped. */
export function resolvePublicFeatured(ids: string[]): AppMeta[] {
  const known = new Map(REGISTRY.map((a) => [a.id, a] as const));
  return ids.map((id) => known.get(id)).filter((a): a is AppMeta => !!a);
}

/**
 * Theme packs in the live index, for a stat whose value is 'auto'. Null when
 * the index cannot be read, and the caller DROPS the row: a nullable stat
 * renders as an absent row, never a placeholder string.
 */
async function distroCount(): Promise<number | null> {
  try {
    const res = await fetch(INDEX_URL, { next: { revalidate: 300 } });
    if (!res.ok) return null;
    const idx = (await res.json()) as { packs?: { packType?: string }[] };
    if (!Array.isArray(idx.packs)) return null;
    return idx.packs.filter((p) => p.packType === 'theme').length;
  } catch {
    return null;
  }
}

export async function resolvePublicStats(stats: Stat[]): Promise<Stat[]> {
  if (!stats.some((s) => s.value === 'auto')) return stats;
  const count = await distroCount();
  return stats
    .map((s) => (s.value === 'auto' ? (count === null ? null : { ...s, value: String(count) }) : s))
    .filter((s): s is Stat => s !== null);
}

/**
 * Headline split for the accent rule the panel documents: everything after the
 * first comma renders in the accent colour. No comma, no accent segment.
 */
export function splitHeadline(headline: string): { plain: string; accent: string | null } {
  const i = headline.indexOf(',');
  if (i < 0) return { plain: headline, accent: null };
  return { plain: headline.slice(0, i + 1), accent: headline.slice(i + 1).trim() || null };
}
