import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, Bar, SlabButton, SlabCell, SoftPanel } from '@/components/studio/ui';
import { retentionByDistro, setupFunnel, type Analytics } from '@/lib/core/analytics';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * ANALYTICS - only what the console cannot express.
 *
 * ## What this page is, and is not
 *
 * It is NOT the Firebase console rebuilt. Active users, the retention overview
 * and raw event counts render well there and are one link away. This shows the
 * two questions the console cannot express, the setup funnel by step and
 * retention split by first distro, and both come from the BigQuery export.
 *
 * ## When the export is off, it says so, and that is the whole design
 *
 * The export is a project setting that is not on. Every panel renders its own
 * not-connected state with the exact reason, and NOTHING shows a made-up number
 * to fill the space. A big empty figure is honest; a big invented one is what
 * makes every other number on every other screen suspect.
 *
 * ## The data-safety correction lives here on purpose
 *
 * The store listing must not claim no data is collected while Firebase
 * Analytics ships a pseudonymous instance id to Google. The note at the foot is
 * phrased as the claim that IS true: no sale, no ads, no account, installs and
 * crashes counted.
 */
export default async function AnalyticsPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ days?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { days: daysRaw } = await searchParams;
  const days = daysRaw === '7' || daysRaw === '90' ? Number(daysRaw) : 30;

  const [funnel, retention] = await Promise.all([setupFunnel(app, days), retentionByDistro(app)]);

  // The funnel's first step is the denominator for a conversion rate.
  const funnelTop = funnel.connected ? (funnel.data[0]?.users ?? 0) : 0;
  const funnelEnd = funnel.connected
    ? (funnel.data.find((s) => s.step === 'setup_complete')?.users ?? 0)
    : 0;
  const completeRate = funnelTop ? Math.round((funnelEnd / funnelTop) * 100) : 0;
  const cohort = retention.connected ? retention.data.reduce((n, r) => n + r.cohort, 0) : 0;

  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Analytics"
        meta={`last ${days} days`}
        actions={
          <SlabButton href="https://console.firebase.google.com/" external>
            Firebase console
          </SlabButton>
        }
        metrics={
          <>
            {/* NOT MEASURED, NEVER A ZERO. An unconnected export has counted
                nothing, and a confident 0% beside "setup completion" is a claim
                that people are failing setup rather than an admission that
                nobody is counting. */}
            <SlabCell
              label="Setup completion"
              value={funnel.connected ? `${completeRate}%` : 'not measured'}
              measured={funnel.connected}
              note={
                funnel.connected
                  ? `${funnelEnd.toLocaleString()} of ${funnelTop.toLocaleString()}`
                  : 'export is off'
              }
            />
            <SlabCell
              label="Reached setup"
              value={funnel.connected ? funnelTop.toLocaleString() : 'not measured'}
              measured={funnel.connected}
              note={`last ${days} days`}
            />
            <SlabCell
              label="Cohort"
              value={retention.connected ? cohort.toLocaleString() : 'not measured'}
              measured={retention.connected}
              note={retention.connected ? 'with a first distro' : 'export is off'}
            />
            <SlabCell
              label="Export"
              value={funnel.connected ? 'connected' : 'off'}
              measured={false}
              note={funnel.connected ? 'BigQuery' : 'nothing is counted'}
            />
          </>
        }
      />

      <div className="flex flex-wrap gap-2">
        {[7, 30, 90].map((d) => (
          <Link
            key={d}
            href={`/apps/${app}/analytics?days=${d}`}
            className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-semibold transition ${
              days === d
                ? 'border-site-accent/30 bg-site-accent-soft text-site-accent-deep'
                : 'border-site-line bg-site-card text-site-ink-3 hover:text-site-ink'
            }`}
          >
            {d}d
          </Link>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <SoftPanel title="Setup funnel" note="by the step names the launcher logs">
          <NotConnected result={funnel}>
            {funnel.connected && (
              <div>
                {funnel.data.map((s) => (
                  <Bar
                    key={s.step}
                    label={s.step}
                    value={s.users.toLocaleString()}
                    pct={funnelTop ? (s.users / funnelTop) * 100 : 0}
                    colour="var(--color-site-accent)"
                  />
                ))}
              </div>
            )}
          </NotConnected>
        </SoftPanel>

        <SoftPanel title="Retention by first distro" note="the segment the console cannot produce">
          <NotConnected result={retention}>
            {retention.connected && (
              <div>
                <div className="flex items-center gap-3 border-b border-site-line pb-2 text-[10.5px] font-bold uppercase tracking-[0.06em] text-site-ink-3">
                  <span className="flex-1">distro</span>
                  <span className="w-14 text-right">cohort</span>
                  <span className="w-10 text-right">D1</span>
                  <span className="w-10 text-right">D7</span>
                  <span className="w-10 text-right">D30</span>
                </div>
                {retention.data.map((r) => (
                  <div
                    key={r.distro}
                    className="flex items-center gap-3 border-b border-site-line py-2 text-[12px] last:border-b-0"
                  >
                    <span className="min-w-0 flex-1 truncate font-mono text-site-ink">{r.distro}</span>
                    <span className="w-14 text-right font-mono text-site-ink tnum">
                      {r.cohort.toLocaleString()}
                    </span>
                    {/* An absent retention day renders as a dash rather than a
                        zero: the query does not compute them yet, and a 0 would
                        read as "nobody came back". */}
                    <span className="w-10 text-right font-mono text-site-ink-3 tnum">{r.d1 || '-'}</span>
                    <span className="w-10 text-right font-mono text-site-ink-3 tnum">{r.d7 || '-'}</span>
                    <span className="w-10 text-right font-mono text-site-ink-3 tnum">{r.d30 || '-'}</span>
                  </div>
                ))}
              </div>
            )}
          </NotConnected>
        </SoftPanel>
      </div>

      <SoftPanel title="Everything else" note="rendered in Firebase, not rebuilt here">
        <p className="max-w-[70ch] text-[12.5px] leading-relaxed">
          Active users, the retention overview and raw event counts are rendered in the Firebase
          console. This page holds only what the console cannot express, which is why it is short.
        </p>
      </SoftPanel>

      <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[12.5px] leading-relaxed text-site-plan">
        Data safety: while Analytics is on, the launcher shares a pseudonymous app instance id with
        Google, so the store listing must not say &quot;no data collected&quot;. The accurate claim
        is: no sale, no ads, no account, installs and crashes counted.
      </p>
    </StudioShell>
  );
}

/**
 * Children when connected, the reason when not. One component so the
 * not-connected state looks identical everywhere and never gets faked past.
 */
function NotConnected<T>({
  result,
  children,
}: {
  result: Analytics<T>;
  children: React.ReactNode;
}) {
  if (result.connected) return <>{children}</>;
  return (
    <div className="rounded-[14px] border border-dashed border-site-line bg-site-sunk px-4 py-7 text-center">
      <p className="text-[13px] font-semibold text-site-ink">Not connected</p>
      <p className="mx-auto mt-1.5 max-w-[46ch] text-[11.5px] leading-relaxed text-site-ink-3">
        {result.reason}
      </p>
    </div>
  );
}
