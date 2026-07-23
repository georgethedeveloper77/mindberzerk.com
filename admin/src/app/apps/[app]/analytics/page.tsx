import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { retentionByDistro, setupFunnel, type Analytics } from '@/lib/analytics';
import { appName, isAppId } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { Banner, Card, Grid, PageHead, Stat, Table, Td, Th, Tr } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C9 — analytics.
 *
 * ## What this page is, and is not
 *
 * It is NOT the Firebase console rebuilt. Active users, retention overview and
 * raw event counts are rendered well there and are one link away. This page
 * shows only the two questions the console cannot express — the setup funnel by
 * step, and retention split by first distro — and both come from the BigQuery
 * export.
 *
 * ## When the export is off, it says so
 *
 * The export is a project setting that is not on yet. Every panel below renders
 * its own not-connected state with the exact reason, and NOTHING shows a made-up
 * number to fill the space. The first fabricated figure would make every real
 * one suspect.
 *
 * ## The data-safety correction lives here on purpose
 *
 * The publishing screens still describe the launcher as collecting no data. That
 * is not true while Firebase Analytics ships a pseudonymous instance id to
 * Google, and Play requires it declared. The note at the foot of this page is
 * the reminder to fix the store listing, phrased as the claim that IS true: no
 * sale, no ads, no account, installs and crashes counted.
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

  const [funnel, retention] = await Promise.all([
    setupFunnel(app, days),
    retentionByDistro(app),
  ]);

  // The funnel's first step is the denominator for a conversion rate.
  const funnelTop = funnel.connected ? funnel.data[0]?.users ?? 0 : 0;
  const funnelEnd = funnel.connected
    ? funnel.data.find((s) => s.step === 'setup_complete')?.users ?? 0
    : 0;
  const completeRate = funnelTop ? Math.round((funnelEnd / funnelTop) * 100) : 0;

  return (
    <Shell app={app} subtitle={`${app} / analytics`}>
      <PageHead
        title={`${appName(app)} analytics`}
        meta={`last ${days} days`}
        actions={
          <div className="flex gap-1">
            {[7, 30, 90].map((d) => (
              <a
                key={d}
                href={`/apps/${app}/analytics?days=${d}`}
                className={`rounded-md px-2 py-1 font-mono text-micro transition ${
                  days === d ? 'bg-surface-3 text-ink' : 'text-ink-3 hover:text-ink-2'
                }`}
              >
                {d}d
              </a>
            ))}
          </div>
        }
      />

      <Grid cols={4}>
        <Stat
          label="Setup completion"
          value={funnel.connected ? `${completeRate}%` : '—'}
          tone={funnel.connected ? 'plain' : 'plain'}
        />
        <Stat label="Reached setup" value={funnel.connected ? funnelTop.toLocaleString() : '—'} />
        <Stat label="Completed" value={funnel.connected ? funnelEnd.toLocaleString() : '—'} />
        <Stat
          label="Export"
          value={funnel.connected ? 'connected' : 'off'}
          tone={funnel.connected ? 'ok' : 'warn'}
        />
      </Grid>

      <div className="mt-3 grid gap-3 sm:mt-4 lg:grid-cols-2">
        <Card title="Setup funnel">
          <NotConnected result={funnel}>
            {funnel.connected && (
              <div className="space-y-2">
                {funnel.data.map((s) => {
                  const pct = funnelTop ? Math.round((s.users / funnelTop) * 100) : 0;
                  return (
                    <div key={s.step}>
                      <div className="flex items-baseline justify-between text-data">
                        <span className="font-mono text-micro text-ink-2">{s.step}</span>
                        <span className="tnum text-ink-3">
                          {s.users.toLocaleString()} · {pct}%
                        </span>
                      </div>
                      <div className="mt-1 h-1.5 rounded bg-surface-2">
                        <div
                          className="h-full rounded bg-accent"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </NotConnected>
        </Card>

        <Card title="Retention by first distro">
          <NotConnected result={retention}>
            {retention.connected && (
              <Table
                head={
                  <>
                    <Th>Distro</Th>
                    <Th num>Cohort</Th>
                    <Th num>D1</Th>
                    <Th num>D7</Th>
                    <Th num>D30</Th>
                  </>
                }
              >
                {retention.data.map((r) => (
                  <Tr key={r.distro}>
                    <Td mono>{r.distro}</Td>
                    <Td num>{r.cohort.toLocaleString()}</Td>
                    <Td num dim>
                      {r.d1 || '—'}
                    </Td>
                    <Td num dim>
                      {r.d7 || '—'}
                    </Td>
                    <Td num dim>
                      {r.d30 || '—'}
                    </Td>
                  </Tr>
                ))}
              </Table>
            )}
          </NotConnected>
        </Card>
      </div>

      <div className="mt-3 sm:mt-4">
        <Card title="Everything else">
          <p className="text-data leading-relaxed text-ink-2">
            Active users, the retention overview and raw event counts are rendered
            in the Firebase console and are not rebuilt here. This page holds only
            what the console cannot express.
          </p>
          <a
            href="https://console.firebase.google.com/"
            target="_blank"
            rel="noreferrer"
            className="mt-2 inline-block text-data text-accent hover:brightness-110"
          >
            Open Firebase console →
          </a>
        </Card>
      </div>

      <div className="mt-3 sm:mt-4">
        <Banner tone="warn">
          Data safety: while Analytics is on, the launcher shares a pseudonymous
          app instance id with Google, so the store listing must not say “no data
          collected”. The accurate claim is: no sale, no ads, no account, installs
          and crashes counted.
        </Banner>
      </div>
    </Shell>
  );
}

/**
 * Renders children when connected, or the reason when not. One component so the
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
    <div className="rounded-lg border border-dashed border-line px-3 py-6 text-center">
      <p className="text-data text-ink-3">Not connected</p>
      <p className="mx-auto mt-1 max-w-sm text-micro leading-relaxed text-ink-3">
        {result.reason}
      </p>
    </div>
  );
}
