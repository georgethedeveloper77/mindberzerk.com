import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabCell, SoftPanel } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readIsps } from '@/lib/g-vpn/isps';

export const dynamic = 'force-dynamic';

const MIN_RANKED = 5;

/**
 * G VPN only: how internet providers compare, from users' direct speed
 * tests. Every provider is listed here, including ones with too few tests
 * for the app to rank (shown faded): the app needs five.
 */
export default async function IspsPage({ params }: { params: Promise<{ app: string }> }) {
  const gate = await adminGate();
  if (gate) return gate;
  const { app } = await params;
  if (!isAppId(app) || app !== 'g-vpn') notFound();

  const state = await readIsps();
  const meta = appMeta(app);
  const down = state.unreachable != null;
  const providers = state.countries.reduce((n, c) => n + c.providers.length, 0);
  const ranked = state.countries.reduce((n, c) => n + c.providers.filter((p) => p.tests >= MIN_RANKED).length, 0);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#2457F5'}
        mark={meta?.mark ?? 'V'}
        crumb={appName(app)}
        title="ISPs"
        meta={down ? `Worker unreachable: ${state.unreachable}` : `last ${state.windowDays} days, direct tests only`}
        metrics={
          <>
            <SlabCell label="Tests" value={down ? 'unknown' : state.totalTests} measured={!down} note="kept 90 days" />
            <SlabCell label="Countries" value={down ? 'unknown' : state.countries.length} measured={!down} />
            <SlabCell label="Providers" value={down ? 'unknown' : providers} measured={!down} note={`${ranked} ranked in the app`} />
          </>
        }
      />

      {state.countries.length === 0 && !down && (
        <p className="text-[13px] text-site-ink-3">No tests yet. They arrive as people run speed tests without the VPN.</p>
      )}

      {state.countries.map((c) => (
        <SoftPanel key={c.country} title={c.country} note={`${c.tests} tests · ${c.cities} cities`} flush>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-left text-[12.5px]">
              <thead>
                <tr className="border-b border-site-line text-[10.5px] uppercase tracking-[0.08em] text-site-ink-3">
                  <th className="px-[18px] py-2">#</th>
                  <th className="px-2 py-2">Provider</th>
                  <th className="px-2 py-2 text-right">Tests</th>
                  <th className="px-2 py-2 text-right">Down</th>
                  <th className="px-2 py-2 text-right">Up</th>
                  <th className="px-[18px] py-2 text-right">Ping</th>
                </tr>
              </thead>
              <tbody>
                {c.providers.map((p) => (
                  <tr
                    key={p.isp}
                    className={`border-b border-site-line last:border-b-0 ${p.tests < MIN_RANKED ? 'text-site-ink-3' : 'text-site-ink'}`}
                  >
                    <td className="px-[18px] py-2.5 font-mono">{p.rank}</td>
                    <td className="px-2 py-2.5 font-semibold">{p.isp}</td>
                    <td className="px-2 py-2.5 text-right font-mono">{p.tests}</td>
                    <td className="px-2 py-2.5 text-right font-mono">{p.down}</td>
                    <td className="px-2 py-2.5 text-right font-mono">{p.up}</td>
                    <td className="px-[18px] py-2.5 text-right font-mono">{p.ping} ms</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </SoftPanel>
      ))}
    </StudioShell>
  );
}
