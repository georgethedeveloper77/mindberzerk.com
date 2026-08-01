import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { isLegalId, writeLegal, type LegalDocument } from '@/lib/studio/legal';

/**
 * PHASE C13 - publish a set of legal documents, for an app or for the studio.
 *
 * Unsigned and on its own track, exactly like `publish/site`: it writes under
 * `site/legal/` and touches nothing about the pack index, its signature or
 * `generatedAt`. A phone never reads these pages; Google and a person do.
 *
 * All validation lives in `writeLegal`, which refuses before it writes anything.
 * That ordering matters here more than usual: a half-published set, where the
 * privacy page is new and the terms are last month's, is the state Play would
 * notice and nobody else would.
 *
 * The body is coerced field by field rather than trusted. This route is behind
 * the allowlist, so this is not a hostile-input defence; it is a shape defence,
 * because a stale client posting the old two-field document would otherwise
 * reach `writeLegal` and fail somewhere less legible.
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

  // isLegalId, NOT isAppId. The studio has a reserved id that is deliberately
  // not an app, and it accepts exactly the app ids plus `studio`.
  const app = String(body.app ?? '');
  if (!isLegalId(app)) {
    return NextResponse.json({ error: `Unknown legal id '${app}'` }, { status: 400 });
  }

  if (!Array.isArray(body.documents)) {
    return NextResponse.json(
      { error: 'documents is required. An older editor posted privacy and terms as strings.' },
      { status: 400 },
    );
  }

  const documents: LegalDocument[] = (body.documents as Record<string, unknown>[]).map((d) => ({
    slug: String(d?.slug ?? ''),
    title: String(d?.title ?? ''),
    body: String(d?.body ?? ''),
  }));

  const result = await writeLegal(app, {
    documents,
    contactEmail: String(body.contactEmail ?? ''),
    jurisdiction: String(body.jurisdiction ?? ''),
  });

  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 });
  return NextResponse.json({ ok: true, updatedAt: result.updatedAt, pages: result.pages });
}
