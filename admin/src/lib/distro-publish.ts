import 'server-only';

import { signPack, signIndex, type IndexPack, type IndexEntitlement } from './sign';
import { putPack, putObject } from './r2';
import { readLiveIndex, upsertPack, nextGeneratedAt, type AppId } from './catalogue';
import { canonicalThemeJson, type ThemeSpecJson } from './theme-spec';
import { canonicalHeroPackJson, type HeroPackJson } from './hero-pack';

export interface DistroPublishInput {
  app: AppId;
  theme: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    title: string;
    summary: string;
    spec: ThemeSpecJson;
    /** Bare-named binaries the theme.json references (wallpapers, logo). */
    assets: { file: string; bytes: Buffer }[];
  };
  icons: {
    /** Optional: a distro can ship a theme with no icon pack. */
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    entries: { pkg: string; file: string; bytes: Buffer }[];
  } | null;
  /** The whole-distro SKU that grants both packs. Null = free distro. */
  distroSku: string | null;
  distroTitle: string;
  distroSummary: string;
}

export type DistroPublishResult =
  | { ok: true; themeVersion: number; iconVersion: number | null }
  | { ok: false; error: string };

/**
 * Publish a whole distro in one shot. The two packs are uploaded first (each in
 * its own safe payload/manifest/signature order), then a SINGLE index write adds
 * both entries plus the distro entitlement, bumps generatedAt, and re-signs.
 *
 * One index write is the point: a device must never see the theme pack land in
 * the catalogue a sync before its icon pack, or a buyer briefly owns half a
 * distro. Uploading the pack objects first is safe (nothing reads them until the
 * index points at them); the index flip is the atomic-enough commit.
 */
export async function publishDistro(input: DistroPublishInput): Promise<DistroPublishResult> {
  try {
    const live = await readLiveIndex(input.app);
    if (live.corrupt) {
      throw new Error('The live index did not parse; refusing to publish over it.');
    }
    const keyId = live.keyId;

    // ── theme pack ───────────────────────────────────────────────────────────
    const themeVersion = (live.packs.find((p) => p.packId === input.theme.packId)?.version ?? 0) + 1;
    const themeJson = Buffer.from(canonicalThemeJson(input.theme.spec), 'utf8');
    const themeFiles = [
      { path: 'theme.json', bytes: themeJson },
      ...input.theme.assets.map((a) => ({ path: a.file, bytes: a.bytes })),
    ];
    const themeSigned = signPack({
      packType: 'theme',
      packId: input.theme.packId,
      version: themeVersion,
      minAppVersion: input.theme.minAppVersion,
      keyId,
      files: themeFiles,
    });
    const themePath = `themes/${input.theme.packId}/${themeVersion}`;
    await putPack(`${input.app}/${themePath}`, themeSigned.objects);
    const themeEntry: IndexPack = {
      packId: input.theme.packId,
      packType: 'theme',
      path: themePath,
      version: themeVersion,
      minAppVersion: input.theme.minAppVersion,
      sizeBytes: themeFiles.reduce((n, f) => n + f.bytes.length, 0),
      title: input.theme.title,
      summary: input.theme.summary,
      sku: input.theme.sku,
    };

    // ── icon pack (optional) ───────────────────────────────────────────────────
    let iconEntry: IndexPack | null = null;
    let iconVersion: number | null = null;
    if (input.icons && input.icons.entries.length > 0) {
      const ic = input.icons;
      iconVersion = (live.packs.find((p) => p.packId === ic.packId)?.version ?? 0) + 1;
      const iconsMap: Record<string, string> = {};
      for (const e of ic.entries) iconsMap[e.pkg] = e.file;
      const packJson: HeroPackJson = { id: ic.packId, name: ic.name, masked: false, icons: iconsMap };
      const iconFiles = [
        { path: 'pack.json', bytes: Buffer.from(canonicalHeroPackJson(packJson), 'utf8') },
        ...ic.entries.map((e) => ({ path: e.file, bytes: e.bytes })),
      ];
      const iconSigned = signPack({
        packType: 'hero',
        packId: ic.packId,
        version: iconVersion,
        minAppVersion: ic.minAppVersion,
        keyId,
        files: iconFiles,
      });
      const iconPath = `hero/${ic.packId}/${iconVersion}`;
      await putPack(`${input.app}/${iconPath}`, iconSigned.objects);
      iconEntry = {
        packId: ic.packId,
        packType: 'hero',
        path: iconPath,
        version: iconVersion,
        minAppVersion: ic.minAppVersion,
        sizeBytes: iconFiles.reduce((n, f) => n + f.bytes.length, 0),
        title: ic.name,
        summary: `${ic.entries.length} ${ic.entries.length === 1 ? 'icon' : 'icons'}`,
        sku: ic.sku,
      };
    }

    // ── merge packs ────────────────────────────────────────────────────────────
    let packs = upsertPack(live.packs, themeEntry);
    if (iconEntry) packs = upsertPack(packs, iconEntry);

    // ── the distro entitlement ─────────────────────────────────────────────────
    // Owning `distroSku` grants both packs. The icon pack ALSO carries its own
    // `icons_x` sku (set on the pack), so it is buyable alone; that needs no
    // entitlement. A free distro writes no entitlement.
    let entitlements = live.entitlements;
    if (input.distroSku) {
      const grants = [themeEntry.packId, ...(iconEntry ? [iconEntry.packId] : [])];
      const next: IndexEntitlement = {
        sku: input.distroSku,
        title: input.distroTitle,
        summary: input.distroSummary,
        grants,
      };
      entitlements = [...entitlements.filter((e) => e.sku !== input.distroSku), next];
    }

    const generatedAt = nextGeneratedAt(live);
    const { index, signature } = signIndex({ generatedAt, keyId, packs, entitlements });
    await putObject(`${input.app}/index.json`, index, 'application/json');
    await putObject(`${input.app}/index.sig`, signature, 'application/octet-stream');

    return { ok: true, themeVersion, iconVersion };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
