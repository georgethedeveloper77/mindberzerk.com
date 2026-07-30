import 'server-only';

import { readLiveIndex, type AppId } from './catalogue';
import { deleteObject, listPrefixObjects } from './r2';
import { INDEX_NAME } from './sign';

/**
 * ORPHANED OBJECTS: what is in the bucket that the catalogue no longer names.
 *
 * Unpublish and distro delete leave objects in place on purpose, so a device
 * holding a thirty-second-old index finishes its download instead of failing
 * with what looks like tampering. This module is the OTHER half of that
 * decision: the deliberate, review-first pass that reclaims those objects
 * later, when a human has looked at exactly what would go.
 *
 * ─── WHAT COUNTS AS ACCOUNTED FOR ───────────────────────────────────────────
 *
 * Protected unconditionally, never reported and never deleted:
 *
 *   - `<app>/index.json` and `<app>/index.sig`, the catalogue itself
 *   - everything under `<app>/admin/`: drafts, listing flags, panel state
 *   - everything under `<app>/site/`: legal pages and site content live at
 *     fixed mutable paths and are versioned by nothing, so the index cannot
 *     vouch for them and this sweep has no opinion about them
 *   - every live pack's CURRENT directory, `<app>/<pack.path>/`
 *
 * Everything else under the app prefix is an orphan: an old version of a pack
 * that is still live, or the whole directory of a pack that is not in the
 * index at all. The two are labelled apart because they read differently to a
 * human deciding: an old version is routine; an unpublished pack might be one
 * you meant to keep.
 *
 * ─── THE UNREADABLE-INDEX REFUSAL, TWICE ────────────────────────────────────
 *
 * With the index unreachable or corrupt, every object in the bucket looks
 * unaccounted for. Reporting that would render the entire CDN as garbage, and
 * sweeping it would BE the catastrophe. Both the report and the sweep refuse
 * with the reason instead, the same arithmetic as guardIndex.
 *
 * ─── THE SWEEP NEVER TRUSTS THE CALLER'S LIST ───────────────────────────────
 *
 * The client sends group directories, not keys. The sweep recomputes the
 * report from the live index and the live listing at delete time and removes
 * only keys that are still orphaned AND inside a requested group. A publish
 * that landed between page load and click therefore protects its own objects
 * automatically, because they stop being orphans before anything is deleted.
 */

export interface OrphanGroup {
  /** Directory relative to the app prefix, e.g. `themes/kali-theme/2`. */
  dir: string;
  /** 'stale' = old version of a live pack. 'unpublished' = not in the index. */
  kind: 'stale' | 'unpublished' | 'loose';
  /** The live pack this is an old version of, when kind is 'stale'. */
  packId: string | null;
  keys: string[];
  sizeBytes: number;
}

export type OrphanReport =
  | { ok: true; groups: OrphanGroup[]; totalBytes: number; objectCount: number }
  | { ok: false; error: string };

function groupDirFor(rel: string): { dir: string; loose: boolean } {
  const parts = rel.split('/');
  // `<typeDir>/<packId>/<version>/...` is the pack layout; group by the first
  // three segments so one group is one pack version. Anything shallower is a
  // stray object and groups as itself.
  if (parts.length >= 4) return { dir: parts.slice(0, 3).join('/'), loose: false };
  return { dir: rel, loose: true };
}

export async function orphanReport(app: AppId): Promise<OrphanReport> {
  const live = await readLiveIndex(app);
  if (live.unreachable) {
    return {
      ok: false,
      error:
        `Could not read ${app}/${INDEX_NAME}: ${live.unreachable}. ` +
        'With no catalogue to compare against, everything would look orphaned, so nothing is reported.',
    };
  }
  if (live.corrupt) {
    return {
      ok: false,
      error: `${app}/${INDEX_NAME} exists but does not parse, so nothing can be safely called orphaned.`,
    };
  }

  let objects: { key: string; size: number }[];
  try {
    objects = await listPrefixObjects(`${app}/`);
  } catch (e) {
    return { ok: false, error: (e as Error).message || 'The bucket could not be listed.' };
  }

  const prefix = `${app}/`;
  const livePathPrefixes = live.packs.map((p) => `${p.path}/`);
  const livePackDirs = new Map<string, string>();
  for (const p of live.packs) {
    // `themes/kali-theme/3` -> parent `themes/kali-theme` owned by packId.
    const parent = p.path.split('/').slice(0, 2).join('/');
    livePackDirs.set(parent, p.packId);
  }

  const groups = new Map<string, OrphanGroup>();
  let totalBytes = 0;
  let objectCount = 0;

  for (const o of objects) {
    const rel = o.key.slice(prefix.length);
    if (!rel) continue;
    if (rel === 'index.json' || rel === 'index.sig') continue;
    if (rel.startsWith('admin/')) continue;
    if (rel.startsWith('site/')) continue;
    if (livePathPrefixes.some((p) => rel.startsWith(p))) continue;

    const { dir, loose } = groupDirFor(rel);
    const parent = dir.split('/').slice(0, 2).join('/');
    const stalePackId = livePackDirs.get(parent) ?? null;

    const existing = groups.get(dir);
    if (existing) {
      existing.keys.push(o.key);
      existing.sizeBytes += o.size;
    } else {
      groups.set(dir, {
        dir,
        kind: loose ? 'loose' : stalePackId ? 'stale' : 'unpublished',
        packId: stalePackId,
        keys: [o.key],
        sizeBytes: o.size,
      });
    }
    totalBytes += o.size;
    objectCount++;
  }

  return {
    ok: true,
    groups: [...groups.values()].sort((a, b) => a.dir.localeCompare(b.dir)),
    totalBytes,
    objectCount,
  };
}

export type SweepResult =
  | { ok: true; deleted: number; freedBytes: number; skippedDirs: string[] }
  | { ok: false; error: string };

/**
 * Delete the orphaned objects inside [dirs]. Recomputed, never taken on faith:
 * a requested directory that is no longer orphaned (a publish landed since the
 * page rendered) is skipped and reported rather than deleted.
 */
export async function sweepOrphans(app: AppId, dirs: string[]): Promise<SweepResult> {
  if (dirs.length === 0) return { ok: false, error: 'Nothing selected to sweep.' };

  const report = await orphanReport(app);
  if (!report.ok) return { ok: false, error: report.error };

  const byDir = new Map(report.groups.map((g) => [g.dir, g]));
  const skippedDirs: string[] = [];
  let deleted = 0;
  let freedBytes = 0;

  for (const dir of dirs) {
    const group = byDir.get(dir);
    if (!group) {
      skippedDirs.push(dir);
      continue;
    }
    for (const key of group.keys) {
      await deleteObject(key);
      deleted++;
    }
    freedBytes += group.sizeBytes;
  }

  return { ok: true, deleted, freedBytes, skippedDirs };
}
