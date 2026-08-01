import Link from 'next/link';
import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import {
  Banner,
  BarRow,
  Button,
  KV,
  Metric,
  PageHead,
  Panel,
  SplitBar,
  bytes,
  when,
} from '@/app/components/ui';
import { appAudience, appInstalls, change } from '@/lib/core/app-metrics';
import { indexIsSigned, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { commerceReport, worstTone } from '@/lib/core/commerce';
import { orphanReport } from '@/lib/core/orphans';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { ensureSeededSafe } from '@/lib/g-launcher/themes';

export const dynamic = 'force-dynamic';

/**
 * THE APP LANDING. Health, not analytics.
 *
 * This route redirected to Packs, and before that it 404'd. Neither answered
 * the question you actually open this panel with, which on the evidence of
 * every session so far is "is anything broken", not "how many installs".
 *
 * ─── WHY THE NUMBERS YOU EXPECT ARE NOT HERE ────────────────────────────────
 *
 * Installs, active users, engagement, countries and revenue are deliberately
 * absent, and the reason is already written on the portfolio overview: a
 * dashboard that shows a plausible number it did not measure is worse than one
 * that shows nothing, because you stop checking the source. The BigQuery export
 * is not wired, so those cards would be dashes for weeks, and a landing page of
 * placeholders teaches you to skip the landing page.
 *
 * Revenue is a stronger no. It lives in Play's financial reports, which is the
 * system of record, and rebuilding it here creates a second number for the one
 * thing that must never have two answers. Play and Firebase render all of it
 * better than this panel will, so they are LINKED rather than copied. That
 * argument used to be printed on the page as four sentences inside a card,
 * which broke `ui.tsx`'s own density rule (a card holds a number, a label and
 * at most one qualifier). It belongs here, in the file, where the next person
 * to be tempted will read it.
 *
 * ─── EVERY FAILURE, AS A LIST OF TASKS ──────────────────────────────────────
 *
 * Each failure this panel reports was visible only on its own page, so finding
 * out something was wrong meant visiting six screens. Aggregating them here was
 * already the argument for this page; the change is HOW.
 *
 * They were four full-width banners, so a bad day was four red blocks stacked
 * above any content, all shouting equally. Now they are rows: a severity edge,
 * what is wrong, what to do about it, and the screen that does it. Two states
 * keep their banner, because they are not tasks: an unreachable bucket and a
 * corrupt index mean every figure below is a default rather than a measurement,
 * and the reader has to know that before reading anything.
 *
 * The list also carries two facts that were computed elsewhere and never
 * reached the landing: how many orphaned objects are sitting in the bucket, and
 * whether the analytics export is connected at all.
 */

type Level = 'bad' | 'warn' | 'ok';

interface Task {
  level: Level;
  title: string;
  detail: string;
  href?: string;
  where?: string;
}

export default async function AppOverviewPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  const appId = app as AppId;

  // In parallel: R2, Play and the seeded drafts are unrelated services and the
  // page waits on the slowest either way.
  const [live, commerce, seeded, orphans] = await Promise.all([
    readLiveIndex(appId),
    commerceReport(appId),
    ensureSeededSafe(appId),
    orphanReport(appId),
  ]);

  // Installs and audience come from Play's reports bucket and GA4, which are
  // slower and likelier to be unconfigured than anything above. Fetched after
  // the first group rather than inside it so a 403 on either cannot delay the
  // figures this page has always shown.
  const [installs, audience] = await Promise.all([
    appInstalls(appMeta(appId)?.pkg ?? null),
    appAudience(appId, 30),
  ]);
  const signed = live.exists ? await indexIsSigned(appId).catch(() => false) : false;

  const meta = appMeta(appId);
  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const iconPacks = live.packs.filter((p) => iconTypes.has(p.packType));
  const themePacks = live.packs.filter((p) => p.packType === 'theme');

  // Distros = published theme packs unioned with seeded drafts, which is what
  // the Distros page lists. Counting only published would report zero for a
  // launcher that ships three inside its APK.
  const distroIds = new Set([
    ...themePacks.map((p) => p.packId),
    ...seeded.drafts.map((d) => d.id),
  ]);

  const broken = commerce.rows.filter((r) => worstTone(r.problems) === 'bad');
  const warned = commerce.rows.filter((r) => worstTone(r.problems) === 'warn');
  const sellable = commerce.rows.filter((r) => r.sellable).length;
  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);

  // Composition and the biggest packs, for the storage panel. Derived rather
  // than fetched: the index already carries every size, so this costs nothing.
  const byType = (t: string) => live.packs.filter((p) => p.packType === t);
  const counts = {
    theme: byType('theme').length,
    brand: byType('brand').length,
    hero: byType('hero').length,
    icon: byType('icon').length,
  };
  const sum = (t: string) => byType(t).reduce((n, p) => n + p.sizeBytes, 0);
  const bytesByType = {
    theme: sum('theme'),
    brand: sum('brand'),
    hero: sum('hero'),
    icon: sum('icon'),
  };
  const biggest = [...live.packs].sort((a, b) => b.sizeBytes - a.sizeBytes).slice(0, 6);
  const largest = biggest[0]?.sizeBytes ?? 0;

  const bucketDown = !!(live.unreachable || seeded.unreachable);
  const playDown = !commerce.play.ok;

  const projectId = process.env.GCP_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;

  // ── the task list ─────────────────────────────────────────────────────────
  const tasks: Task[] = [];

  if (live.exists && !signed) {
    tasks.push({
      level: 'bad',
      title: 'The index is published without a signature',
      detail:
        'Every device refuses index.json with no index.sig and keeps the catalogue it already had. Republish to regenerate both.',
      href: `/apps/${appId}/packs`,
      where: 'CDN objects',
    });
  }
  if (broken.length > 0) {
    tasks.push({
      level: 'bad',
      title:
        broken.length === 1
          ? `${broken[0].sku} cannot be bought`
          : `${broken.length} products cannot be bought`,
      detail:
        'A price is advertised that Play will not charge, so ownership resolves false forever.',
      href: `/apps/${appId}/commerce`,
      where: 'Commerce',
    });
  }
  // Narrowed INLINE rather than through `playDown`. PlayCatalogue is a
  // discriminated union and TypeScript cannot carry the narrowing through a
  // boolean stored in a variable, so `.error` is only reachable inside a direct
  // check on `.ok`.
  if (!commerce.play.ok) {
    tasks.push({
      level: 'warn',
      title: 'Play cannot be read',
      detail: commerce.play.error,
      href: `/apps/${appId}/commerce`,
      where: 'Commerce',
    });
  }
  if (warned.length > 0) {
    tasks.push({
      level: 'warn',
      title: `${warned.length} ${warned.length === 1 ? 'product needs' : 'products need'} attention`,
      detail:
        'Configured and sellable, but something about the listing will surprise a buyer or an older client.',
      href: `/apps/${appId}/commerce`,
      where: 'Commerce',
    });
  }
  if (orphans.ok && orphans.groups.length > 0) {
    tasks.push({
      level: 'warn',
      title: `${orphans.objectCount} orphaned ${orphans.objectCount === 1 ? 'object' : 'objects'} on the CDN`,
      detail: `Old versions and unpublished packs, ${bytes(orphans.totalBytes)}. Reviewed before anything is deleted.`,
      href: `/apps/${appId}/packs`,
      where: 'CDN objects',
    });
  }
  if (!projectId) {
    tasks.push({
      level: 'warn',
      title: 'GCP_PROJECT is not set',
      detail:
        'The Firebase link and the Config screen have no project to point at, and the analytics export cannot be reached.',
      href: `/apps/${appId}/config`,
      where: 'Config',
    });
  }
  // Two different measurements, two different switches, so two different
  // tasks. One panel going dark because the other is unconfigured is exactly
  // the ambiguity these rows exist to remove.
  if (!installs.ok) {
    tasks.push({
      level: 'warn',
      title: 'Install reports are not readable',
      detail: installs.reason,
      href: `/apps/${appId}/config`,
      where: 'Config',
    });
  }
  if (!audience.ok) {
    tasks.push({
      level: 'warn',
      title: 'Active users are not measured',
      detail: audience.reason,
      href: `/apps/${appId}/analytics`,
      where: 'Analytics',
    });
  }
  if (!bucketDown && !live.corrupt && signed) {
    tasks.push({
      level: 'ok',
      title: 'Bucket readable, index signed',
      detail: `${process.env.R2_BUCKET ?? 'mindberzerk-cdn'} · key ${live.keyId || (process.env.PACK_KEY_ID ?? '-')} · updated ${when(live.generatedAt)}`,
    });
  }

  return (
    <Shell app={appId} subtitle={meta?.pkg ?? 'admin.mindberzerk.com'}>
      {/* THESE TWO KEEP THEIR BANNER, and only these two. They are not tasks:
          they mean every figure on this page is a default rather than a
          measurement, so they have to be read before anything else is. */}
      {bucketDown && (
        <Banner tone="bad">
          The CDN bucket could not be read, so every catalogue figure below is a
          default rather than a measurement.{' '}
          {live.unreachable ?? seeded.unreachable}
        </Banner>
      )}
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Publishing is blocked rather
          than overwriting it, because a bad merge drops every pack from the store.
        </Banner>
      )}

      <PageHead
        title={appName(appId)}
        meta={meta?.pkg ?? undefined}
        actions={
          <Button href={`/apps/${appId}/distros/builder`} variant="primary">
            New distro
          </Button>
        }
      />

      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
        <Metric
          label="Packs live"
          value={bucketDown ? '-' : live.packs.length}
          sub={bucketDown ? 'bucket unreachable' : bytes(size)}
          tone={bucketDown ? 'warn' : 'plain'}
          href={`/apps/${appId}/packs`}
        />
        <Metric
          label="Index"
          value={bucketDown ? '-' : signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
          sub={bucketDown ? undefined : when(live.generatedAt)}
          tone={bucketDown ? 'warn' : signed ? 'ok' : live.exists ? 'bad' : 'plain'}
        />
        <Metric
          label="Sellable"
          value={playDown ? '-' : `${sellable} / ${commerce.rows.length}`}
          sub={
            playDown
              ? 'Play unreachable'
              : broken.length
                ? `${broken.length} broken`
                : 'all good'
          }
          tone={playDown ? 'warn' : broken.length ? 'bad' : 'ok'}
          href={`/apps/${appId}/commerce`}
        />
        <Metric
          label="Distros"
          value={distroIds.size}
          sub={`${iconPacks.length} icon ${iconPacks.length === 1 ? 'pack' : 'packs'}`}
          href={`/apps/${appId}/distros`}
        />
      </div>

      <div className="mt-2 sm:mt-3">
        <Panel title="What needs doing" flush>
          <div>
            {tasks.map((t, i) => (
              <TaskRow key={i} task={t} />
            ))}
          </div>
        </Panel>
      </div>

      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-[1.5fr_1fr]">
        <Panel title="Storage by pack">
          {biggest.length === 0 ? (
            <p className="text-micro leading-relaxed text-ink-3">
              {bucketDown
                ? 'The bucket could not be read.'
                : 'Nothing published, so there is nothing to measure.'}
            </p>
          ) : (
            <>
              <div className="mb-3">
                <div className="mb-1.5 flex items-baseline justify-between">
                  <span className="text-micro text-ink-3">catalogue</span>
                  <span className="font-mono text-micro text-ink-3 tnum">{bytes(size)}</span>
                </div>
                <SplitBar
                  segments={[
                    { label: `${counts.theme} theme`, value: bytesByType.theme, tone: 'accent' },
                    { label: `${counts.brand} brand`, value: bytesByType.brand, tone: 'info' },
                    { label: `${counts.hero} hero`, value: bytesByType.hero, tone: 'ok' },
                    { label: `${counts.icon} icon`, value: bytesByType.icon, tone: 'warn' },
                  ]}
                />
              </div>
              <div className="space-y-2">
                {biggest.map((p) => (
                  <BarRow
                    key={p.packId}
                    label={p.packId}
                    value={bytes(p.sizeBytes)}
                    pct={largest ? (p.sizeBytes / largest) * 100 : 0}
                    tone={
                      p.packType === 'theme'
                        ? 'accent'
                        : p.packType === 'brand'
                          ? 'info'
                          : p.packType === 'hero'
                            ? 'ok'
                            : 'warn'
                    }
                  />
                ))}
              </div>
            </>
          )}
        </Panel>

        <Panel title="Inventory">
          <KV
            k="Distros"
            v={`${distroIds.size} · ${seeded.drafts.filter((d) => d.bundled).length} bundled`}
          />
          <KV
            k="Icon packs"
            v={`${iconPacks.length} · ${iconPacks.filter((p) => p.packType === 'brand').length} brand`}
          />
          <KV k="Paid packs" v={live.packs.filter((p) => p.sku).length} />
          <KV k="Bundles" v={live.entitlements.length} />
          <KV k="Package" v={meta?.pkg ?? '-'} />
          <KV k="Key id" v={live.keyId || (process.env.PACK_KEY_ID ?? '-')} />
        </Panel>
      </div>

      {/* ── INSTALLS AND AUDIENCE ─────────────────────────────────────────
          Measured now, where it can be. Revenue is still absent and still
          deliberate: Play's financial reports are the system of record and a
          second answer to a revenue question is worse than no answer.

          Each half reports its own state. Installs can be connected while the
          audience is not, and saying so beats one panel that goes dark because
          half of it is unconfigured. */}
      <div className="mt-2 grid gap-2 sm:mt-3 sm:gap-3 lg:grid-cols-2">
        <Panel
          title="Installs"
          right={
            installs.ok && installs.data.through ? (
              <span className="font-mono text-micro text-ink-3">through {installs.data.through}</span>
            ) : undefined
          }
        >
          {!installs.ok ? (
            <p className="text-micro leading-relaxed text-ink-3">{installs.reason}</p>
          ) : (
            <>
              <div className="mb-3 grid grid-cols-3 gap-2">
                <span>
                  <span className="block text-micro uppercase tracking-wider text-ink-3">installs</span>
                  <span className="block text-lg font-semibold tracking-tight text-ink tnum">
                    {installs.data.installs.toLocaleString()}
                  </span>
                </span>
                <span>
                  <span className="block text-micro uppercase tracking-wider text-ink-3">uninstalls</span>
                  <span className="block text-lg font-semibold tracking-tight text-ink-2 tnum">
                    {installs.data.uninstalls.toLocaleString()}
                  </span>
                </span>
                <span>
                  <span className="block text-micro uppercase tracking-wider text-ink-3">net</span>
                  <span
                    className={`block text-lg font-semibold tracking-tight tnum ${
                      installs.data.net >= 0 ? 'text-ok' : 'text-bad'
                    }`}
                  >
                    {installs.data.net >= 0 ? '+' : ''}
                    {installs.data.net.toLocaleString()}
                  </span>
                </span>
              </div>

              {/* Nullable stats render as ABSENT ROWS, never as a placeholder
                  string. Play omits these columns on some report versions. */}
              {installs.data.activeDeviceInstalls !== null && (
                <KV k="Active device installs" v={installs.data.activeDeviceInstalls.toLocaleString()} />
              )}
              {installs.data.totalUserInstalls !== null && (
                <KV k="Total user installs" v={installs.data.totalUserInstalls.toLocaleString()} />
              )}

              <div className="mt-3 space-y-1">
                {(() => {
                  const recent = installs.data.series.slice(-14);
                  const peak = Math.max(1, ...recent.map((d) => d.installs));
                  return recent.map((d) => (
                    <BarRow
                      key={d.date}
                      label={d.date.slice(5)}
                      value={d.installs.toLocaleString()}
                      pct={(d.installs / peak) * 100}
                      tone="ok"
                    />
                  ));
                })()}
              </div>
            </>
          )}
        </Panel>

        <Panel title="Active users" right={<span className="font-mono text-micro text-ink-3">30 days</span>}>
          {!audience.ok ? (
            <p className="text-micro leading-relaxed text-ink-3">{audience.reason}</p>
          ) : (
            <>
              <div className="mb-3 grid grid-cols-2 gap-2">
                <span>
                  <span className="block text-micro uppercase tracking-wider text-ink-3">active</span>
                  <span className="block text-lg font-semibold tracking-tight text-ink tnum">
                    {audience.data.activeUsers.toLocaleString()}
                  </span>
                  {(() => {
                    const delta = change(audience.data.activeUsers, audience.data.previousActive);
                    return delta === null ? null : (
                      <span className={`block font-mono text-micro tnum ${delta >= 0 ? 'text-ok' : 'text-bad'}`}>
                        {delta >= 0 ? '+' : ''}
                        {delta}% vs previous
                      </span>
                    );
                  })()}
                </span>
                <span>
                  <span className="block text-micro uppercase tracking-wider text-ink-3">new</span>
                  <span className="block text-lg font-semibold tracking-tight text-ink-2 tnum">
                    {audience.data.newUsers.toLocaleString()}
                  </span>
                </span>
              </div>

              <div className="space-y-1">
                {(() => {
                  const recent = audience.data.series.slice(-14);
                  const peak = Math.max(1, ...recent.map((d) => d.users));
                  return recent.map((d) => (
                    <BarRow
                      key={d.date}
                      label={`${d.date.slice(4, 6)}-${d.date.slice(6, 8)}`}
                      value={d.users.toLocaleString()}
                      pct={(d.users / peak) * 100}
                      tone="info"
                    />
                  ));
                })()}
              </div>
            </>
          )}
        </Panel>
      </div>

      <div className="mt-2 sm:mt-3">
        <Panel title="Revenue">
          <p className="text-micro leading-relaxed text-ink-3">
            Not here, on purpose. Play&apos;s financial reports are the system of record, and a
            revenue figure with two answers is worse than one with none.
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {meta?.pkg && (
              <Button href="https://play.google.com/console/u/0/developers">Play Console</Button>
            )}
            {projectId && (
              <Button href={`https://console.firebase.google.com/project/${projectId}/analytics`}>
                Firebase
              </Button>
            )}
            <Button href={`/apps/${appId}/analytics`}>What this panel adds</Button>
          </div>
        </Panel>
      </div>

      <p className="mt-3 text-micro leading-relaxed text-ink-3">
        A pack only reaches devices when its version increases, and the index is
        what advertises it. Publishing signs both; unpublishing removes the entry
        and every device drops the pack on its next sync.
      </p>
    </Shell>
  );
}

