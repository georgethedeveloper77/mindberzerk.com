'use server';

import { readDraft, writeDraft } from '@/lib/themes';
import type { AppId } from '@/lib/catalogue';
import type { ThemeDraft } from '@/lib/theme-spec';
// The shared admin gate. Every server action re-checks it: proxy.ts is not a
// security boundary. If your gate lives elsewhere or is named differently, this
// is the one import to adjust.
import { requireAdmin } from '@/lib/admin';

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
