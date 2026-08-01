import 'server-only';

import { getObject, putObject } from '@/lib/core/r2';
import { REGISTRY, type AppMeta, type AppState } from '@/lib/core/registry';

/**
 * THE STUDIO'S APP LIST, AS DATA.
 *
 * ## Why this exists at all
 *
 * `lib/core/registry.ts` holds `REGISTRY` as a hardcoded array, and four things
 * read it: the dashboard's counts, the public catalogue, the featured order in
 * Site content, and the legal documents keyed by app id. Adding an app meant
 * editing a source file and deploying, which is fine for two apps and absurd
 * for fifteen.
 *
 * So the list becomes an object on the bucket, `site/registry.json`, with the
 * hardcoded array as its SEED rather than its replacement.
 *
 * ## The hardcoded array does not go away, and that is deliberate
 *
 * Two of its rows, `g-launcher` and `g-recovery`, are also route segments in
 * the closed `APPS` tuple, and `isAppId` guards every per-app page against
 * them. A managed app that existed only in a JSON file could be deleted from a
 * form and take its own console section with it. So:
 *
 *   - MANAGED rows are anchored. This module refuses to delete one, and refuses
 *     to change its id. Everything else about them is editable.
 *   - Unmanaged rows are free. Add Tryst, add a game, delete one that was never
 *     shipped, all without a deploy.
 *   - When the bucket cannot be read, the seed IS the answer, not a fallback
 *     that loses data: an unpublished registry and the compiled one agree.
 *
 * ## Same track as site content
 *
 * Unsigned, whole-file writes, no index, no `generatedAt`. A phone never reads
 * this. Last write wins, which is the correct concurrency story for one admin.
 */

const KEY = 'site/registry.json';

/** The compiled ids that own a route segment and cannot be removed here. */
const ANCHORED = new Set(REGISTRY.filter((a) => a.managed).map((a) => a.id));

export interface RegistryState {
  apps: AppMeta[];
  exists: boolean;
  corrupt: boolean;
  /** Distinct from `exists: false`: one means nothing published, the other
   *  means we do not know, and only the first is safe to write over. */
  unreachable?: string;
}

const STATES: AppState[] = ['live', 'build', 'planned', 'external'];

/** Coerce one stored row, falling back to the compiled row where one exists. */
function row(input: Record<string, unknown>): AppMeta | null {
  const id = String(input.id ?? '').trim();
  if (!id) return null;
  const compiled = REGISTRY.find((a) => a.id === id);
  const state = String(input.state ?? '') as AppState;

  return {
    id,
    name: String(input.name ?? compiled?.name ?? id),
    pkg: input.pkg ? String(input.pkg) : null,
    mark: String(input.mark ?? compiled?.mark ?? id.slice(0, 1).toUpperCase()).slice(0, 2),
    tint: /^#[0-9a-f]{6}$/i.test(String(input.tint ?? '')) ? String(input.tint) : compiled?.tint ?? '#6d4ae8',
    // MANAGED IS NEVER TAKEN FROM THE DOCUMENT. It means "this panel has a
    // route and a bucket prefix for it", which is a fact about the code, not a
    // field someone can grant themselves by editing JSON.
    managed: !!compiled?.managed,
    state: STATES.includes(state) ? state : compiled?.state ?? 'planned',
    blurb: String(input.blurb ?? compiled?.blurb ?? ''),
    playConsoleAppId: input.playConsoleAppId ? String(input.playConsoleAppId) : undefined,
    appStoreAppId: input.appStoreAppId ? String(input.appStoreAppId) : undefined,
  };
}

export async function readRegistry(): Promise<RegistryState> {
  let bytes: Buffer | null;
  try {
    bytes = await getObject(KEY);
  } catch (e) {
    return {
      apps: REGISTRY,
      exists: false,
      corrupt: false,
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
  if (!bytes) return { apps: REGISTRY, exists: false, corrupt: false };

  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as { apps?: unknown };
    if (!Array.isArray(parsed.apps)) return { apps: REGISTRY, exists: true, corrupt: true };

    const apps = (parsed.apps as Record<string, unknown>[])
      .map(row)
      .filter((a): a is AppMeta => a !== null);

    // An anchored app missing from the document is re-added rather than lost.
    // The alternative is a console section whose app vanished from every list
    // that names it, which looks like a bug in five places at once.
    for (const compiled of REGISTRY) {
      if (compiled.managed && !apps.some((a) => a.id === compiled.id)) apps.push(compiled);
    }

    return { apps, exists: true, corrupt: false };
  } catch {
    return { apps: REGISTRY, exists: true, corrupt: true };
  }
}

const ID_RE = /^[a-z][a-z0-9-]{1,40}$/;

/** Problems for the whole list. Empty means publishable. */
export function validateRegistry(apps: AppMeta[]): string[] {
  const problems: string[] = [];
  const seen = new Set<string>();

  for (const a of apps) {
    const label = a.name.trim() || a.id;
    if (!ID_RE.test(a.id)) problems.push(`"${a.id}" is not a usable id. Lowercase, digits, hyphens.`);
    if (seen.has(a.id)) problems.push(`Two apps share the id "${a.id}".`);
    seen.add(a.id);

    if (!a.name.trim()) problems.push(`The app at ${a.id} has no name.`);
    if (!a.blurb.trim()) problems.push(`${label} has no blurb, and the site renders it verbatim.`);
    if (a.pkg && !/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/i.test(a.pkg)) {
      problems.push(`${label} has a package that is not a valid Android application id.`);
    }
    if (a.state === 'live' && !a.pkg && !a.appStoreAppId) {
      problems.push(`${label} is live but has neither a package nor an App Store id, so it links nowhere.`);
    }
    for (const [field, value] of [
      ['Play Console id', a.playConsoleAppId],
      ['App Store id', a.appStoreAppId],
    ] as const) {
      if (value && !/^[0-9]{5,20}$/.test(value)) {
        problems.push(`${label} has a ${field} that is not numeric.`);
      }
    }
  }

  for (const id of ANCHORED) {
    if (!apps.some((a) => a.id === id)) {
      problems.push(`${id} is administered by this panel and cannot be removed from the registry.`);
    }
  }

  return problems;
}

export async function writeRegistry(
  apps: AppMeta[],
): Promise<{ ok: true; updatedAt: number; count: number } | { ok: false; error: string }> {
  const problems = validateRegistry(apps);
  if (problems.length > 0) return { ok: false, error: problems.join(' ') };

  const updatedAt = Math.floor(Date.now() / 1000);
  const doc = {
    updatedAt,
    apps: apps.map((a) => ({
      id: a.id,
      name: a.name,
      pkg: a.pkg,
      mark: a.mark,
      tint: a.tint,
      state: a.state,
      blurb: a.blurb,
      ...(a.playConsoleAppId ? { playConsoleAppId: a.playConsoleAppId } : {}),
      ...(a.appStoreAppId ? { appStoreAppId: a.appStoreAppId } : {}),
    })),
  };

  await putObject(KEY, Buffer.from(JSON.stringify(doc, null, 2), 'utf8'), 'application/json');
  return { ok: true, updatedAt, count: apps.length };
}

export function isAnchored(id: string): boolean {
  return ANCHORED.has(id);
}
