'use server';

import { requireAdmin } from '@/lib/admin';
import { APPS, type AppId } from '@/lib/catalogue';
import { publishDistro, type DistroPublishResult } from '@/lib/distro-publish';
import type { ThemeSpecJson } from '@/lib/theme-spec';

interface DistroMeta {
  app: string;
  theme: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    title: string;
    summary: string;
    spec: ThemeSpecJson;
    assets: { file: string }[];
  };
  icons: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    order: { pkg: string; file: string }[];
  } | null;
  distroSku: string | null;
  distroTitle: string;
  distroSummary: string;
}

async function bytesFor(formData: FormData, key: string): Promise<Buffer | null> {
  const part = formData.get(key);
  if (!(part instanceof File)) return null;
  return Buffer.from(await part.arrayBuffer());
}

export async function publishDistroAction(formData: FormData): Promise<DistroPublishResult> {
  await requireAdmin();

  const metaRaw = formData.get('meta');
  if (typeof metaRaw !== 'string') return { ok: false, error: 'Missing distro metadata' };
  let meta: DistroMeta;
  try {
    meta = JSON.parse(metaRaw) as DistroMeta;
  } catch {
    return { ok: false, error: 'Distro metadata was not valid JSON' };
  }
  if (!APPS.includes(meta.app as AppId)) return { ok: false, error: `Unknown app '${meta.app}'` };

  const themeAssets: { file: string; bytes: Buffer }[] = [];
  for (const a of meta.theme.assets ?? []) {
    const bytes = await bytesFor(formData, `asset:${a.file}`);
    if (!bytes) return { ok: false, error: `Missing asset ${a.file}` };
    themeAssets.push({ file: a.file, bytes });
  }

  let iconsResolved: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    entries: { pkg: string; file: string; bytes: Buffer }[];
  } | null = null;
  if (meta.icons && meta.icons.order.length > 0) {
    const entries: { pkg: string; file: string; bytes: Buffer }[] = [];
    for (const o of meta.icons.order) {
      const bytes = await bytesFor(formData, `icon:${o.file}`);
      if (!bytes) return { ok: false, error: `Missing icon for ${o.pkg}` };
      entries.push({ pkg: o.pkg, file: o.file, bytes });
    }
    iconsResolved = {
      packId: meta.icons.packId,
      minAppVersion: meta.icons.minAppVersion,
      sku: meta.icons.sku,
      name: meta.icons.name,
      entries,
    };
  }

  return publishDistro({
    app: meta.app as AppId,
    theme: {
      packId: meta.theme.packId,
      minAppVersion: meta.theme.minAppVersion,
      sku: meta.theme.sku,
      title: meta.theme.title,
      summary: meta.theme.summary,
      spec: meta.theme.spec,
      assets: themeAssets,
    },
    icons: iconsResolved,
    distroSku: meta.distroSku,
    distroTitle: meta.distroTitle,
    distroSummary: meta.distroSummary,
  });
}
