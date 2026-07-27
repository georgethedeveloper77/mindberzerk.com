import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { IconBuilder } from '@/app/components/icon-builder';
import { readLiveIndex } from '@/lib/catalogue';
import { appName, isAppId } from '@/lib/registry';

export const dynamic = 'force-dynamic';

/**
 * The icon pack editor, split off `/icons`.
 *
 *   /apps/<app>/icons/builder            a new pack
 *   /apps/<app>/icons/builder?id=<pack>  open an existing one
 *
 * `/icons` had the list and the builder on one route, so publishing something
 * was three screens of scrolling from seeing what you already had. Same split
 * Distros uses: a list you browse, an editor you open.
 *
 * `publishedVersion` is what the builder uses to pick the next version number,
 * and it must come from the live index rather than from the form: a pack only
 * reaches devices when its version INCREASES, and a version typed by hand is a
 * silent no-op on every phone the day someone repeats one.
 */
export default async function IconBuilderPage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!isAppId(app)) notFound();

  const { id } = await searchParams;
  const live = await readLiveIndex(app);
  const hero = live.packs.filter((p) => p.packType === 'hero');

  const publishedVersion: Record<string, number> = {};
  for (const p of hero) publishedVersion[p.packId] = p.version;

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      <Breadcrumb
        items={[
          { label: appName(app), href: `/apps/${app}/packs` },
          { label: 'Icons', href: `/apps/${app}/icons` },
          { label: id ?? 'new' },
        ]}
      />
      <IconBuilder
        app={app}
        publishedIds={hero.map((p) => p.packId)}
        publishedVersion={publishedVersion}
      />
    </Shell>
  );
}
