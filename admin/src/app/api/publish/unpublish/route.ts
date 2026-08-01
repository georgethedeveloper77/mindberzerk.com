import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { isAppId } from '@/lib/core/registry';
import { unpublishPacks } from '@/lib/core/unpublish-core';

/**
 * PHASE C6 - pulling a release. NOW A WRAPPER over `lib/unpublish-core.ts`.
 *
 * The guards, the entitlement trimming, the bundled-pack refusal and the
 * objects-left-in-place reasoning all moved there when distro delete needed to
 * pull a theme and its icon pack in ONE index write. This route keeps its
 * contract: one pack per call, and a refusal when pulling it would leave a
 * bundle granting nothing, because editing a live bundle is a decision for the
 * Bundles page rather than a side effect here.
 *
 * The response shape is unchanged on purpose: the unpublish button parses it.
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
  if (!packId) {
    return NextResponse.json({ error: 'Missing packId' }, { status: 400 });
  }

  const out = await unpublishPacks(app, [packId], { removeEmptiedEntitlements: false });
  if (!out.ok) {
    return NextResponse.json({ error: out.error }, { status: out.status });
  }

  const pack = out.pulled[0];
  return NextResponse.json({
    ok: true,
    packId,
    // Returned so the UI can say where the files still are. Republishing at a
    // HIGHER version is the way back, not the same one: a device that installed
    // it still holds that version number and refuses anything not greater.
    remains: `${app}/${pack.path}`,
    nextVersion: pack.version + 1,
    packs: out.packsLeft,
    generatedAt: out.generatedAt,
  });
}
