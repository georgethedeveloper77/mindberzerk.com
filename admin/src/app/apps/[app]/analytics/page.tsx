import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, Bar, SlabButton, SlabCell, SoftPanel } from '@/components/studio/ui';
import { exportState, retentionByDistro, setupFunnel, type Analytics } from '@/lib/core/analytics';
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

  /**
   * G RECOVERY BRANCHES BEFORE THE LAUNCHER QUERIES RUN.
   *
   * Both panels below ask launcher questions: a setup funnel over
   * `setup_home_role` and friends, and retention split by the `active_theme`
   * user property. G Recovery logs neither, so this screen rendered two empty
   * panels that looked like a broken export rather than like an app that has
   * not been instrumented. Those are different problems with different fixes.
   */
  if (app === 'g-recovery') return <RecoveryAnalytics app={app} />;

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

/**
 * ANALYTICS FOR AN APP THAT LOGS NOTHING YET.
 *
 * ─── WHY THIS IS A LIST OF EVENTS AND NOT A DASHBOARD ───────────────────────
 *
 * The honest state is that no custom event exists, so there is nothing to
 * chart. What IS worth putting on the screen is which events would answer which
 * question, because that decision is the blocker and it is currently held in
 * nobody's head in particular. Each row names the question first, since an
 * event log full of things that answer nothing is how analytics becomes a cost.
 *
 * NOTHING HERE IS A MEASUREMENT and nothing pretends to be. The one live figure
 * is whether the export exists at all, which is a fact about the pipeline
 * rather than about the app.
 */
async function RecoveryAnalytics({ app }: { app: string }) {
  const state = await exportState(app);
  const meta = appMeta(app);

  const proposed: { event: string; answers: string; params: string }[] = [
    {
      event: 'scan_started',
      answers: 'How many people get past opening the app.',
      params: 'source',
    },
    {
      event: 'source_found',
      answers: 'Which trash sources actually hold anything, across real devices.',
      params: 'source, fidelity, count',
    },
    {
      event: 'coverage_gap',
      answers:
        'Which manufacturer and API level combinations matched no rule. This is the trashmap backlog, measured instead of guessed.',
      params: 'manufacturer, sdk',
    },
    {
      event: 'item_restored',
      answers: 'Whether a scan ever turns into a recovered file.',
      params: 'source, fidelity',
    },
    {
      event: 'restore_failed',
      answers: 'Where a restore breaks, split by cause rather than by crash report.',
      params: 'source, reason',
    },
  ];

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Analytics"
        meta="no custom events instrumented"
        actions={<SlabButton href={`/apps/${app}`}>Overview</SlabButton>}
        metrics={
          <>
            <SlabCell
              label="Custom events"
              value={0}
              note="nothing logged by the app yet"
            />
            <SlabCell
              label="Export"
              value={state.connected ? `${state.data.days} days` : 'not connected'}
              measured={state.connected}
              note={state.connected ? 'daily tables in BigQuery' : 'no data to query'}
            />
          </>
        }
      />

      {!state.connected && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          {state.reason}
        </p>
      )}

      <SoftPanel
        title="What to log"
        note="proposed, not built"
        right={<span className="font-mono text-[11.5px] text-site-ink-3">{proposed.length} events</span>}
      >
        <p className="mb-3 max-w-[70ch] text-[12.5px] leading-relaxed text-site-ink-3">
          Installs and active users are on the Overview and come from Play and GA4 rather than from
          the app. These are the events the app would have to log for this screen to answer anything
          the console cannot. Nothing below is instrumented, so nothing below has a number.
        </p>
        {proposed.map((e) => (
          <div key={e.event} className="border-t border-site-line py-3 first:border-t-0">
            <div className="flex flex-wrap items-baseline gap-2.5">
              <code className="rounded bg-site-sunk px-1.5 py-0.5 font-mono text-[11.5px] text-site-ink-2">
                {e.event}
              </code>
              <span className="font-mono text-[11px] text-site-ink-3">{e.params}</span>
            </div>
            <p className="mt-1.5 max-w-[70ch] text-[12.5px] leading-relaxed text-site-ink-3">
              {e.answers}
            </p>
          </div>
        ))}
      </SoftPanel>

      <SoftPanel title="Before any of it is worth building">
        <p className="max-w-[70ch] text-[12.5px] leading-relaxed text-site-ink-3">
          Firebase Analytics rejects boolean parameters, so anything that would be a flag is logged
          as 1 or 0. And the BigQuery export is per app: this screen needs{' '}
          <code className="rounded bg-site-sunk px-1.5 py-0.5 font-mono text-[11.5px] text-site-ink-2">
            BQ_DATASET_G_RECOVERY
          </code>{' '}
          set to the export dataset once the daily export is switched on, alongside GCP_PROJECT.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Link
            href={`/apps/${app}/config`}
            className="inline-flex items-center gap-1.5 rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45"
          >
            Config
          </Link>
        </div>
      </SoftPanel>
    </StudioShell>
  );
}
