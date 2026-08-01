import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { writeRemoteConfigKey } from '@/lib/core/remote-config';

/**
 * PHASE C11 - write one Remote Config key.
 *
 * Thin on purpose: all the safety (allowlist, per-key validation, ETag
 * compare-and-swap) lives in `writeRemoteConfigKey`. This handler is auth plus
 * shape-checking, so the concurrency logic has exactly one home.
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

  let body: { key?: string; value?: string; etag?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const key = String(body.key ?? '');
  const value = String(body.value ?? '');
  const etag = String(body.etag ?? '');
  if (!key || !etag) {
    return NextResponse.json({ error: 'key and etag are required' }, { status: 400 });
  }

  const result = await writeRemoteConfigKey(key, value, etag);
  if (!result.ok) {
    // A stale ETag is a conflict, not a bad request: the input was fine, the
    // world moved. 409 lets the client tell the two apart and say "reload".
    return NextResponse.json(
      { error: result.error, stale: result.stale ?? false },
      { status: result.stale ? 409 : 400 },
    );
  }

  return NextResponse.json({ ok: true, versionNumber: result.versionNumber });
}
