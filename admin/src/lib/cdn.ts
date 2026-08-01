import 'server-only';

import type { PackManifest } from '@/lib/pack-content';

/**
 * THE PUBLIC DOOR.
 *
 * `r2.ts` is the S3 door: credentialed, able to write, and the one the panel
 * uses for everything that changes the bucket. This is the other one. The bucket
 * is served publicly at `cdn.mindberzerk.com`, so anything already published can
 * be read over plain HTTPS with no credential at all.
 *
 * ─── WHY THAT MATTERS RATHER THAN BEING A DETAIL ────────────────────────────
 *
 * Two doors, two independent failure modes, and right now one of them is shut.
 * The S3 token is being rejected, which takes out `getObject` and therefore
 * `readPackJson` and `readManifest` in `pack-content.ts`. Everything that reads
 * a pack's CONTENTS through those goes with it.
 *
 * The public door is unaffected, and `icons/page.tsx` already leans on that: it
 * renders real pack art off the CDN while the S3 side is down, and says so.
 *
 * ─── AND WHY THIS IS SERVER-SIDE, WHICH LOOKS BACKWARDS ─────────────────────
 *
 * The obvious move is to fetch this from the browser, since the URL is public
 * and the browser is already loading these exact images on the icons list.
 *
 * It is not the same thing. `<img src>` is not subject to CORS; `fetch()` is. A
 * browser reading `pack.json` would need an `Access-Control-Allow-Origin` on the
 * bucket allowing the panel's origin, which is one more thing to configure and
 * one more thing to be silently wrong.
 *
 * CORS is a BROWSER policy. Node is not a browser. A server-side fetch of a
 * public URL is subject to neither CORS nor the S3 credential, which is the only
 * route to a pack's contents that is open today with nothing configured.
 *
 * `server-only` is therefore load-bearing rather than decorative: importing this
 * into a client component would put `process.env.CDN_BASE_URL` in the browser,
 * where Next inlines nothing that is not `NEXT_PUBLIC_`, so it would read as
 * undefined and fall through to the default host without a word. Better a build
 * error.
 */

