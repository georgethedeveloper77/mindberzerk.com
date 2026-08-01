import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { retentionByDistro, setupFunnel, type Analytics } from '@/lib/core/analytics';
import { appName, isAppId } from '@/lib/core/registry';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import {
  Banner,
  BarRow,
  Button,
  Filter,
  Metric,
  PageHead,
  Panel,
  Table,
  Td,
  Th,
  Toolbar,
  Tr,
} from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C9 - analytics.
 *
 * ## What this page is, and is not
 *
 * It is NOT the Firebase console rebuilt. Active users, retention overview and
 * raw event counts are rendered well there and are one link away. This page
 * shows only the two questions the console cannot express - the setup funnel by
 * step, and retention split by first distro - and both come from the BigQuery
 * export.
 *
 * ## When the export is off, it says so, and that is the whole design
 *
 * The export is a project setting that is not on yet. Every panel renders its
 * own not-connected state with the exact reason, and NOTHING shows a made-up
 * number to fill the space. This page is in the dashboard register like the
 * landing and the overview, which raises the stakes on that rule rather than
 * lowering them: a big empty metric card is honest, a big invented one is the
 * thing that makes every other number on every other screen suspect.
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
  const funnelTop = funnel.connected ? (funnel.data[0]?.users ?? 0) : 0;
  const funnelEnd = funnel.connected
    ? (funnel.data.find((s) => s.step === 'setup_complete')?.users ?? 0)
    : 0;
  const completeRate = funnelTop ? Math.round((funnelEnd / funnelTop) * 100) : 0;

  const cohort = retention.connected
    ? retention.data.reduce((n, r) => n + r.cohort, 0)
    : 0;

  return (
    <Shell app={app} subtitle={`${app} / analytics`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Analytics' }]}
      />

      <PageHead
        title={`${appName(app)} analytics`}
        meta={`last ${days} days`}
        actions={
          <Button href="https://console.firebase.google.com/">Firebase console</Button>
        }
      />

      <Toolbar>
        {[7, 30, 90].map((d) => (
          <Filter key={d} href={`/apps/${app}/analytics?days=${d}`} active={days === d}>
            {`${d}d`}
          </Filter>
        ))}
      </Toolbar>

      {/* A DASH, NEVER A ZERO. An unconnected export has measured nothing, and
          a big confident 0% next to "setup completion" is a claim that people
          are failing setup rather than an admission that nobody is counting. */}
      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
        <Metric
          label="Setup completion"
          value={funnel.connected ? `${completeRate}%` : '-'}
          sub={funnel.connected ? `${funnelEnd.toLocaleString()} of ${funnelTop.toLocaleString()}` : 'not measured'}
          tone={funnel.connected ? 'plain' : 'warn'}
        />
        <Metric
          label="Reached setup"
          value={funnel.connected ? funnelTop.toLocaleString() : '-'}
          sub={`last ${days} days`}
          tone={funnel.connected ? 'plain' : 'warn'}
        />
        <Metric
          label="Cohort"
          value={retention.connected ? cohort.toLocaleString() : '-'}
          sub={retention.connected ? 'with a first distro' : 'not measured'}
          tone={retention.connected ? 'plain' : 'warn'}
        />
        <Metric
          label="Export"
          value={funnel.connected ? 'connected' : 'off'}
          sub={funnel.connected ? 'BigQuery' : 'nothing is counted'}
          tone={funnel.connected ? 'ok' : 'warn'}
        />
      </div>

      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-2">
        <Panel title="Setup funnel">
          <NotConnected result={funnel}>
            {funnel.connected && (
              <div className="space-y-2">
                {funnel.data.map((s) => (
                  <BarRow
                    key={s.step}
                    label={s.step}
                    value={s.users.toLocaleString()}
                    pct={funnelTop ? (s.users / funnelTop) * 100 : 0}
                  />
                ))}
              </div>
            )}
          </NotConnected>
        </Panel>

        <Panel title="Retention by first distro">
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
                      {r.d1 || '-'}
                    </Td>
                    <Td num dim>
                      {r.d7 || '-'}
                    </Td>
                    <Td num dim>
                      {r.d30 || '-'}
                    </Td>
                  </Tr>
                ))}
              </Table>
            )}
          </NotConnected>
        </Panel>
      </div>

      <div className="mt-2 sm:mt-3">
        <Panel title="Everything else">
          <p className="text-micro leading-relaxed text-ink-3">
            Active users, the retention overview and raw event counts are rendered
            in the Firebase console and are not rebuilt here. This page holds only
            what the console cannot express.
          </p>
        </Panel>
      </div>

      <div className="mt-2 sm:mt-3">
        <Banner tone="warn">
          Data safety: while Analytics is on, the launcher shares a pseudonymous
          app instance id with Google, so the store listing must not say &quot;no
          data collected&quot;. The accurate claim is: no sale, no ads, no
          account, installs and crashes counted.
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
