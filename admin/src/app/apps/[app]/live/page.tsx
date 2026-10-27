import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { LiveMap, type LiveData } from '@/components/g-vpn/LiveMap';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { gserverConfigs, readGServers } from '@/lib/g-vpn/gservers';
import { readIsps } from '@/lib/g-vpn/isps';
import { readProviders } from '@/lib/g-vpn/providers';
import { readRealtime } from '@/lib/g-vpn/realtime';
import { readVpnState } from '@/lib/g-vpn/servers';

export const dynamic = 'force-dynamic';

/**
 * G VPN only: the live map. People in the app now and where they connect
 * to (GA4 realtime), the servers (both Workers), and from the provider
 * Workers, speed tests and ratings by country. Every layer that cannot be
 * read says why instead of showing zeros. The page refreshes itself.
 */
export default async function LivePage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ m?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();
  const minutes = (await searchParams).m === '5' ? 5 : 30;

  const [realtime, vpn, gs, isps, providers] = await Promise.all([
    readRealtime(minutes),
    readVpnState(),
    readGServers(),
    readIsps(),
    readProviders(),
  ]);

  // G Servers carry their country in GVPN_GSERVERS ("country": "DE").
  const configs = gserverConfigs().servers as { name: string; country?: string }[];
  const countryOf = new Map(configs.map((c) => [c.name, c.country?.toUpperCase()]));

  const free = new Map<string, { code: string; count: number; fast: number; good: number; slow: number }>();
  for (const s of vpn.servers.filter((s) => s.listed)) {
    const row = free.get(s.countryCode) ?? { code: s.countryCode, count: 0, fast: 0, good: 0, slow: 0 };
    row.count++;
    row[s.grade]++;
    free.set(s.countryCode, row);
  }
  const unreachable = vpn.servers.filter((s) => s.reachable === false).length;

  const data: LiveData = {
    minutes,
    realtime,
    free: [...free.values()],
    freeDown: unreachable,
    freeNote: vpn.unreachable,
    gservers: gs.servers.map((s) => ({
      name: s.name,
      country: countryOf.get(s.name) ?? null,
      online: s.online,
      peers: s.active ?? s.peers ?? 0,
      load: s.load1 != null && s.cpus ? Math.round((s.load1 / s.cpus) * 100) : null,
    })),
    tests: isps.countries.map((c) => ({ code: c.country, tests: c.tests, providers: c.providers.map((p) => ({ isp: p.isp, down: p.down })) })),
    testsNote: isps.unreachable,
    providers: providers.providers
      .filter((p) => !p.hidden)
      .map((p) => ({
        code: p.country ?? '',
        name: p.name || p.org,
        org: p.org,
        color: p.color,
        users: p.users ?? 0,
        ratings: p.ratings,
        average: p.average,
      })),
    providersNote: providers.unreachable,
  };

  const meta = appMeta(app);
  return (
    <StudioShell app={app}>
      <AppSlab tint={meta?.tint ?? '#2457F5'} mark={meta?.mark ?? 'V'} crumb={appName(app)} title="Live map" />
      <LiveMap data={data} />
    </StudioShell>
  );
}
