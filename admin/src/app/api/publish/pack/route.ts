import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { checkThemePackFlat, flatRefusal } from '@/lib/g-launcher/flat-check';
import { commitIndex, packKeyId, uploadPack, withShelfGrant } from '@/lib/core/publish-core';
import { unzipSync } from 'fflate';

import {
  INDEX_NAME,
  KNOWN_PACK_TYPES,
  isSafePackId,
  isSafeRelativePath,
  type PackFile,
  type PackType,
} from '@/lib/core/sign';

/**
 * PHASE C4 — POST a pack, get it signed, uploaded and listed.
 *
 * This is the route the whole panel exists for. Everything else is a form.
 *
 * ## Node runtime, not Edge
 *
 * Declared below and load-bearing. The Edge runtime has no `node:crypto`, so
 * `sign.ts` cannot run there, and `firebase-admin` cannot either. Without this
 * line a Next upgrade that changes the default would break signing and auth at
 * the same time, at deploy, with an error about a missing module.
 */
export const runtime = 'nodejs';

/**
 * Signing plus hashing several MB and then uploading it. The default 15s would
 * fail on a theme pack over a slow connection, and a half-published pack is
 * exactly what the upload ordering in `putPack` is designed around.
 */
export const maxDuration = 300;

/** Refuse absurd uploads before reading them into memory. */
const MAX_TOTAL_BYTES = 64 * 1024 * 1024;

/**
 * Publishing metadata, not pack content. Stripped from either input shape.
 *
 * `publish-all.mjs` reads it; the panel takes the same values from the form
 * fields instead. Letting it through would put a file in the signed manifest
 * that describes the pack rather than being part of it, and the device would
 * dutifully download and cache it forever.
 */
const META_SKIP = 'pack.meta.json';

