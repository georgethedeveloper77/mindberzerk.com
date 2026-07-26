import 'server-only';

import { getObject } from './r2';
import type { AppId } from './registry';

/**
 * PHASE C5 - reading a published pack back out of the bucket.
 *
 * The index says a pack exists. This says what is inside it. Everything here is
 * a plain GET against the versioned path, so it is safe to call on a page: the
 * objects are immutable and cached for a year, and nothing is written.
 *
 * `path` comes from the index entry and already carries the version
 * (`themes/ubuntu-24-04/3`), which is why a detail page cannot accidentally read
 * a different version's manifest against this version's payload.
 */

export interface ManifestFile {
  path: string;
  size: number;
  sha256: string;
}

export interface PackManifest {
  formatVersion: number;
  packType: string;
  packId: string;
  version: number;
  minAppVersion: number;
  keyId: string;
  files: ManifestFile[];
}

export async function readManifest(
  app: AppId,
  path: string,
): Promise<PackManifest | null> {
  const bytes = await getObject(`${app}/${path}/manifest.json`);
  if (!bytes) return null;
  try {
    return JSON.parse(bytes.toString('utf8')) as PackManifest;
  } catch {
    // A manifest that does not parse cannot have been signed by this codebase,
    // so treating it as absent is the honest answer. The caller renders it as a
    // missing manifest, which is what the device would see too.
    return null;
  }
}

export async function hasSignature(app: AppId, path: string): Promise<boolean> {
  return (await getObject(`${app}/${path}/manifest.sig`)) !== null;
}

/**
 * Any JSON file inside a pack, as parsed data plus its raw text.
 *
 * The raw text is returned alongside because the detail page shows the file as
 * authored. Re-stringifying parsed JSON would reorder keys and normalise
 * whitespace, and the whole signing model rests on the bytes being exactly what
 * was uploaded.
 */
export async function readPackJson(
  app: AppId,
  path: string,
  name: string,
): Promise<{ data: unknown; raw: string } | null> {
  const bytes = await getObject(`${app}/${path}/${name}`);
  if (!bytes) return null;
  const raw = bytes.toString('utf8');
  try {
    return { data: JSON.parse(raw), raw };
  } catch {
    return { data: null, raw };
  }
}
