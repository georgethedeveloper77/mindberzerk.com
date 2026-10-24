import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { refreshNow, saveOverrides, type Overrides } from '@/lib/g-vpn/servers';

/**
 * G VPN server list: save overrides, refresh, or both.
 *
 * The Worker's admin token stays on the server; the browser only ever talks
 * to this route. "save" is always followed by a refresh, because an override
 * that waits up to two hours for the cron looks like a save that failed.
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

  let body: { action?: string; overrides?: Overrides };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  try {
    if (body.action === 'save') {
      if (!body.overrides) return NextResponse.json({ error: 'overrides are required' }, { status: 400 });
      const saved = await saveOverrides(body.overrides);
      if (!saved.ok) return NextResponse.json({ error: saved.error }, { status: 502 });
    } else if (body.action !== 'refresh') {
      return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
    }
    const refreshed = await refreshNow();
    if (!refreshed.ok) return NextResponse.json({ error: refreshed.error }, { status: 502 });
    return NextResponse.json({ ok: true, servers: refreshed.servers });
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 500 });
  }
}
