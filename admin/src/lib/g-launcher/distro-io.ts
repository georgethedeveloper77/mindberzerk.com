import 'server-only';

import { getObject, putObject } from '@/lib/core/r2';
import type { AppId } from '@/lib/core/catalogue';
import { readAllDrafts, writeDraft } from '@/lib/g-launcher/themes';
import {
  canonicalThemeJson,
  importTheme,
  isSafePackId,
  validateDraft,
  type ThemeDraft,
  type ThemeSpecJson,
} from '@/lib/g-launcher/theme-spec';

/**
 * Distros in and out of the admin, many at a time.
 *
 * ─── DRAFTS ONLY, BY DESIGN ─────────────────────────────────────────────────
 *
 * Import writes drafts and nothing else. Publishing stays its own step, with
 * its own check that Play is serving the build a pack asks for, so dropping a
 * folder of files on the page can never put a pack on phones that cannot run
 * it.
 *
 * ─── ONE PATH INTO A DRAFT ──────────────────────────────────────────────────
 *
 * Every file goes through `importTheme` and `validateDraft`, the same pair the
 * builder and the theme.json editor use, and is written with `writeDraft`,
 * which validates again. A file that would fail there is reported here first,
 * row by row, before anything is written.
 */

/** The file a distro exports as, matching the repo's `themes/g-launcher`. */
export function distroFileName(id: string): string {
  const base = id.endsWith('-theme') ? id.slice(0, -'-theme'.length) : id;
  return `${base}.theme.json`;
}

export interface ImportFile {
  /** What the file was called, for the report. Matching uses the spec's id. */
  name: string;
  text: string;
}

export type ImportKind = 'new' | 'update' | 'same' | 'error';

export interface ImportRow {
  file: string;
  kind: ImportKind;
  id?: string;
  title?: string;
  /** Top-level sections the file changes, in reading order. */
  changes: string[];
  minFrom?: number | null;
  minTo?: number | null;
  /** Import notes: shown, never blocking. */
  warnings: string[];
  /** Anything that would stop `writeDraft`. A row with errors is not written. */
  errors: string[];
}

/** Split an upload into theme files: one object, or an array of them. */
export function expandFiles(files: ImportFile[]): { name: string; value: unknown; error?: string }[] {
  const out: { name: string; value: unknown; error?: string }[] = [];
  for (const f of files) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(f.text);
    } catch (e) {
      out.push({ name: f.name, value: null, error: `Not JSON: ${(e as Error).message}` });
      continue;
    }
    if (Array.isArray(parsed)) {
      parsed.forEach((v, i) => out.push({ name: `${f.name} [${i + 1}]`, value: v }));
    } else {
      out.push({ name: f.name, value: parsed });
    }
  }
  return out;
}

/** The top-level keys whose content differs, plus a word for added or removed. */
function changedSections(before: ThemeSpecJson | null, after: ThemeSpecJson): string[] {
  if (!before) return ['new distro'];
  const a = JSON.parse(canonicalThemeJson(before)) as Record<string, unknown>;
  const b = JSON.parse(canonicalThemeJson(after)) as Record<string, unknown>;
  const keys = [...new Set([...Object.keys(a), ...Object.keys(b)])];
  const out: string[] = [];
  for (const k of keys) {
    if (k === 'minAppVersion') continue;
    if (!(k in a)) out.push(`${k} added`);
    else if (!(k in b)) out.push(`${k} removed`);
    else if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) out.push(k);
  }
  return out;
}

interface Planned {
  row: ImportRow;
  draft: ThemeDraft | null;
}

