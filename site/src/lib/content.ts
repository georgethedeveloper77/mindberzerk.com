import 'server-only';

import { REGISTRY, type AppMeta } from './registry';

/**
 * The read side of the panel's site-content track.
 *
 * ## Kept in step with admin/src/lib/site-content.ts
 *
 * The panel WRITES site/content.json; this module READS it. The interfaces are
 * copied from the panel's file and must stay shape-identical, or a publish from
 * the panel renders wrong here in a way no build step catches. Edit the two
 * together, the same discipline as registry.ts.
 *
 * ## Fallbacks over failures
 *
 * A marketing page must render something even when the bucket is empty or
 * unreachable, so every read degrades to the seed rather than throwing. That is
 * the same posture as the panel's readSiteContent, minus the corrupt/unreachable
 * reporting, because there is no admin looking at this page to act on it.
 */

export interface Hero {
  eyebrow: string;
  /** Text after the first comma renders in the accent colour. */
  headline: string;
  lede: string;
}

export interface Stat {
  label: string;
  /** A typed value, or the literal 'auto' for the one the site computes. */
  value: string;
}

export interface SiteContent {
  /** Registry ids, in display order. */
  featured: string[];
  hero: Hero;
  stats: Stat[];
  updatedAt: number;
}

const CDN_BASE = (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/$/, '');
const CONTENT_URL = `${CDN_BASE}/site/content.json`;

/**
 * Where the launcher's live catalogue is fetched from, for the one stat the
 * site computes. Overridable because the site does not own this path; if the
 * publish layout ever moves the index, this is an env change, not a deploy.
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

export async function readSiteContent(): Promise<SiteContent> {
  let parsed: Partial<SiteContent>;
  try {
    const res = await fetch(CONTENT_URL, { next: { revalidate: 300 } });
    if (!res.ok) return seed();
    parsed = (await res.json()) as Partial<SiteContent>;
  } catch {
    return seed();
  }
  // Field-by-field with seed fallbacks, same as the panel's reader, so a
  // document written by an older panel still renders rather than throwing.
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
export function resolveFeatured(ids: string[]): AppMeta[] {
  const known = new Map(REGISTRY.map((a) => [a.id, a] as const));
  return ids.map((id) => known.get(id)).filter((a): a is AppMeta => !!a);
}

/**
 * The distro count for a stat whose value is 'auto': theme packs in the live
 * index. Null when the index cannot be read or parsed, and the caller DROPS the
 * row: an absent stat, never a placeholder string.
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

/** Stats ready to render: 'auto' computed or the row dropped. */
export async function resolveStats(stats: Stat[]): Promise<Stat[]> {
  if (!stats.some((s) => s.value === 'auto')) return stats;
  const count = await distroCount();
  return stats
    .map((s) => (s.value === 'auto' ? (count === null ? null : { ...s, value: String(count) }) : s))
    .filter((s): s is Stat => s !== null);
}

/**
 * Headline split for the accent rule: everything after the first comma renders
 * in the accent colour. No comma, no accent segment.
 */
export function splitHeadline(headline: string): { plain: string; accent: string | null } {
  const i = headline.indexOf(',');
  if (i < 0) return { plain: headline, accent: null };
  return { plain: headline.slice(0, i + 1), accent: headline.slice(i + 1).trim() || null };
}
