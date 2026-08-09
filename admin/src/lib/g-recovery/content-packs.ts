import 'server-only';

import type { PackFile, PackType } from '@/lib/core/sign';

/**
 * G RECOVERY content packs: the trashmap registry, the Learn guide, and per
 * brand recovery notes.
 *
 * ─── WHY VALIDATION LIVES HERE AND NOT ONLY ON THE DEVICE ───────────────────
 *
 * The app already degrades safely: an unknown block type renders nothing, a
 * malformed trashmap entry is skipped, a bad pack is refused. That is the right
 * behaviour for a device and the wrong place to discover a mistake. By the time
 * a phone skips a block, the pack is published, the index points at it, and the
 * symptom is a chapter that is silently one paragraph shorter on some devices
 * and not others.
 *
 * Failing at publish costs one error message. Same argument `sign.ts` makes for
 * keeping the traversal gate in both places.
 *
 * ─── THE BLOCK VOCABULARY IS A CONTRACT ─────────────────────────────────────
 *
 * `ContentBlockView` in the app renders exactly six types and skips anything
 * else. This list must equal that one. It is deliberately not markdown: markdown
 * needs a parser, a renderer, and a decision about which subset is supported,
 * and every one of those is a place for published content to render wrong on a
 * stranger's phone.
 */

export const CONTENT_PACK_TYPES = ['registry', 'article', 'guide'] as const;
export type ContentPackType = (typeof CONTENT_PACK_TYPES)[number];

/** Must equal the switch in `lib/features/learn/widgets/content_block_view.dart`. */
const BLOCK_TYPES = ['p', 'h', 'note', 'warn', 'path', 'list'] as const;

/** Must equal `TrashMap.Entry.role` in the app. */
const ROLES = ['trash', 'status', 'cache'] as const;

/** Must equal the fidelity stamps `SourceTile` and `ItemRow` can draw. */
const FIDELITIES = ['full', 'preview', 'none'] as const;

/**
 * How much a rule is trusted, and OPTIONAL ON PURPOSE.
 *
 * A path reproduced on a phone and a path copied off a forum are identical to
 * the scanner: it stats both and reports what it finds. Only the person who
 * added the row knows which is which, and without somewhere to say so that
 * knowledge lives in a chat message. The app can use it to offer a manual
 * browse instead of implying a result.
 *
 * ABSENT IS ITS OWN ANSWER, not a synonym for either value. Rows written before
 * this field existed are unstated, and defaulting them to `verified` would be a
 * claim nobody made, while defaulting them to `reported` would libel paths that
 * were tested on the Samsung sitting on the desk.
 */
const CONFIDENCE = ['verified', 'reported'] as const;

export interface ContentPackPlan {
  packId: string;
  packType: PackType;
  /** The single payload file inside the pack. */
  fileName: string;
  title: string;
  summary: string;
  /**
   * The app version this pack needs.
   *
   * ZERO unless a pack uses something a shipped build cannot render. Setting it
   * high "to be safe" is not safe: it silently withholds the pack from every
   * device below it, and a coverage fix that nobody receives is the same as no
   * fix.
   */
  minAppVersion: number;
}

/** The three packs this app reads, keyed by the id the device asks for. */
export const CONTENT_PACKS: Record<string, ContentPackPlan> = {
  trashmap: {
    packId: 'trashmap',
    packType: 'registry' as PackType,
    fileName: 'trashmap.json',
    title: 'Recovery coverage',
    summary: 'Trash folder paths per app and per manufacturer.',
    minAppVersion: 0,
  },
  'learn-en': {
    packId: 'learn-en',
    packType: 'article' as PackType,
    fileName: 'learn-en.json',
    title: 'How Android storage works',
    summary: 'The in app guide, English.',
    minAppVersion: 0,
  },
  'oem-guide': {
    packId: 'oem-guide',
    packType: 'guide' as PackType,
    fileName: 'oem-guide.json',
    title: 'Per brand guidance',
    summary: 'Manufacturer specific recovery notes.',
    minAppVersion: 0,
  },
  /**
   * THE STORAGE MAP: what every folder on the device is, and what happens to a
   * file deleted from it.
   *
   * ─── WHY THIS IS A REGISTRY AND NOT AN ARTICLE ──────────────────────────────
   *
   * It carries prose, so `article` was tempting. But its primary key is a PATH,
   * and the app reads it by looking up the folder it is standing in rather than
   * by reading it front to back. That is the same access pattern as the
   * trashmap and the opposite of the guide, so it lives in `registries/` beside
   * the map it explains. The alternative was a fourth pack type, which means
   * touching an exhaustive switch that gates the launcher's publish path, for a
   * directory name.
   *
   * ─── AND WHY IT REPLACES MOST OF LEARN ──────────────────────────────────────
   *
   * Seven chapters about Android storage is a manual, and nobody opens a manual
   * on a phone. The same knowledge attached to the folder someone is actually
   * looking at is a label. `recoverable` is the join: it answers "why can this
   * not be recovered" at the exact moment the question occurs, per folder,
   * instead of in a chapter they would have to go and find.
   */
  'storage-map': {
    packId: 'storage-map',
    packType: 'registry' as PackType,
    fileName: 'storage-map.json',
    title: 'Storage map',
    summary: 'What each folder is and what deleting from it costs.',
    minAppVersion: 0,
  },
};