async function plan(app: AppId, files: ImportFile[]): Promise<Planned[]> {
  const drafts = new Map((await readAllDrafts(app)).map((d) => [d.id, d]));
  const seen = new Set<string>();
  const out: Planned[] = [];

  for (const f of expandFiles(files)) {
    const row: ImportRow = { file: f.name, kind: 'error', changes: [], warnings: [], errors: [] };
    if (f.error) {
      row.errors.push(f.error);
      out.push({ row, draft: null });
      continue;
    }

    const imported = importTheme(f.value);
    if ('error' in imported) {
      row.errors.push(imported.error);
      out.push({ row, draft: null });
      continue;
    }

    const spec = imported.spec;
    row.id = spec.id;
    row.title = spec.name;
    row.warnings.push(...imported.notes);

    if (!spec.id || !isSafePackId(spec.id)) {
      row.errors.push(`'${spec.id}' is not a usable distro id`);
      out.push({ row, draft: null });
      continue;
    }
    // Two files for one distro in one drop: the second would silently win, so
    // it is refused and the first stands.
    if (seen.has(spec.id)) {
      row.errors.push(`${spec.id} appears more than once in this import`);
      out.push({ row, draft: null });
      continue;
    }
    seen.add(spec.id);

    const existing = drafts.get(spec.id) ?? null;
    const next: ThemeDraft = existing
      ? { ...existing, spec }
      : {
          id: spec.id,
          title: spec.name,
          summary: '',
          sku: null,
          bundled: false,
          packVersion: 1,
          spec,
          updatedAt: 0,
        };

    row.errors.push(...validateDraft(next));
    row.minFrom = existing ? (existing.spec.minAppVersion ?? null) : null;
    row.minTo = spec.minAppVersion ?? null;

    if (!existing) {
      row.kind = row.errors.length ? 'error' : 'new';
      row.changes = ['new distro'];
      row.warnings.push('New distro: add its wallpapers, logo and Play product in the editor.');
    } else if (canonicalThemeJson(existing.spec) === canonicalThemeJson(spec)) {
      row.kind = row.errors.length ? 'error' : 'same';
    } else {
      row.kind = row.errors.length ? 'error' : 'update';
      row.changes = changedSections(existing.spec, spec);
    }
    if (existing && spec.tier === 'pro' && !existing.sku) {
      row.warnings.push('Tier is pro but there is no Play product id yet, so it cannot sell.');
    }

    out.push({ row, draft: row.errors.length ? null : next });
  }
  return out;
}

/** What an import would do, row by row, writing nothing. */
export async function previewImport(app: AppId, files: ImportFile[]): Promise<ImportRow[]> {
  return (await plan(app, files)).map((p) => p.row);
}

/**
 * Write the chosen rows as drafts. Re-plans from the files rather than trusting
 * the preview, so a draft edited between the two steps is compared afresh.
 */
export async function applyImport(
  app: AppId,
  files: ImportFile[],
  ids: string[],
): Promise<{ id: string; ok: boolean; detail: string }[]> {
  const wanted = new Set(ids);
  const results: { id: string; ok: boolean; detail: string }[] = [];
  for (const p of await plan(app, files)) {
    const id = p.row.id;
    if (!id || !wanted.has(id)) continue;
    if (!p.draft) {
      results.push({ id, ok: false, detail: p.row.errors.join('; ') || 'nothing to write' });
      continue;
    }
    if (p.row.kind === 'same') {
      results.push({ id, ok: true, detail: 'unchanged' });
      continue;
    }
    try {
      await writeDraft(app, p.draft);
      results.push({ id, ok: true, detail: p.row.kind === 'new' ? 'new draft' : 'draft updated' });
    } catch (e) {
      results.push({ id, ok: false, detail: (e as Error).message });
    }
  }
  return results;
}

// ── the build Play is serving ───────────────────────────────────────────────

const playBuildKey = (app: AppId) => `${app}/admin/play-build.json`;

/**
 * The build number Play is serving, as set by hand on the Config screen.
 *
 * Kept in the bucket beside the drafts rather than in Remote Config: no app
 * reads it, and Remote Config's allowlist is for values a device consumes.
 * Null when it was never set, and the list then says so rather than guessing.
 */
export async function readPlayBuild(app: AppId): Promise<number | null> {
  try {
    const bytes = await getObject(playBuildKey(app));
    if (!bytes) return null;
    const v = (JSON.parse(bytes.toString('utf8')) as { build?: unknown }).build;
    return typeof v === 'number' && Number.isInteger(v) && v > 0 ? v : null;
  } catch {
    return null;
  }
}

export async function writePlayBuild(app: AppId, build: number): Promise<void> {
  await putObject(
    playBuildKey(app),
    Buffer.from(JSON.stringify({ build, setAt: Math.floor(Date.now() / 1000) }) + '\n', 'utf8'),
    'application/json',
  );
}

/** Every distro's file, for an export. Drafts are the source: they are seeded
 *  from what is live, and they are what the list shows. */
export async function exportDistros(
  app: AppId,
  ids: string[] | null,
): Promise<{ name: string; id: string; text: string }[]> {
  const wanted = ids ? new Set(ids) : null;
  return (await readAllDrafts(app))
    .filter((d) => !wanted || wanted.has(d.id))
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((d) => ({ name: distroFileName(d.id), id: d.id, text: canonicalThemeJson(d.spec) }));
}