export async function POST(request: Request) {
  // FIRST LINE OF THE HANDLER, ALWAYS. The middleware does not verify anything
  // — it cannot, it runs on Edge — and /api is excluded from it anyway so that
  // an auth failure here returns 401 JSON rather than a redirect to an HTML
  // login page, which at the caller looks like a parse error.
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return NextResponse.json({ error: 'Expected multipart form data' }, { status: 400 });
  }

  const app = String(form.get('app') ?? 'g-launcher') as AppId;
  const packId = String(form.get('packId') ?? '');
  const packType = String(form.get('packType') ?? '') as PackType;
  const version = Number(form.get('version'));
  const minAppVersion = Number(form.get('minAppVersion') ?? 0);
  const title = String(form.get('title') ?? packId);
  const summary = String(form.get('summary') ?? '');
  const skuRaw = String(form.get('sku') ?? '').trim();
  const sku = skuRaw === '' ? null : skuRaw;

  if (!isSafePackId(packId)) {
    return NextResponse.json({ error: `Unsafe packId '${packId}'` }, { status: 400 });
  }
  if (!KNOWN_PACK_TYPES.includes(packType)) {
    return NextResponse.json({ error: `Unknown packType '${packType}'` }, { status: 400 });
  }
  if (!Number.isInteger(version) || version < 1) {
    return NextResponse.json({ error: 'version must be an integer >= 1' }, { status: 400 });
  }

  // ── read the files ─────────────────────────────────────────────────────────
  //
  // TWO INPUT SHAPES, because mobile browsers cannot do the first one.
  //
  //   files[] + paths[]  a directory picked with webkitdirectory. Desktop only:
  //                      neither iOS Safari nor Android Chrome supports
  //                      directory selection, so on a phone the picker silently
  //                      offers individual files and the tree is lost.
  //   archive            a .zip, unpacked here. Works everywhere, and is the
  //                      only path that exists on a phone.
  //
  // Both converge on the same `files` array before anything is signed, so there
  // is one validation path and one signing path regardless of how the bytes
  // arrived.
  const files: PackFile[] = [];
  let total = 0;

  const archive = form.get('archive');
  if (archive instanceof Blob) {
    let unpacked: Record<string, Uint8Array>;
    try {
      unpacked = unzipSync(new Uint8Array(await archive.arrayBuffer()));
    } catch (e) {
      return NextResponse.json(
        { error: `Could not read the zip: ${(e as Error).message}` },
        { status: 400 },
      );
    }

    // A zip made by right-clicking a folder on macOS wraps everything in that
    // folder. Strip a single common top-level directory so both shapes work
    // without the user having to know which one they made.
    const names = Object.keys(unpacked).filter((n) => !n.endsWith('/'));
    const tops = new Set(names.map((n) => n.split('/')[0]));
    const strip = tops.size === 1 && names.every((n) => n.includes('/'));

    for (const name of names) {
      // macOS zips carry __MACOSX resource forks and .DS_Store. They would fail
      // the device's unlisted-files check if they ever reached the bucket, and
      // more immediately they are not part of the pack.
      if (name.startsWith('__MACOSX/') || name.endsWith('.DS_Store')) continue;

      const path = strip ? name.slice(name.indexOf('/') + 1) : name;
      if (!path || path === META_SKIP) continue;
      if (!isSafeRelativePath(path)) {
        return NextResponse.json({ error: `Unsafe path in zip: '${path}'` }, { status: 400 });
      }
      if (path === 'manifest.json' || path === 'manifest.sig') continue;

      const bytes = Buffer.from(unpacked[name]);
      total += bytes.length;
      if (total > MAX_TOTAL_BYTES) {
        return NextResponse.json({ error: 'Pack exceeds 64 MB' }, { status: 413 });
      }
      files.push({ path, bytes });
    }
  } else {
    const entries = form.getAll('files');
    const paths = form.getAll('paths').map(String);
    if (entries.length === 0) {
      return NextResponse.json({ error: 'No files' }, { status: 400 });
    }
    if (paths.length !== entries.length) {
      return NextResponse.json({ error: 'files and paths must match' }, { status: 400 });
    }

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (!(entry instanceof Blob)) {
        return NextResponse.json({ error: `files[${i}] is not a file` }, { status: 400 });
      }
      const path = paths[i];

    // The SAME check the device performs, deliberately duplicated here. The
    // device would reject a traversal path anyway, but by then the pack is
    // published, every install has failed, and you are debugging from the wrong
    // end. Failing at publish costs one error message.
    if (!isSafeRelativePath(path)) {
      return NextResponse.json({ error: `Unsafe path '${path}'` }, { status: 400 });
    }
    // manifest.json and manifest.sig are OUTPUT. Accepting them as input would
    // let a stale manifest from a previous publish ride along and then be
    // overwritten — or worse, not be, if the signing step ever changed.
      if (path === 'manifest.json' || path === 'manifest.sig') continue;
      if (path === META_SKIP) continue;

      const bytes = Buffer.from(await entry.arrayBuffer());
      total += bytes.length;
      if (total > MAX_TOTAL_BYTES) {
        return NextResponse.json({ error: 'Pack exceeds 64 MB' }, { status: 413 });
      }
      files.push({ path, bytes });
    }
  }

  if (files.length === 0) {
    return NextResponse.json({ error: 'A pack with no payload is not a pack' }, { status: 400 });
  }

  // ── the live catalogue, before anything is written ─────────────────────────
  const live = await readLiveIndex(app);

  // THE HARDEST REFUSAL IN THIS FILE, and it guards the most expensive mistake.
  //
  // `readLiveIndex` no longer throws on a read failure — every page in the panel
  // called it and none caught it, so one expired credential took out the whole
  // console. But a soft read failure here is a different animal: the merge below
  // would take an EMPTY catalogue as its base and the write at the end would
  // replace a live index holding every other pack with one holding this pack
  // alone. Every installed launcher would then see the rest of the store vanish,
  // because a token rolled.
  //
  // `unreachable` is a separate flag from `exists` for exactly this line. "There
  // is nothing published" is safe to merge into. "We could not find out" is not.
  // The two refusals now live in `publish-core.guardIndex`, which
  // `distro-publish` also calls. Keeping the messages here as well is how the
  // two paths drifted the first time.
  if (live.unreachable) {
    return NextResponse.json(
      {
        error:
          `Could not read ${app}/${INDEX_NAME}: ${live.unreachable}. ` +
          'Refusing to publish, because merging into a catalogue we could not read ' +
          'would overwrite it with this pack alone.',
      },
      { status: 503 },
    );
  }

  if (live.corrupt) {
    // Present but unparseable. Merging into it is impossible and treating it as
    // absent would wipe every other pack from the store. Someone has to look.
    return NextResponse.json(
      { error: `${app}/${INDEX_NAME} exists but does not parse. Refusing to overwrite it.` },
      { status: 409 },
    );
  }

  // THE ROLLBACK FLOOR, enforced at publish rather than discovered on-device.
  // A device refuses a pack whose version is not greater than what it holds, so
  // republishing at the same number produces content that nobody ever receives
  // and no error anywhere. Catching it here is the difference between a red
  // message now and an afternoon later.
  const existing = live.packs.find((p) => p.packId === packId);
  if (existing && version <= existing.version) {
    return NextResponse.json(
      {
        error:
          `Version ${version} is not newer than the published ${existing.version}. ` +
          'Devices refuse a pack that does not increase its version, silently.',
      },
      { status: 409 },
    );
  }

  // ── THE ASSET-RESOLUTION GATE ──────────────────────────────────────────────
  //
  // It catches the hardest failure in this system to diagnose from the outside:
  // a theme whose `theme.json` names a file the pack does not contain verifies,
  // downloads, installs, and renders the Ubuntu fallback. Nothing errors
  // anywhere.
  //
  // The rule is `ThemeSource.asset`'s own: the last path segment is kept and the
  // rest dropped, so a reference is fine exactly when that segment names a file
  // in the payload. It used to refuse any reference containing a separator,
  // which refused packs that work and passed packs that do not. See flat-check.
  //
  // Theme packs only, and it refuses rather than rewriting: rewriting the JSON
  // would change the bytes being signed, and the whole point is that the
  // theme.json and the files agree.
  //
  // `distro-publish` runs the same check with the same message. A gate on one of
  // two publish paths is worse than no gate, because it reads as covered.
  if (packType === 'theme') {
    const flat = checkThemePackFlat(files);
    if (!flat.ok) {
      return NextResponse.json({ error: flatRefusal(flat) }, { status: 400 });
    }
  }

  const keyId = packKeyId();

  // ── sign and upload ────────────────────────────────────────────────────────
  // One shared implementation with `distro-publish`, which is what stops the two
  // from disagreeing about where a pack type lives in the bucket. `putPack`
  // inside owns the ordering: payload, then manifest, then signature, then a
  // sweep of files the previous version listed and this one does not.
  let entry;
  try {
    entry = await uploadPack(
      app,
      { packType, packId, version, minAppVersion, title, summary, sku, files },
      keyId,
    );
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 400 });
  }

  // ── rebuild the index ──────────────────────────────────────────────────────
  // AFTER the pack is fully up, never before. The index is what tells devices a
  // pack exists; advertising one whose files are still uploading produces a
  // wave of failed installs across the whole install base at once.
  //
  // ── the one entitlement edit a pack publish may make ──────────────────────
  //
  // The rule used to be absolute: a pack publish never touches who owns what.
  // Phase 3 carves the single exception that makes shelf pricing honest: a
  // PAID hero pack whose id a paid distro owns joins that distro's grants, so
  // "comes with the distro" is true for the buyer and not just for the shelf.
  // The helper is append-only and refuses everything else, so ownership scope
  // can still only ever GROW here; shrinking stays on the screens that own it.
  const shelf =
    packType === 'hero' ? withShelfGrant(live, packId, sku) : { entitlements: live.entitlements, grantedTo: null };

  let generatedAt: number;
  try {
    generatedAt = await commitIndex(
      app,
      live,
      [entry],
      shelf.grantedTo ? shelf.entitlements : undefined,
    );
  } catch (e) {
    // The pack is already uploaded and is perfectly valid; only the catalogue
    // failed. Say so precisely, because "publish failed" would send someone
    // re-uploading a pack that is already there.
    return NextResponse.json(
      {
        error: `Pack uploaded, but the index could not be written: ${(e as Error).message}`,
        packUploaded: true,
      },
      { status: 500 },
    );
  }

  return NextResponse.json({
    ok: true,
    packId,
    version,
    grantedTo: shelf.grantedTo,
    remoteDir: `${app}/${entry.path}`,
    fileCount: files.length,
    sizeBytes: total,
    generatedAt,
    previousGeneratedAt: live.generatedAt,
  });
}