export class ContentValidationError extends Error {}

function fail(message: string): never {
  throw new ContentValidationError(message);
}

function asObject(value: unknown, where: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    fail(`${where} must be an object`);
  }
  return value as Record<string, unknown>;
}

function asArray(value: unknown, where: string): unknown[] {
  if (!Array.isArray(value)) fail(`${where} must be an array`);
  return value;
}

function asString(value: unknown, where: string): string {
  if (typeof value !== 'string' || value.length === 0) fail(`${where} must be a non-empty string`);
  return value;
}

/**
 * Validate the trashmap.
 *
 * PATHS ARE CANDIDATES AND ARE NOT CHECKED FOR EXISTENCE, deliberately. The
 * scanner probes each one and reports only what it finds, so a wrong guess costs
 * a stat call. That is precisely what makes it safe to publish paths for
 * hardware nobody on the team owns, which is the entire reason this pipeline
 * exists.
 *
 * What IS checked is shape: a leading slash or a `..` would be silently dropped
 * by the app's own parser, and a typo that quietly reduces coverage is the
 * hardest kind of mistake to notice from the panel.
 */
export function validateTrashmap(doc: unknown): void {
  const root = asObject(doc, 'trashmap');
  if (root.id !== 'trashmap') fail("trashmap 'id' must be \"trashmap\"");
  if (typeof root.version !== 'number' || !Number.isInteger(root.version) || root.version < 1) {
    fail("trashmap 'version' must be an integer >= 1");
  }

  const checkPaths = (paths: unknown, where: string) => {
    const list = asArray(paths, `${where}.paths`);
    if (list.length === 0) fail(`${where}.paths is empty`);
    for (const p of list) {
      const path = asString(p, `${where}.paths entry`);
      if (path.startsWith('/')) fail(`${where}: '${path}' must be relative to shared storage`);
      if (path.includes('..')) fail(`${where}: '${path}' contains '..'`);
    }
  };

  const checkEntry = (raw: unknown, where: string) => {
    const entry = asObject(raw, where);
    asString(entry.label, `${where}.label`);
    checkPaths(entry.paths, where);
    const role = entry.role ?? 'trash';
    if (!ROLES.includes(role as (typeof ROLES)[number])) {
      fail(`${where}.role '${String(role)}' is not one of ${ROLES.join(', ')}`);
    }
    const fidelity = entry.fidelity ?? 'full';
    if (!FIDELITIES.includes(fidelity as (typeof FIDELITIES)[number])) {
      fail(`${where}.fidelity '${String(fidelity)}' is not one of ${FIDELITIES.join(', ')}`);
    }
    // Checked ONLY WHEN PRESENT. A required field here would refuse every
    // document written before it existed, including the one that is live.
    if (entry.confidence !== undefined) {
      if (!CONFIDENCE.includes(entry.confidence as (typeof CONFIDENCE)[number])) {
        fail(
          `${where}.confidence '${String(entry.confidence)}' is not one of ` +
            `${CONFIDENCE.join(', ')}. Leave it out to mean unstated.`,
        );
      }
    }
  };

  asArray(root.apps, 'trashmap.apps').forEach((e, i) => checkEntry(e, `apps[${i}]`));
  asArray(root.oem, 'trashmap.oem').forEach((e, i) => checkEntry(e, `oem[${i}]`));

  const thumbnails = asObject(root.thumbnails, 'trashmap.thumbnails');
  checkPaths(thumbnails.paths, 'thumbnails');

  // restoreFolder becomes a directory under shared storage that files are
  // copied INTO, so it gets the same treatment as a payload path.
  const restore = asString(root.restoreFolder ?? 'Pictures/G Recovery', 'trashmap.restoreFolder');
  if (restore.startsWith('/') || restore.includes('..')) {
    fail(`trashmap.restoreFolder '${restore}' must be a plain relative folder`);
  }
}

