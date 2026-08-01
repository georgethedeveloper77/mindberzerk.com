import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { Shell } from '@/app/components/shell';
import { Banner } from '@/app/components/ui';
import { Breadcrumb } from '@/components/console/breadcrumb';
import { IconBuilder } from '@/app/components/icon-builder';
import { readLiveIndex } from '@/lib/core/catalogue';
import { readPublishedHeroPack, type RehydratedPack } from '@/lib/core/cdn';
import { listPlayProducts, playLite } from '@/lib/core/play';
import { appMeta, appName, isAppId } from '@/lib/core/registry';

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
 *
 * ─── `?id=` USED TO BE READ AND THROWN AWAY ─────────────────────────────────
 *
 * The second URL above was already documented, already linked to from the Edit
 * button on every card in `/icons`, and already destructured here. It reached
 * the breadcrumb and stopped. `IconBuilder` never received it and starts every
 * field blank, so Edit opened an empty builder WITH THE PACK'S ID IN THE
 * BREADCRUMB, which reads as loaded rather than as broken. Publishing from that
 * screen wrote an empty pack over a real one at the next version number.
 *
 * So the pack is now read back and handed down. See `lib/cdn.ts` for why that
 * read goes over public HTTPS rather than through `pack-content.ts`.
 *
 * ─── AND AN UNREADABLE INDEX NOW REFUSES, RATHER THAN PUBLISHING v1 ─────────
 *
 * `readLiveIndex` reports three separate states and this route checked none of
 * them. When the bucket cannot be read, `packs` is empty, so `publishedVersion`
 * is empty, so the builder computes version 1 for a pack that is already live at
 * 4, and publishing it is a silent no-op on every device that has it. That is
 * exactly the failure the paragraph above warns about, arriving through the one
 * path that was not guarded.
 *
 * It is worse with rehydration than it was without: an unreadable index also
 * means an empty editor that looks loaded. So the builder does not render at all
 * until the catalogue is known.
 *
 * ─── PLAY IS READ TOO, AND ITS FAILURE DOES NOT CLOSE THE BUILDER ───────────
 *
 * The product ID field becomes a picker over what exists in Play, with a
 * status line. Unlike the index, nothing about publishing depends on Play, so
 * an unreachable Play degrades the field to a plain input with the reason
 * rather than refusing the page. `listPlayProducts` never throws.
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
  const [live, playRaw] = await Promise.all([
    readLiveIndex(app),
    listPlayProducts(appMeta(app)?.pkg ?? null),
  ]);
  const play = playLite(playRaw);

  const crumbs = (
    <Breadcrumb
      items={[
        { label: appName(app), href: `/apps/${app}/packs` },
        { label: 'Icons', href: `/apps/${app}/icons` },
        { label: id ?? 'new' },
      ]}
    />
  );

  // No catalogue, no builder. Both of these mean the next version number cannot
  // be known, and a wrong version number is the one publishing mistake that
  // reports success and changes nothing on any phone.
  if (live.unreachable || live.corrupt) {
    return (
      <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
        {crumbs}
        <Banner tone="bad">
          {live.unreachable
            ? `The catalogue could not be read, so the next version number is unknown and nothing can be published safely. ${live.unreachable}`
            : 'The live index is present but does not parse. Publishing would rebuild it from an unreadable state, so the builder is closed until someone looks at the bucket.'}
        </Banner>
      </Shell>
    );
  }

  const hero = live.packs.filter((p) => p.packType === 'hero');

  const publishedVersion: Record<string, number> = {};
  for (const p of hero) publishedVersion[p.packId] = p.version;

  const entry = id ? (hero.find((p) => p.packId === id) ?? null) : null;
  let initial: RehydratedPack | null = null;
  if (entry) initial = await readPublishedHeroPack(app, entry);

  return (
    <Shell app={app} subtitle={`cdn.mindberzerk.com / ${app}`}>
      {crumbs}

      {id && !entry && (
        <Banner tone="bad">
          No published hero pack has the id {id}. Starting a new pack instead, so
          nothing is overwritten by accident.
        </Banner>
      )}

      {/* `pack.json` is the only place the package-to-filename map exists, so a
          pack whose copy cannot be read cannot be edited. Opening a blank
          builder on the real pack id would republish it with every mapping
          gone. See readPublishedHeroPack. */}
      {entry && !initial && (
        <Banner tone="bad">
          {entry.packId} is published, but its pack.json could not be read from
          the CDN, and that file is the only record of which icon belongs to
          which app. Editing it would republish it with no icons at all, so the
          builder has been left empty. Republish this pack from its source art.
        </Banner>
      )}

      {initial && initial.notes.length > 0 && (
        <Banner tone="bad">
          {initial.packId} opened with problems. Publishing before fixing them
          ships the pack as shown here. {initial.notes.join(' ')}
        </Banner>
      )}

      <IconBuilder
        app={app}
        publishedIds={hero.map((p) => p.packId)}
        publishedVersion={publishedVersion}
        initial={initial}
        play={play}
      />
    </Shell>
  );
}
