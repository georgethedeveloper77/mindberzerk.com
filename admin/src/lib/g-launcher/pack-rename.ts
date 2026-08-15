import 'server-only';

import { readLiveIndex, type AppId, type LiveIndex } from '@/lib/core/catalogue';
import {
  commitIndex,
  guardIndex,
  nextVersionFor,
  packKeyId,
  shelfOwnerBase,
  uploadPack,
  withShelfGrant,
} from '@/lib/core/publish-core';
import { getObject } from '@/lib/core/r2';
import { isSafePackId, type IndexPack, type PackFile } from '@/lib/core/sign';
import { BUNDLED_PACK_IDS } from '@/lib/core/unpublish-core';
import { canonicalHeroPackJson, validateHeroPack } from '@/lib/g-launcher/hero-pack';
import {
  deleteIconDraft,
  draftAssetKey,
  readIconDraft,
  stampIconDraftPublished,
  writeIconDraft,
  type DraftAsset,
} from '@/lib/g-launcher/icon-drafts';
import { buildHeroPackJson, expandRoleEntries } from '@/lib/g-launcher/icon-pack';
import { readAllDrafts, writeDraft } from '@/lib/g-launcher/themes';
import type { ThemeDraft } from '@/lib/g-launcher/theme-spec';

/**
 * RENAME AN ICON PACK'S ID, KEEPING ITS ART.
 *
 * ## Why this cannot be the Pack id field
 *
 * `IconBuilder` renders that field read-only once a pack is open, and the
 * comment there is correct: the id is the primary key of the draft, of the
 * bucket directory, of the index entry and of the device's install path, so
 * typing a new one publishes a SECOND pack at v1 and leaves the original live
 * and orphaned. That is the fork that produced two Ubuntus. The guard stays.
 *
 * A rename is therefore not an edit, it is a MIGRATION, and it belongs in one
 * deliberate operation that knows about all four of those places at once.
 *
 * ## What a rename is not
 *
 * It is not a move. Nothing in this pipeline can move a published pack: the id
 * is inside the CDN path, inside the signed manifest and inside `pack.json`,
 * and a device follows the `path` in the index it already holds. So the new id
 * is a NEW PACK at version 1, and the old one keeps existing until somebody
 * decides otherwise.
 *
 * ## The old pack is deliberately left published
 *
 * Pulling it here would be the one step in this sequence that can break a
 * phone. A device holding the old catalogue may still be resolving the old id
 * from a theme it has not re-synced yet, and a hero pack that stops resolving
 * reports NOTHING: every app falls through to the generator and the screen just
 * looks wrong. Unpublishing is a separate, visible act on the icons list once
 * the repointed theme has had time to reach devices.
 *
 * ## Order, and why it is this order
 *
 *   1. new draft written      art is safe under the new id before anything else
 *   2. new pack published     the index names it before any theme does
 *   3. theme drafts repointed a theme may now name a pack that exists
 *   4. old draft deleted      last, so every earlier failure is recoverable
 *
 * Reverse 2 and 3 and there is a window where a theme names a pack the
 * catalogue does not list, which on device is the silent generator fallback
 * again.
 *
 * ## Two calls, not one
 *
 * [planPackRename] reads the live state and reports exactly what will happen.
 * [executePackRename] does it. The split exists because the answers to "is the
 * old pack published", "does a theme still name it" and "is a bundle granting
 * it" live in a bucket this code cannot know the contents of in advance, and
 * every one of them changes what the operation means.
 */

// The draft-store id rule, which is STRICTER than `isSafePackId`: no dots or
// underscores and it must start with a letter, because the id becomes a bucket
// directory name under `admin/icon-drafts/`. Copied from `writeIconDraft`,
// which refuses anything else, so a plan cannot approve an id the write would
// then reject halfway through.
const DRAFT_ID = /^[a-z][a-z0-9-]{1,60}$/;

