'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { isAppId, type AppId } from '@/lib/core/registry';
import {
  deleteIconDraft,
  stampIconDraftPublished,
  writeIconDraft,
  type DraftAsset,
} from '@/lib/g-launcher/icon-drafts';

/**
 * Save and delete an icon pack draft.
 *
 * A SERVER ACTION rather than a route handler, because the caller is a form in
 * a client component and the payload is a FormData carrying image blobs. The
 * publish path is a route because it is shared with the distro workspace; this
 * one has exactly one caller.
 *
 * ─── A DRAFT IS NOT VALIDATED LIKE A PUBLISH ────────────────────────────────
 *
 * Deliberately. A draft is unfinished work, so it may have icons with no
 * package, a blank sku, a name nobody has written yet. The only rules enforced
 * are the two that would make it unopenable later: a usable pack id, and bare
 * filenames. Everything else is checked when publish is pressed, which is where
 * a refusal is useful rather than obstructive.
 */

export type DraftResult = { ok: true; updatedAt: number } | { ok: false; error: string };

export async function saveIconDraftAction(form: FormData): Promise<DraftResult> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }

  const app = String(form.get('app') ?? '');
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };
  const appId = app as AppId;

  const packId = String(form.get('packId') ?? '').trim();

  // Files and their names arrive as parallel lists, the same shape the publish
  // route uses, so a name can never drift from the blob it belongs to.
  const files = form.getAll('files').filter((f): f is File => f instanceof File);
  const names = form.getAll('paths').map((p) => String(p));
  if (files.length !== names.length) {
    return { ok: false, error: 'Every file needs exactly one name.' };
  }

  const assets: DraftAsset[] = [];
  for (let i = 0; i < files.length; i++) {
    assets.push({
      file: names[i],
      bytes: Buffer.from(await files[i].arrayBuffer()),
      contentType: files[i].type || 'image/png',
    });
  }

  // The package-to-file map, as JSON rather than another parallel list: it is
  // read back as a unit and never iterated alongside the blobs.
  let icons: { pkg: string; file: string }[] = [];
  try {
    const raw = String(form.get('icons') ?? '[]');
    const parsed = JSON.parse(raw) as { pkg?: unknown; file?: unknown }[];
    icons = parsed.map((i) => ({ pkg: String(i.pkg ?? ''), file: String(i.file ?? '') }));
  } catch {
    return { ok: false, error: 'The icon map did not parse.' };
  }

  const result = await writeIconDraft(
    appId,
    {
      packId,
      name: String(form.get('name') ?? ''),
      minAppVersion: Number(form.get('minAppVersion') ?? 6) || 6,
      masked: String(form.get('masked') ?? '') === '1',
      sku: String(form.get('sku') ?? '').trim(),
      plate: String(form.get('plate') ?? '#E95420'),
      radius: Number(form.get('radius') ?? 22) || 22,
      // Not validated against ICON_TREATMENTS here, matching the rest of this
      // action: a draft is unfinished work and the only rules enforced are the
      // two that would make it unopenable. An unknown shape falls back to the
      // default in the builder rather than refusing a save.
      shape: String(form.get('shape') ?? 'roundedSquare'),
      icons,
    },
    assets,
  );

  if (result.ok) {
    revalidatePath(`/apps/${appId}/icons`);
    revalidatePath(`/apps/${appId}/icons/builder`);
  }
  return result;
}

export async function deleteIconDraftAction(app: string, packId: string): Promise<DraftResult> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };

  const result = await deleteIconDraft(app as AppId, packId);
  if (result.ok) {
    revalidatePath(`/apps/${app}/icons`);
    return { ok: true, updatedAt: 0 };
  }
  return result;
}

/**
 * Mark the open draft as published at [version].
 *
 * SEPARATE FROM THE PUBLISH ROUTE ON PURPOSE. `api/publish/pack` is shared with
 * the distro workspace and knows nothing about the icon draft store; teaching
 * it would put a draft-store write inside the one path that has to stay a pure
 * sign-and-upload. So the builder calls this after its publish returns, and a
 * failure here is cosmetic: the banner stays stale until the next save.
 */
export async function markIconDraftPublishedAction(
  app: string,
  packId: string,
  version: number,
): Promise<{ ok: boolean }> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false };
    throw e;
  }
  if (!isAppId(app) || !packId) return { ok: false };

  const res = await stampIconDraftPublished(app as AppId, packId, version);
  if (res.ok) {
    revalidatePath(`/apps/${app}/icons`);
    revalidatePath(`/apps/${app}/icons/builder`);
  }
  return res;
}
