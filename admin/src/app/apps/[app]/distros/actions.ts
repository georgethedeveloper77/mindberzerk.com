'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { APPS, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { publishDistro, type DistroPublishResult } from '@/lib/g-launcher/distro-publish';
import type { ThemeDraft, ThemeSpecJson } from '@/lib/g-launcher/theme-spec';
import {
  copyDraftAssets,
  writeDraftAssets,
  type DraftAsset,
} from '@/lib/g-launcher/distro-draft-assets';
import {
  writeIconDraft,
  type DraftAsset as IconDraftAsset,
} from '@/lib/g-launcher/icon-drafts';
import { deleteDraft, distroIconPackIds, readAllDrafts, writeDraft } from '@/lib/g-launcher/themes';
import { BUNDLED_PACK_IDS, unpublishPacks } from '@/lib/core/unpublish-core';

interface DistroMeta {
  app: string;
  theme: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    title: string;
    summary: string;
    spec: ThemeSpecJson;
    assets: { file: string }[];
  };
  icons: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    order: { pkg: string; file: string }[];
    /** When true, an `icon:preview.png` part rides along as a payload file. */
    preview?: boolean;
  } | null;
  distroSku: string | null;
  distroTitle: string;
  distroSummary: string;
}

async function bytesFor(formData: FormData, key: string): Promise<Buffer | null> {
  const part = formData.get(key);
  if (!(part instanceof File)) return null;
  return Buffer.from(await part.arrayBuffer());
}

export type DistroDraftResult = { ok: true; assets: number } | { ok: false; error: string };

export async function publishDistroAction(formData: FormData): Promise<DistroPublishResult> {
  await requireAdmin();

  const metaRaw = formData.get('meta');
  if (typeof metaRaw !== 'string') return { ok: false, error: 'Missing distro metadata' };
  let meta: DistroMeta;
  try {
    meta = JSON.parse(metaRaw) as DistroMeta;
  } catch {
    return { ok: false, error: 'Distro metadata was not valid JSON' };
  }
  if (!APPS.includes(meta.app as AppId)) return { ok: false, error: `Unknown app '${meta.app}'` };

  const themeAssets: { file: string; bytes: Buffer }[] = [];
  for (const a of meta.theme.assets ?? []) {
    const bytes = await bytesFor(formData, `asset:${a.file}`);
    if (!bytes) return { ok: false, error: `Missing asset ${a.file}` };
    themeAssets.push({ file: a.file, bytes });
  }

  let iconsResolved: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    entries: { pkg: string; file: string; bytes: Buffer }[];
    /** Composited by the workspace and shipped as a payload file. Null = none. */
    preview: Buffer | null;
  } | null = null;
  if (meta.icons && meta.icons.order.length > 0) {
    const entries: { pkg: string; file: string; bytes: Buffer }[] = [];
    for (const o of meta.icons.order) {
      const bytes = await bytesFor(formData, `icon:${o.file}`);
      if (!bytes) return { ok: false, error: `Missing icon for ${o.pkg}` };
      entries.push({ pkg: o.pkg, file: o.file, bytes });
    }
    // Optional, and its absence is not an error: packs published before
    // previews existed, and a compositor that returned null, both just mean
    // the device falls back to the schematic card.
    const preview = meta.icons.preview ? await bytesFor(formData, 'icon:preview.png') : null;

    iconsResolved = {
      packId: meta.icons.packId,
      minAppVersion: meta.icons.minAppVersion,
      sku: meta.icons.sku,
      name: meta.icons.name,
      entries,
      preview,
    };
  }

  return publishDistro({
    app: meta.app as AppId,
    theme: {
      packId: meta.theme.packId,
      minAppVersion: meta.theme.minAppVersion,
      sku: meta.theme.sku,
      title: meta.theme.title,
      summary: meta.theme.summary,
      spec: meta.theme.spec,
      assets: themeAssets,
    },
    icons: iconsResolved,
    distroSku: meta.distroSku,
    distroTitle: meta.distroTitle,
    distroSummary: meta.distroSummary,
  });
}

