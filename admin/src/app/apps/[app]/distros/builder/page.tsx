import { notFound } from 'next/navigation';

import { APPS, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { adminGate } from '@/app/components/admin-gate';
import { StudioShell } from '@/components/studio/shell';
import { skuCatalogue } from '@/lib/core/sku-catalogue';
import { appMeta } from '@/lib/core/registry';
import { rehydrateFilesFromUrls, rehydrateIconsFromUrls } from '@/lib/core/cdn';
import { readDraft } from '@/lib/g-launcher/themes';
import { draftAssetUrl, readDraftAssets } from '@/lib/g-launcher/distro-draft-assets';
import {
  draftAssetUrl as iconDraftAssetUrl,
  readIconDraft,
} from '@/lib/g-launcher/icon-drafts';
import { DistroWorkspace } from '@/components/distro-builder/DistroWorkspace';

/**
 * The one editor.
 *
 *   /apps/<app>/distros/builder            a new distro
 *   /apps/<app>/distros/builder?id=<pack>  open an existing one
 *
 * A theme and a distro were always the same artifact, and having two editors
 * meant two places for the schema to drift apart.
 *
 * ─── LOADED ON THE SERVER, NOT FETCHED IN THE CLIENT ────────────────────────
 *
 * The draft is read here and handed down as a prop, so the workspace mounts
 * with the right values in its `useState` initialisers rather than mounting
 * blank and being corrected by an effect. That difference is visible: a builder
 * that flashes a blank palette and then fills in is a builder you do not trust
 * to have loaded everything.
 *
 * A MISSING DRAFT IS NOT A 404. `readDraft` returns null for an id that has no
 * draft, which includes every theme that only exists as a published pack. The
 * workspace opens empty in that case rather than refusing, because an empty
 * builder is a usable thing and a 404 on an Edit button is not.
 *
 * ─── AND NOW THE DRAFT'S OWN ART, WHICH WAS SAVED AND NEVER READ ────────────
 *
 * `saveDistroDraftAction` has stored every wallpaper and logo under
 * `admin/distro-drafts/<id>/` since it existed, and nothing ever read them
 * back: the workspace mounted with empty asset slots over a spec that still
 * referenced the files, so every reopen looked like the art was lost. It was
 * in the bucket the whole time.
 *
 * The bytes are FETCHED server-side and INLINED as data URLs, not linked. The
 * same rule the icon builder learned the hard way: the client decodes with
 * `atob`, and an https URL handed to `atob` is an exception during render, not
 * a degraded preview. See rehydrateFilesFromUrls in lib/core/cdn.
 *
 * The distro's inline icon set lives one store over, in `icon-drafts` under
 * `<base>-icons`, written by the same save. It is read back through the exact
 * path the icon builder uses, so the two screens can resume each other's work.
 *
 * ─── AND THE PUBLISHED HERO PACKS, FOR THE SAME REASON ──────────────────────
 *
 * A distro's icon pack can be one that already exists rather than one built on
 * this screen, so the workspace needs the list of what is published.
 *
 * AN UNREADABLE BUCKET IS NOT AN EMPTY ONE. `readLiveIndex` never throws, so a
 * refused credential comes back as `unreachable` with an empty `packs`. Handed
 * down as-is that becomes a picker saying nothing is published, which is an
 * invitation to build a second copy of a pack that already exists. The flag
 * carries the difference and the picker says which it is. It does NOT refuse
 * the page, unlike the icon builder: nothing here derives a version number from
 * the index, `publishDistro` computes versions server-side and `guardIndex`
 * refuses an unreadable bucket before anything is written.
 *
 * ─── AND THE SKU CATALOGUE, SO NOBODY TYPES A PERMANENT IDENTIFIER ──────────
 *
 * `skuCatalogue` merges three sources: Play when it answers, the snapshot of
 * the last successful Play read, and the product ids the signed index already
 * uses. That last one works with nothing configured, which matters because Play
 * currently returns 403 and every id was being typed by hand into a field where
 * a typo burns an identifier permanently.
 *
 * It never throws, and it returns `ok: false` only when there is genuinely
 * nothing to offer, so the text-input fallback now means "we know of no ids"
 * rather than "Play is down". Read in the same Promise.all so the slowest of
 * the three sets the page's latency rather than their sum.
 *
 * ─── THE FRAME IS StudioShell NOW ───────────────────────────────────────────
 *
 * Swapped together with the builder's own palette, never separately. The
 * workspace draws itself from the `C` map in theme-builder/console.tsx, which
 * now points at the soft tokens; changing only this line would have put a dark
 * tool on a light page, which is worse than leaving both dark.
 */
export default async function DistroWorkspacePage({
  params,
  searchParams,
}: {
  params: Promise<{ app: string }>;
  searchParams: Promise<{ id?: string }>;
}) {
  const gate = await adminGate();
  if (gate) return gate;

  const { app } = await params;
  if (!APPS.includes(app as AppId)) notFound();
  const appId = app as AppId;

  const { id } = await searchParams;
  // Never let a bad read take the builder down: the point of opening it may be
  // to replace whatever is broken.
  const [initial, live, play] = await Promise.all([
    id ? readDraft(appId, id).catch(() => null) : Promise.resolve(null),
    readLiveIndex(appId),
    skuCatalogue(appId, appMeta(appId)?.pkg ?? null),
  ]);

  // The saved art, when a draft actually opened. Keyed by the DRAFT id, which
  // is what the save wrote under; the icon-pack draft's id is derived the same
  // way the workspace derives it, so the two screens name one store.
  let initialAssets: { file: string; dataUrl: string }[] = [];
  let initialIcons: {
    name: string;
    icons: { pkg: string; file: string; dataUrl: string }[];
  } | null = null;
  const rehydrateNotes: string[] = [];

  if (initial && id) {
    const names = await readDraftAssets(appId, initial.id);
    if (names.length > 0) {
      const got = await rehydrateFilesFromUrls(
        names.map((n) => ({ file: n, url: draftAssetUrl(appId, initial.id, n) })),
      );
      initialAssets = got.files;
      rehydrateNotes.push(...got.notes);
    }

    // Bundled drafts carry a bare id; workspace-born ones end in `-theme`.
    // Both derive their icon pack as `<base>-icons`.
    const iconsId = `${initial.id.replace(/-theme$/, '')}-icons`;
    const iconDraft = await readIconDraft(appId, iconsId);
    if (iconDraft && iconDraft.icons.length > 0) {
      const got = await rehydrateIconsFromUrls(
        iconDraft.icons.map((i) => ({
          pkg: i.pkg,
          file: i.file,
          url: iconDraftAssetUrl(appId, iconDraft.packId, i.file),
        })),
      );
      initialIcons = { name: iconDraft.name, icons: got.icons };
      rehydrateNotes.push(...got.notes);
    }
  }

  // 'hero' only. `brand` is the CC0 glyph layer and is chosen through
  // `icons.brandPack`, which is a different field with a different meaning, and
  // `icon`/`theme` are not hero art at all. Offering them here would let a
  // distro name a brand pack as its hero pack, which resolves to nothing.
  const heroPacks = live.packs
    .filter((p) => p.packType === 'hero')
    .map((p) => ({ packId: p.packId, title: p.title || p.packId, sku: p.sku ?? null }))
    .sort((a, b) => a.title.localeCompare(b.title));

  return (
    <StudioShell app={appId}>
      <DistroWorkspace
        app={appId}
        initial={initial}
        initialAssets={initialAssets}
        initialIcons={initialIcons}
        rehydrateNotes={rehydrateNotes}
        heroPacks={heroPacks}
        heroPacksUnreadable={!!live.unreachable || live.corrupt}
        play={play}
      />
    </StudioShell>
  );
}
