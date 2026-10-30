import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { writeRemoteConfigKeys } from '@/lib/core/remote-config';

/**
 * PHASE C11 - write one Remote Config key.
 *
 * Thin on purpose: all the safety (allowlist, per-key validation, ETag
 * compare-and-swap) lives in `writeRemoteConfigKeys`. This handler is auth plus
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

  // Either one key ({ key, value }) or several in one publish ({ values }).
  let body: { key?: string; value?: string; values?: Record<string, unknown>; etag?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const etag = String(body.etag ?? '');
  const values: Record<string, string> = {};
  if (body.values && typeof body.values === 'object') {
    for (const [k, v] of Object.entries(body.values)) values[k] = String(v ?? '');
  } else if (body.key) {
    values[String(body.key)] = String(body.value ?? '');
  }
  if (Object.keys(values).length === 0 || !etag) {
    return NextResponse.json({ error: 'key (or values) and etag are required' }, { status: 400 });
  }

  const result = await writeRemoteConfigKeys(values, etag);
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
