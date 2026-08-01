import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import {
  AppSlab,
  Bar,
  KVRow,
  PACK_COLOURS,
  SlabButton,
  SlabCell,
  SoftButton,
  SoftPanel,
  Split,
  TaskRow,
} from '@/components/studio/ui';
import { bytes, when } from '@/app/components/ui';
import { appAudience, appInstalls, change } from '@/lib/core/app-metrics';
import { indexIsSigned, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { commerceReport, worstTone } from '@/lib/core/commerce';
import { orphanReport } from '@/lib/core/orphans';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { ensureSeededSafe } from '@/lib/g-launcher/themes';

export const dynamic = 'force-dynamic';

/**
 * THE APP LANDING. Health first, measurement second.
 *
 * ─── WHAT THIS SCREEN IS FOR ────────────────────────────────────────────────
 *
 * "Is anything broken", which on the evidence of every session so far is the
 * question this panel is actually opened with. Installs and active users are
 * here now that they are genuinely measured, but they sit BELOW the task list,
 * because a number you look at is worth less than a job you have to do.
 *
 * ─── EVERY FAILURE, AS A LIST OF TASKS ──────────────────────────────────────
 *
 * Each failure this panel can see was visible only on its own screen, so
 * finding out something was wrong meant visiting six of them. They are rows
 * here: severity edge, what is wrong, what to do, and the screen that does it.
 * Two states keep a banner instead, because they are not tasks: an unreachable
 * bucket and a corrupt index mean every figure below is a default rather than a
 * measurement, and that has to be read before anything else.
 *
 * ─── REVENUE IS STILL ABSENT, STILL DELIBERATE ──────────────────────────────
 *
 * It lives in Play's financial reports, which are the system of record, and a
 * revenue figure with two answers is worse than one with none. Play and
 * Firebase are LINKED rather than copied.
 *
 * ─── AND NOTHING IS INVENTED ────────────────────────────────────────────────
 *
 * Every source here can be unreadable: the bucket, Play, the reports bucket,
 * GA4. Each reports its own state and renders a named absence rather than a
 * zero. A dashboard that shows a plausible figure it did not measure teaches
 * you to stop checking it.
 */

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

  const [live, commerce, seeded, orphans] = await Promise.all([
    readLiveIndex(appId),
    commerceReport(appId),
    ensureSeededSafe(appId),
    orphanReport(appId),
  ]);
  const signed = live.exists ? await indexIsSigned(appId).catch(() => false) : false;

  const meta = appMeta(appId);

  // Installs and audience are slower and likelier to be unconfigured than
  // anything above, so they are fetched after the first group rather than
  // inside it: a 403 on either cannot delay the figures this page has always
  // shown.
  const [installs, audience] = await Promise.all([
    appInstalls(meta?.pkg ?? null),
    appAudience(appId, 30),
  ]);

  const iconTypes = new Set(['hero', 'icon', 'brand']);
  const iconPacks = live.packs.filter((p) => iconTypes.has(p.packType));
  const themePacks = live.packs.filter((p) => p.packType === 'theme');

  // Distros are published theme packs unioned with seeded drafts, which is what
  // the Distros screen lists. Counting only published would report zero for a
  // launcher that ships three inside its APK.
  const distroIds = new Set([...themePacks.map((p) => p.packId), ...seeded.drafts.map((d) => d.id)]);

  const broken = commerce.rows.filter((r) => worstTone(r.problems) === 'bad');
  const warned = commerce.rows.filter((r) => worstTone(r.problems) === 'warn');
  const sellable = commerce.rows.filter((r) => r.sellable).length;
  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);

  const byType = (t: string) => live.packs.filter((p) => p.packType === t);
  const sum = (t: string) => byType(t).reduce((n, p) => n + p.sizeBytes, 0);
  const biggest = [...live.packs].sort((a, b) => b.sizeBytes - a.sizeBytes).slice(0, 6);
  const largest = biggest[0]?.sizeBytes ?? 0;

  const bucketDown = !!(live.unreachable || seeded.unreachable);
  const playDown = !commerce.play.ok;
  const projectId = process.env.GCP_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;

  // ── tasks, blockers first ─────────────────────────────────────────────────
  interface Task {
    level: 'bad' | 'warn' | 'ok';
    title: string;
    detail: React.ReactNode;
    href?: string;
    where?: string;
  }
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
        broken.length === 1 ? `${broken[0].sku} cannot be bought` : `${broken.length} products cannot be bought`,
      detail: 'A price is advertised that Play will not charge, so ownership resolves false forever.',
      href: `/apps/${appId}/commerce`,
      where: 'Commerce',
    });
  }
  // Narrowed INLINE. PlayCatalogue is a discriminated union and TypeScript
  // cannot carry the narrowing through a boolean stored in a variable, so
  // `.error` is only reachable inside a direct check on `.ok`.
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
  // Two measurements, two switches, two tasks. One panel going dark because
  // the other is unconfigured is exactly the ambiguity these rows remove.
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

  const blockers = tasks.filter((t) => t.level === 'bad').length;
  const watch = tasks.filter((t) => t.level === 'warn').length;

  return (
    <StudioShell app={appId}>
      {/* THESE TWO KEEP A BANNER, and only these two. They are not tasks: they
          mean every figure on this page is a default rather than a measurement,
          so they have to be read before anything else is. */}
      {bucketDown && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The CDN bucket could not be read, so every catalogue figure below is a default rather than
          a measurement. {live.unreachable ?? seeded.unreachable}
        </p>
      )}
      {live.corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is present but does not parse. Publishing is blocked rather than overwriting
          it, because a bad merge drops every pack from the store.
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(appId)}
        title="Overview"
        meta={meta?.pkg ?? undefined}
        actions={
          <>
            {meta?.pkg && (
              <SlabButton href={`https://play.google.com/store/apps/details?id=${meta.pkg}`} external>
                Store listing
              </SlabButton>
            )}
            <SlabButton href={`/apps/${appId}/distros/builder`} primary>
              New distro
            </SlabButton>
          </>
        }
        metrics={
          <>
            <SlabCell
              label="Packs live"
              value={bucketDown ? 'unknown' : live.packs.length}
              measured={!bucketDown}
              note={bucketDown ? 'bucket unreachable' : bytes(size)}
            />
            <SlabCell
              label="Index"
              value={bucketDown ? 'unknown' : signed ? 'signed' : live.exists ? 'unsigned' : 'none'}
              measured={false}
              note={bucketDown ? undefined : when(live.generatedAt)}
            />
            <SlabCell
              label="Sellable"
              value={playDown ? 'not measured' : `${sellable} of ${commerce.rows.length}`}
              measured={!playDown}
              note={playDown ? 'Play unreachable' : broken.length ? `${broken.length} broken` : 'all good'}
            />
            <SlabCell
              label="Distros"
              value={distroIds.size}
              note={`${iconPacks.length} icon ${iconPacks.length === 1 ? 'pack' : 'packs'}`}
            />
          </>
        }
      />

      <SoftPanel
        title="What needs doing"
        note="every failure this panel can see, in one list"
        right={
          <span className="font-mono text-[11.5px] text-site-ink-3">
            {blockers} blocking, {watch} to watch
          </span>
        }
        flush
      >
        {tasks.map((t, i) => (
          <TaskRow key={i} {...t} />
        ))}
      </SoftPanel>

      <div className="grid gap-4 lg:grid-cols-[1.5fr_1fr]">
        <SoftPanel
          title="Storage by pack"
          right={<span className="font-mono text-[11.5px] text-site-ink-3">{bytes(size)}</span>}
        >
          {biggest.length === 0 ? (
            <p className="text-[12px] leading-relaxed text-site-ink-3">
              {bucketDown ? 'The bucket could not be read.' : 'Nothing published, so there is nothing to measure.'}
            </p>
          ) : (
            <>
              <Split
                segments={(['theme', 'brand', 'hero', 'icon'] as const).map((t) => ({
                  label: `${byType(t).length} ${t}`,
                  value: sum(t),
                  colour: PACK_COLOURS[t],
                }))}
              />
              <div className="mt-4">
                {biggest.map((p) => (
                  <Bar
                    key={p.packId}
                    label={p.packId}
                    value={bytes(p.sizeBytes)}
                    pct={largest ? (p.sizeBytes / largest) * 100 : 0}
                    colour={PACK_COLOURS[p.packType] ?? PACK_COLOURS.icon}
                  />
                ))}
              </div>
            </>
          )}
        </SoftPanel>

        <SoftPanel title="Inventory">
          <KVRow
            k="Distros"
            v={`${distroIds.size} · ${seeded.drafts.filter((d) => d.bundled).length} bundled`}
          />
          <KVRow
            k="Icon packs"
            v={`${iconPacks.length} · ${iconPacks.filter((p) => p.packType === 'brand').length} brand`}
          />
          <KVRow k="Paid packs" v={live.packs.filter((p) => p.sku).length} />
          <KVRow k="Bundles" v={live.entitlements.length} />
          <KVRow k="Package" v={<span className="font-mono">{meta?.pkg ?? '-'}</span>} />
          <KVRow k="Key id" v={<span className="font-mono">{live.keyId || (process.env.PACK_KEY_ID ?? '-')}</span>} />
        </SoftPanel>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <SoftPanel
          title="Installs"
          right={
            installs.ok && installs.data.through ? (
              <span className="font-mono text-[11.5px] text-site-ink-3">through {installs.data.through}</span>
            ) : undefined
          }
        >
          {!installs.ok ? (
            <p className="text-[12px] leading-relaxed text-site-ink-3">{installs.reason}</p>
          ) : (
            <>
              <div className="mb-4 grid grid-cols-3 gap-3">
                <Figure label="installs" value={installs.data.installs.toLocaleString()} />
                <Figure label="uninstalls" value={installs.data.uninstalls.toLocaleString()} muted />
                <Figure
                  label="net"
                  value={`${installs.data.net >= 0 ? '+' : ''}${installs.data.net.toLocaleString()}`}
                  tone={installs.data.net >= 0 ? 'ok' : 'bad'}
                />
              </div>

              {/* Nullable stats render as ABSENT ROWS, never as a placeholder
                  string. Play omits these columns on some report versions. */}
              {installs.data.activeDeviceInstalls !== null && (
                <KVRow k="Active device installs" v={installs.data.activeDeviceInstalls.toLocaleString()} />
              )}
              {installs.data.totalUserInstalls !== null && (
                <KVRow k="Total user installs" v={installs.data.totalUserInstalls.toLocaleString()} />
              )}

              <div className="mt-3">
                {(() => {
                  const recent = installs.data.series.slice(-14);
                  const peak = Math.max(1, ...recent.map((d) => d.installs));
                  return recent.map((d) => (
                    <Bar
                      key={d.date}
                      label={d.date.slice(5)}
                      value={d.installs.toLocaleString()}
                      pct={(d.installs / peak) * 100}
                      colour="var(--color-site-ok)"
                    />
                  ));
                })()}
              </div>
            </>
          )}
        </SoftPanel>

        <SoftPanel
          title="Active users"
          right={<span className="font-mono text-[11.5px] text-site-ink-3">30 days</span>}
        >
          {!audience.ok ? (
            <p className="text-[12px] leading-relaxed text-site-ink-3">{audience.reason}</p>
          ) : (
            <>
              <div className="mb-4 grid grid-cols-2 gap-3">
                <Figure
                  label="active"
                  value={audience.data.activeUsers.toLocaleString()}
                  sub={(() => {
                    const delta = change(audience.data.activeUsers, audience.data.previousActive);
                    return delta === null
                      ? undefined
                      : `${delta >= 0 ? '+' : ''}${delta}% vs previous`;
                  })()}
                />
                <Figure label="new" value={audience.data.newUsers.toLocaleString()} muted />
              </div>
              <div>
                {(() => {
                  const recent = audience.data.series.slice(-14);
                  const peak = Math.max(1, ...recent.map((d) => d.users));
                  return recent.map((d) => (
                    <Bar
                      key={d.date}
                      label={`${d.date.slice(4, 6)}-${d.date.slice(6, 8)}`}
                      value={d.users.toLocaleString()}
                      pct={(d.users / peak) * 100}
                      colour="var(--color-site-info)"
                    />
                  ));
                })()}
              </div>
            </>
          )}
        </SoftPanel>
      </div>

      <SoftPanel title="Revenue" note="not rebuilt here, on purpose">
        <p className="max-w-[70ch] text-[12.5px] leading-relaxed">
          Play&apos;s financial reports are the system of record, and a revenue figure with two
          answers is worse than one with none. What this panel adds instead are the questions Play
          and Firebase cannot answer: the setup funnel by attempt number, retention split by first
          distro, and package frequency across the base.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          {meta?.pkg && (
            <SoftButton href="https://play.google.com/console/u/0/developers" external>
              Play Console
            </SoftButton>
          )}
          {projectId && (
            <SoftButton href={`https://console.firebase.google.com/project/${projectId}/analytics`} external>
              Firebase
            </SoftButton>
          )}
          <SoftButton href={`/apps/${appId}/analytics`}>What this panel adds</SoftButton>
        </div>
      </SoftPanel>

      <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
        A pack only reaches devices when its version increases, and the index is what advertises it.
        Publishing signs both; unpublishing removes the entry and every device drops the pack on its
        next sync.
      </p>
    </StudioShell>
  );
}

/** One figure in a panel. Small enough not to compete with the slab's. */
function Figure({
  label,
  value,
  sub,
  tone,
  muted,
}: {
  label: string;
  value: string;
  sub?: string;
  tone?: 'ok' | 'bad';
  muted?: boolean;
}) {
  const colour = tone === 'ok' ? 'text-site-ok' : tone === 'bad' ? 'text-site-plan' : muted ? 'text-site-ink-2' : 'text-site-ink';
  return (
    <span>
      <span className="block text-[10.5px] font-bold uppercase tracking-[0.07em] text-site-ink-3">
        {label}
      </span>
      <span className={`mt-1 block font-site-display text-[22px] font-extrabold tracking-[-0.03em] ${colour}`}>
        {value}
      </span>
      {sub && <span className="mt-0.5 block font-mono text-[11px] text-site-ink-3">{sub}</span>}
    </span>
  );
}
