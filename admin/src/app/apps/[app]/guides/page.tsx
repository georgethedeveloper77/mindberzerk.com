import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { appName, appMeta, isAppId } from '@/lib/core/registry';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { Banner, Button, Chip, Metric, PageHead, Panel } from '@/app/components/ui';

export const dynamic = 'force-dynamic';

/**
 * PHASE C13 - G Recovery guides, PLACEHOLDER ONLY.
 *
 * Pure design, no functionality. Nothing here reads a bucket or writes
 * anything. It exists so opening G Recovery shows the SHAPE of what it will be,
 * per-brand OEM recovery guidance delivered to a budget-phone install base,
 * rather than a blank app section.
 *
 * ─── THE ILLUSTRATIVE TABLE IS GONE, AND THAT IS THE CHANGE ─────────────────
 *
 * It used to render five manufacturers with install shares (26%, 21%, 19%) in
 * a table that looked exactly like the real tables on every other screen. Those
 * numbers were invented. Nobody has measured the install base, because the app
 * has not shipped, and a plausible percentage in a data table is precisely the
 * thing this panel refuses everywhere else: `analytics.ts` returns
 * `connected: false` rather than a zero, the landing shows a dash rather than
 * inventing a count, and the analytics page shows four dashes rather than a
 * confident 0%.
 *
 * A placeholder screen is the easiest place to break that rule and the worst
 * place to break it, because the number is never checked again. So the brands
 * are listed as WHAT THEY ARE, a target set with no share attached, and every
 * figure that would be a measurement is a dash.
 *
 * When the app is real, this becomes a reader over whatever store holds the
 * guidance, likely Remote Config keyed by manufacturer, and the shares come
 * from the analytics export like every other measured number.
 */
export default async function GuidesPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const meta = appMeta(app);

  // The OEMs the product is aimed at. A TARGET SET, not a measurement: no
  // shares, no counts, nothing that reads as data until something measures it.
  const brands = [
    'Infinix',
    'Tecno',
    'Xiaomi and Redmi',
    'Samsung',
    'Oppo and realme',
    'itel',
  ];

  return (
    <Shell app={app} subtitle={`${app} / guides`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Guides' }]}
      />

      <Banner tone="warn">
        Design only. Nothing on this screen is wired to anything, and no figure
        here has been measured. It is here to show the shape of the section
        before the app exists.
      </Banner>

      <PageHead
        title={`${appName(app)} guides`}
        meta={meta?.pkg ?? undefined}
        actions={<Chip tone="warn">not built</Chip>}
      />

      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
        <Metric label="Guides published" value="-" sub="nothing yet" tone="warn" />
        <Metric label="Brands covered" value="-" sub={`${brands.length} targeted`} tone="warn" />
        <Metric label="Delivery" value="remote config" sub="keyed by manufacturer" />
        <Metric label="State" value="planned" sub="after the launcher" tone="warn" />
      </div>

      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-[1.4fr_1fr]">
        <Panel title="Target manufacturers">
          <div className="flex flex-wrap gap-1.5">
            {brands.map((b) => (
              <span
                key={b}
                className="rounded-md border border-line px-2 py-1 text-micro text-ink-2"
              >
                {b}
              </span>
            ))}
          </div>
          <p className="mt-3 text-micro leading-relaxed text-ink-3">
            Recovery behaviour differs per OEM skin more than per Android
            version, which is why the guidance is keyed by manufacturer rather
            than written once. No install share is shown because none has been
            measured: the app has not shipped, so any percentage here would be a
            number this panel made up.
          </p>
        </Panel>

        <Panel title="What this section becomes">
          <p className="text-micro leading-relaxed text-ink-3">
            Honestly-scoped recovery, storage auditing, and per-brand guidance
            delivered by remote config. The editor will look like the legal and
            registry screens: a list on the left, one document in the panel, one
            publish.
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            <Button href={`/apps/${app}`}>Overview</Button>
            <Button href={`/apps/${app}/config`}>Config</Button>
          </div>
        </Panel>
      </div>
    </Shell>
  );
}