/**
 * Delete a distro: unpublish what it put in the index, then remove its draft.
 *
 * NOT exported as a type union from here: a 'use server' module may only
 * export async functions, so callers type the result off the function itself.
 *
 * ─── WHAT "DELETE" MEANS PER STATE ──────────────────────────────────────────
 *
 * Draft-only: the draft is removed from theme-drafts.json and nothing else
 * happened, because nothing else exists. Published: the theme pack and this
 * distro's own icon packs come out of the signed index in ONE write, the
 * distro's entitlement goes with them, and then the draft is removed. Bundled:
 * refused, the packs ship inside the APK and the unpublish layer refuses their
 * ids for the same reason.
 *
 * Bucket objects are deliberately left in place, see unpublish-core. A paid
 * distro's Play product survives too: Play never releases a product ID, and
 * everyone who bought it keeps the purchase. The UI says both before confirm.
 *
 * ─── AN ICON PACK ANOTHER DISTRO POINTS AT IS KEPT ──────────────────────────
 *
 * The workspace's "use published" source lets distro B name distro A's icon
 * pack in its own theme.json. Deleting A must not pull a pack B still ships,
 * so any candidate named by another draft's `icons.heroPack` is kept in the
 * index and reported rather than pulled. Only drafts can be checked, which is
 * the honest limit: a theme published out-of-band with no draft is invisible
 * here, and the packs screen still shows the kept pack for a manual pull.
 *
 * ─── ORDER: INDEX FIRST, DRAFT LAST ─────────────────────────────────────────
 *
 * If the unpublish fails the draft survives, so the card is still there and
 * still editable. The reverse order could leave a live paid pack with no draft
 * to open, which is exactly the half-deleted state this action exists to avoid.
 */
/**
 * SAVE A DISTRO DRAFT.
 *
 * Three stores, one press, and they are deliberately separate:
 *
 *   the SPEC   -> `writeDraft` in themes.ts, which validates and merges
 *   the ART    -> `writeDraftAssets`, because a ThemeDraft references wallpapers
 *                 by filename and has never carried the bytes behind them
 *   the ICONS  -> `writeIconDraft`, because the inline icon set publishes as its
 *                 own pack (`<base>-icons`) and the icon builder must be able to
 *                 resume it too; two stores for one pack would drift
 *
 * Until this existed, a distro could be edited and only published. Closing the
 * tab discarded every uploaded wallpaper and logo, which on a distro is most of
 * the work. The icon assignments were a second copy of the same bug: the save
 * claimed icon art "is saved with the icon pack" and nothing ever saved it.
 *
 * ─── ASSETS FIRST, SPEC LAST ────────────────────────────────────────────────
 *
 * If the spec saved first and the asset write then failed, the draft would name
 * five wallpapers that are not stored, and reopening it would look exactly like
 * the bug this is fixing. The other order fails safe: art with no draft is
 * unreferenced bytes under `admin/`, which nothing serves and nothing sweeps.
 * The icon draft sits between them for the same reason: it is art too.
 *
 * ─── A DRAFT IS STILL VALIDATED, AND THAT IS NOT A MISTAKE ──────────────────
 *
 * `writeDraft` refuses an invalid spec, and this does not work around it. The
 * rules it enforces are structural (an id, a title, a name, hex colours, a
 * shell that exists), and the workspace holds a valid spec from the moment it
 * mounts because every field has a default. What is genuinely unfinished on a
 * half-built distro is the ART, and that is the half this action adds.
 */
