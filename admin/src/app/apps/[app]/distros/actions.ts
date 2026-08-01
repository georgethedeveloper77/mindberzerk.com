'use server';

import { requireAdmin } from '@/lib/core/admin';
import { APPS, readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { publishDistro, type DistroPublishResult } from '@/lib/g-launcher/distro-publish';
import type { ThemeDraft, ThemeSpecJson } from '@/lib/g-launcher/theme-spec';
import { deleteDraft, distroIconPackIds, readAllDrafts } from '@/lib/g-launcher/themes';
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
  } | null = null;
  if (meta.icons && meta.icons.order.length > 0) {
    const entries: { pkg: string; file: string; bytes: Buffer }[] = [];
    for (const o of meta.icons.order) {
      const bytes = await bytesFor(formData, `icon:${o.file}`);
      if (!bytes) return { ok: false, error: `Missing icon for ${o.pkg}` };
      entries.push({ pkg: o.pkg, file: o.file, bytes });
    }
    iconsResolved = {
      packId: meta.icons.packId,
      minAppVersion: meta.icons.minAppVersion,
      sku: meta.icons.sku,
      name: meta.icons.name,
      entries,
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