/**
 * One task. A link when there is a screen that fixes it, a plain row when the
 * fact is just a fact: "bucket readable, index signed" has nowhere to go and a
 * row that looks clickable and is not is worse than one that does not.
 */
function TaskRow({ task }: { task: Task }) {
  const edge =
    task.level === 'bad'
      ? 'border-l-2 border-l-bad'
      : task.level === 'warn'
        ? 'border-l-2 border-l-warn'
        : '';
  const titleColour =
    task.level === 'bad' ? 'text-bad' : task.level === 'warn' ? 'text-ink' : 'text-ok';

  const body = (
    <>
      <span className="min-w-0 flex-1">
        <span className={`block text-data ${titleColour}`}>{task.title}</span>
        <span className="block text-micro leading-relaxed text-ink-3">{task.detail}</span>
      </span>
      {task.where && (
        <span className="shrink-0 font-mono text-micro text-ink-3">{task.where}</span>
      )}
    </>
  );

  const shape = `flex items-center gap-3 border-b border-line-soft px-3 py-2.5 last:border-b-0 sm:px-4 ${edge}`;

  return task.href ? (
    <Link href={task.href} className={`${shape} transition hover:bg-surface-2`}>
      {body}
    </Link>
  ) : (
    <div className={shape}>{body}</div>
  );
}
