import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { StorageEditor } from '@/components/g-recovery/StorageEditor';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readPublishedContent } from '@/lib/g-recovery/content-read';

export const dynamic = 'force-dynamic';

/**
 * THE STORAGE MAP.
 *
 * Every folder on the device, in plain words, with what deleting from it costs.
 * It is the screen that took most of Learn's job: seven chapters about Android
 * storage is a manual and nobody opens a manual on a phone, but the same
 * sentence attached to the folder someone is standing in is a label they cannot
 * miss.
 *
 * `recoverable` is the field that earns the screen. It answers "why can this
 * not be recovered" per folder, at the moment the question occurs, and it is
 * the join between this document and the trashmap.
 */
export default async function StoragePage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  if (app !== 'g-recovery') notFound();

  const published = await readPublishedContent('storage-map');
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Storage"
        meta={
          published.version > 0
            ? `registries/storage-map, live at v${published.version}`
            : 'not published'
        }
        actions={<SlabButton href={`/apps/${app}/coverage`}>Coverage</SlabButton>}
      />

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          What each folder is, who put it there, and what happens to a file deleted from it. The app
          measures the sizes itself; this supplies the words. Write for someone who has just lost a
          photo and is looking at a folder called DCIM for the first time.
        </p>
      </div>

      <StorageEditor
        initial={published.document}
        liveVersion={published.version}
        unreachable={published.unreachable}
      />
    </StudioShell>
  );
}
