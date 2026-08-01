import 'server-only';

import { getObject, putObject } from '@/lib/r2';
import type { AppId } from '@/lib/catalogue';

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

/**
 * The listing flags, plus whether we actually managed to read them.
 *
 * TWO FUNCTIONS OVER ONE RESULT, because readers and writers need opposite
 * behaviour from the same failure. A page rendering a toggle should degrade to
 * "everything listed" and show a banner. [setListed] must NOT: it merges into
 * what it read, so a soft-failed read would hand it an empty object and the
 * write would erase every other pack's flag.
 */
export async function readListingResult(
  app: AppId,
): Promise<{ listing: Listing; unreachable: string | null }> {
  let bytes: Buffer | null;
  try {
    bytes = await getObject(keyFor(app));
  } catch (e) {
    return { listing: {}, unreachable: (e as Error).message || 'The bucket could not be read.' };
  }
  if (!bytes) return { listing: {}, unreachable: null };
  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    return {
      listing: parsed && typeof parsed === 'object' ? (parsed as Listing) : {},
      unreachable: null,
    };
  } catch {
    // Unparseable is treated as empty rather than fatal: the flags are a
    // presentation nicety, and every pack defaulting to listed is the safe
    // reading of a broken file.
    return { listing: {}, unreachable: null };
  }
}

export async function readListing(app: AppId): Promise<Listing> {
  return (await readListingResult(app)).listing;
}

export async function setListed(app: AppId, packId: string, listed: boolean): Promise<void> {
  // The read-before-write guard. Without it, one expired credential turns a
  // single toggle into "unhide everything", because the merge base came back
  // empty and the write is unconditional.
  const { listing: current, unreachable } = await readListingResult(app);
  if (unreachable) {
    throw new Error(`Cannot change listing: the bucket could not be read (${unreachable}).`);
  }
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
