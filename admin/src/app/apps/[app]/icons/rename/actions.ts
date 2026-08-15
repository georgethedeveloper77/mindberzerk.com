'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { isAppId, type AppId } from '@/lib/core/registry';
import {
  executePackRename,
  planPackRename,
  type RenameOutcome,
  type RenamePlan,
} from '@/lib/g-launcher/pack-rename';

/**
 * The two halves of a pack-id migration, as server actions.
 *
 * SEPARATE ACTIONS RATHER THAN ONE WITH A `dryRun` FLAG, because the flag would
 * be a boolean between a report and an irreversible publish, and a boolean in
 * that position is a thing that eventually gets passed wrong. Two names cannot
 * be confused.
 */

export async function planRenameAction(
  app: string,
  from: string,
  to: string,
): Promise<{ ok: true; plan: RenamePlan } | { ok: false; error: string }> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };

  const f = from.trim();
  const t = to.trim();
  if (!f || !t) return { ok: false, error: 'Both ids are needed.' };

  const plan = await planPackRename(app as AppId, f, t);
  if ('error' in plan) return { ok: false, error: plan.error };
  return { ok: true, plan };
}

export async function runRenameAction(
  app: string,
  from: string,
  to: string,
): Promise<{ ok: true; outcome: RenameOutcome } | { ok: false; error: string }> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };

  const f = from.trim();
  const t = to.trim();
  if (!f || !t) return { ok: false, error: 'Both ids are needed.' };

  const outcome = await executePackRename(app as AppId, f, t);

  revalidatePath(`/apps/${app}/icons`);
  revalidatePath(`/apps/${app}/icons/builder`);
  revalidatePath(`/apps/${app}/packs`);
  revalidatePath(`/apps/${app}/distros`);

  return { ok: true, outcome };
}
