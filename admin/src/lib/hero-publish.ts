import 'server-only';

import { signPack, signIndex, type IndexPack } from './sign';
import { putPack, putObject } from './r2';
import { readLiveIndex, upsertPack, nextGeneratedAt, type AppId } from './catalogue';
import {
  canonicalHeroPackJson,
  isBareFilename,
  isSafePackId,
  isValidPackage,
  type HeroPackJson,
} from './hero-pack';

export interface HeroPublishInput {
  app: AppId;
  id: string;
  name: string;
  minAppVersion: number;
  masked: boolean;
  sku: string | null;
  icons: { pkg: string; file: string; bytes: Buffer }[];
}

export type HeroPublishResult = { ok: true; version: number } | { ok: false; error: string };

/**
 * Publish a hero pack. Same invariant as every other publish: read the live
 * index, add this pack, bump generatedAt, re-sign, write. The pack.json and its
 * PNGs are signed together, so a device installs an all-or-nothing set.
 *
 * The version is derived from what is live (existing + 1, or 1), because
 * ThemeAssetLoader refuses a version that is not strictly greater than what it
 * holds. Re-publishing without a change still bumps the number, which is the
 * only way the daily sync worker notices there is anything to fetch.
 */
export async function publishHeroPack(input: HeroPublishInput): Promise<HeroPublishResult> {
  try {
    if (!isSafePackId(input.id)) throw new Error(`Pack id '${input.id}' is unsafe`);
    if (!input.name.trim()) throw new Error('Pack name is required');
    if (input.icons.length === 0) throw new Error('A hero pack needs at least one icon');
    for (const ic of input.icons) {
      if (!isValidPackage(ic.pkg)) throw new Error(`'${ic.pkg}' is not a valid package name`);
      if (!isBareFilename(ic.file)) throw new Error(`'${ic.file}' is not a bare filename`);
    }

    const live = await readLiveIndex(input.app);
    if (live.corrupt) {
      throw new Error('The live index did not parse; refusing to publish over it. Check the bucket.');
    }

    const existing = live.packs.find((p) => p.packId === input.id);
    const version = (existing?.version ?? 0) + 1;
    const keyId = live.keyId;

    const iconsMap: Record<string, string> = {};
    for (const ic of input.icons) iconsMap[ic.pkg] = ic.file;
    const packJson: HeroPackJson = {
      id: input.id,
      name: input.name,
      masked: input.masked,
      icons: iconsMap,
    };
    const packJsonBytes = Buffer.from(canonicalHeroPackJson(packJson), 'utf8');

    const files = [
      { path: 'pack.json', bytes: packJsonBytes },
      ...input.icons.map((ic) => ({ path: ic.file, bytes: ic.bytes })),
    ];

    const signed = signPack({
      packType: 'hero',
      packId: input.id,
      version,
      minAppVersion: input.minAppVersion,
      keyId,
      files,
    });

    const path = `hero/${input.id}/${version}`;
    await putPack(`${input.app}/${path}`, signed.objects);

    const sizeBytes = files.reduce((n, f) => n + f.bytes.length, 0);
    const entry: IndexPack = {
      packId: input.id,
      packType: 'hero',
      path,
      version,
      minAppVersion: input.minAppVersion,
      sizeBytes,
      title: input.name,
      summary: `${input.icons.length} ${input.icons.length === 1 ? 'icon' : 'icons'}`,
      sku: input.sku || null,
    };

    const packs = upsertPack(live.packs, entry);
    const generatedAt = nextGeneratedAt(live);
    const { index, signature } = signIndex({
      generatedAt,
      keyId,
      packs,
      entitlements: live.entitlements,
    });

    await putObject(`${input.app}/index.json`, index, 'application/json');
    await putObject(`${input.app}/index.sig`, signature, 'application/octet-stream');

    return { ok: true, version };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
