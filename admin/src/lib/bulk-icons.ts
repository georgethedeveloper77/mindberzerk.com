'use client';

import { unzipSync } from 'fflate';

/**
 * BULK INTAKE for icon art: expand what was picked, refuse what cannot ship.
 *
 * One module because two screens consume it (the icon builder and the distro
 * workspace's app grid) and the rules must not drift: which extensions count
 * as art, how a zip is walked, and which license markers refuse a file are
 * policy, not presentation.
 *
 * ─── THE LICENSE GATE, AND ITS HONEST LIMITS ────────────────────────────────
 *
 * Papirus and Numix are GPL-3.0 and CANNOT ship over the CDN: a pack is
 * distribution, not personal use. Wholesale imports of desktop icon themes are
 * exactly how those sets would walk in, so intake scans every SVG's text for
 * GPL and Creative Commons license markers and refuses matches BY NAME, with
 * the reason, before they ever become entries.
 *
 * The scan is a tripwire, not a proof. Raster files carry no text to scan,
 * and a stripped SVG scans clean, which is why the builders also require the
 * human attestation checkbox before publishing. The pair is the gate: the
 * scan catches the honest mistake of dragging a Papirus folder in, the
 * checkbox makes the remaining claim explicitly yours.
 *
 * CC0 does not trip the scan on purpose: its marker is
 * `creativecommons.org/publicdomain/zero`, a different path from `/licenses/`,
 * and CC0 is precisely what simple-icons ships and what this pipeline exists
 * to accept.
 */

/** Art the pipeline accepts. Everything else in a folder or zip is skipped. */
const IMAGE_EXT: Record<string, string> = {
  svg: 'image/svg+xml',
  png: 'image/png',
  webp: 'image/webp',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
};

const LICENSE_BLOCK =
  /GNU General Public License|GNU Lesser General Public|\bL?GPL-?[23](\.\d+)?(-only|-or-later)?\b|creativecommons\.org\/licenses\//i;

export interface RefusedFile {
  name: string;
  reason: string;
}

export interface ExpandedIntake {
  /** Ready for the render pipeline, in the order they arrived. */
  files: File[];
  /** Named refusals and skips; empty means everything picked was taken. */
  refused: RefusedFile[];
}

function extOf(name: string): string {
  const m = /\.([A-Za-z0-9]+)$/.exec(name);
  return m ? m[1].toLowerCase() : '';
}

function baseName(path: string): string {
  const parts = path.split('/');
  return parts[parts.length - 1];
}

/** Junk a zip or folder walk must never surface as an entry. */
function isNoise(path: string): boolean {
  const base = baseName(path);
  return (
    path.endsWith('/') ||
    path.includes('__MACOSX/') ||
    base.startsWith('.') ||
    base === 'Thumbs.db'
  );
}

async function scanSvg(name: string, text: string, refused: RefusedFile[]): Promise<boolean> {
  const hit = LICENSE_BLOCK.exec(text);
  if (!hit) return true;
  refused.push({
    name,
    reason:
      `carries a license marker ('${hit[0]}'). GPL and CC-licensed sets like Papirus ` +
      'and Numix cannot ship over the CDN. CC0, MIT, or your own work only.',
  });
  return false;
}

/**
 * Flatten a pick into renderable image files.
 *
 * Accepts whatever an input hands over: loose images, a folder pick (which
 * arrives as its files, paths in `webkitRelativePath`), and `.zip` archives,
 * which are expanded in the browser. Non-image files are skipped quietly by
 * count; license-marked SVGs are refused loudly by name. Order is preserved
 * so the review list reads like the folder did.
 */
export async function expandPicked(picked: File[]): Promise<ExpandedIntake> {
  const files: File[] = [];
  const refused: RefusedFile[] = [];
  let skipped = 0;

  for (const f of picked) {
    const ext = extOf(f.name);

    if (ext === 'zip') {
      let entries: Record<string, Uint8Array>;
      try {
        entries = unzipSync(new Uint8Array(await f.arrayBuffer()));
      } catch {
        refused.push({ name: f.name, reason: 'could not be read as a zip.' });
        continue;
      }
      for (const [path, bytes] of Object.entries(entries)) {
        if (isNoise(path)) continue;
        const zext = extOf(path);
        const mime = IMAGE_EXT[zext];
        if (!mime) {
          skipped++;
          continue;
        }
        const name = baseName(path);
        if (zext === 'svg') {
          const ok = await scanSvg(`${f.name}/${path}`, new TextDecoder().decode(bytes), refused);
          if (!ok) continue;
        }
        files.push(new File([bytes.slice().buffer as ArrayBuffer], name, { type: mime }));
      }
      continue;
    }

    const rel = (f as File & { webkitRelativePath?: string }).webkitRelativePath || f.name;
    if (isNoise(rel)) continue;
    const mime = IMAGE_EXT[ext];
    if (!mime) {
      skipped++;
      continue;
    }
    if (ext === 'svg') {
      const ok = await scanSvg(rel, await f.text(), refused);
      if (!ok) continue;
    }
    files.push(f);
  }

  if (skipped > 0) {
    refused.push({
      name: `${skipped} file${skipped === 1 ? '' : 's'}`,
      reason: 'not SVG, PNG, WEBP, or JPEG, so skipped.',
    });
  }

  return { files, refused };
}

/** The attestation line, one copy, so the two builders cannot word it apart. */
export const LICENSE_ATTESTATION =
  'These icons are CC0, MIT, or my own work. GPL sets (Papirus, Numix) cannot ship over the CDN.';
