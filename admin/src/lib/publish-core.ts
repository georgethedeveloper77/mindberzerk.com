import 'server-only';

import {
  nextGeneratedAt,
  upsertPack,
  type AppId,
  type LiveIndex,
} from '@/lib/core/catalogue';
import { putObject, putPack } from '@/lib/core/r2';
import {
  INDEX_NAME,
  INDEX_SIGNATURE_NAME,
  signIndex,
  signPack,
  type IndexEntitlement,
  type IndexFeature,
  type IndexPack,
  type IndexPreview,
  type PackFile,
  type PackType,
} from '@/lib/core/sign';

/**
 * ONE PUBLISH PATH.
 *
 * There were two. `api/publish/pack/route.ts` handled a zip or a directory and
 * signed one pack; `distro-publish.ts` reimplemented the same sequence to sign
 * two and write one index. They agreed on nearly everything, which is what made
 * the places they disagreed so expensive:
 *
 *   * `dirFor('hero')` returned `heropacks/` in one and `hero/` in the other, so
 *     an icon pack's objects lived in a different prefix depending on which
 *     screen published it. Devices follow the `path` in the index so both
 *     installed fine, and the damage was invisible: republishing through the
 *     other screen left the previous version's files orphaned in a prefix that
 *     `putPack`'s sweep would never look at.
 *   * one resolved the signing key from the environment and the other from
 *     whatever key the LAST index happened to be signed with, so a key rotation
 *     took effect on one screen and silently did not on the other.
 *   * only one refused to publish into a bucket it could not read, which is the
 *     failure that replaces a live catalogue with a single pack.
 *
 * None of those is a bug anyone writes. They are what a copy becomes.
 *
 * ─── THE SHAPE ──────────────────────────────────────────────────────────────
 *
 * [uploadPack] puts one pack's objects in the bucket and hands back the index
 * entry that WOULD describe it. It deliberately does not touch the index, so a
 * caller can upload several and commit once.
 *
 * [commitIndex] merges entries, re-signs and writes.
 *
 * That split is the whole reason a distro can be atomic. A device must never
 * see a theme land in the catalogue one sync before its icon pack, or someone
 * who just paid owns half a distro until the next refresh. Uploading pack
 * objects first is safe because nothing reads them until the index points at
 * them; the index write is the commit.
 */

/**
 * Where a pack type lives in the bucket.
 *
 * MUST match the launcher and `backend/content/`, which mirror each other path
 * for path. This is now the only copy.
 */
export function dirFor(packType: PackType): string {
  switch (packType) {
    case 'theme':
      return 'themes';
    case 'brand':
      return 'brandpacks';
    case 'hero':
      return 'heropacks';
    case 'icon':
      return 'iconpacks';
      case 'registry':
      return 'registries';
    case 'article':
      return 'articles';
    case 'guide':
      return 'guides';
  }
}

/**
 * The key id written into every manifest and index this panel signs.
 *
 * FROM THE ENVIRONMENT, never from the live index. Reading it back off the last
 * index looks harmless and quietly makes key rotation impossible: change
 * `PACK_KEY_ID`, publish, and the pack is signed with the OLD id because that is
 * what the index said. It has to be a decision this deployment makes, not a
 * value it inherits from its own previous output.
 *
 * Must be present in `PackKeys.ACCEPTED_HEX` in the shipped app, or every pack
 * is refused with UnknownKey.
 */
export function packKeyId(): string {
  return process.env.PACK_KEY_ID ?? 'mh-2026-07';
}

/**
 * Whether it is safe to publish into this index at all, as a message or null.
 *
 * TWO REFUSALS, and they are different failures with the same consequence.
 *
 * `unreachable` is the destructive one. Every merge below starts from
 * `live.packs`, so a read that failed to an empty list means the write replaces
 * a catalogue holding every pack with one holding this pack alone. Every
 * installed launcher would then see the rest of the store vanish, because a
 * token expired.
 *
 * `corrupt` is the same arithmetic with a different cause: something is there,
 * it cannot be merged into, and treating it as absent wipes it.
 */
export function guardIndex(app: AppId, live: LiveIndex): string | null {
  if (live.unreachable) {
    return (
      `Could not read ${app}/${INDEX_NAME}: ${live.unreachable}. ` +
      'Refusing to publish, because merging into a catalogue we could not read ' +
      'would overwrite it.'
    );
  }
  if (live.corrupt) {
    return `${app}/${INDEX_NAME} exists but does not parse. Refusing to overwrite it.`;
  }
  return null;
}

/** The next version for a pack id. Monotonic integers, never semver. */
/**
 * ── THE SHELF-OWNER RULE, in one shared place ───────────────────────────────
 *
 * A hero pack belongs to the distro whose base id prefixes its own, longest
 * base wins. The launcher's icons screen shelves by exactly this rule, and the
 * icon builder's picker writes ids to match, so this function is the third
 * copy of the rule and therefore lives in core where both publish paths import
 * it rather than re-deriving it.
 */
