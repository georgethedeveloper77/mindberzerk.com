'use client';

/**
 * PHASE C8 — normalising uploaded art into a hero PNG, in the browser.
 *
 * ## This is deliberately minimal, because renderHero is
 *
 * The first cut trimmed to alpha bounds and rescaled every drawing to the 0.58
 * keyline. That was correct for the BRAND layer and wrong for hero: `renderHero`
 * draws the drawable at 1.0f and never applies foregroundScale, so a hero image
 * is shown at its own native size. Trimming and re-centring it here would move
 * and shrink art the author already positioned, and the result on device would
 * be a set of icons that no longer line up with each other.
 *
 * So the pipeline is: decode, letterbox to a square if needed (the launcher
 * assumes a square drawable), encode PNG. Nothing is trimmed, nothing is
 * rescaled. What the author drew is what ships.
 *
 * ## Why the browser and not sharp
 *
 * No native dependency in the App Hosting build, raw art never leaves the
 * machine, and the preview is the actual output bytes rather than a guess at
 * what the server would do. The cost — the browser's PNG encoder, so two
 * browsers produce byte-different files — does not matter here: the manifest
 * hashes whatever is uploaded, and nothing compares bytes across sessions.
 */

/** Longest edge of the square canvas art is normalised onto. */
const CANVAS = 192;

export interface RenderedIcon {
  blob: Blob;
  /** Object URL for the preview. Revoke it when the entry is dropped. */
  url: string;
  /** Source aspect, for flagging art that is not square. */
  aspect: number;
}

/**
 * SVGs without width and height decode to zero intrinsic size in Firefox and
 * Safari and draw blank with no error, so inject dimensions from the viewBox.
 */
async function toImage(file: File): Promise<HTMLImageElement> {
  let source: Blob = file;

  if (file.type === 'image/svg+xml' || /\.svg$/i.test(file.name)) {
    const text = await file.text();
    const hasSize =
      /<svg[^>]*\swidth\s*=/i.test(text) && /<svg[^>]*\sheight\s*=/i.test(text);
    if (!hasSize) {
      const vb = text.match(
        /viewBox\s*=\s*["']\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)/i,
      );
      if (!vb) throw new Error('This SVG has no width, height or viewBox, so it cannot be sized.');
      const w = Number(vb[1]);
      const h = Number(vb[2]);
      const long = Math.max(w, h);
      const target = CANVAS * 4; // render big, downscale once, avoids upscaling
      const patched = text.replace(
        /<svg/i,
        `<svg width="${Math.round((w / long) * target)}" height="${Math.round((h / long) * target)}"`,
      );
      source = new Blob([patched], { type: 'image/svg+xml' });
    }
  }

  const url = URL.createObjectURL(source);
  try {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error('Could not decode this image.'));
      img.src = url;
    });
    return img;
  } finally {
    URL.revokeObjectURL(url);
  }
}

/**
 * Normalise one file into a square PNG at native proportions.
 *
 * Non-square art is letterboxed transparently rather than stretched, because a
 * hero drawable is assumed square by the renderer and stretching would distort
 * every logo. A wide or tall source is flagged via `aspect` so the author can
 * see the padding was added.
 */
export async function renderHeroIcon(file: File): Promise<RenderedIcon> {
  const img = await toImage(file);
  const sw = img.naturalWidth || img.width;
  const sh = img.naturalHeight || img.height;
  if (!sw || !sh) throw new Error('This image decoded to zero size.');

  const out = document.createElement('canvas');
  out.width = CANVAS;
  out.height = CANVAS;
  const ctx = out.getContext('2d');
  if (!ctx) throw new Error('Canvas is unavailable in this browser.');
  ctx.imageSmoothingQuality = 'high';

  // Fit the whole source inside the square, preserving aspect and its own
  // internal positioning. No trim: the author's framing is kept.
  const ratio = Math.min(CANVAS / sw, CANVAS / sh);
  const w = sw * ratio;
  const h = sh * ratio;
  ctx.drawImage(img, (CANVAS - w) / 2, (CANVAS - h) / 2, w, h);

  // PNG, not WebP: the pack format's convention, and lossless keeps hard icon
  // edges clean.
  const blob = await new Promise<Blob | null>((resolve) =>
    out.toBlob(resolve, 'image/png'),
  );
  if (!blob) throw new Error('This browser could not encode PNG.');

  return { blob, url: URL.createObjectURL(blob), aspect: sw / sh };
}
