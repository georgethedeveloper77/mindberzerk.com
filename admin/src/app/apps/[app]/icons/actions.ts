'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { isAppId } from '@/lib/core/registry';
import { BUNDLED_PACK_IDS, unpublishPacks } from '@/lib/core/unpublish-core';
import { deleteIconDraft, readIconDraft } from '@/lib/g-launcher/icon-drafts';
import { readAllDrafts } from '@/lib/g-launcher/themes';

/**
 * DELETE AN ICON PACK: out of the signed index, then off the draft store.
 *
 * The list screen has said "to pull this from every device, use Unpublish on
 * CDN objects" since it was written, and that was the right call while
 * unpublish was a raw index operation shown beside a manifest. It is the wrong
 * call now: an icon pack is a THING AN AUTHOR MADE, and the screen where you
 * make it is the screen where you should be able to unmake it. What the CDN
 * screen still owns is pulling an arbitrary pack by id; this owns deleting one
 * you can see, with the checks that only make sense here.
 *
 * ─── THE GUARD THAT IS SPECIFIC TO ICON PACKS ───────────────────────────────
 *
 * A theme names its icons in `theme.json` (`icons.heroPack` / `icons.brandPack`),
 * and NOTHING IN THE INDEX RECORDS THAT LINK. So deleting a pack a live distro
 * still names does not fail anywhere: the pack simply stops resolving on device
 * and every app in that distro falls through to the generator, silently, which
 * is this project's most expensive failure shape. The list page already builds
 * the reverse lookup for its "used by" row; this rebuilds it server-side rather
 * than trusting a value that travelled through the client, and refuses by name.
 *
 * Only DRAFTS are checked, which is the honest limit and the same one
 * `deleteDistroAction` documents: a theme published out-of-band has no draft to
 * read. The list page's own "used by" column reads published theme.json too, so
 * the number shown there is the better one to trust before pressing this.
 *
 * ─── EVERYTHING ELSE IS DELIBERATELY THE DISTRO DELETE'S BEHAVIOUR ──────────
 *
 * Bundled ids refused (pulling `yaru` strands every device on the APK seed).
 * `removeEmptiedEntitlements: false`, so a bundle left granting nothing refuses
 * instead of quietly emptying: that is a decision for the Bundles screen. Index
 * first and draft last, so a failed unpublish leaves the row still editable.
 * Bucket objects stay, for the in-flight downloads the orphan sweep exists to
 * clean up later. Play keeps the product and every buyer keeps the purchase,
 * because Play never releases a product id.
 *
 * Shelf grants need no special handling: `unpublishPacks` already trims the
 * pulled id out of every entitlement's grants, which is exactly what undoes a
 * phase-3 shelf grant.
 */
export async function deleteIconPackAction(
  app: string,
  packId: string,
): Promise<
  | { ok: true; unpublished: boolean; draftRemoved: boolean; removedSkus: string[] }
  | { ok: false; error: string }
> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }

  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };
  const appId = app as AppId;
  if (!packId) return { ok: false, error: 'Missing pack id' };

  if (BUNDLED_PACK_IDS.has(packId)) {
    return {
      ok: false,
      error: `${packId} ships inside the app and cannot be deleted. Publish a higher version instead.`,
    };
  }

  const live = await readLiveIndex(appId);
  if (live.unreachable) {
    return { ok: false, error: `The bucket could not be read (${live.unreachable}), so nothing was deleted.` };
  }
  if (live.corrupt) {
    return { ok: false, error: 'index.json exists but does not parse. Refusing to touch it.' };
  }

  const published = live.packs.some((p) => p.packId === packId);
  const draft = await readIconDraft(appId, packId);
  if (!published && !draft) {
    return { ok: false, error: `${packId} is neither published nor a draft.` };
  }

  // THE REFERENCE CHECK, and it runs before anything is written.
  if (published) {
    let themes;
    try {
      themes = await readAllDrafts(appId);
    } catch (e) {
      return { ok: false, error: (e as Error).message };
    }
    const users = themes
      .filter(
        (d) => d.spec.icons?.heroPack === packId || d.spec.icons?.brandPack === packId,
      )
      .map((d) => d.id);
    if (users.length > 0) {
      return {
        ok: false,
        error:
          `${users.join(', ')} still names ${packId} in theme.json. Deleting it would leave ` +
          'that distro resolving no icons at all, with nothing reported on the device. ' +
          'Point the distro at another pack first.',
      };
    }
  }

  let removedSkus: string[] = [];
  if (published) {
    const out = await unpublishPacks(appId, [packId], { removeEmptiedEntitlements: false });
    if (!out.ok) return { ok: false, error: out.error };
    removedSkus = out.removedSkus;
  }

  let draftRemoved = false;
  if (draft) {
    const gone = await deleteIconDraft(appId, packId);
    if (!gone.ok) {
      return {
        ok: false,
        error: published
          ? `Unpublished, but the draft could not be removed: ${gone.error}`
          : gone.error,
      };
    }
    draftRemoved = true;
  }

  revalidatePath(`/apps/${appId}/icons`);
  revalidatePath(`/apps/${appId}/packs`);
  return { ok: true, unpublished: published, draftRemoved, removedSkus };
}

/**
 * Delete several icon packs, one at a time, reporting each.
 *
 * SEQUENTIAL ON PURPOSE. Every delete re-signs the index, so running them in
 * parallel is several writers racing one document: last write wins and the
 * losers vanish without an error. `for await` is the correct shape here even
 * though it looks like the slow one.
 *
 * PER-ITEM RESULTS, for the same reason the single delete refuses loudly. A
 * batch where two ids are still named by a distro and seven are free to go is
 * the ordinary case, and the only honest report of it is nine lines.
 */
export async function bulkDeleteIconPacksAction(
  app: string,
  packIds: string[],
): Promise<{ id: string; ok: boolean; detail: string }[]> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return packIds.map((id) => ({ id, ok: false, detail: 'Not authorised' }));
    }
    throw e;
  }

  const out: { id: string; ok: boolean; detail: string }[] = [];
  for (const packId of packIds) {
    const res = await deleteIconPackAction(app, packId);
    out.push(
      res.ok
        ? {
            id: packId,
            ok: true,
            detail: res.unpublished
              ? 'pulled from the catalogue'
              : 'draft removed, nothing was live',
          }
        : { id: packId, ok: false, detail: res.error },
    );
  }
  return out;
}
