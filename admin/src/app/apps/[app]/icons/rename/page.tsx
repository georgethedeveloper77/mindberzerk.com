import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { RenamePack } from '@/components/icon-list/RenamePack';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * The migration reads, re-uploads and signs several hundred KB against a
 * bucket in another region, and a local run took 95 seconds. Cloud Run's
 * default cuts a server action off well inside that, and the cut would land
 * mid-publish: objects uploaded, index not written. Same 300 the pack route
 * sets, and for the same reason.
 */
export const maxDuration = 300;

/**
 * Migrate an icon pack to a new id.
 *
 *   /apps/<app>/icons/rename
 *   /apps/<app>/icons/rename?from=<old>&to=<new>
 *
 * ITS OWN ROUTE rather than a control on the icons list, for two reasons. The
 * list is a browsing screen and this is the most destructive thing in the
 * section, so it should take a deliberate navigation rather than sit one
 * mis-click from Edit. And a new route touches no existing file, which matters
 * on a screen whose neighbours have been edited several times this week.
 */
export default async function RenamePackPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { from, to } = await searchParams;
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={`${appName(app)} / Icons`}
        title="Rename a pack"
        meta="moves the art, publishes a new id, repoints the distros"
      />
      <RenamePack app={app} initialFrom={from ?? ''} initialTo={to ?? ''} />
    </StudioShell>
  );
}
