import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { writeRegistry } from '@/lib/studio/apps';
import type { AppMeta, AppState } from '@/lib/core/registry';

/**
 * Publish the studio's app registry.
 *
 * Unsigned, whole-file, same track as site content. All validation lives in
 * `writeRegistry`, including the rule that an app this panel administers cannot
 * be removed: that one is not cosmetic, because such an app owns a route
 * segment and a bucket prefix, and deleting it from a form would leave a
 * console section pointing at a list that no longer names it.
 *
 * `managed` is deliberately NOT read from the body. It means "this panel has a
 * route for it", which is a fact about the code, and letting a request assert
 * it would be letting a form grant itself a capability.
 */
export const runtime = 'nodejs';

const STATES: AppState[] = ['live', 'build', 'planned', 'external'];

export async function POST(request: Request) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: { apps?: unknown };
  try {
    body = (await request.json()) as { apps?: unknown };
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  if (!Array.isArray(body.apps)) {
    return NextResponse.json({ error: 'apps is required' }, { status: 400 });
  }

  const apps: AppMeta[] = (body.apps as Record<string, unknown>[]).map((a) => {
    const state = String(a?.state ?? '') as AppState;
    return {
      id: String(a?.id ?? '').trim(),
      name: String(a?.name ?? ''),
      pkg: a?.pkg ? String(a.pkg) : null,
      mark: String(a?.mark ?? '?').slice(0, 2),
      tint: /^#[0-9a-f]{6}$/i.test(String(a?.tint ?? '')) ? String(a.tint) : '#6d4ae8',
      managed: false,
      state: STATES.includes(state) ? state : 'planned',
      blurb: String(a?.blurb ?? ''),
      playConsoleAppId: a?.playConsoleAppId ? String(a.playConsoleAppId) : undefined,
      appStoreAppId: a?.appStoreAppId ? String(a.appStoreAppId) : undefined,
    };
  });

  const result = await writeRegistry(apps);
  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 });
  return NextResponse.json({ ok: true, updatedAt: result.updatedAt, count: result.count });
}
