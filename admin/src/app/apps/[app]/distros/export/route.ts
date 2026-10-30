import { NextResponse } from 'next/server';
import { strToU8, zipSync } from 'fflate';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { APPS, type AppId } from '@/lib/core/catalogue';
import { ensureSeededSafe } from '@/lib/g-launcher/themes';
import { exportDistros } from '@/lib/g-launcher/distro-io';

export const dynamic = 'force-dynamic';

/**
 * EXPORT DISTROS.
 *
 * `?format=zip` (the default) downloads one `<id>.theme.json` per distro, named
 * the way the repo's `themes/g-launcher` folder names them, so the round trip
 * is export, edit in the repo, import. `?format=json` returns one JSON array,
 * which is what "copy all" puts on the clipboard and what import accepts back.
 * `?ids=a,b` limits either to the selection.
 *
 * Each file is the CANONICAL theme.json: exactly what publish would sign.
 */
export async function GET(
  request: Request,
  { params }: { params: Promise<{ app: string }> },
) {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return NextResponse.json({ error: 'Not authorised' }, { status: 401 });
    }
    throw e;
  }

  const { app } = await params;
  if (!APPS.includes(app as AppId)) {
    return NextResponse.json({ error: `Unknown app '${app}'` }, { status: 404 });
  }
  const appId = app as AppId;

  const url = new URL(request.url);
  const format = url.searchParams.get('format') === 'json' ? 'json' : 'zip';
  const idsRaw = url.searchParams.get('ids');
  const ids = idsRaw ? idsRaw.split(',').map((s) => s.trim()).filter(Boolean) : null;

  // The same seeding the page does, so a distro that is only live, with no
  // draft yet, still exports rather than going missing from the zip.
  await ensureSeededSafe(appId);
  const files = await exportDistros(appId, ids);

  if (format === 'json') {
    const all = `[\n${files.map((f) => f.text.trim()).join(',\n')}\n]\n`;
    return new NextResponse(all, {
      headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
    });
  }

  const zip = zipSync(
    Object.fromEntries(files.map((f) => [f.name, strToU8(f.text.endsWith('\n') ? f.text : `${f.text}\n`)])),
    { level: 6 },
  );
  const stamp = new Date().toISOString().slice(0, 10);
  return new NextResponse(Buffer.from(zip), {
    headers: {
      'content-type': 'application/zip',
      'content-disposition': `attachment; filename="${appId}-distros-${stamp}.zip"`,
      'cache-control': 'no-store',
    },
  });
}