/** Validate the Learn guide against the block vocabulary the app can draw. */
export function validateLearn(doc: unknown): void {
  const root = asObject(doc, 'learn');
  if (typeof root.version !== 'number' || !Number.isInteger(root.version) || root.version < 1) {
    fail("learn 'version' must be an integer >= 1");
  }
  const chapters = asArray(root.chapters, 'learn.chapters');
  if (chapters.length === 0) fail('a guide with no chapters is not a guide');

  const seen = new Set<string>();
  chapters.forEach((raw, i) => {
    const chapter = asObject(raw, `chapters[${i}]`);
    const id = asString(chapter.id, `chapters[${i}].id`);
    // Chapter ids are referenced by LearnIds constants in the app, and an info
    // icon pointing at a renamed chapter opens a "not in this version" screen.
    // Duplicates are worse: chapter() returns the first and the second becomes
    // unreachable with no error anywhere.
    if (seen.has(id)) fail(`duplicate chapter id '${id}'`);
    seen.add(id);
    asString(chapter.title, `chapters[${i}].title`);
    asString(chapter.summary, `chapters[${i}].summary`);

    const blocks = asArray(chapter.blocks, `chapters[${i}].blocks`);
    if (blocks.length === 0) fail(`chapter '${id}' has no blocks`);
    validateBlocks(blocks, `chapter '${id}'`);
  });
}

/**
 * The block vocabulary, checked once for every document that uses it.
 *
 * SHARED BY LEARN AND BRAND GUIDANCE, and that sharing is the design decision
 * rather than a tidy-up. Brand guidance could have had a vocabulary of its own,
 * and then the app would need a second renderer, a second set of six cases, and
 * a second way for a published document to draw wrong on a stranger's phone.
 * Reusing `ContentBlockView` means the feature costs one screen on the device
 * instead of a subsystem.
 */
function validateBlocks(blocks: unknown[], where: string): void {
  blocks.forEach((rawBlock, j) => {
    const block = asObject(rawBlock, `${where} block ${j}`);
    const type = block.t;
    if (!BLOCK_TYPES.includes(type as (typeof BLOCK_TYPES)[number])) {
      fail(
        `${where} block ${j} has type '${String(type)}', which the app cannot ` +
          `render. Allowed: ${BLOCK_TYPES.join(', ')}`,
      );
    }
    if (type === 'list') {
      const items = asArray(block.items, `${where} block ${j}.items`);
      if (items.length === 0) fail(`${where} block ${j} is an empty list`);
      items.forEach((it, k) => asString(it, `${where} block ${j}.items[${k}]`));
    } else if (type === 'path') {
      asString(block.name, `${where} block ${j}.name`);
      asString(block.text, `${where} block ${j}.text`);
    } else {
      asString(block.text, `${where} block ${j}.text`);
    }
  });
}

/**
 * Validate per brand guidance.
 *
 * ─── BRANDS ARE MATCHED, NOT DISPLAYED ──────────────────────────────────────
 *
 * `brand` is compared against a lowercased `Build.MANUFACTURER`, which returns
 * things like `samsung`, `Xiaomi`, `TECNO MOBILE LIMITED` and `HUAWEI`
 * depending on who assembled the ROM. So the match key is lowercase and
 * separate from `label`, which is what a person reads. Uppercase in `brand` is
 * refused rather than silently lowercased, because a document that works in the
 * panel and matches nothing on a phone is the worst failure this pipeline has.
 *
 * ─── AND A FALLBACK IS NOT A BRAND ──────────────────────────────────────────
 *
 * Most of the install base is a long tail of manufacturers nobody will write a
 * page for. `fallback` is what those devices read. Without it they get an empty
 * screen, which reads as a broken app rather than as an absence of guidance.
 */
