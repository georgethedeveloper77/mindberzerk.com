/**
 * SVG PRIMITIVES TO PATH DATA.
 *
 * ─── WHY THIS HAS TO EXIST ──────────────────────────────────────────────────
 *
 * `PathParser.createPathFromPathData` on Android takes ONE string of path data.
 * It does not take a `<line>`, a `<circle>` or a `<polyline>`, and Arcticons is
 * full of them: a drawing is typically one `<path>` plus two or three of the
 * others. Shipping only the `<path>` elements would produce icons missing half
 * their strokes, and it would do it silently, because the result is still a
 * valid drawing of something.
 *
 * So every primitive is converted at BUILD time, on a machine, once. Nothing
 * about this belongs on a phone.
 *
 * ─── CIRCLES AND THE ARC FLAG ───────────────────────────────────────────────
 *
 * A circle cannot be one arc. `A rx ry rot large sweep x y` needs a start and
 * an end point, and for a full circle those are the same point, which every
 * renderer treats as a no-op. Two half arcs is the standard workaround and it
 * is what this emits. Getting it wrong produces an invisible circle rather than
 * an error, which is the failure mode this whole file is built to avoid.
 */

/** Numbers, trimmed. `stroke-width` cares about precision; coordinates do not. */
function num(v, fallback = 0) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : fallback;
}

/** Round to 3 decimals and drop the trailing zeros. Purely a size measure. */
function r(n) {
  return String(Math.round(n * 1000) / 1000);
}

function attrs(tag) {
  const out = {};
  const re = /([\w-]+)\s*=\s*"([^"]*)"/g;
  let m;
  while ((m = re.exec(tag)) !== null) out[m[1]] = m[2];
  return out;
}

function points(value) {
  const nums = (value.match(/-?\d*\.?\d+(?:e[-+]?\d+)?/gi) || []).map(Number);
  const pts = [];
  for (let i = 0; i + 1 < nums.length; i += 2) pts.push([nums[i], nums[i + 1]]);
  return pts;
}

/**
 * Elements that carry no stroke, so their absence from the output is correct.
 *
 * `metadata` is the interesting one. Some Arcticons files embed a C2PA content
 * provenance manifest, and it is enormous relative to the drawing: termux.svg
 * is 18,306 bytes, of which 17,930 are a base64 manifest and 376 are the icon.
 * Left in, a 13,623 glyph bundle would be mostly provenance data for art it is
 * not shipping.
 */
const IGNORED = new Set([
  'svg', 'defs', 'style', 'g', 'title', 'desc', 'metadata',
  'clippath', 'mask', 'lineargradient', 'radialgradient', 'stop', 'use', 'symbol',
]);

const CONVERTERS = {
  path: (a) => (a.d ? a.d.trim() : null),

  line: (a) =>
    `M${r(num(a.x1))},${r(num(a.y1))}L${r(num(a.x2))},${r(num(a.y2))}`,

  circle: (a) => {
    const cx = num(a.cx);
    const cy = num(a.cy);
    const rad = num(a.r);
    if (rad <= 0) return null;
    // Two half arcs. One full arc collapses to a no-op because its start and
    // end points are identical.
    return (
      `M${r(cx - rad)},${r(cy)}` +
      `A${r(rad)},${r(rad)} 0 1,0 ${r(cx + rad)},${r(cy)}` +
      `A${r(rad)},${r(rad)} 0 1,0 ${r(cx - rad)},${r(cy)}Z`
    );
  },

  ellipse: (a) => {
    const cx = num(a.cx);
    const cy = num(a.cy);
    const rx = num(a.rx);
    const ry = num(a.ry);
    if (rx <= 0 || ry <= 0) return null;
    return (
      `M${r(cx - rx)},${r(cy)}` +
      `A${r(rx)},${r(ry)} 0 1,0 ${r(cx + rx)},${r(cy)}` +
      `A${r(rx)},${r(ry)} 0 1,0 ${r(cx - rx)},${r(cy)}Z`
    );
  },

  rect: (a) => {
    const x = num(a.x);
    const y = num(a.y);
    const w = num(a.width);
    const h = num(a.height);
    if (w <= 0 || h <= 0) return null;
    // `rx` alone means both corners, per the SVG spec's auto rule. Missing it
    // produces square corners on a drawing whose author asked for round ones,
    // which reads as a slightly wrong icon rather than as a bug.
    const rx = Math.min(num(a.rx, num(a.ry)), w / 2);
    const ry = Math.min(num(a.ry, num(a.rx)), h / 2);
    if (rx <= 0 || ry <= 0) {
      return `M${r(x)},${r(y)}H${r(x + w)}V${r(y + h)}H${r(x)}Z`;
    }
    return (
      `M${r(x + rx)},${r(y)}` +
      `H${r(x + w - rx)}A${r(rx)},${r(ry)} 0 0,1 ${r(x + w)},${r(y + ry)}` +
      `V${r(y + h - ry)}A${r(rx)},${r(ry)} 0 0,1 ${r(x + w - rx)},${r(y + h)}` +
      `H${r(x + rx)}A${r(rx)},${r(ry)} 0 0,1 ${r(x)},${r(y + h - ry)}` +
      `V${r(y + ry)}A${r(rx)},${r(ry)} 0 0,1 ${r(x + rx)},${r(y)}Z`
    );
  },

  polyline: (a) => {
    const p = points(a.points || '');
    if (p.length < 2) return null;
    return `M${p.map(([x, y]) => `${r(x)},${r(y)}`).join('L')}`;
  },

  polygon: (a) => {
    const p = points(a.points || '');
    if (p.length < 3) return null;
    return `M${p.map(([x, y]) => `${r(x)},${r(y)}`).join('L')}Z`;
  },
};

