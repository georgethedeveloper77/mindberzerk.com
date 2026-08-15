import { NextResponse } from 'next/server';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { glyphBySlug, searchGlyphs } from '@/lib/g-launcher/glyph-search';

/**
 * Search the CC0 brand set for the icon builder's glyph picker.
 *
 *   GET /api/icons/glyphs?q=whats     search, best match first
 *   GET /api/icons/glyphs?slug=whatsapp   one icon, for rehydrating a draft
 *
 * BEHIND requireAdmin like every other route here. Not because the data is
 * secret, it is CC0 and public, but because an unauthenticated endpoint that
 * scans a 3,453-item list on every request is a free way to spend this
 * backend's CPU, and the panel has exactly one user.
 *
 * `nodejs`, because `simple-icons` is a CommonJS package and the Edge runtime
 * would not load it. Same reason the publish route declares it.
 */
export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  const url = new URL(request.url);
  const slug = url.searchParams.get('slug');
  if (slug) {
    const one = glyphBySlug(slug);
    return NextResponse.json({ glyphs: one ? [one] : [] });
  }

  return NextResponse.json({
    glyphs: searchGlyphs(url.searchParams.get('q') ?? ''),
  });
}