export function shelfOwnerBase(packId: string, live: LiveIndex): string | null {
  let best: string | null = null;
  for (const p of live.packs) {
    if (p.packType !== 'theme') continue;
    const base = p.packId.endsWith('-theme')
      ? p.packId.slice(0, -'-theme'.length)
      : p.packId;
    if (packId !== base && packId.startsWith(`${base}-`)) {
      if (best === null || base.length > best.length) best = base;
    }
  }
  return best;
}

/**
 * Append a PAID shelf pack to its distro's entitlement, when one exists.
 *
 * "Comes with the distro" has to be true for money, not just for shelving:
 * a paid pack on a paid distro's shelf is included in the distro purchase, so
 * its id joins that distro's grants. The operation is deliberately narrow:
 *
 *   APPEND-ONLY.  Ownership scope can grow here and never shrink; removing
 *                 grants stays a deliberate act on the screens that own them.
 *   PAID ONLY.    A free pack is unlocked for everyone already; granting it
 *                 would be signed noise.
 *   EXISTING ENTITLEMENT ONLY. A free distro has no entitlement, and this
 *                 function will not invent one; the pack stays standalone.
 *
 * The distro's entitlement is identified by its grants containing the distro's
 * theme pack id, which is ground truth rather than a naming convention.
 */
export function withShelfGrant(
  live: LiveIndex,
  packId: string,
  packSku: string | null,
): { entitlements: IndexEntitlement[]; grantedTo: string | null } {
  const unchanged = { entitlements: live.entitlements, grantedTo: null };
  if (!packSku) return unchanged;

  const base = shelfOwnerBase(packId, live);
  if (!base) return unchanged;

  const themeIds = new Set([base, `${base}-theme`]);
  const owner = live.entitlements.find((e) => e.grants.some((g) => themeIds.has(g)));
  if (!owner) return unchanged;
  if (owner.grants.includes(packId)) return unchanged;

  return {
    entitlements: live.entitlements.map((e) =>
      e === owner ? { ...e, grants: [...e.grants, packId] } : e,
    ),
    grantedTo: owner.sku,
  };
}

export function nextVersionFor(live: LiveIndex, packId: string): number {
  return (live.packs.find((p) => p.packId === packId)?.version ?? 0) + 1;
}

export interface PackUpload {
  packType: PackType;
  packId: string;
  version: number;
  minAppVersion: number;
  title: string;
  summary: string;
  /** null = free. */
  sku: string | null;

  /**
   * The storefront preview, or undefined to publish without one.
   *
   * Optional on the upload rather than derived in here, because a pack is not
   * always a theme: an icon pack and a hero pack go through this same function
   * and neither has a palette to preview. The caller knows which it is holding.
   */
  preview?: IndexPreview;

  /**
   * Pack ids this one cannot function without. Omit when there are none.
   *
   * A derived icon pack is 200 bytes naming a colour and pointing at
   * `arcticons-line`, which carries the drawings all fourteen distros share.
   * Installed alone it verifies, resolves and draws nothing.
   *
   * OMIT rather than passing an empty array: `signIndex` emits the field
   * whenever it is defined, and its `assertNothingDropped` guard treats `[]`
   * as present, so an empty array would put `"requires":[]` into the signed
   * bytes of every pack that has no dependency.
   */
  requires?: string[];

  /**
   * Storefront rows, or omit when this pack names none.
   *
   * `IndexPack` has carried this since the feature rows shipped and
   * `PackUpload` never did, so `distro-publish.ts` passed it and the typecheck
   * failed at the call site rather than here. Same shape of gap as `preview`
   * and `requires`: the type at the end of the pipeline grew and the type at
   * the start did not.
   *
   * `[]` and absent mean different things and both are legal. An empty array
   * says "this pack chose to name nothing", which the device honours by
   * showing no rows; absent says "published before the field existed", which
   * falls back to the floor card. `distro-publish.ts` sends `[]` deliberately
   * for exactly that reason.
   */
  features?: IndexFeature[];
  files: PackFile[];
}

/**
 * Sign one pack and put its objects in the bucket. Returns the index entry.
 *
 * VERSION IS IN THE PATH, so every object under a pack is genuinely immutable
 * and cacheable for a year. Without it, publishing v3 leaves edges serving v2's
 * manifest against v3's payload, which reads to a device as tampering. Old
 * versions are left in place deliberately: a device that read the index a moment
 * ago and is mid-download still finds its files.
 *
 * `putPack` owns the ordering (payload, manifest, signature, then a sweep of
 * files the previous version listed and this one does not), because every
 * intermediate state has to be one a device handles.
 */
