'use server';

import { getObject, putObject } from '@/lib/r2';
import { requireAdmin } from '@/lib/admin';
import { APPS, type AppId } from '@/lib/catalogue';
import { validateRegistry, type RegistryApp } from '@/lib/app-registry';

const key = (app: AppId) => `${app}/admin/registry.json`;

export async function loadRegistry(app: string): Promise<RegistryApp[]> {
  await requireAdmin();
  if (!APPS.includes(app as AppId)) return [];
  const bytes = await getObject(key(app as AppId));
  if (!bytes) return [];
  try {
    const parsed = JSON.parse(bytes.toString('utf8'));
    return Array.isArray(parsed) ? (parsed as RegistryApp[]) : [];
  } catch {
    // Present but unparseable: do not silently return empty and let the next
    // save wipe it. Surface it as an error the editor can show.
    throw new Error('registry.json did not parse; refusing to load over a corrupt file');
  }
}

/**
 * The registry, plus whether the bucket could be read at all.
 *
 * ─── WHY THE PAGE MUST NOT JUST CATCH AND RENDER [] ─────────────────────────
 *
 * This is the one reader in the panel where degrading quietly is DESTRUCTIVE
 * rather than merely misleading. The editor loads the whole array, the user
 * edits it in the browser, and [saveRegistry] writes the whole array back. So a
 * read that fails to an empty list puts an empty editor in front of someone,
 * and the moment they add one app and save, every other app in the registry is
 * gone. Nothing warned them, because from the browser it looked like a registry
 * that had not been filled in yet.
 *
 * `unreachable` is what lets the page draw a banner AND disable saving, which
 * are both required. The banner alone would be an explanation nobody reads
 * before clicking the button that destroys the file.
 *
 * [loadRegistry] is deliberately left throwing. An uncaught throw kills the
 * screen, which is ugly, but a dead screen cannot overwrite anything. Until the
 * page is switched over, that is the safer of the two failures.
 */
export async function loadRegistrySafe(
  app: string,
): Promise<{ apps: RegistryApp[]; unreachable: string | null }> {
  try {
    return { apps: await loadRegistry(app), unreachable: null };
  } catch (e) {
    return {
      apps: [],
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
}

export async function saveRegistry(
  app: string,
  apps: RegistryApp[],
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireAdmin();
  if (!APPS.includes(app as AppId)) return { ok: false, error: `Unknown app '${app}'` };

  const problems = validateRegistry(apps);
  if (problems.length) return { ok: false, error: problems.join('; ') };

  // ── READ BEFORE WRITE, AND REFUSE IF THE READ FAILS ──────────────────────
  //
  // A whole-file write with no read is a wipe waiting for one bad minute. The
  // client sends the entire array, so if the editor was populated from a failed
  // load, this call is "replace the registry with whatever is on screen", and
  // what is on screen is nothing.
  //
  // The read is not used for anything except proving the bucket answers. That
  // is the point: the failure mode is not a merge conflict, it is writing
  // confidently on top of a file we could not open.
  //
  // Costs one GET per save, on an action a human performs a few times a week.
  try {
    await getObject(key(app as AppId));
  } catch (e) {
    return {
      ok: false,
      error:
        `The bucket could not be read (${(e as Error).message}), so this save is refused. ` +
        'Writing the editor\u2019s contents now would replace the live registry with whatever ' +
        'loaded, which after a failed read is nothing.',
    };
  }

  // Sorted by package so the file diffs cleanly between saves.
  const sorted = [...apps].sort((a, b) => a.pkg.localeCompare(b.pkg));
  try {
    await putObject(
      key(app as AppId),
      Buffer.from(JSON.stringify(sorted, null, 2) + '\n', 'utf8'),
      'application/json',
    );
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
