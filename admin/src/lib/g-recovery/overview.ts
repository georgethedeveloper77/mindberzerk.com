import 'server-only';

import { indexIsSigned, readLiveIndex } from '@/lib/core/catalogue';
import type { IndexPack } from '@/lib/core/sign';

import { CONTENT_PACKS, type ContentPackPlan } from './content-packs';
import { readPublishedContent } from './content-read';

/**
 * WHAT THIS APP ACTUALLY SHIPS, read off the bucket.
 *
 * ─── WHY G RECOVERY NEEDS ITS OWN READER ────────────────────────────────────
 *
 * The launcher's overview counts distros, icon packs and paid packs, because
 * that is what the launcher sells. None of those exist here. This app ships
 * three documents and one of them is a map of where deleted files hide, so the
 * question the screen has to answer is "what do phones currently believe about
 * this device", not "how many packs are in the bucket".
 *
 * ─── EVERYTHING IS READ, NOTHING IS REMEMBERED ──────────────────────────────
 *
 * The counts come from the published trashmap, not from a draft, not from a
 * database, not from the editor's state. The screen's job is to report what
 * devices hold, and a number that describes something else while looking like
 * this one is worse than no number.
 *
 * ─── AND AN UNREADABLE BUCKET IS NOT AN EMPTY ONE ───────────────────────────
 *
 * [unreachable] is carried through untouched, same as `readLiveIndex` and
 * `readPublishedContent` do, because collapsing it into zero is how a panel
 * reports full coverage while a credential is expired.
 */

/**
 * How much we trust a rule.
 *
 * OPTIONAL IN THE DOCUMENT, and absent is its own answer rather than a
 * synonym for either other value. A path taken from a forum post and a path
 * reproduced on hardware behave identically in the scanner, so nothing in the
 * app can tell them apart; only the person who added the row knows, and this is
 * where they say so. `unstated` means the row predates the field.
 */
export type Confidence = 'verified' | 'reported' | 'unstated';

export interface CoverageEntry {
  kind: 'app' | 'oem' | 'thumbnails';
  /** Package name, brand, or an empty string for the thumbnail cache. */
  id: string;
  label: string;
  paths: string[];
  role: string;
  fidelity: string;
  confidence: Confidence;
}

export interface CoverageCounts {
  apps: number;
  oem: number;
  paths: number;
  verified: number;
  reported: number;
  unstated: number;
}

export interface RegistryReport {
  /** The registry's own version, which is what the device displays. */
  version: number;
  /** The pack version, which is the immutable object path. */
  packVersion: number;
  entries: CoverageEntry[];
  counts: CoverageCounts;
  restoreFolder: string;
}

export interface ContentPackState {
  plan: ContentPackPlan;
  live: IndexPack | null;
}

export interface RecoveryReport {
  index: {
    exists: boolean;
    corrupt: boolean;
    unreachable: string | null;
    signed: boolean;
    generatedAt: number;
    keyId: string;
    packCount: number;
    sizeBytes: number;
  };
  /** One row per pack this app knows how to publish, published or not. */
  content: ContentPackState[];
  /** Null when the trashmap is unpublished or could not be read. */
  registry: RegistryReport | null;
  /** Why the trashmap could not be read, distinct from "not published yet". */
  registryUnreachable: string | null;
}

export async function recoveryReport(): Promise<RecoveryReport> {
  const live = await readLiveIndex('g-recovery');

  // Only worth asking when there is an index to sign. On an unreachable bucket
  // this returns false, and false rendered as "unsigned" beside the unreachable
  // banner reads as unknown, which is what it is.
  const signed = live.exists ? await indexIsSigned('g-recovery').catch(() => false) : false;

  const content: ContentPackState[] = Object.values(CONTENT_PACKS).map((plan) => ({
    plan,
    live: live.packs.find((p) => p.packId === plan.packId) ?? null,
  }));

  const index = {
    exists: live.exists,
    corrupt: live.corrupt,
    unreachable: live.unreachable,
    signed,
    generatedAt: live.generatedAt,
    keyId: live.keyId,
    packCount: live.packs.length,
    sizeBytes: live.packs.reduce((n, p) => n + p.sizeBytes, 0),
  };

  // No point fetching the document when the index that names it could not be
  // read: the fetch would fail for the same reason and report it twice.
  if (live.unreachable || live.corrupt) {
    return { index, content, registry: null, registryUnreachable: live.unreachable };
  }

  const published = await readPublishedContent('trashmap');
  if (published.unreachable) {
    return { index, content, registry: null, registryUnreachable: published.unreachable };
  }
  if (!published.document) {
    return { index, content, registry: null, registryUnreachable: null };
  }

  return {
    index,
    content,
    registry: parseRegistry(published.document, published.version),
    registryUnreachable: null,
  };
}

// ── parsing ─────────────────────────────────────────────────────────────────

/**
 * Read the published trashmap into rows.
 *
 * TOLERANT ON PURPOSE, and the reason is not politeness. This parses a document
 * that is already live: it was validated on the way up, but it may have been
 * written by an older build of this panel, by the CLI, or by hand. Throwing here
 * would take out the overview because one row lacks a label, which is the least
 * useful moment for the screen that reports problems to become one.
 */
function parseRegistry(raw: unknown, packVersion: number): RegistryReport {
  const doc = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;

  const entries: CoverageEntry[] = [
    ...list(doc.apps).map((e) => entry(e, 'app')),
    ...list(doc.oem).map((e) => entry(e, 'oem')),
  ];

  const thumbs = (typeof doc.thumbnails === 'object' && doc.thumbnails !== null
    ? doc.thumbnails
    : {}) as Record<string, unknown>;
  const thumbPaths = list(thumbs.paths).filter((p): p is string => typeof p === 'string');
  if (thumbPaths.length > 0) {
    entries.push({
      kind: 'thumbnails',
      id: '',
      label: 'Thumbnail cache',
      paths: thumbPaths,
      role: str(thumbs.role) ?? 'cache',
      fidelity: str(thumbs.fidelity) ?? 'preview',
      confidence: confidence(thumbs.confidence),
    });
  }

  const counts: CoverageCounts = {
    apps: entries.filter((e) => e.kind === 'app').length,
    oem: entries.filter((e) => e.kind === 'oem').length,
    paths: entries.reduce((n, e) => n + e.paths.length, 0),
    verified: entries.filter((e) => e.confidence === 'verified').length,
    reported: entries.filter((e) => e.confidence === 'reported').length,
    unstated: entries.filter((e) => e.confidence === 'unstated').length,
  };

  return {
    version: typeof doc.version === 'number' ? doc.version : 0,
    packVersion,
    entries,
    counts,
    restoreFolder: str(doc.restoreFolder) ?? 'Pictures/G Recovery',
  };
}

function list(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function confidence(value: unknown): Confidence {
  return value === 'verified' || value === 'reported' ? value : 'unstated';
}

function entry(raw: unknown, kind: 'app' | 'oem'): CoverageEntry {
  const e = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;
  const id = str(kind === 'app' ? e.pkg : e.brand) ?? '';
  return {
    kind,
    id,
    label: str(e.label) ?? id ?? 'unnamed',
    paths: list(e.paths).filter((p): p is string => typeof p === 'string'),
    role: str(e.role) ?? 'trash',
    fidelity: str(e.fidelity) ?? 'full',
    confidence: confidence(e.confidence),
  };
}
