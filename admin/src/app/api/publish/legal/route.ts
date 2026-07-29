import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { writeLegal } from '@/lib/legal';
import { isAppId } from '@/lib/registry';

/**
 * PHASE C13 — publish an app's privacy policy and terms.
 *
 * Unsigned and on its own track, exactly like `publish/site`: it writes under
 * `site/legal/` and touches nothing about the pack index, its signature or
 * `generatedAt`. A phone never reads these pages; Google and a person do.
 *
 * All validation lives in `writeLegal`, which refuses before it writes anything.
 * That ordering matters here more than usual — a half-published pair, where the
 * privacy page is new and the terms are last month's, is the state Play would
 * notice and nobody else would.
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

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  const app = String(body.app ?? '');
  if (!isAppId(app)) {
    return NextResponse.json({ error: `Unknown app '${app}'` }, { status: 400 });
  }

  const result = await writeLegal(app, {
    privacy: String(body.privacy ?? ''),
    terms: String(body.terms ?? ''),
    contactEmail: String(body.contactEmail ?? ''),
    jurisdiction: String(body.jurisdiction ?? ''),
  });

  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 });
  return NextResponse.json({ ok: true, updatedAt: result.updatedAt });
}
