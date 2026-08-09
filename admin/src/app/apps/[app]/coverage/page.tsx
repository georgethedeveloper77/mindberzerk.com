import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { CoverageEditor } from '@/components/g-recovery/CoverageEditor';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readPublishedContent } from '@/lib/g-recovery/content-read';

/**
 * Recovery coverage: the trashmap registry.
 *
 * G RECOVERY ONLY. The trashmap has no meaning for the launcher, and a screen
 * that renders an empty editor for the wrong app is worse than one that is not
 * there: it invites a publish into a bucket prefix nothing reads.
 *
 * ─── THE BREADCRUMB IS GONE, AND IT WAS A BUG NOT A STYLE ───────────────────
 *
 * `components/console/breadcrumb` is built on the dark console tokens, `ink`,
 * `ink-3`, `micro`. This page renders inside `StudioShell`, which is the light
 * soft surface, so those resolved to dark text values on a light canvas. Every
 * other studio screen opens with `AppSlab`, which also carries the app tint, so
 * which app you are editing is legible before a word is read. That matters more
 * here than anywhere: publishing a trashmap into the launcher's prefix would be
 * quiet and permanent.
 */
export const dynamic = 'force-dynamic';

export default async function CoveragePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  if (app !== 'g-recovery') notFound();

  const published = await readPublishedContent('trashmap');
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Coverage"
        meta={
          published.version > 0
            ? `registries/trashmap, live at v${published.version}`
            : 'not published'
        }
        actions={<SlabButton href={`/apps/${app}/guides`}>Brand guidance</SlabButton>}
      />

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          Where deleted files hide, per app and per manufacturer. Published as a signed pack, so
          adding a path for a phone nobody here owns takes minutes instead of a Play release.
          Devices apply it on their next launch and fall back to the copy built into the app until
          then.
        </p>
      </div>

      <CoverageEditor
        initial={published.document}
        liveVersion={published.version}
        unreachable={published.unreachable}
      />
    </StudioShell>
  );
}
