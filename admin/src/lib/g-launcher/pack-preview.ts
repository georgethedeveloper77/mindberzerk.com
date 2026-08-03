/**
 * THE SHELF PREVIEW, composited in the browser at publish time.
 *
 * The device's store card should show the pack's own art, exactly as the
 * admin grid does. The honest way to get it there is to make the preview a
 * PAYLOAD FILE: composited here from the first six icons, appended to the
 * publish alongside pack.json, listed in the signed manifest and cached
 * immutably like every other object. Nothing new is trusted, nothing new is
 * parsed on-device, and `HeroIconResolver` ignores files its map does not
 * name, so a client that predates previews is entirely unaffected.
 *
 * The alternative was a preview URL in the signed index, which touches the
 * index schema, the Kotlin parser and the rollback story for one image. This
 * touches none of them.
 *
 * NO `server-only`: both builders run this in the browser, where the blobs
 * already live.
 */

export const PREVIEW_NAME = 'preview.png';

/** 3 x 2 grid of the first six icons, transparent background, PNG. */
export async function composePreviewPng(blobs: Blob[]): Promise<Blob | null> {
  const take = blobs.slice(0, 6);
  if (take.length === 0) return null;

  const cell = 96;
  const gap = 12;
  const pad = 14;
  const cols = 3;
  const rows = 2;
  const w = pad * 2 + cols * cell + (cols - 1) * gap;
  const h = pad * 2 + rows * cell + (rows - 1) * gap;

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;

  for (let i = 0; i < take.length; i++) {
    try {
      const bmp = await createImageBitmap(take[i]);
      const x = pad + (i % cols) * (cell + gap);
      const y = pad + Math.floor(i / cols) * (cell + gap);
      const s = Math.min(cell / bmp.width, cell / bmp.height);
      const dw = bmp.width * s;
      const dh = bmp.height * s;
      ctx.drawImage(bmp, x + (cell - dw) / 2, y + (cell - dh) / 2, dw, dh);
      bmp.close();
    } catch {
      // One undecodable image must not sink the whole preview; its cell
      // simply stays transparent.
    }
  }

  return await new Promise<Blob | null>((resolve) =>
    canvas.toBlob((b) => resolve(b), 'image/png'),
  );
}
