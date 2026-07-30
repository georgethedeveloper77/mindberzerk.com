import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { sweepOrphans } from '@/lib/orphans';
import { isAppId } from '@/lib/registry';

/**
 * Delete orphaned objects, by group directory.
 *
 * The heavy thinking lives in `lib/orphans.ts`: the caller names directories
 * from the report it was shown, and the sweep recomputes what is actually
 * orphaned before deleting anything, so this route cannot be talked into
 * removing a live pack even by a stale or hostile request body.
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

  let body: { app?: string; dirs?: unknown };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const app = String(body.app ?? '');
  if (!isAppId(app)) {
    return NextResponse.json({ error: `Unknown app '${app}'` }, { status: 400 });
  }

  const dirs = Array.isArray(body.dirs)
    ? body.dirs.filter((d): d is string => typeof d === 'string')
    : [];
  if (dirs.length === 0) {
    return NextResponse.json({ error: 'dirs must be a non-empty list' }, { status: 400 });
  }

  const out = await sweepOrphans(app, dirs);
  if (!out.ok) {
    return NextResponse.json({ error: out.error }, { status: 409 });
  }
  return NextResponse.json(out);
}
