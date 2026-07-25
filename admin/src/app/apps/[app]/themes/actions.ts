'use server';

import { readDraft, writeDraft } from '@/lib/themes';
import { setListed } from '@/lib/listing';
import type { AppId } from '@/lib/catalogue';
import type { ThemeDraft } from '@/lib/theme-spec';
// The shared admin gate. Every server action re-checks it: proxy.ts is not a
// security boundary. If your gate lives elsewhere or is named differently, this
// is the one import to adjust.
import { requireAdmin } from '@/lib/admin';

/** Turn a pack's storefront listing on or off. Bundled packs are always on and
 *  are disabled in the UI, so this only ever runs for CDN packs and drafts. */
export async function setPackListed(
  app: string,
  packId: string,
  listed: boolean,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireAdmin();
  try {
    await setListed(app as AppId, packId, listed);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export async function loadThemeDraft(app: AppId, id: string): Promise<ThemeDraft | null> {
  await requireAdmin();
  return readDraft(app, id);
}

export async function saveThemeDraft(
  app: string,
  draft: ThemeDraft,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireAdmin();
  try {
    await writeDraft(app as AppId, draft);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
