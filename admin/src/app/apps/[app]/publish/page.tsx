import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { PublishForm } from '@/app/components/publish-form';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab, SlabButton, SlabCell } from '@/components/studio/ui';
import { bytes } from '@/app/components/ui';
import { readLiveIndex } from '@/lib/core/catalogue';
import { appMeta, appName, isAppId, minAppVersionFor, packTypesFor } from '@/lib/core/registry';

export const dynamic = 'force-dynamic';

/**
 * UPLOAD PACK - the escape hatch, and the only route that publishes a pack type
 * no builder covers.
 *
 * It stays a separate route rather than living under the pack list: on a phone
 * the list and a twelve-field form cannot share a screen without one of them
 * becoming a scroll-past, and publishing is a task you enter deliberately.
 *
 * ─── THE UNREADABLE-BUCKET BANNER MATTERS MOST HERE ─────────────────────────
 *
 * This page passes `live.packs` to the form, and the form uses that list to
 * pre-fill the NEXT version for a pack that already exists. With the bucket
 * unreachable that list is empty, so every pack looks new, so the version field
 * offers 1 for something already live at 4, and the publish is a silent no-op
 * on every device that holds it. The server guard refuses the write, but the
 * form would have let you fill the whole thing in first.
 *
 * ─── MIGRATED OFF THE CONSOLE FRAME ─────────────────────────────────────────
 *
 * This was the last per-app screen still rendering `app/components/shell.tsx`.
 * That frame is dark-only and built on the `surface-*` tokens, so opening this
 * page from any other one was a full theme flip mid-task. Its own docblock says
 * screens migrate one at a time and the file is deleted when the last one moves;
 * grep for `@/app/components/shell` before deleting it, because the launcher's
 * own screens are not in this pass.
 */
export default async function PublishPage({
  params,
}: {
  params: Promise<{ app: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const live = await readLiveIndex(app);
  const meta = appMeta(app);
  const catalogueUnknown = !!live.unreachable || live.corrupt;
  const size = live.packs.reduce((n, p) => n + p.sizeBytes, 0);

  return (
    <StudioShell app={app}>
      {live.unreachable && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          The catalogue could not be read, so nothing here knows which packs already exist or what
          version they are at. Publishing would offer version 1 for a pack that is already live,
          which reaches no device and reports success. {live.unreachable}
        </p>
      )}
      {live.corrupt && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          index.json is present but does not parse. Publishing is blocked rather than overwriting
          it.
        </p>
      )}

      <AppSlab
        tint={meta?.tint ?? '#6d4ae8'}
        mark={meta?.mark ?? '?'}
        crumb={appName(app)}
        title="Upload pack"
        meta={`cdn.mindberzerk.com/${app}`}
        actions={<SlabButton href={`/apps/${app}/packs`}>CDN objects</SlabButton>}
        metrics={
          <>
            <SlabCell
              label="Packs live"
              value={catalogueUnknown ? 'unknown' : live.packs.length}
              measured={!catalogueUnknown}
              note={catalogueUnknown ? 'catalogue unreadable' : bytes(size)}
            />
            <SlabCell
              label="Key id"
              value={live.keyId || (process.env.PACK_KEY_ID ?? '-')}
              measured={false}
              note="written into every manifest"
            />
          </>
        }
      />

      <PublishForm
        app={app}
        packs={live.packs}
        catalogueUnknown={catalogueUnknown}
        types={packTypesFor(app)}
        defaultMinAppVersion={minAppVersionFor(app)}
      />
    </StudioShell>
  );
}