export function validateOemGuide(doc: unknown): void {
  const root = asObject(doc, 'oem-guide');
  if (root.id !== 'oem-guide') fail("oem-guide 'id' must be \"oem-guide\"");
  if (typeof root.version !== 'number' || !Number.isInteger(root.version) || root.version < 1) {
    fail("oem-guide 'version' must be an integer >= 1");
  }

  const brands = asArray(root.brands, 'oem-guide.brands');
  if (brands.length === 0) fail('a guide with no brands is not a guide');

  const seen = new Set<string>();
  brands.forEach((raw, i) => {
    const where = `brands[${i}]`;
    const entry = asObject(raw, where);
    const brand = asString(entry.brand, `${where}.brand`);
    if (brand !== brand.toLowerCase()) {
      fail(
        `${where}.brand '${brand}' must be lowercase. It is compared against a ` +
          'lowercased Build.MANUFACTURER, so any capital here matches nothing.',
      );
    }
    // A duplicate is not a merge. The device takes the first match and the
    // second becomes unreachable with nothing reported at either end.
    if (seen.has(brand)) fail(`duplicate brand '${brand}'`);
    seen.add(brand);

    asString(entry.label, `${where}.label`);
    asString(entry.summary, `${where}.summary`);

    if (entry.aliases !== undefined) {
      asArray(entry.aliases, `${where}.aliases`).forEach((a, k) => {
        const alias = asString(a, `${where}.aliases[${k}]`);
        if (alias !== alias.toLowerCase()) {
          fail(`${where}.aliases[${k}] '${alias}' must be lowercase`);
        }
        if (seen.has(alias)) fail(`alias '${alias}' is already claimed`);
        seen.add(alias);
      });
    }

    const blocks = asArray(entry.blocks, `${where}.blocks`);
    if (blocks.length === 0) fail(`brand '${brand}' has no blocks`);
    validateBlocks(blocks, `brand '${brand}'`);
  });

  if (root.fallback !== undefined) {
    const fallback = asObject(root.fallback, 'oem-guide.fallback');
    const blocks = asArray(fallback.blocks, 'oem-guide.fallback.blocks');
    if (blocks.length === 0) fail('the fallback has no blocks. Leave it out instead.');
    validateBlocks(blocks, 'fallback');
  }
}

/** Who put a folder there. Decides the tone of the explanation, not the icon. */
const OWNERS = ['system', 'app', 'user'] as const;

/**
 * What deleting from a folder costs, which is the whole point of the map.
 *
 *   trash  it goes somewhere recoverable, and the trashmap says where
 *   cache  it is regenerated, so losing it costs nothing
 *   none   it is gone, and no scan will find it
 *
 * REQUIRED, unlike confidence. A folder with no answer to this is a row that
 * looks informative and answers the one question the user actually has.
 */
const RECOVERABLE = ['trash', 'cache', 'none'] as const;

/**
 * THE ICON SET, closed and small.
 *
 * ─── WHY A FIXED SET AND NOT FREE TEXT ──────────────────────────────────────
 *
 * The app is built so a person taps an icon or opens a folder rather than reads
 * a page. That only works if an icon means the same thing every time it appears,
 * and free text guarantees it will not: `camera`, `Camera` and `photo` become
 * three icons for one idea within a month, and the fourth one renders as a blank
 * square on a device that shipped before it was invented.
 *
 * MIRRORED IN `StorageEditor.tsx` because that file is a client component and
 * this one is server-only. Same arrangement as `isSafeSku`: the copy the
 * browser can reach is a convenience, and this copy is the gate.
 */
const ICONS = [
  'camera',
  'image',
  'video',
  'audio',
  'download',
  'document',
  'app',
  'cache',
  'archive',
  'folder',
  'trash',
  'system',
] as const;

/**
 * The hard ceiling on a folder's one line.
 *
 * SEVENTY, AND REFUSED RATHER THAN WARNED. A soft limit is a suggestion the
 * panel makes and the document ignores, and the first long line teaches everyone
 * that the number is decorative. If a folder needs more than this, it needs a
 * better name: the person reading it is standing in a file browser looking for
 * something they lost, not reading documentation.
 */
const SUMMARY_MAX = 70;