export async function saveDistroDraftAction(form: FormData): Promise<DistroDraftResult> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }

  const app = String(form.get('app') ?? '');
  if (!APPS.includes(app as AppId)) return { ok: false, error: `Unknown app '${app}'` };
  const appId = app as AppId;

  let draft: ThemeDraft;
  try {
    draft = JSON.parse(String(form.get('draft') ?? '')) as ThemeDraft;
  } catch {
    return { ok: false, error: 'The draft did not parse.' };
  }
  if (!draft?.id) return { ok: false, error: 'A distro id is required before a draft can be saved.' };

  const files = form.getAll('files').filter((f): f is File => f instanceof File);
  const names = form.getAll('paths').map((p) => String(p));
  if (files.length !== names.length) {
    return { ok: false, error: 'Every file needs exactly one name.' };
  }

  const assets: DraftAsset[] = [];
  for (let i = 0; i < files.length; i++) {
    assets.push({
      name: names[i],
      bytes: Buffer.from(await files[i].arrayBuffer()),
      contentType: files[i].type || 'application/octet-stream',
    });
  }

  const stored = await writeDraftAssets(appId, draft.id, assets);
  if (!stored.ok) return { ok: false, error: stored.error };

  // The inline icon set, when the workspace sent one. Optional on purpose: a
  // distro pointed at a published pack, or with no icons yet, sends nothing
  // and no icon draft is touched.
  const iconRaw = form.get('iconDraft');
  if (typeof iconRaw === 'string' && iconRaw) {
    let iconMeta: {
      packId: string;
      name: string;
      minAppVersion: number;
      masked: boolean;
      sku: string;
      plate: string;
      radius: number;
      shape: string;
      icons: { pkg: string; file: string }[];
    };
    try {
      iconMeta = JSON.parse(iconRaw) as typeof iconMeta;
    } catch {
      return { ok: false, error: 'The icon draft did not parse.' };
    }

    const iconFiles = form.getAll('iconFiles').filter((f): f is File => f instanceof File);
    const iconNames = form.getAll('iconPaths').map((p) => String(p));
    if (iconFiles.length !== iconNames.length) {
      return { ok: false, error: 'Every icon file needs exactly one name.' };
    }

    const iconAssets: IconDraftAsset[] = [];
    for (let i = 0; i < iconFiles.length; i++) {
      iconAssets.push({
        file: iconNames[i],
        bytes: Buffer.from(await iconFiles[i].arrayBuffer()),
        contentType: iconFiles[i].type || 'image/png',
      });
    }

    const iconStored = await writeIconDraft(appId, iconMeta, iconAssets);
    if (!iconStored.ok) return { ok: false, error: iconStored.error };
    revalidatePath(`/apps/${appId}/icons`);
    revalidatePath(`/apps/${appId}/icons/builder`);
  }

  try {
    await writeDraft(appId, draft);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  revalidatePath(`/apps/${appId}/distros`);
  revalidatePath(`/apps/${appId}/distros/builder`);
  return { ok: true, assets: stored.count };
}

export async function deleteDistroAction(
  app: string,
  id: string,
): Promise<
  | { ok: true; pulled: string[]; kept: string[]; removedSkus: string[]; unpublished: boolean }
  | { ok: false; error: string }