/** Where the bucket is served publicly. Not the S3 endpoint, which is signed. */
export function cdnBase(): string {
  return (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
}

/** Absolute public URL of one file inside a published pack. */
export function cdnUrl(app: string, path: string, name: string): string {
  return `${cdnBase()}/${app}/${path}/${name}`;
}

/** One published icon, carried to the client as bytes it can rebuild a File from. */
export interface RehydratedIcon {
  pkg: string;
  file: string;
  /** `data:image/png;base64,...`. See the note in [readPublishedHeroPack]. */
  dataUrl: string;
}

/** A published hero pack, read back into the shape the builder starts from. */
export interface RehydratedPack {
  packId: string;
  name: string;
  masked: boolean;
  sku: string | null;
  minAppVersion: number;
  /** The version currently live. The builder publishes this plus one. */
  publishedVersion: number;
  icons: RehydratedIcon[];
  /**
   * Everything that went wrong without being fatal, as sentences.
   *
   * A pack that is missing four of its forty icons has to OPEN, or the only way
   * to fix it is to rebuild it from nothing. But it must not open quietly, or
   * the next publish drops those four permanently and the pack that reaches
   * devices is the broken one. So it opens, and it says what is missing.
   */
  notes: string[];
}

const MIME: Record<string, string> = {
  png: 'image/png',
  webp: 'image/webp',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  svg: 'image/svg+xml',
};

function mimeFor(file: string): string {
  const ext = file.split('.').pop()?.toLowerCase() ?? '';
  return MIME[ext] ?? 'image/png';
}

/**
 * GET one object over the public door.
 *
 * `force-cache` because a pack path carries its version (`hero/kali-icons/3`)
 * and every object under it is immutable, which is the same property that lets
 * `r2.ts` set a year-long cache header on it. Re-reading the same version can
 * never see different bytes, so caching it is free.
 */
async function getPublic(url: string): Promise<Buffer | null> {
  try {
    const res = await fetch(url, { cache: 'force-cache' });
    if (!res.ok) return null;
    return Buffer.from(await res.arrayBuffer());
  } catch {
    return null;
  }
}

/**
 * Read a published hero pack back into an editable starting state.
 *
 * ─── pack.json IS THE ONLY SOURCE OF THE PACKAGE MAP ────────────────────────
 *
 * `manifest.json` lists the FILES in a pack, and that is not enough. The grid
 * needs to know which package each file belongs to, and only `pack.json` has
 * that. It cannot be recovered from the filenames either: `fileNameFor` maps
 * every non-alphanumeric to an underscore, so `com_whatsapp.png` is equally
 * `com.whatsapp` and `com_whatsapp` and nothing distinguishes them.
 *
 * So a pack whose `pack.json` cannot be read does not open. Returning a partial
 * pack there would silently drop every mapping and republish a pack that
 * installs and renders nothing.
 *
 * ─── DATA URLS, NOT BASE64 IN A SIDE FIELD ──────────────────────────────────
 *
 * The client needs three things per icon: a preview `src`, a Blob to publish,
 * and a File to hold. A data URL is all three at once. It is the preview `src`
 * directly, it decodes to a Blob synchronously with `atob`, and it needs no
 * `URL.createObjectURL`, which means the builder has nothing to revoke and
 * cannot leak a handle when an entry is replaced.
 *
 * ─── THE BYTES ARE PASSED THROUGH, NOT RE-RENDERED ──────────────────────────
 *
 * These PNGs already went through `renderHeroIcon` before they were published,
 * so they are already 192 squares. Sending them back through it would be a 1:1
 * blit and lossless, but it would RE-ENCODE, and the file itself notes that two
 * browsers produce byte-different PNGs. Opening a pack and republishing it
 * untouched would then change every file hash in the manifest for no reason.
 * Passing the published bytes through unchanged keeps that a no-op.
 */
export async function readPublishedHeroPack(
  app: string,
  entry: { packId: string; path: string; version: number; sku?: string | null },
): Promise<RehydratedPack | null> {
  const notes: string[] = [];

  const packBytes = await getPublic(cdnUrl(app, entry.path, 'pack.json'));
  if (!packBytes) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(packBytes.toString('utf8'));
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;
  const pack = parsed as Record<string, unknown>;

  const iconMap =
    pack.icons && typeof pack.icons === 'object'
      ? (pack.icons as Record<string, unknown>)
      : {};

  // minAppVersion lives in the manifest, not in pack.json. Missing is survivable
  // (the builder's own default applies) but it must be said, because publishing
  // with a lower floor than the pack had is how an old client picks up a pack it
  // cannot render.
  const manifestBytes = await getPublic(cdnUrl(app, entry.path, 'manifest.json'));
  let minAppVersion = 6;
  if (manifestBytes) {
    try {
      const m = JSON.parse(manifestBytes.toString('utf8')) as PackManifest;
      if (Number.isInteger(m.minAppVersion)) minAppVersion = m.minAppVersion;
    } catch {
      notes.push('The manifest could not be parsed, so the minimum app version fell back to the default. Check it before publishing.');
    }
  } else {
    notes.push('The manifest could not be read, so the minimum app version fell back to the default. Check it before publishing.');
  }

  const wanted: { pkg: string; file: string }[] = [];
  for (const [pkg, file] of Object.entries(iconMap)) {
    if (typeof file === 'string' && file.trim()) wanted.push({ pkg, file: file.trim() });
    else notes.push(`'${pkg}' has no filename in pack.json and was dropped.`);
  }

  const fetched = await Promise.all(
    wanted.map(async (w) => {
      const bytes = await getPublic(cdnUrl(app, entry.path, w.file));
      if (!bytes) return null;
      return {
        pkg: w.pkg,
        file: w.file,
        dataUrl: `data:${mimeFor(w.file)};base64,${bytes.toString('base64')}`,
      };
    }),
  );

  const icons: RehydratedIcon[] = [];
  for (let i = 0; i < fetched.length; i++) {
    const got = fetched[i];
    if (got) icons.push(got);
    else notes.push(`${wanted[i].file} is listed in pack.json but could not be read from the CDN. Publishing now would drop ${wanted[i].pkg}.`);
  }

  icons.sort((a, b) => a.pkg.localeCompare(b.pkg));

  return {
    packId: typeof pack.id === 'string' && pack.id ? pack.id : entry.packId,
    name: typeof pack.name === 'string' ? pack.name : entry.packId,
    masked: pack.masked === true,
    sku: entry.sku ?? null,
    minAppVersion,
    publishedVersion: entry.version,
    icons,
    notes,
  };
}
