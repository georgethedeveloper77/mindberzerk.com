import 'server-only';

import {
  nextGeneratedAt,
  upsertPack,
  type AppId,
  type LiveIndex,
} from './catalogue';
import { putObject, putPack } from './r2';
import {
  INDEX_NAME,
  INDEX_SIGNATURE_NAME,
  signIndex,
  signPack,
  type IndexEntitlement,
  type IndexPack,
  type PackFile,
  type PackType,
} from './sign';

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
    sku: upload.sku,
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
