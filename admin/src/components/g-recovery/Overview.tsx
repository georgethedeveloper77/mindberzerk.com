import Link from 'next/link';

import { bytes, when } from '@/app/components/ui';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, KVRow, SlabButton, SlabCell, SoftPanel, TaskRow } from '@/components/studio/ui';
import { appAudience, appInstalls } from '@/lib/core/app-metrics';
import { appMeta, appName } from '@/lib/core/registry';
import { recoveryReport, type CoverageEntry } from '@/lib/g-recovery/overview';

/**
 * THE G RECOVERY OVERVIEW. What phones currently believe, in one screen.
 *
 * ─── WHY THIS IS NOT THE LAUNCHER'S OVERVIEW ────────────────────────────────
 *
 * That one counts distros, icon packs and paid packs, and offers New distro.
 * This app has none of those, so three of its four figures were meaningless
 * here and its primary action led somewhere that does not apply. Worse, the
 * page reached into `lib/g-launcher` to seed theme drafts for an app with no
 * themes. `page.tsx` now branches before any of that runs.
 *
 * ─── COVERAGE IS A PICTURE, NOT A NUMBER ────────────────────────────────────
 *
 * "41 paths" tells you nothing about whether they work. The block strip gives
 * one cell per rule, coloured by how much we trust it, so the shape of the
 * coverage is legible before any label is read. The tree under it is the same
 * data in the form the data actually takes: a filesystem.
 *
 * ─── AND NOTHING IS INVENTED ────────────────────────────────────────────────
 *
 * Inherited from the launcher's overview and worth restating because this
 * screen has more absent sources than that one: install reports, GA4 and the
 * bucket can each be unreadable, and each renders a named absence rather than a
 * zero. A dashboard that shows a plausible figure it did not measure teaches
 * you to stop checking it.
 */

const APP_ID = 'g-recovery';

/**
 * Which screen edits which document.
 *
 * A TABLE RATHER THAN A NESTED TERNARY, because the fourth document turned that
 * ternary into a line nobody could read and a fifth would have been worse. A
 * pack with no screen gets a row with no link, which is correct for anything
 * published by hand through Upload pack.
 */
const SCREEN_FOR: Record<string, { path: string; label: string }> = {
  trashmap: { path: 'coverage', label: 'Coverage' },
  'storage-map': { path: 'storage', label: 'Storage' },
  'learn-en': { path: 'learn', label: 'Learn' },
  'oem-guide': { path: 'guides', label: 'Brand guidance' },
};

/** How each confidence level is drawn. One table, used by strip and tree. */
const TRUST: Record<string, { colour: string; text: string; label: string }> = {
  verified: { colour: 'var(--color-site-ok)', text: 'text-site-ok', label: 'verified on hardware' },
  reported: { colour: 'var(--color-site-plan)', text: 'text-site-plan', label: 'reported, not tested' },
  unstated: { colour: 'var(--color-site-line)', text: 'text-site-ink-3', label: 'trust not stated' },
};