export async function uploadPack(
  app: AppId,
  upload: PackUpload,
  keyId: string,
): Promise<IndexPack> {
  const path = `${dirFor(upload.packType)}/${upload.packId}/${upload.version}`;

  const signed = signPack({
    packType: upload.packType,
    packId: upload.packId,
    version: upload.version,
    minAppVersion: upload.minAppVersion,
    keyId,
    files: upload.files,
  });

  await putPack(`${app}/${path}`, signed.objects);

  return {
    packId: upload.packId,
    packType: upload.packType,
    path,
    version: upload.version,
    minAppVersion: upload.minAppVersion,
    sizeBytes: upload.files.reduce((n, f) => n + f.bytes.length, 0),
    title: upload.title,
    summary: upload.summary,
    // ─── SPREAD, NOT WRITTEN AS NULL ──────────────────────────────────────
    //
    // This was `sku: upload.sku`, unconditionally, so a FREE pack carried
    // `sku: null` out of here. `signIndex` rebuilds the same entry with
    // `...(p.sku ? { sku } : {})` and drops a null, and its
    // `assertNothingDropped` guard counts null as present, so publishing any
    // free distro threw: `buildIndex dropped sku from 'ubuntu-24-04'`.
    //
    // The guard was right and the fix belongs here rather than there. Every
    // other optional in this rebuild is spread-when-present, including the
    // three lines below it, and the note under them says so in as many words:
    // an entry with `preview: null` and one with no key are the same thing to
    // the device. `sku` was the one field breaking its own file's rule.
    //
    // Relaxing the guard to ignore null was the other option and it is the
    // wrong one: it would have hidden this, and the guard exists because six
    // themes once published with no preview and nothing said a word.
    ...(upload.sku ? { sku: upload.sku } : {}),
    // OMITTED when absent, not written as null. An entry with `preview: null`
    // and one with no `preview` key are the same thing to the device, and the
    // spread keeps the index readable for the packs that have no palette.
    ...(upload.preview ? { preview: upload.preview } : {}),
    // ─── AND `requires`, FOR THE SAME REASON THE LINE ABOVE EXISTS ─────────
    //
    // This function rebuilds `IndexPack` field by field, exactly as `signIndex`
    // does, so a field added to the type reaches here and is dropped unless it
    // is named. `preview` was lost that way once and six themes published
    // without one. Named here so a derived pack's dependency survives the trip
    // from `PackUpload` to the entry `commitIndex` signs.
    ...(upload.requires ? { requires: upload.requires } : {}),
    // ─── AND `features`, THE THIRD FIELD THIS REBUILD HAS DROPPED ──────────
    //
    // `!= null` rather than truthy, because `[]` is falsy in JavaScript and an
    // empty array is a MEANINGFUL value here: it says this pack named no rows,
    // which the device shows as no rows, while absent falls back to the floor
    // card. A truthy test would silently turn the first into the second.
    //
    // `signIndex` uses `!= null` on the same field for the same reason. The two
    // rebuilds have to agree or a pack's rows would survive one and not the
    // other.
    ...(upload.features != null ? { features: upload.features } : {}),
  };
}

/**
 * Merge entries into the live catalogue, sign it, write it.
 *
 * AFTER every pack is fully uploaded, never before. The index is what tells
 * devices a pack exists; advertising one whose files are still going up
 * produces a wave of failed installs across the whole install base at once.
 *
 * [entitlements] REPLACES the live list when given, and is carried through
 * untouched when omitted. A pack publish must never be able to change who owns
 * what, so the route passes nothing; the distro workspace passes a list because
 * granting is the point of what it is doing.
 */
export async function commitIndex(
  app: AppId,
  live: LiveIndex,
  entries: IndexPack[],
  entitlements?: IndexEntitlement[],
): Promise<number> {
  let packs = live.packs;
  for (const e of entries) packs = upsertPack(packs, e);

  /**
   * ─── A PUBLISH MAY ADD AND REPLACE. IT MUST NEVER SUBTRACT ────────────────
   *
   * `arcticons-line` was published, verified in the live index at seventeen
   * packs, and was gone an hour later with sixteen remaining and every other
   * pack intact. I looked for the cause twice and was wrong twice: the read
   * path has no HTTP cache, and nothing in this file removes a pack.
   *
   * So this does not try to name the cause. `upsertPack` replaces by id and
   * appends otherwise, which means the count after a merge can only ever grow
   * or hold. If it shrank, something between reading the index and signing it
   * lost a pack, and signing that result publishes the loss to every device.
   *
   * Refusing costs a failed publish that can be retried. Not refusing costs a
   * pack that silently stops existing, which is a thing that has now happened
   * once and was noticed by accident.
   *
   * The comparison is on IDS rather than length: a merge that dropped one pack
   * while adding another would keep the count identical and is the same bug.
   */
  if (live.exists) {
    const after = new Set(packs.map((p) => p.packId));
    const lost = live.packs.map((p) => p.packId).filter((id) => !after.has(id));
    if (lost.length > 0) {
      throw new Error(
        `Refusing to publish: this write would drop ${lost.join(', ')} from the catalogue. ` +
          'A publish can add and replace, never remove. Use Unpublish for that.',
      );
    }
  }

  const generatedAt = nextGeneratedAt(live);
  const { index, signature } = signIndex({
    generatedAt,
    keyId: packKeyId(),
    packs,
    entitlements: entitlements ?? live.entitlements,
  });

  await putObject(`${app}/${INDEX_NAME}`, index, 'application/json');
  await putObject(`${app}/${INDEX_SIGNATURE_NAME}`, signature, 'application/octet-stream');

  return generatedAt;
}
