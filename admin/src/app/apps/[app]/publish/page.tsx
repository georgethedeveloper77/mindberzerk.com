import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { readLiveIndex } from '@/lib/catalogue';
import { isAppId, appName } from '@/lib/registry';
import { Shell } from '@/app/components/shell';
import { PageHead } from '@/app/components/ui';
import { PublishForm } from '@/app/components/publish-form';

export const dynamic = 'force-dynamic';

/**
 * PHASE C5 — publishing, now per app.
 *
 * Same page as before with the app read from the segment instead of hardcoded.
 * It stays a separate route rather than living under the pack list: on a phone
 * the list and a twelve-field form cannot share a screen without one of them
 * becoming a scroll-past, and publishing is a task you enter deliberately.
 *
 * `PublishForm` is untouched by this pass. Its inputs still use the old
 * neutral-* palette, so it will read slightly colder than the rest of the panel
 * until it is moved onto the tokens.
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
      <PageHead
        title={`Publish to ${appName(app)}`}
        meta={`${live.packs.length} packs live`}
      />
      <PublishForm app={app} packs={live.packs} />
    </Shell>
  );
}