function cdnBase(): string {
  return (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
}

export interface ThemeReference {
  /** The theme draft's id. */
  id: string;
  title: string;
  /** Which field names the pack. */
  field: 'heroPack' | 'brandPack';
  /** Whether that theme is itself published, and therefore needs a republish. */
  published: boolean;
}

export interface RenamePlan {
  from: string;
  to: string;
  /** Blocking problems. Non-empty means [executePackRename] will refuse. */
  refusals: string[];
  /** Things worth knowing that do not stop the operation. */
  warnings: string[];
  /** Where the art is coming from. */
  source: 'draft' | 'published' | null;
  iconCount: number;
  /** The old pack's index entry, when it is published. */
  publishedFrom: IndexPack | null;
  /** The version the new pack will be created at. Normally 1. */
  newVersion: number;
  /** Distro base the old id shelved under, and the new one will. */
  shelfFrom: string | null;
  shelfTo: string | null;
  /** Theme drafts naming the old id, which this will repoint. */
  themeRefs: ThemeReference[];
  /** Skus whose grants name the old id. Left alone, reported. */
  grantingSkus: string[];
}

interface SourcePack {
  origin: 'draft' | 'published';
  name: string;
  minAppVersion: number;
  masked: boolean;
  /** Blank means free. */
  sku: string;
  plate: string;
  radius: number;
  shape: string;
  /** One per uploaded file. `pkg` may be a role id or a real package id. */
  icons: { pkg: string; file: string; bytes: Buffer }[];
  /**
   * Payload files the old published pack carried that are not icons and not
   * `pack.json`, most importantly the shelf preview. Carried across so the new
   * pack is not visually blank on the device's icons screen.
   *
   * Empty when the source is a draft with no published counterpart, because a
   * preview is composited by canvas in the browser and there is no server-side
   * equivalent. The next publish from the builder regenerates it.
   */
  extras: { file: string; bytes: Buffer }[];
}

/**
 * Read the old pack's art, preferring the draft because it is the newer work.
 *
 * [fallbackId] IS THE RESUME PATH. A migration writes the new draft before it
 * publishes, so a failure at the publish step leaves the art under the NEW id
 * and, if the run got far enough, no draft under the old one. Reading only the
 * old id would then report "neither published nor a draft" on a second attempt
 * and strand the work under a name nothing looks for. Old id first, because
 * while it exists it is the source of truth.
 */
async function loadSource(
  app: AppId,
  packId: string,
  entry: IndexPack | null,
  fallbackId?: string,
): Promise<SourcePack | { error: string }> {
  const draft =
    (await readIconDraft(app, packId)) ??
    (fallbackId ? await readIconDraft(app, fallbackId) : null);

  if (draft) {
    const icons: { pkg: string; file: string; bytes: Buffer }[] = [];
    const missing: string[] = [];
    for (const i of draft.icons) {
      // draft.packId, NOT packId: on a resume these bytes live under the new id.
      const bytes = await getObject(draftAssetKey(app, draft.packId, i.file));
      if (!bytes) {
        missing.push(i.file);
        continue;
      }
      icons.push({ pkg: i.pkg, file: i.file, bytes });
    }
    if (missing.length > 0) {
      return {
        error:
          `${missing.length} of the draft's icon files are not in the bucket ` +
          `(${missing.slice(0, 4).join(', ')}). Renaming would publish a pack ` +
          'missing that art permanently, so nothing was changed.',
      };
    }
    const extras = entry ? await loadExtras(app, entry, new Set(icons.map((i) => i.file))) : [];
    return {
      origin: 'draft',
      name: draft.name,
      minAppVersion: draft.minAppVersion,
      masked: draft.masked,
      sku: draft.sku,
      plate: draft.plate,
      radius: draft.radius,
      shape: draft.shape ?? 'roundedSquare',
      icons,
      extras,
    };
  }

  if (!entry) return { error: `${packId} is neither published nor a draft.` };

  // No draft, so the published pack is the only copy of the art. Read it over
  // public HTTPS by the path the index gives, which is the same route the
  // builder's rehydration takes and needs no bucket credential.
  const base = `${cdnBase()}/${app}/${entry.path}`;
  let pack: { name?: unknown; masked?: unknown; icons?: unknown };
  try {
    const res = await fetch(`${base}/pack.json`, { cache: 'no-store' });
    if (!res.ok) return { error: `pack.json for ${packId} answered ${res.status}.` };
    pack = (await res.json()) as typeof pack;
  } catch (e) {
    return { error: `pack.json for ${packId} could not be read: ${(e as Error).message}` };
  }

  const map = (pack.icons ?? {}) as Record<string, string>;
  // One entry per FILE, not per package: several packages legitimately share
  // one drawing after `expandRoleEntries`, and uploading that file once is the
  // whole point of the role table.
  const byFile = new Map<string, string>();
  for (const [pkg, file] of Object.entries(map)) {
    if (!byFile.has(file)) byFile.set(file, pkg);
  }

  const icons: { pkg: string; file: string; bytes: Buffer }[] = [];
  for (const [file, pkg] of byFile) {
    try {
      const res = await fetch(`${base}/${encodeURIComponent(file)}`, { cache: 'no-store' });
      if (!res.ok) return { error: `${file} answered ${res.status} and is part of the pack.` };
      icons.push({ pkg, file, bytes: Buffer.from(await res.arrayBuffer()) });
    } catch (e) {
      return { error: `${file} could not be read: ${(e as Error).message}` };
    }
  }

  const extras = await loadExtras(app, entry, new Set(icons.map((i) => i.file)));
  return {
    origin: 'published',
    name: typeof pack.name === 'string' ? pack.name : packId,
    minAppVersion: entry.minAppVersion,
    masked: pack.masked === true,
    sku: entry.sku ?? '',
    plate: '#E95420',
    radius: 22,
    shape: 'roundedSquare',
    icons,
    extras,
  };
}

/**
 * Payload files the published pack lists that are neither icons nor the two
 * signing artefacts. Read from the MANIFEST rather than from a guessed name,
 * because the preview's filename is a constant in a client module and hardcoding
 * a second copy of it here is how the `hero/` and `heropacks/` split happened.
 */
async function loadExtras(
  app: AppId,
  entry: IndexPack,
  iconFiles: Set<string>,
): Promise<{ file: string; bytes: Buffer }[]> {
  const base = `${cdnBase()}/${app}/${entry.path}`;
  const out: { file: string; bytes: Buffer }[] = [];
  try {
    const res = await fetch(`${base}/manifest.json`, { cache: 'no-store' });
    if (!res.ok) return out;
    const manifest = (await res.json()) as { files?: { path?: unknown }[] };
    for (const f of manifest.files ?? []) {
      const path = typeof f.path === 'string' ? f.path : '';
      if (!path) continue;
      if (path === 'pack.json' || path === 'manifest.json' || path === 'manifest.sig') continue;
      if (iconFiles.has(path)) continue;
      const got = await fetch(`${base}/${encodeURIComponent(path)}`, { cache: 'no-store' });
      if (!got.ok) continue;
      out.push({ file: path, bytes: Buffer.from(await got.arrayBuffer()) });
    }
  } catch {
    // Best effort. A missing preview is a cosmetic loss on one shelf; failing
    // the whole migration over it would be the wrong trade.
  }
  return out;
}

function themeRefsFor(
  drafts: ThemeDraft[],
  packId: string,
  live: LiveIndex,
): ThemeReference[] {
  const out: ThemeReference[] = [];
  for (const d of drafts) {
    const icons = d.spec.icons;
    if (!icons) continue;
    const published = live.packs.some((p) => p.packId === d.id || p.packId === `${d.id}-theme`);
    if (icons.heroPack === packId) {
      out.push({ id: d.id, title: d.title || d.id, field: 'heroPack', published });
    }
    if (icons.brandPack === packId) {
      out.push({ id: d.id, title: d.title || d.id, field: 'brandPack', published });
    }
  }
  return out;
}

export async function planPackRename(
  app: AppId,
  from: string,
  to: string,
): Promise<RenamePlan | { error: string }> {
  const refusals: string[] = [];
  const warnings: string[] = [];

  const live = await readLiveIndex(app);
  const refusal = guardIndex(app, live);
  if (refusal) return { error: refusal };

  if (from === to) return { error: 'The two ids are the same.' };
  if (!isSafePackId(to) || !DRAFT_ID.test(to)) {
    refusals.push(
      `'${to}' is not usable as a pack id. Lowercase letters, digits and hyphens, ` +
        'starting with a letter, because the id becomes a directory name.',
    );
  }
  if (BUNDLED_PACK_IDS.has(from)) {
    refusals.push(`${from} ships inside the app. Renaming it would strand every device on the APK seed.`);
  }
  if (BUNDLED_PACK_IDS.has(to)) {
    refusals.push(`${to} is a bundled id. Publishing over it would collide with the in-APK pack.`);
  }

  const publishedFrom = live.packs.find((p) => p.packId === from) ?? null;
  const publishedTo = live.packs.find((p) => p.packId === to) ?? null;
  if (publishedTo) {
    refusals.push(
      `${to} is already published at v${publishedTo.version}. Renaming onto it would ` +
        'overwrite a different pack rather than create one.',
    );
  }
  // A DRAFT UNDER THE NEW ID IS NOT ALWAYS A COLLISION.
  //
  // This step writes the new draft before it publishes, so a run that failed at
  // the publish step leaves exactly this state behind. Refusing here would make
  // the tool unable to finish its own half-finished work, which is the worst
  // shape a migration can have. It is only a real collision when `to` is
  // PUBLISHED as well, and that is refused above.
  const draftAtTarget = await readIconDraft(app, to);
  const resuming = !!draftAtTarget && !publishedTo;

  let themeDrafts: ThemeDraft[] = [];
  try {
    themeDrafts = await readAllDrafts(app);
  } catch (e) {
    return { error: (e as Error).message };
  }

  const themeRefs = themeRefsFor(themeDrafts, from, live);
  const grantingSkus = live.entitlements
    .filter((e) => e.grants.includes(from))
    .map((e) => e.sku)
    .sort();

  if (resuming) {
    warnings.push(
      `${to} already has a draft of ${draftAtTarget?.icons.length ?? 0} icons from an earlier ` +
        'attempt that did not finish. Running again rewrites it from the source and carries on ' +
        'from there, rather than starting a second pack.',
    );
  }
  if (grantingSkus.length > 0) {
    warnings.push(
      `${grantingSkus.join(', ')} grants ${from}. The grant is left alone, so the old pack ` +
        `stays included in that purchase and ${to} is not. If the new pack is paid, add it ` +
        'on the Bundles screen.',
    );
  }
  if (themeRefs.length === 0) {
    warnings.push(
      `No theme draft names ${from}, so nothing is repointed. If a distro applies this pack, ` +
        'it is doing so from a published theme.json that has no draft, and that theme will ' +
        'keep naming the old id.',
    );
  }
  for (const t of themeRefs.filter((t) => t.published)) {
    warnings.push(
      `${t.title} is published. Repointing its draft is not enough on its own: publish it ` +
        'from the distro workspace afterwards, or devices keep the old pack.',
    );
  }

  const source =
    refusals.length > 0 ? null : await loadSource(app, from, publishedFrom, to);
  if (source && 'error' in source) return { error: source.error };

  const unmapped = source ? source.icons.filter((i) => !i.pkg).length : 0;
  if (unmapped > 0) {
    warnings.push(
      `${unmapped} icons have no app assigned yet. They move with the draft but are left out ` +
        'of the published pack, exactly as the builder leaves them out.',
    );
  }
  if (source && source.origin === 'draft' && source.extras.length === 0 && publishedFrom) {
    warnings.push('The shelf preview could not be read from the old pack, so the new one ships without one.');
  }

  return {
    from,
    to,
    refusals,
    warnings,
    source: source ? source.origin : null,
    iconCount: source ? source.icons.length : 0,
    publishedFrom,
    newVersion: nextVersionFor(live, to),
    shelfFrom: shelfOwnerBase(from, live),
    shelfTo: shelfOwnerBase(to, live),
    themeRefs,
    grantingSkus,
  };
}

export interface RenameOutcome {
  ok: boolean;
  /** What actually happened, in order, for the report. */
  steps: { label: string; detail: string; ok: boolean }[];
}

export async function executePackRename(
  app: AppId,
  from: string,
  to: string,
): Promise<RenameOutcome> {
  const steps: { label: string; detail: string; ok: boolean }[] = [];
  const fail = (label: string, detail: string): RenameOutcome => {
    steps.push({ label, detail, ok: false });
    return { ok: false, steps };
  };

  const plan = await planPackRename(app, from, to);
  if ('error' in plan) return fail('Check', plan.error);
  if (plan.refusals.length > 0) return fail('Check', plan.refusals.join(' '));

  const live = await readLiveIndex(app);
  const guard = guardIndex(app, live);
  if (guard) return fail('Check', guard);

  const source = await loadSource(app, from, plan.publishedFrom, to);
  if ('error' in source) return fail('Read the art', source.error);
  steps.push({
    label: 'Read the art',
    detail: `${source.icons.length} icons from the ${source.origin}${
      source.extras.length ? `, plus ${source.extras.length} carried file(s)` : ''
    }.`,
    ok: true,
  });

  // ── 1. the new draft ──────────────────────────────────────────────────────
  const assets: DraftAsset[] = source.icons.map((i) => ({
    file: i.file,
    bytes: i.bytes,
    contentType: 'image/png',
  }));
  const wrote = await writeIconDraft(
    app,
    {
      packId: to,
      name: source.name,
      minAppVersion: source.minAppVersion,
      masked: source.masked,
      sku: source.sku,
      plate: source.plate,
      radius: source.radius,
      shape: source.shape,
      icons: source.icons.map((i) => ({ pkg: i.pkg, file: i.file })),
    },
    assets,
  );
  if (!wrote.ok) return fail('Write the new draft', wrote.error);
  steps.push({
    label: 'Write the new draft',
    detail: `${to} saved with ${assets.length} icons. The old draft is untouched until the end.`,
    ok: true,
  });

  // ── 2. publish the new pack ───────────────────────────────────────────────
  const mapped = source.icons.filter((i) => i.pkg);

  // PRE-EXPANSION duplicate check, which is the stage it belongs at. After
  // `expandRoleEntries` one file legitimately serves every package in a role,
  // so a repeated filename there is the design rather than a fault; before it,
  // two slots sharing a filename means one drawing would silently overwrite
  // the other in the bucket. `validateHeroPack` used to do this downstream and
  // reported every multi-package role as an error.
  const bySlot = new Map<string, string>();
  const dupSlots: string[] = [];
  const dupFiles: string[] = [];
  for (const i of mapped) {
    if (bySlot.has(i.pkg)) dupSlots.push(i.pkg);
    bySlot.set(i.pkg, i.file);
  }
  const filesSeen = new Set<string>();
  for (const i of mapped) {
    if (filesSeen.has(i.file)) dupFiles.push(i.file);
    filesSeen.add(i.file);
  }
  if (dupSlots.length > 0 || dupFiles.length > 0) {
    return fail(
      'Publish the new pack',
      'The draft moved, but its own icon list is inconsistent, so nothing was published. ' +
        (dupSlots.length ? `Slots listed twice: ${[...new Set(dupSlots)].join(', ')}. ` : '') +
        (dupFiles.length ? `Files listed twice: ${[...new Set(dupFiles)].join(', ')}. ` : '') +
        'Open the pack in the builder and remove the repeated rows.',
    );
  }

  const expanded = expandRoleEntries(mapped.map((i) => ({ slot: i.pkg, file: i.file })));
  const packSku = source.sku.trim() === '' ? null : source.sku.trim();

  const problems = validateHeroPack(
    { id: to, name: source.name || to, minAppVersion: source.minAppVersion, masked: source.masked, sku: packSku },
    expanded.map((e) => ({ pkg: e.pkg, label: e.pkg, file: e.file })),
  );
  if (problems.length > 0) {
    return fail(
      'Publish the new pack',
      `The draft moved, but it does not pass publish validation, so nothing was published: ${problems.join(' ')}`,
    );
  }

  const packJson = buildHeroPackJson(to, source.name || to, source.masked, expanded);
  const files: PackFile[] = [
    ...mapped.map((i) => ({ path: i.file, bytes: i.bytes })),
    ...source.extras.map((x) => ({ path: x.file, bytes: x.bytes })),
    { path: 'pack.json', bytes: Buffer.from(canonicalHeroPackJson(packJson), 'utf8') },
  ];

  const version = nextVersionFor(live, to);
  let entry: IndexPack;
  try {
    entry = await uploadPack(
      app,
      {
        packType: 'hero',
        packId: to,
        version,
        minAppVersion: source.minAppVersion,
        title: source.name || to,
        summary: `${mapped.length} hero icons`,
        sku: packSku,
        files,
      },
      packKeyId(),
    );
  } catch (e) {
    return fail('Publish the new pack', `The draft moved but the upload failed: ${(e as Error).message}`);
  }

  const { entitlements, grantedTo } = withShelfGrant(live, to, packSku);
  try {
    await commitIndex(app, live, [entry], entitlements);
  } catch (e) {
    return fail(
      'Publish the new pack',
      `The objects uploaded but the index write failed, so nothing is live yet: ${(e as Error).message}`,
    );
  }
  // The draft this step just published FROM now matches what devices will get,
  // so it must not go on claiming to be ahead. Same reason the builder stamps
  // after its own publish; without it the migration hands over a brand new pack
  // whose builder already says there is unpublished work waiting.
  await stampIconDraftPublished(app, to, version);

  steps.push({
    label: 'Publish the new pack',
    detail:
      `${to} v${version}, ${files.length} files` +
      (grantedTo ? `, included with ${grantedTo}` : '') +
      '. The old pack is still published and still works.',
    ok: true,
  });

  // ── 3. repoint theme drafts ───────────────────────────────────────────────
  const repointed: string[] = [];
  const repointFailed: string[] = [];
  for (const ref of plan.themeRefs) {
    try {
      const drafts = await readAllDrafts(app);
      const d = drafts.find((x) => x.id === ref.id);
      if (!d || !d.spec.icons) continue;
      const next: ThemeDraft = {
        ...d,
        spec: { ...d.spec, icons: { ...d.spec.icons, [ref.field]: to } },
      };
      await writeDraft(app, next);
      repointed.push(`${ref.title} (${ref.field})`);
    } catch (e) {
      repointFailed.push(`${ref.title}: ${(e as Error).message}`);
    }
  }
  if (plan.themeRefs.length > 0) {
    steps.push({
      label: 'Repoint the distros',
      detail:
        (repointed.length ? `${repointed.join(', ')} now name ${to}. ` : '') +
        (repointFailed.length ? `Failed: ${repointFailed.join('; ')}. ` : '') +
        (plan.themeRefs.some((t) => t.published)
          ? 'Publish those distros from the workspace to reach devices.'
          : 'None of them is published, so there is nothing further to do.'),
      ok: repointFailed.length === 0,
    });
  }

  // ── 4. the old draft, last ────────────────────────────────────────────────
  const gone = await deleteIconDraft(app, from);
  steps.push({
    label: 'Remove the old draft',
    detail: gone.ok
      ? `${from}'s draft and its files are gone. The published ${from} pack is untouched and still in the catalogue.`
      : `Everything else succeeded, but the old draft could not be removed: ${gone.error}`,
    ok: gone.ok,
  });

  return { ok: steps.every((s) => s.ok), steps };
}
