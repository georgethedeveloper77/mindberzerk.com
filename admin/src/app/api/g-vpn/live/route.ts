import { NextResponse } from 'next/server';

import { readLiveSnapshot } from '@/components/g-vpn-site/live-servers';

/**
 * PUBLIC: the live server snapshot for open mindberzerk.com/gvpn pages.
 *
 * No auth by design. It returns only what the landing already shows (server
 * counts per country, our servers' cities and up/down state) and never a
 * server address. /api is outside proxy.ts's matcher, so this needs no entry
 * in the public allowlist. Cached a minute at the edge so a busy page costs
 * the Workers one read a minute, not one per visitor.
 */
export const revalidate = 60;

export async function GET() {
  const snapshot = await readLiveSnapshot();
  return NextResponse.json(snapshot, {
    headers: { 'cache-control': 'public, s-maxage=60, stale-while-revalidate=300' },
  });
}