/**
 * Every stroke in [svg], as path data strings.
 *
 * Returns `{ paths, skipped }`. `skipped` names any element type this does not
 * understand, so the build can COUNT them rather than dropping them quietly.
 * A converter that silently ignores an element it has never seen produces
 * icons missing a stroke, and there is no way to notice that across thirteen
 * thousand drawings except by counting.
 */
export function svgToPaths(svg) {
  const paths = [];
  const skipped = [];

  // `[\w:-]` rather than `\w`, so a namespaced element is matched WHOLE.
  // `\w` stops at the colon, so `<c2pa:manifest>` was reported as an unknown
  // element called `c2pa`, which is a confusing way to learn that some
  // Arcticons files carry embedded content-provenance manifests.
  const re = /<([\w:-]+)\b([^>]*?)\/?>/g;
  let m;
  while ((m = re.exec(svg)) !== null) {
    const name = m[1].toLowerCase();
    if (IGNORED.has(name) || name.includes(':')) continue;
    const convert = CONVERTERS[name];
    if (!convert) {
      skipped.push(name);
      continue;
    }
    const d = convert(attrs(m[2]));
    if (d) paths.push(d);
    else skipped.push(`${name}(degenerate)`);
  }

  return { paths, skipped };
}

/**
 * The viewBox extent, assuming a square box.
 *
 * Arcticons is 48 throughout, but a set that mixed 24 and 48 would render half
 * its icons at double size with no error anywhere, so it is read per file and
 * checked by the caller rather than assumed once.
 */
export function viewBoxOf(svg) {
  const vb = /viewBox\s*=\s*"([^"]*)"/i.exec(svg);
  if (!vb) return null;
  const n = vb[1].trim().split(/[\s,]+/).map(Number);
  if (n.length !== 4 || !n.every(Number.isFinite)) return null;
  // Only square boxes starting at the origin. Anything else needs a translate
  // that the renderer does not apply, and would draw off-centre.
  if (n[0] !== 0 || n[1] !== 0 || n[2] !== n[3]) return null;
  return n[2];
}

/** The declared stroke width, or null when the file relies on the SVG default. */
export function strokeWidthOf(svg) {
  const m = /\bstroke-width\s*[:=]\s*"?\s*([0-9]*\.?[0-9]+)\s*(px|pt|em|rem|%)?/i.exec(svg);
  if (!m) return null;
  const width = parseFloat(m[1]);

  // ─── ZERO IS NOT A WIDTH, IT IS AN ABSENCE ────────────────────────────────
  //
  // bolt.svg declares `stroke-width:0px`, which the SVG spec says renders
  // nothing. Recorded literally into a vector pack it produces an icon that
  // downloads, verifies, resolves and draws absolutely nothing, and there is no
  // way to tell that apart from a missing file by looking at a phone.
  //
  // A unit is also dropped rather than being treated as part of the number.
  // `0px` parsed as `0` is right; `1px` parsed as `1` is right because the
  // viewBox is unitless; anything in `em` or `%` is relative to a context the
  // renderer does not have, so it is refused rather than guessed at.
  if (width <= 0) return null;
  if (m[2] && !/^(px|pt)$/i.test(m[2])) return null;
  return width;
}
