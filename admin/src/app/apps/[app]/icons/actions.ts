'use server';

import { requireAdmin } from '@/lib/admin';
import { APPS, type AppId } from '@/lib/catalogue';
import { publishHeroPack, type HeroPublishResult } from '@/lib/hero-publish';

interface MetaShape {
  app: string;
  id: string;
  name: string;
  minAppVersion: number;
  masked: boolean;
  sku: string | null;
  order: { pkg: string; file: string }[];
}

/**
 * The client sends one `meta` JSON part plus one image part per icon, each keyed
 * `icon:<filename>`. Images arrive already rasterized to 192px PNG in the
 * browser, so nothing here needs an image library.
 */
export async function publishHeroPackAction(formData: FormData): Promise<HeroPublishResult> {
  await requireAdmin();

  const metaRaw = formData.get('meta');
  if (typeof metaRaw !== 'string') return { ok: false, error: 'Missing pack metadata' };

  let meta: MetaShape;
  try {
    meta = JSON.parse(metaRaw) as MetaShape;
  } catch {
    return { ok: false, error: 'Pack metadata was not valid JSON' };
  }

  if (!APPS.includes(meta.app as AppId)) return { ok: false, error: `Unknown app '${meta.app}'` };

  const icons: { pkg: string; file: string; bytes: Buffer }[] = [];
  for (const o of meta.order ?? []) {
    const part = formData.get(`icon:${o.file}`);
    if (!(part instanceof File)) return { ok: false, error: `Missing image for ${o.pkg}` };
    icons.push({ pkg: o.pkg, file: o.file, bytes: Buffer.from(await part.arrayBuffer()) });
  }

  return publishHeroPack({
    app: meta.app as AppId,
    id: meta.id,
    name: meta.name,
    minAppVersion: Number(meta.minAppVersion) || 0,
    masked: !!meta.masked,
    sku: meta.sku || null,
    icons,
  });
}
