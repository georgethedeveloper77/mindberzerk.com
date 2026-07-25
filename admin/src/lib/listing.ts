import 'server-only';

import { getObject, putObject } from './r2';
import type { AppId } from './catalogue';

/**
 * The storefront on/off switch, kept OUT of the signed pipeline.
 *
 * A map of packId -> listed. Absent means listed, so the file only ever records
 * the exceptions (the things turned OFF), and a fresh install with no file lists
 * everything, which is the right default. Unsigned, the same way registry.json
 * and site content are: this is a merchandising choice, not a security one, and
 * it must not be able to change what a device is entitled to.
 *
 * Bundled packs (Ubuntu, KDE, Terminal, simple-icons) live in the APK and are
 * always available; the toggle is disabled for them in the UI. For CDN packs the
 * hard "remove from a device" action is Unpublish on the Packs screen; this flag
 * is the softer "hide from the storefront listing" that a paid catalogue needs.
 */
export type Listing = Record<string, boolean>;

const keyFor = (app: AppId) => `${app}/admin/listing.json`;

export async function readListing(app: AppId): Promise<Listing> {
  const bytes = await getObject(keyFor(app));
  if (!bytes) return {};
  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    return parsed && typeof parsed === 'object' ? (parsed as Listing) : {};
  } catch {
    return {};
  }
}

export async function setListed(app: AppId, packId: string, listed: boolean): Promise<void> {
  const current = await readListing(app);
  if (listed) delete current[packId];
  else current[packId] = false;
  await putObject(
    keyFor(app),
    Buffer.from(JSON.stringify(current, null, 2) + '\n', 'utf8'),
    'application/json',
  );
}

export function isListed(listing: Listing, packId: string): boolean {
  return listing[packId] !== false;
}
