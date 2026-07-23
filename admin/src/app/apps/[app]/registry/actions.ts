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

export async function saveRegistry(
  app: string,
  apps: RegistryApp[],
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireAdmin();
  if (!APPS.includes(app as AppId)) return { ok: false, error: `Unknown app '${app}'` };

  const problems = validateRegistry(apps);
  if (problems.length) return { ok: false, error: problems.join('; ') };

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
