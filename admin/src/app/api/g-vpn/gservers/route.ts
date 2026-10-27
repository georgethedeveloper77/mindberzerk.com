import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { saveBroker, type BrokerSettings } from '@/lib/g-vpn/gservers';

/** Saves the G Servers switches. The broker's admin token stays on the server. */
export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    throw e;
  }
  let body: BrokerSettings;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }
  const saved = await saveBroker(body);
  if (!saved.ok) return NextResponse.json({ error: saved.error }, { status: 502 });
  return NextResponse.json({ ok: true, settings: saved.settings });
}
