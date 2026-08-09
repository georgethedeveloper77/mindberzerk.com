import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { GuidanceEditor } from '@/components/g-recovery/GuidanceEditor';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readPublishedContent } from '@/lib/g-recovery/content-read';

export const dynamic = 'force-dynamic';

/**
 * BRAND GUIDANCE. Formerly a design-only placeholder, now the third publisher.
 *
 * ─── WHAT THE PLACEHOLDER GOT RIGHT AND WHAT IT GOT WRONG ───────────────────
 *
 * Right: refusing to print an install share it had not measured. That rule
 * survives, and the brand list is no longer a hardcoded target set at all,
 * because the document is the list now.
 *
 * Wrong: the delivery mechanism. It said Remote Config keyed by manufacturer.
 * Remote Config would have been a second content pipeline with its own auth,
 * its own versioning, no signature and no offline copy, sitting beside one that
 * already signs, versions and caches. This publishes as `oem-guide` through the
 * same route as everything else.
 *
 * ─── G RECOVERY ONLY ────────────────────────────────────────────────────────
 *
 * Same reasoning as Coverage. A guidance editor rendered for the launcher would
 * invite a publish into a prefix nothing reads.
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
  if (app !== 'g-recovery') notFound();

  const published = await readPublishedContent('oem-guide');
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Brand guidance"
        meta={
          published.version > 0
            ? `guides/oem-guide, live at v${published.version}`
            : 'not published'
        }
        actions={<SlabButton href={`/apps/${app}/coverage`}>Coverage</SlabButton>}
      />

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          What to tell someone based on who made their phone. Recovery behaviour
          diverges by OEM skin far more than by Android version: whether the
          gallery keeps a bin, how long it holds it, and whether a cloud sync has
          already removed the copy they are looking for. Published as a signed
          pack alongside the trashmap, and every device that matches no brand
          reads the fallback.
        </p>
      </div>

      <GuidanceEditor
        initial={published.document}
        liveVersion={published.version}
        unreachable={published.unreachable}
      />
    </StudioShell>
  );
}