> {
  await requireAdmin();

  if (!APPS.includes(app as AppId)) return { ok: false, error: `Unknown app '${app}'` };
  const appId = app as AppId;
  if (!id) return { ok: false, error: 'Missing distro id' };

  const live = await readLiveIndex(appId);
  if (live.unreachable) {
    return {
      ok: false,
      error: `The bucket could not be read (${live.unreachable}), so nothing was deleted.`,
    };
  }
  if (live.corrupt) {
    return { ok: false, error: 'index.json exists but does not parse. Refusing to touch it.' };
  }

  // The drafts, read through the throwing path on purpose: this function is a
  // writer, and a soft-failed read here would make the reference check below
  // vacuous and the deleteDraft at the end a wipe hazard.
  let drafts: ThemeDraft[];
  try {
    drafts = await readAllDrafts(appId);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
  const draft = drafts.find((d) => d.id === id) ?? null;

  // The button is hidden for bundled cards; this is the server saying the same
  // thing to anything that is not the button.
  if (draft?.bundled || BUNDLED_PACK_IDS.has(id)) {
    return { ok: false, error: `${id} is bundled into the app and cannot be deleted.` };
  }

  const published = live.packs.some((p) => p.packId === id);
  if (!published && !draft) {
    return { ok: false, error: `${id} has no draft and is not in the catalogue.` };
  }

  const pulled: string[] = [];
  const kept: string[] = [];
  let removedSkus: string[] = [];

  if (published) {
    const { present } = distroIconPackIds(live, id);
    const targets = [id];
    for (const iconId of present) {
      const referencedBy = drafts.find(
        (d) => d.id !== id && d.spec.icons?.heroPack === iconId,
      );
      if (referencedBy) kept.push(`${iconId} (used by ${referencedBy.id})`);
      else targets.push(iconId);
    }

    const out = await unpublishPacks(appId, targets, { removeEmptiedEntitlements: true });
    if (!out.ok) return { ok: false, error: out.error };
    pulled.push(...out.pulled.map((p) => p.packId));
    removedSkus = out.removedSkus;
  }

  if (draft) {
    try {
      await deleteDraft(appId, id);
    } catch (e) {
      return {
        ok: false,
        error: `Unpublished, but the draft could not be removed: ${(e as Error).message}`,
      };
    }
  }

  return { ok: true, pulled, kept, removedSkus, unpublished: published };
}

/**
 * Delete several distros, one at a time, reporting each.
 *
 * Sequential and per-item, for the reasons `bulkDeleteIconPacksAction`
 * documents: each delete re-signs the index, and a batch where some ids are
 * bundled and others are not is the ordinary case rather than the error case.
 */
export async function bulkDeleteDistrosAction(
  app: string,
  ids: string[],
): Promise<{ id: string; ok: boolean; detail: string }[]> {
  await requireAdmin();

  const out: { id: string; ok: boolean; detail: string }[] = [];
  for (const id of ids) {
    const res = await deleteDistroAction(app, id);
    out.push(
      res.ok
        ? {
            id,
            ok: true,
            detail: res.unpublished
              ? `pulled ${res.pulled.join(', ') || 'nothing'}${res.kept.length ? `, kept ${res.kept.join(', ')}` : ''}`
              : 'draft removed, nothing was live',
          }
        : { id, ok: false, detail: res.error },
    );
  }
  return out;
}

/**
 * DUPLICATE A DISTRO into a new draft.
 *
 * The reason this exists rather than "open it and change the id": the id is
 * immutable in the workspace, deliberately, because editing it forks rather
 * than renames. Duplicate is the honest version of that same intention, and
 * doing it as one server operation means the copy is complete before it is
 * visible instead of being assembled by hand in a form.
 *
 * WHAT IS COPIED: the spec, retargeted at the new id, and the draft's art.
 * WHAT IS NOT: anything about being live. The copy is a draft with no
 * published version, no listing flag and NO SKU. A product id may only ever
 * belong to one pack, so carrying it over would produce two drafts claiming
 * one Play product and a publish that quietly reassigns it.
 *
 * NEVER OVERWRITES. An id that already has a draft or a published pack is
 * refused rather than merged into, which is the whole class of bug the id lock
 * exists to prevent.
 */
export async function duplicateDistroAction(
  app: string,
  fromId: string,
  toId: string,
): Promise<{ ok: true; id: string; assets: number } | { ok: false; error: string }> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }

  if (!APPS.includes(app as AppId)) return { ok: false, error: `Unknown app '${app}'` };
  const appId = app as AppId;

  const id = toId.trim().toLowerCase();
  if (!/^[a-z][a-z0-9-]{1,60}$/.test(id)) {
    return { ok: false, error: 'A new distro id is required. Lowercase letters, digits, hyphens.' };
  }

  let drafts: ThemeDraft[];
  try {
    drafts = await readAllDrafts(appId);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  const source = drafts.find((d) => d.id === fromId);
  if (!source) {
    return {
      ok: false,
      error: `${fromId} has no draft to copy. Open it in the workspace and save a draft first.`,
    };
  }
  if (drafts.some((d) => d.id === id)) {
    return { ok: false, error: `${id} already exists as a draft.` };
  }

  const live = await readLiveIndex(appId);
  if (live.unreachable) {
    return { ok: false, error: `The catalogue could not be read (${live.unreachable}), so nothing was copied.` };
  }
  if (live.packs.some((p) => p.packId === id || p.packId === `${id}-theme`)) {
    return { ok: false, error: `${id} is already published. Pick another id.` };
  }

  const copy: ThemeDraft = {
    ...source,
    id,
    // The spec's own id must equal the draft id or the pack inherits the
    // original's prefs bucket on device, which is the exact failure that made
    // a published Ubuntu render with no wallpaper.
    spec: { ...source.spec, id, name: `${source.spec.name} copy` },
    title: `${source.title} copy`,
    // NOT bundled: only the three ids in the APK are, and a copy is not one.
    bundled: false,
    sku: null,
    publishedVersion: null,
  } as ThemeDraft;

  try {
    await writeDraft(appId, copy);
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }

  // Art last: a draft with no art is editable, art with no draft is orphaned
  // bytes under admin/ that nothing serves.
  const assets = await copyDraftAssets(appId, fromId, id);

  revalidatePath(`/apps/${appId}/distros`);
  return { ok: true, id, assets };
}
