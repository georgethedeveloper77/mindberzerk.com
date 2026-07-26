import 'server-only';

import { getObject, putObject } from './r2';
import { REGISTRY, type AppMeta } from './registry';

/**
 * PHASE C12 — the publisher site's content, as JSON this panel writes.
 *
 * ## Why site content is its own track, not a pack
 *
 * A pack is signed and versioned because a phone verifies it before installing.
 * The marketing site is a static Next.js build that reads a JSON file; nothing
 * verifies it, so signing would be ceremony with no reader. It gets its own
 * object, its own route, and its own publish button, and it deliberately does
 * NOT touch the index, the signature, or `generatedAt`. Confusing the two is how
 * a copy tweak ends up bumping the catalogue every device re-syncs.
 *
 * ## The registry is the source of truth for apps
 *
 * The featured row does not store app names, blurbs or marks. It stores an
 * ORDER and a visible-set of registry ids, and the site resolves the rest from
 * `REGISTRY` at build time. So adding G News to the site is a registry row plus
 * one id here, not a second copy of its description that drifts from the first.
 *
 * ## One object, whole-file writes
 *
 * `site/content.json` is small and edited by one person, so every publish writes
 * the whole document. No merge, no partial update, last-write-wins. The read
 * before a render is the concurrency story, same as the rest of the panel.
 */

const CONTENT_KEY = 'site/content.json';

export interface Hero {
  eyebrow: string;
  /** Text after the first comma renders in the accent colour on the site. */
  headline: string;
  lede: string;
}

export interface Stat {
  label: string;
  /** A typed value, or the literal 'auto' for the one the site computes. */
  value: string;
}

export interface SiteContent {
  /** Registry ids, in display order. Only ids; the site resolves the rest. */
  featured: string[];
  hero: Hero;
  stats: Stat[];
  /** Unix seconds of the last publish. Display only; not a version. */
  updatedAt: number;
}

/** What a fresh site looks like before anyone has published. */
function seed(): SiteContent {
  return {
    // Managed, live-or-building apps, in registry order. A sensible default so
    // the first render is not empty.
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

export interface SiteState {
  content: SiteContent;
  exists: boolean;
  /** Present but unparseable. Refuse to overwrite, same rule as the index. */
  corrupt: boolean;
  /**
   * Why the bucket could not be read, or absent. Distinct from `exists: false`
   * for the same reason it is on LiveIndex: one means "nothing published", the
   * other means "we do not know", and only the first is safe to write over.
   */
  unreachable?: string;
}

export async function readSiteContent(): Promise<SiteState> {
  // Same guard as readLiveIndex, for the same reason: this is called from a
  // page, and `getObject` rethrows anything that is not a missing key, so a
  // credential problem rendered as a stack trace where a sentence belonged.
  let bytes: Buffer | null;
  try {
    bytes = await getObject(CONTENT_KEY);
  } catch (e) {
    return {
      content: seed(),
      exists: false,
      corrupt: false,
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
  if (!bytes) return { content: seed(), exists: false, corrupt: false };
  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as Partial<SiteContent>;
    // Field-by-field with seed fallbacks, so a document written by an older
    // version of this panel still renders rather than throwing.
    const s = seed();
    return {
      content: {
        featured: Array.isArray(parsed.featured) ? parsed.featured.filter((x) => typeof x === 'string') : s.featured,
        hero: { ...s.hero, ...(parsed.hero ?? {}) },
        stats: Array.isArray(parsed.stats) ? (parsed.stats as Stat[]) : s.stats,
        updatedAt: Number(parsed.updatedAt) || 0,
      },
      exists: true,
      corrupt: false,
    };
  } catch {
    return { content: seed(), exists: true, corrupt: true };
  }
}

/**
 * Validate against the registry and write.
 *
 * The one real rule: a featured id must be a real registry app, and it must have
 * a store link if it is live — the site links a featured card to the store, so a
 * live app with no link is a card that goes nowhere. A planned app with no link
 * is fine; its card says "coming soon" and does not link.
 */
export async function writeSiteContent(
  next: SiteContent,
): Promise<{ ok: true; updatedAt: number } | { ok: false; error: string }> {
  const known = new Map(REGISTRY.map((a) => [a.id, a] as const));

  for (const id of next.featured) {
    const app = known.get(id);
    if (!app) return { ok: false, error: `"${id}" is not a registered app.` };
  }

  // A live featured app with no store link points a visitor at nothing. Planned
  // apps are allowed through: their card is informational, not a link.
  const brokenLinks = next.featured
    .map((id) => known.get(id))
    .filter((a): a is AppMeta => !!a)
    .filter((a) => a.state === 'live' && !a.pkg);
  if (brokenLinks.length > 0) {
    return {
      ok: false,
      error: `${brokenLinks.map((a) => a.name).join(', ')} ${
        brokenLinks.length === 1 ? 'is live but has' : 'are live but have'
      } no package for a store link. Add it to the registry or unfeature it.`,
    };
  }

  const updatedAt = Math.floor(Date.now() / 1000);
  const doc: SiteContent = { ...next, updatedAt };

  await putObject(
    CONTENT_KEY,
    Buffer.from(JSON.stringify(doc, null, 2), 'utf8'),
    'application/json',
  );

  return { ok: true, updatedAt };
}

/**
 * The registry rows a featured id resolves to, in the given order, skipping
 * anything unknown. This is what the SITE would call at build time; the panel
 * uses it to render the preview from the same resolution the site uses.
 */
export function resolveFeatured(ids: string[]): AppMeta[] {
  const known = new Map(REGISTRY.map((a) => [a.id, a] as const));
  return ids.map((id) => known.get(id)).filter((a): a is AppMeta => !!a);
}