export async function RecoveryOverview() {
  const report = await recoveryReport();
  const meta = appMeta(APP_ID);

  // Slower and likelier to be unconfigured than the bucket, so fetched after
  // it: a 403 on either cannot delay the figures this page is for.
  const [installs, audience] = await Promise.all([
    appInstalls(meta?.pkg ?? null),
    appAudience(APP_ID, 30),
  ]);

  const { index, content, registry } = report;
  const bucketDown = index.unreachable !== null;
  const projectId = process.env.GCP_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? null;
  const publishedCount = content.filter((c) => c.live).length;

  interface Task {
    level: 'bad' | 'warn' | 'ok';
    title: string;
    detail: React.ReactNode;
    href?: string;
    where?: string;
  }
  const tasks: Task[] = [];

  if (index.exists && !index.signed) {
    tasks.push({
      level: 'bad',
      title: 'The index is published without a signature',
      detail:
        'Every device refuses index.json with no index.sig and keeps the documents it already had. Republish to regenerate both.',
      href: `/apps/${APP_ID}/coverage`,
      where: 'Coverage',
    });
  }
  if (report.registryUnreachable) {
    tasks.push({
      level: 'bad',
      title: 'The trashmap could not be read',
      detail: report.registryUnreachable,
      href: `/apps/${APP_ID}/coverage`,
      where: 'Coverage',
    });
  } else if (!registry && !bucketDown && !index.corrupt) {
    tasks.push({
      level: 'bad',
      title: 'No trashmap is published',
      detail:
        'Every install is running on the copy built into the APK, so a path added for a phone nobody here owns reaches nobody until this ships.',
      href: `/apps/${APP_ID}/coverage`,
      where: 'Coverage',
    });
  }
  if (registry && registry.counts.unstated > 0) {
    tasks.push({
      level: 'warn',
      title: `${registry.counts.unstated} ${registry.counts.unstated === 1 ? 'rule has' : 'rules have'} no confidence set`,
      detail:
        'A path reproduced on a phone and a path copied off a forum look identical to the scanner. Marking which is which is the only way the app can tell a user what to expect.',
      href: `/apps/${APP_ID}/coverage`,
      where: 'Coverage',
    });
  }
  for (const c of content) {
    if (c.live) continue;
    // TRASHMAP IS SKIPPED HERE. It already has its own task above, worded for
    // what its absence actually means, and this loop was adding a second row
    // for the same fact: "No trashmap is published" directly over "Recovery
    // coverage is not published". Two rows for one problem is how one of them
    // goes stale, and it also inflated the count in the header.
    if (c.plan.packId === 'trashmap') continue;
    const screen = SCREEN_FOR[c.plan.packId];
    tasks.push({
      level: 'warn',
      title: `${c.plan.title} is not published`,
      detail: `${c.plan.summary} Devices fall back to what shipped in the APK.`,
      href: screen ? `/apps/${APP_ID}/${screen.path}` : undefined,
      where: screen?.label,
    });
  }
  if (!projectId) {
    tasks.push({
      level: 'warn',
      title: 'GCP_PROJECT is not set',
      detail:
        'The Firebase link and the Config screen have no project to point at, and the analytics export cannot be reached.',
      href: `/apps/${APP_ID}/config`,
      where: 'Config',
    });
  }
  if (!installs.ok) {
    tasks.push({
      level: 'warn',
      title: 'Install reports are not readable',
      detail: `${installs.reason} Until they are, which manufacturers matter is a guess rather than a measurement.`,
      href: `/apps/${APP_ID}/config`,
      where: 'Config',
    });
  }
  if (!audience.ok) {
    tasks.push({
      level: 'warn',
      title: 'Active users are not measured',
      detail: audience.reason,
      href: `/apps/${APP_ID}/analytics`,
      where: 'Analytics',
    });
  }
  if (!bucketDown && !index.corrupt && index.signed && registry) {
    tasks.push({
      level: 'ok',
      title: 'Bucket readable, index signed, trashmap live',
      detail: `${process.env.R2_BUCKET ?? 'mindberzerk-cdn'} · key ${index.keyId} · updated ${when(index.generatedAt)}`,
    });
  }

  const blockers = tasks.filter((t) => t.level === 'bad').length;
  const watch = tasks.filter((t) => t.level === 'warn').length;

  return (
    <StudioShell app={APP_ID}>
      {bucketDown && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The CDN bucket could not be read, so every figure below is a default rather than a
          measurement. {index.unreachable}
        </p>
      )}
      {index.corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is present but does not parse. Publishing is blocked rather than overwriting
          it, because a bad merge drops every document from every device.
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#2f7d6b'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(APP_ID)}
        title="Overview"
        meta={meta?.pkg ?? undefined}
        actions={
          <>
            {meta?.pkg && (
              <SlabButton href={`https://play.google.com/store/apps/details?id=${meta.pkg}`} external>
                Store listing
              </SlabButton>
            )}
            <SlabButton href={`/apps/${APP_ID}/coverage`} primary>
              Edit coverage
            </SlabButton>
          </>
        }
        metrics={
          <>
            <SlabCell
              label="Registry"
              value={bucketDown ? 'unknown' : registry ? `v${registry.version}` : 'none'}
              measured={!bucketDown && !!registry}
              note={
                bucketDown
                  ? 'bucket unreachable'
                  : registry
                    ? `pack v${registry.packVersion}`
                    : 'nothing published'
              }
            />
            <SlabCell
              label="Documents"
              value={bucketDown ? 'unknown' : publishedCount}
              of={bucketDown ? undefined : `of ${content.length}`}
              measured={!bucketDown}
              note={bucketDown ? undefined : bytes(index.sizeBytes)}
            />
            <SlabCell
              label="Paths mapped"
              value={registry ? registry.counts.paths : bucketDown ? 'unknown' : 0}
              measured={!!registry}
              note={
                registry
                  ? `${registry.counts.apps} apps · ${registry.counts.oem} brands`
                  : 'no trashmap live'
              }
            />
            <SlabCell
              label="Index"
              value={bucketDown ? 'unknown' : index.signed ? 'signed' : index.exists ? 'unsigned' : 'none'}
              measured={false}
              note={bucketDown ? undefined : when(index.generatedAt)}
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
          title="Trash paths"
          note="what devices are holding right now"
          right={
            <Link
              href={`/apps/${APP_ID}/coverage`}
              className="font-mono text-[11.5px] font-semibold text-site-accent-deep"
            >
              edit
            </Link>
          }
        >
          {!registry ? (
            <p className="text-[12px] leading-relaxed text-site-ink-3">
              {report.registryUnreachable ??
                (bucketDown
                  ? 'The bucket could not be read.'
                  : 'Nothing published, so every install is running on the map built into the APK.')}
            </p>
          ) : (
            <>
              <TrustStrip entries={registry.entries} />
              <PathTree entries={registry.entries} restoreFolder={registry.restoreFolder} />
            </>
          )}
        </SoftPanel>

        <div className="flex flex-col gap-4">
          <SoftPanel title="Documents" note="one row per pack this app reads">
            {content.map((c) => (
              <KVRow
                key={c.plan.packId}
                k={c.plan.title}
                v={
                  c.live ? (
                    <span className="font-mono">
                      v{c.live.version} · {bytes(c.live.sizeBytes)}
                    </span>
                  ) : (
                    <span className="text-site-ink-3">not published</span>
                  )
                }
              />
            ))}
            <KVRow k="Package" v={<span className="font-mono">{meta?.pkg ?? '-'}</span>} />
            <KVRow
              k="Key id"
              v={<span className="font-mono">{index.keyId || (process.env.PACK_KEY_ID ?? '-')}</span>}
            />
            {registry && (
              <KVRow k="Restore folder" v={<span className="font-mono">{registry.restoreFolder}</span>} />
            )}
          </SoftPanel>

          <SoftPanel title="Reach" note="measured, or named as absent">
            {installs.ok ? (
              <>
                <KVRow k="Installs, 30d" v={installs.data.installs.toLocaleString()} />
                <KVRow k="Uninstalls, 30d" v={installs.data.uninstalls.toLocaleString()} />
                {installs.data.activeDeviceInstalls !== null && (
                  <KVRow
                    k="Active device installs"
                    v={installs.data.activeDeviceInstalls.toLocaleString()}
                  />
                )}
              </>
            ) : (
              <Absent k="Installs" reason={installs.reason} />
            )}
            {audience.ok ? (
              <KVRow k="Active users, 30d" v={audience.data.activeUsers.toLocaleString()} />
            ) : (
              <Absent k="Active users" reason={audience.reason} />
            )}
          </SoftPanel>
        </div>
      </div>

      <p className="px-0.5 text-[11.5px] leading-relaxed text-site-ink-3">
        Every path here is a candidate. The scanner probes each one and reports only what exists and
        holds files, so a wrong guess costs one stat call. That is what makes it safe to publish
        paths for hardware nobody here owns, and it is also why saying which paths were actually
        reproduced matters.
      </p>
    </StudioShell>
  );
}

/**
 * A figure that could not be read.
 *
 * The reason takes the value's place rather than sitting under a zero. Zero is
 * a measurement and this is the absence of one, and the two must never look
 * alike on a screen whose whole job is telling you what is wrong.
 */
function Absent({ k, reason }: { k: string; reason: string }) {
  return (
    <div className="flex justify-between gap-3 border-b border-site-line py-2.5 text-[12.5px] last:border-b-0">
      <span className="font-medium text-site-ink-3">{k}</span>
      <span className="max-w-[24ch] text-right text-[11.5px] leading-snug text-site-ink-3">
        {reason}
      </span>
    </div>
  );
}

/**
 * One cell per rule, coloured by how much it is trusted.
 *
 * Reads as a disk map on purpose. The count of paths says nothing about whether
 * they were ever seen to work; this says it without a sentence, and the legend
 * carries the numbers for anyone who wants them.
 */
function TrustStrip({ entries }: { entries: CoverageEntry[] }) {
  const order: Array<keyof typeof TRUST> = ['verified', 'reported', 'unstated'];
  const counts = order.map((k) => ({
    key: k,
    n: entries.filter((e) => e.confidence === k).length,
  }));

  return (
    <div>
      <div className="flex flex-wrap gap-[3px]">
        {order.flatMap((key) =>
          entries
            .filter((e) => e.confidence === key)
            .map((e, i) => (
              <span
                key={`${key}-${i}-${e.id || e.label}`}
                title={`${e.label} · ${TRUST[key].label}`}
                className="h-4 w-[11px] rounded-[2px]"
                style={{ background: TRUST[key].colour }}
              />
            )),
        )}
      </div>
      <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5">
        {counts.map(({ key, n }) => (
          <span key={key} className="inline-flex items-center gap-1.5 text-[11px] text-site-ink-3">
            <span
              className="size-[8px] rounded-[2px]"
              style={{ background: TRUST[key].colour }}
            />
            {n} {TRUST[key].label}
          </span>
        ))}
      </div>
    </div>
  );
}

/**
 * The same rules as a filesystem.
 *
 * A trash path IS a directory, so a tree is the honest shape for it, and it
 * makes an unfamiliar package name legible from its neighbours. Capped, because
 * this is a summary and the editor is one click away: a hundred rows here would
 * make the panel's own header scroll off the top of the screen.
 */
function PathTree({
  entries,
  restoreFolder,
}: {
  entries: CoverageEntry[];
  restoreFolder: string;
}) {
  const LIMIT = 12;
  const shown = entries.slice(0, LIMIT);
  const hidden = entries.length - shown.length;

  return (
    <div className="mt-4 overflow-x-auto font-mono text-[12px] leading-[1.9]">
      <div className="text-site-ink-3">/storage/emulated/0</div>
      {shown.map((e, i) => {
        const last = i === shown.length - 1 && hidden === 0;
        const trust = TRUST[e.confidence];
        return (
          <div key={`${e.kind}-${e.id || e.label}-${i}`} className="flex items-baseline gap-2.5">
            <span className="shrink-0 text-site-ink-3">{last ? '└──' : '├──'}</span>
            <span className="shrink-0 text-site-ink">{e.label}</span>
            <span className="min-w-0 flex-1 truncate text-site-ink-3">
              {e.paths[0] ?? 'no path'}
              {e.paths.length > 1 ? ` +${e.paths.length - 1}` : ''}
            </span>
            <span className={`shrink-0 text-[10.5px] ${trust.text}`}>{e.confidence}</span>
          </div>
        );
      })}
      {hidden > 0 && (
        <div className="flex items-baseline gap-2.5">
          <span className="shrink-0 text-site-ink-3">└──</span>
          <span className="text-site-ink-3">
            {hidden} more {hidden === 1 ? 'rule' : 'rules'} in the editor
          </span>
        </div>
      )}
      <div className="mt-2 text-[11px] text-site-ink-3">
        restored into {restoreFolder}
      </div>
    </div>
  );
}
