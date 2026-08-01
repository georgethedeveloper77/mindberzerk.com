import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/core/catalogue';
import { isAppId, appName } from '@/lib/core/registry';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { Banner, PageHead } from '@/app/components/ui';
import { PublishForm } from '@/app/components/publish-form';

export const dynamic = 'force-dynamic';

/**
 * UPLOAD PACK - the escape hatch, and the only route that publishes a pack type
 * no builder covers.
 *
 * It stays a separate route rather than living under the pack list: on a phone
 * the list and a twelve-field form cannot share a screen without one of them
 * becoming a scroll-past, and publishing is a task you enter deliberately.
 *
 * ─── THE UNREADABLE-BUCKET BANNER IS NEW AND IT MATTERS HERE ────────────────
 *
 * This page passes `live.packs` to the form, and the form uses that list to
 * pre-fill the NEXT version for a pack that already exists. With the bucket
 * unreachable that list is empty, so every pack looks new, so the version field
 * offers 1 for something already live at 4, and the publish is a silent no-op
 * on every device that holds it. The server guard refuses the write, but the
 * form would have let you fill the whole thing in first.
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

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      <Breadcrumb
        items={[{ label: appName(app), href: `/apps/${app}/packs` }, { label: 'Upload pack' }]}
      />

      {live.unreachable && (
        <Banner tone="bad">
          The catalogue could not be read, so nothing here knows which packs
          already exist or what version they are at. Publishing would offer
          version 1 for a pack that is already live, which reaches no device and
          reports success. {live.unreachable}
        </Banner>
      )}
      {live.corrupt && (
        <Banner tone="bad">
          index.json is present but does not parse. Publishing is blocked rather
          than overwriting it.
        </Banner>
      )}

      <PageHead
        title={`Upload to ${appName(app)}`}
        meta={`${live.packs.length} ${live.packs.length === 1 ? 'pack' : 'packs'} live`}
      />

      <PublishForm
        app={app}
        packs={live.packs}
        catalogueUnknown={!!live.unreachable || live.corrupt}
      />
    </Shell>
  );
}