/**
 * Validate the storage map.
 *
 * PATHS ARE RELATIVE TO SHARED STORAGE, same rule as the trashmap and for the
 * same reason: the app resolves them under `/storage/emulated/0`, so a leading
 * slash is silently dropped and the node attaches to the wrong place in the
 * tree. An empty path is legal and means the volume root itself.
 *
 * ─── NO BLOCKS HERE, AND THAT IS A DELIBERATE REMOVAL ───────────────────────
 *
 * An earlier version let each folder carry the same six block types the guide
 * uses. It was the wrong affordance: a block list invites three paragraphs about
 * the Movies folder, and nobody has ever read three paragraphs about the Movies
 * folder. A row is an icon, a name, what the name stands for, and one line.
 * Anything that genuinely needs prose belongs in Learn, where it is reached
 * deliberately.
 */
export function validateStorageMap(doc: unknown): void {
  const root = asObject(doc, 'storage-map');
  if (root.id !== 'storage-map') fail("storage-map 'id' must be \"storage-map\"");
  if (typeof root.version !== 'number' || !Number.isInteger(root.version) || root.version < 1) {
    fail("storage-map 'version' must be an integer >= 1");
  }

  const nodes = asArray(root.nodes, 'storage-map.nodes');
  if (nodes.length === 0) fail('a storage map with no folders is not a map');

  const seen = new Set<string>();
  nodes.forEach((raw, i) => {
    const where = `nodes[${i}]`;
    const node = asObject(raw, where);

    // The root is the one node allowed an empty path, so this cannot use
    // asString, which refuses empty.
    const path = typeof node.path === 'string' ? node.path : fail(`${where}.path must be a string`);
    if (path.startsWith('/')) fail(`${where}: '${path}' must be relative to shared storage`);
    if (path.includes('..')) fail(`${where}: '${path}' contains '..'`);
    // Two rows for one folder means the app draws one and hides the other, and
    // which one it draws depends on an ordering nobody chose.
    if (seen.has(path)) fail(`duplicate path '${path}'`);
    seen.add(path);

    asString(node.label, `${where}.label`);

    const summary = asString(node.summary, `${where}.summary`);
    if (summary.length > SUMMARY_MAX) {
      fail(
        `${where}.summary is ${summary.length} characters, and ${SUMMARY_MAX} is the limit. ` +
          'A folder needs a name, not a paragraph.',
      );
    }

    if (node.expand !== undefined) asString(node.expand, `${where}.expand`);

    if (!ICONS.includes(node.icon as (typeof ICONS)[number])) {
      fail(
        `${where}.icon '${String(node.icon)}' is not one of ${ICONS.join(', ')}. ` +
          'An icon the app cannot draw renders as a blank square.',
      );
    }

    const owner = node.owner ?? 'system';
    if (!OWNERS.includes(owner as (typeof OWNERS)[number])) {
      fail(`${where}.owner '${String(owner)}' is not one of ${OWNERS.join(', ')}`);
    }
    if (owner === 'app' && node.pkg !== undefined) asString(node.pkg, `${where}.pkg`);

    if (!RECOVERABLE.includes(node.recoverable as (typeof RECOVERABLE)[number])) {
      fail(
        `${where}.recoverable '${String(node.recoverable)}' is not one of ` +
          `${RECOVERABLE.join(', ')}. Every folder needs an answer to what deleting costs.`,
      );
    }

    // REFUSED RATHER THAN IGNORED. A document carrying blocks was written
    // against the old schema, and publishing it while silently dropping them
    // would lose work with no error anywhere.
    if (node.blocks !== undefined) {
      fail(
        `${where}.blocks is no longer part of this document. A folder carries one line; ` +
          'prose belongs in the Learn guide.',
      );
    }
  });
}

export function validateContent(packId: string, doc: unknown): void {
  switch (packId) {
    case 'trashmap':
      return validateTrashmap(doc);
    case 'learn-en':
      return validateLearn(doc);
    case 'oem-guide':
      return validateOemGuide(doc);
    case 'storage-map':
      return validateStorageMap(doc);
    default:
      fail(`unknown content pack '${packId}'`);
  }
}

/**
 * Serialise the payload exactly as it will be signed and uploaded.
 *
 * Two space indent and a trailing newline, matching every other JSON this
 * pipeline writes. The bytes here are the bytes hashed into the manifest, so
 * this function is the only place the document becomes text.
 */
export function contentFile(plan: ContentPackPlan, doc: unknown): PackFile {
  return {
    path: plan.fileName,
    bytes: Buffer.from(JSON.stringify(doc, null, 2) + '\n', 'utf8'),
  };
}
