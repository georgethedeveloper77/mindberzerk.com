import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { nextGeneratedAt, readLiveIndex } from '@/lib/catalogue';
import { isAppId } from '@/lib/registry';
import { putObject } from '@/lib/r2';
import { INDEX_NAME, INDEX_SIGNATURE_NAME, signIndex } from '@/lib/sign';

/**
 * Pack ids that ship inside the launcher APK and whose CDN copy supersedes the
 * seed. Mirrors `PackPaths.bundledPackIds` in the launcher.
 *
 * KEEP THIS IN SYNC WITH THE KOTLIN. It is a two-element set that changes about
 * once a year, so a shared source is not worth the coupling, but a divergence
 * here has a specific bad shape: pulling one of these strands every device on
 * the in-APK seed (see the guard below), and adding one to the Kotlin without
 * adding it here would let this route do exactly that.
 */
const BUNDLED_PACK_IDS = new Set(['simple-icons', 'yaru']);

/**
 * PHASE C6 — pulling a release.
 *
 * Until now a bad pack could only be replaced, never removed: the panel could
 * publish v4 over v3, but nothing could take the pack out of the store. This
 * rewrites the index without the entry.
 *
 * ## THE OBJECTS ARE LEFT IN PLACE, AND THAT IS NOT AN OVERSIGHT
 *
 * A device that read the index thirty seconds ago is holding a path and may be
 * halfway through downloading it. Deleting the bucket objects turns that into a
 * failed install and, because the manifest goes with them, one that reports as a
 * verification failure rather than a 404. Removing the index entry is enough:
 * nothing new discovers the pack, in-flight installs finish, and the storage
 * cost of a few MB is not worth the alarm.
 *
 * Devices that already installed it keep it. There is no remote uninstall here
 * and there should not be.
 *
 * ## Two things that make an unpublish illegal
 *
 * `signIndex` refuses an index with no packs, and it refuses an entitlement with
 * no grants. So pulling the only pack, or pulling the only pack a bundle grants,
 * would produce an index that cannot be signed. Both are checked here with a
 * message naming what is in the way, because the alternative is either a raw
 * throw or silently deleting a product someone has bought.
 */
export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: { app?: string; packId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const app = String(body.app ?? '');
  const packId = String(body.packId ?? '');
  if (!isAppId(app)) {
    return NextResponse.json({ error: `Unknown app '${app}'` }, { status: 400 });
  }

  const live = await readLiveIndex(app);
  if (live.corrupt) {
    return NextResponse.json(
      { error: `${app}/${INDEX_NAME} exists but does not parse. Refusing to overwrite it.` },
      { status: 409 },
    );
  }

  const pack = live.packs.find((p) => p.packId === packId);
  if (!pack) {
    return NextResponse.json(
      { error: `${packId} is not in the catalogue.` },
      { status: 404 },
    );
  }

  // A bundled pack ships in the APK, and the launcher's sync worker keeps its
  // CDN copy ahead of the in-APK seed by treating it as always-installed. Pull
  // the index entry and that mechanism has nothing to update against: every
  // device silently reverts to the frozen seed set (39 brand glyphs, no yaru
  // art) with no way forward, and the catalogue stops showing it. That is not a
  // delisting, so it is refused. Publishing a higher version is the only lever
  // for these ids.
  if (BUNDLED_PACK_IDS.has(packId)) {
    return NextResponse.json(
      {
        error:
          `${packId} ships inside the app, so pulling it would strand every ` +
          'device on the bundled seed with no way to update. Publish a higher ' +
          'version instead.',
      },
      { status: 409 },
    );
  }

  const packs = live.packs.filter((p) => p.packId !== packId);
  if (packs.length === 0) {
    return NextResponse.json(
      {
        error:
          'This is the only pack. An index with no packs cannot be signed, and ' +
          'an unsigned index is refused by every device.',
      },
      { status: 409 },
    );
  }

  // A bundle that granted only this pack would be left granting nothing, which
  // signIndex refuses. Name it rather than quietly deleting a purchasable
  // product or quietly leaving a buyer with an empty bundle.
  const orphaned = live.entitlements.filter(
    (e) => !e.grants.includes('*') && e.grants.every((g) => g === packId),
  );
  if (orphaned.length > 0) {
    return NextResponse.json(
      {
        error:
          `${orphaned.map((e) => e.sku).join(', ')} would be left granting nothing. ` +
          'Edit the bundle first, or delete it.',
      },
      { status: 409 },
    );
  }

  // Everything else just loses the reference. A grant naming a pack that is not
  // in the catalogue is legal on purpose, but leaving a dangling grant behind
  // after a deliberate pull would be a surprise later.
  const entitlements = live.entitlements.map((e) => ({
    ...e,
    grants: e.grants.includes('*') ? e.grants : e.grants.filter((g) => g !== packId),
  }));

  const keyId = process.env.PACK_KEY_ID ?? 'mh-2026-07';
  const generatedAt = nextGeneratedAt(live);

  let index;
  try {
    index = signIndex({ generatedAt, keyId, packs, entitlements });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 400 });
  }

  await putObject(`${app}/${INDEX_NAME}`, index.index, 'application/json');
  await putObject(
    `${app}/${INDEX_SIGNATURE_NAME}`,
    index.signature,
    'application/octet-stream',
  );

  return NextResponse.json({
    ok: true,
    packId,
    // Returned so the UI can say where the files still are. Republishing at a
    // HIGHER version is the way back, not the same one: a device that installed
    // it still holds that version number and refuses anything not greater.
    remains: `${app}/${pack.path}`,
    nextVersion: pack.version + 1,
    packs: packs.length,
    generatedAt,
  });
}
