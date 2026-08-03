import { notFound } from 'next/navigation';

import { adminGate } from '@/app/components/admin-gate';
import { IconBuilder } from '@/app/components/icon-builder';
import { StudioShell } from '@/components/studio/shell';
import { AppSlab } from '@/components/studio/ui';
import { readLiveIndex, type AppId as CatalogueAppId } from '@/lib/core/catalogue';
import {
  readPublishedHeroPack,
  rehydrateIconsFromUrls,
  type RehydratedPack,
} from '@/lib/core/cdn';
import { appMeta, appName, isAppId } from '@/lib/core/registry';
import { skuCatalogue } from '@/lib/core/sku-catalogue';
import { draftAssetUrl, readIconDraft } from '@/lib/g-launcher/icon-drafts';
import { readAllDraftsSafe } from '@/lib/g-launcher/themes';

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
 * button on every row in `/icons`, and already destructured here. It reached
 * the breadcrumb and stopped. `IconBuilder` never received it and starts every
 * field blank, so Edit opened an empty builder WITH THE PACK'S ID IN THE
 * BREADCRUMB, which reads as loaded rather than as broken. Publishing from that
 * screen wrote an empty pack over a real one at the next version number.
 *
 * So the pack is read back and handed down. See `lib/core/cdn.ts` for why that
 * read goes over public HTTPS rather than through `pack-content.ts`.
 *
 * ─── AND AN UNREADABLE INDEX REFUSES, RATHER THAN PUBLISHING v1 ─────────────
 *
 * `readLiveIndex` reports three separate states. When the bucket cannot be
 * read, `packs` is empty, so `publishedVersion` is empty, so the builder
 * computes version 1 for a pack already live at 4, and publishing it is a
 * silent no-op on every device that has it.
 *
 * It is worse with rehydration than without: an unreadable index also means an
 * empty editor that looks loaded. So the builder does not render at all until
 * the catalogue is known.
 *
 * ─── THREE THINGS `?id=` CAN NAME, CHECKED IN THIS ORDER ────────────────────
 *
 *   1. A PUBLISHED pack. Rehydrated from the CDN, editing bumps the version.
 *   2. A DRAFT. Rehydrated from `admin/icon-drafts/`, nothing is live yet.
 *   3. Neither, which starts a new pack rather than 404ing.
 *
 * Published wins when both exist, because the published pack is what devices
 * have and is therefore the thing being edited. The banner says which one
 * opened, since the two look identical once the fields are full and the
 * difference decides whether pressing publish changes anything on a phone.
 *
 * ─── THE PRODUCT ID COMES FROM THE MERGED CATALOGUE ─────────────────────────
 *
 * `skuCatalogue` rather than `listPlayProducts` directly, so the picker still
 * has options when Play answers 403: the snapshot of the last successful read,
 * and the product ids the signed index already uses. Nothing about publishing
 * depends on Play, so its failure degrades the field rather than closing the
 * page.
 *
 * ─── AND NOW THE DISTRO LIST, FOR THE BELONGS-TO PICKER ─────────────────────
 *
 * A hero pack belongs to the distro whose base id prefixes its own, and the
 * launcher shelves its icons screen by exactly that rule. The builder needs
 * the list of bases so choosing a distro can prefix the pack id. Read from
 * BOTH the theme drafts and the live theme packs: a draft-only distro is a
 * legitimate shelf to build for before it publishes, and a theme published
 * out-of-band has no draft. Union, keyed by base, drafts fill the gaps.
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
  const meta = appMeta(app);
  const [live, play, themeDrafts] = await Promise.all([
    readLiveIndex(app),
    skuCatalogue(app, meta?.pkg ?? null),
    readAllDraftsSafe(app as CatalogueAppId),
  ]);

  const stripTheme = (s: string) =>
    s.endsWith('-theme') ? s.slice(0, -'-theme'.length) : s;
  const baseTitle = new Map<string, string>();
  for (const p of live.packs) {
    if (p.packType !== 'theme') continue;
    const base = stripTheme(p.packId);
    baseTitle.set(base, p.title || base);
  }
  for (const d of themeDrafts.drafts) {
    const base = stripTheme(d.id);
    if (!baseTitle.has(base)) baseTitle.set(base, d.title || base);
  }
  const distros = [...baseTitle]
    .map(([base, title]) => ({ base, title }))
    .sort((a, b) => a.title.localeCompare(b.title));

  const bad = 'rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan';

  const slab = (meta_: ReturnType<typeof appMeta>, title: string, sub?: string) => (
    <AppSlab
      tint={meta_?.tint ?? '#6d4ae8'}
      mark={meta_?.mark ?? '?'}
      crumb={`${appName(app)} / Icons`}
      title={title}
      meta={sub}
    />
  );

  // No catalogue, no builder. Both of these mean the next version number cannot
  // be known, and a wrong version number is the one publishing mistake that
  // reports success and changes nothing on any phone.
  if (live.unreachable || live.corrupt) {
    return (
      <StudioShell app={app}>
        {slab(meta, id ?? 'New icon pack')}
        <p className={bad}>
          {live.unreachable
            ? `The catalogue could not be read, so the next version number is unknown and nothing can be published safely. ${live.unreachable}`
            : 'The live index is present but does not parse. Publishing would rebuild it from an unreadable state, so the builder is closed until someone looks at the bucket.'}
        </p>
      </StudioShell>
    );
  }

  const hero = live.packs.filter((p) => p.packType === 'hero');

  const publishedVersion: Record<string, number> = {};
  for (const p of hero) publishedVersion[p.packId] = p.version;

  const entry = id ? (hero.find((p) => p.packId === id) ?? null) : null;
  let initial: RehydratedPack | null = null;
  if (entry) initial = await readPublishedHeroPack(app, entry);

  // ── A DRAFT IS READ EVEN WHEN THE PACK IS PUBLISHED ───────────────────────
  //
  // This used to be `id && !entry`, so a published pack always won and a draft
  // saved against it COULD NOT BE OPENED BY ANY ROUTE. Saving forty icons onto
  // a live pack therefore wrote them somewhere the builder would never look
  // again, and Edit reopened the fourteen that were published. That is the
  // worst shape a save can have: it succeeds, it reports success, and the work
  // is unreachable.
  //
  // The reasoning behind the old rule was that a draft must never SHADOW what
  // devices hold. It still does not: the draft supplies the CONTENT, because it
  // is the newer work, while `publishedVersion` below keeps coming from the
  // index, so publishing writes v(entry+1) and cannot silently rewrite v1 over
  // a live pack. The banner says which state the screen is in.
  const draft = id ? await readIconDraft(app, id) : null;
  if (draft) {
    // The bytes are FETCHED, not linked. `IconBuilder` decodes every icon with
    // `atob`, so handing it an https URL is not a degraded preview, it is an
    // exception during render. See rehydrateIconsFromUrls.
    const rehydrated = await rehydrateIconsFromUrls(
      draft.icons.map((i) => ({
        pkg: i.pkg,
        file: i.file,
        url: draftAssetUrl(app, draft.packId, i.file),
      })),
    );

    initial = {
      packId: draft.packId,
      name: draft.name,
      minAppVersion: draft.minAppVersion,
      masked: draft.masked,
      sku: draft.sku || null,
      // NEVER PUBLISHED, so the builder computes version 1 from this. A draft
      // that claimed a published version would offer v2 for a pack no device
      // has, which is the exact silent no-op the version guard exists to stop.
      // FROM THE INDEX when the pack is live, so a draft edited on top of v4
      // publishes v5. Zero only when nothing is published under this id, which
      // is what makes a never-published draft compute v1.
      publishedVersion: entry?.version ?? 0,
      // The SAME shape `readPublishedHeroPack` returns, which is why the
      // builder needs no new prop: both arrive as inlined bytes.
      icons: rehydrated.icons,
      // A draft asset that cannot be read is reported for the same reason a
      // published one is: publishing from here would drop it permanently.
      notes: rehydrated.notes,
    };
  }

  return (
    <StudioShell app={app}>
      {slab(
        meta,
        entry ? entry.title || entry.packId : draft ? draft.name || draft.packId : 'New icon pack',
        entry
          ? `${draft ? 'draft ahead of' : 'editing'} v${entry.version}, publishing writes v${entry.version + 1}`
          : draft
            ? `draft, ${draft.icons.length} ${draft.icons.length === 1 ? 'icon' : 'icons'}, never published`
            : `${hero.length} hero ${hero.length === 1 ? 'pack' : 'packs'} published`,
      )}

      {draft && (
        <p className="rounded-[14px] bg-site-info-soft px-4 py-3 text-[13px] leading-relaxed text-site-info">
          {entry
            ? `Opened from a saved draft, which is ahead of the published v${entry.version}. Publishing writes v${entry.version + 1}; until then devices keep v${entry.version}.`
            : `Opened from a draft. Nothing here is live: publishing will create ${draft.packId} at version 1 and it will reach devices on their next sync.`}
        </p>
      )}

      {id && !entry && !draft && (
        <p className={bad}>
          No published hero pack and no draft has the id {id}. Starting a new pack instead, so
          nothing is overwritten by accident.
        </p>
      )}

      {/* `pack.json` is the only place the package-to-filename map exists, so a
          pack whose copy cannot be read cannot be edited. Opening a blank
          builder on the real pack id would republish it with every mapping
          gone. See readPublishedHeroPack. */}
      {entry && !initial && (
        <p className={bad}>
          {entry.packId} is published, but its pack.json could not be read from the CDN, and that
          file is the only record of which icon belongs to which app. Editing it would republish it
          with no icons at all, so the builder has been left empty. Republish this pack from its
          source art.
        </p>
      )}

      {initial && initial.notes.length > 0 && (
        <p className={bad}>
          {initial.packId} opened with problems. Publishing before fixing them ships the pack as
          shown here. {initial.notes.join(' ')}
        </p>
      )}

      <IconBuilder
        app={app}
        publishedIds={hero.map((p) => p.packId)}
        publishedVersion={publishedVersion}
        initial={initial}
        distros={distros}
        // ── THE DRAFT'S PREVIEW SETTINGS, WHICH WERE BEING DROPPED ──────
        //
        // `IconDraft` has carried `plate` and `radius` since drafts existed,
        // with a comment promising a reopened draft looks like the one you
        // left, and the save action has always written them. Nothing read them
        // back: the builder hardcoded its two useState defaults, so every
        // reopen silently reset both. `shape` joins them rather than becoming
        // the second field with the same bug.
        //
        // Only on the draft branch. A published pack read off the CDN has no
        // preview settings to restore, because pack.json does not carry any.
        preview={
          draft
            ? {
                plate: draft.plate,
                radius: draft.radius,
                shape: draft.shape ?? 'roundedSquare',
              }
            : null
        }
        play={play}
      />
    </StudioShell>
  );
}
