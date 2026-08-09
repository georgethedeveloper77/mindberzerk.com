import 'server-only';

import { readLiveIndex } from '@/lib/core/catalogue';
import { getObject } from '@/lib/core/r2';

import { CONTENT_PACKS } from './content-packs';

/**
 * Read what is currently published, so an editor starts from the live document
 * rather than from an empty box.
 *
 * READ THROUGH THE INDEX, NOT BY GUESSING A PATH. The object key contains the
 * version, and the version lives in the index. Assembling a key from the pack id
 * alone would work today and silently read the wrong version the moment anything
 * about `dirFor` changes, which is the exact failure the panel's own history
 * records for the two publish paths that disagreed about a directory.
 */
export interface PublishedContent {
  /** Parsed document, or null when nothing is published yet. */
  document: unknown | null;
  /** Live version, or 0. */
  version: number;
  /** Object key, for showing where it came from. */
  key: string | null;
  /**
   * Set when the live index could not be read at all.
   *
   * Distinct from "nothing published", and the editor must show it: starting
   * from an empty document because a token expired, then publishing, is how a
   * whole registry gets replaced with one row. `guardIndex` refuses the write,
   * but the editor should not have let it get that far.
   */
  unreachable: string | null;
}

export async function readPublishedContent(packId: string): Promise<PublishedContent> {
  const plan = CONTENT_PACKS[packId];
  if (!plan) return { document: null, version: 0, key: null, unreachable: null };

  const live = await readLiveIndex('g-recovery');
  if (live.unreachable) {
    return { document: null, version: 0, key: null, unreachable: live.unreachable };
  }

  const entry = live.packs.find((p) => p.packId === packId);
  if (!entry) return { document: null, version: 0, key: null, unreachable: null };

  const key = `g-recovery/${entry.path}/${plan.fileName}`;
  const bytes = await getObject(key);
  if (!bytes) {
    // The index says it exists and the object does not. Reported rather than
    // treated as absent, because publishing over it would look like a first
    // publish and would not be one.
    return {
      document: null,
      version: entry.version,
      key,
      unreachable: `${key} is listed in the index but missing from the bucket`,
    };
  }

  try {
    return {
      document: JSON.parse(bytes.toString('utf8')) as unknown,
      version: entry.version,
      key,
      unreachable: null,
    };
  } catch (e) {
    return {
      document: null,
      version: entry.version,
      key,
      unreachable: `${key} is not valid JSON: ${e instanceof Error ? e.message : String(e)}`,
    };
  }
}
