import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { DocumentEditor } from '@/components/g-recovery/DocumentEditor';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton } from '@/components/studio/ui';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { readPublishedContent } from '@/lib/g-recovery/content-read';

export const dynamic = 'force-dynamic';

/**
 * The short reading behind an info icon.
 *
 * ─── WHAT THIS SCREEN IS NOW FOR ────────────────────────────────────────────
 *
 * It used to be the whole explanation: seven chapters on how Android storage
 * works. Most of that job moved to Storage, where the same knowledge is
 * attached to the folder a person is standing in and cannot be avoided, rather
 * than filed in a manual nobody opens on a phone.
 *
 * What is left here is the reading that has nowhere else to live: why a deleted
 * file is sometimes gone for good, what a preview quality recovery actually is,
 * and why the answer depends on an Android version. Reached from an info icon
 * at the moment a verdict is delivered, which is the only moment anyone wants
 * it.
 *
 * KEEP IT SHORT. Two screens of explanation that overlap with Storage will
 * disagree with Storage within a month, and the version that is wrong will be
 * whichever one nobody remembered to edit.
 *
 * ─── THE SUMMARISER USED TO BE PASSED DOWN FROM HERE ─────────────────────────
 *
 * It cannot be. This is a server component and the editor is a client one, so a
 * function prop is a closure React is being asked to serialise, and the page
 * died on it. The summariser now lives inside the editor keyed by pack id. Left
 * as a note because the mistake is easy to repeat: it looks like an ordinary
 * prop right up until the first request.
 */
export default async function LearnPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();
  if (app !== 'g-recovery') notFound();

  const published = await readPublishedContent('learn-en');
  const meta = appMeta(app);

  return (
    <StudioShell app={app}>
      <AppSlab
        tint={meta?.tint ?? '#4c8dff'}
        mark={meta?.mark ?? 'R'}
        crumb={appName(app)}
        title="Learn"
        meta={
          published.version > 0 ? `articles/learn-en, live at v${published.version}` : 'not published'
        }
        actions={<SlabButton href={`/apps/${app}/storage`}>Storage</SlabButton>}
      />

      <div className="mb-1">
        <p className="max-w-[70ch] text-[13px] leading-relaxed text-site-ink-3">
          The short answer to why a file cannot be recovered, reached from an info icon rather than
          from a menu. What a folder is belongs in Storage now, so anything here that names a
          folder is duplicating a screen that will drift away from it. Six block types: p, h, note,
          warn, path, list. The app renders exactly those and skips anything else, so a type it
          cannot draw is refused at publish rather than going missing on someone&apos;s phone.
        </p>
      </div>

      <DocumentEditor
        packId="learn-en"
        initial={published.document}
        liveVersion={published.version}
        unreachable={published.unreachable}
      />
    </StudioShell>
  );
}
