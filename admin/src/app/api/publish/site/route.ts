import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { writeSiteContent, type SiteContent } from '@/lib/studio/site-content';

/**
 * PHASE C12 - publish site content.
 *
 * Unsigned, and on its own track: it writes site/content.json and touches
 * nothing about the pack index or its signature. All validation (featured ids
 * are real, live apps have links) lives in `writeSiteContent`.
 */
export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  let body: Partial<SiteContent>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Expected JSON' }, { status: 400 });
  }

  if (!Array.isArray(body.featured) || !body.hero || !Array.isArray(body.stats)) {
    return NextResponse.json({ error: 'featured, hero and stats are required' }, { status: 400 });
  }

  const result = await writeSiteContent({
    featured: body.featured.map(String),
    hero: {
      eyebrow: String(body.hero.eyebrow ?? ''),
      headline: String(body.hero.headline ?? ''),
      lede: String(body.hero.lede ?? ''),
    },
    stats: body.stats.map((s) => ({ label: String(s.label ?? ''), value: String(s.value ?? '') })),
    updatedAt: 0,
  });

  if (!result.ok) return NextResponse.json({ error: result.error }, { status: 400 });
  return NextResponse.json({ ok: true, updatedAt: result.updatedAt });
}
