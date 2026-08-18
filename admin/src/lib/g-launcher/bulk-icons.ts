'use client';

import { gunzipSync, unzipSync } from 'fflate';

import { CORE_ROLES, matchStemStrict } from '@/lib/g-launcher/icon-pack';

/**
 * BULK INTAKE for icon art: expand what was picked, refuse what cannot ship.
 *
 * One module because three screens consume it (the icon builder, its unmatched
 * shelf, and the distro workspace's app grid) and the rules must not drift:
 * which extensions count as art, how an archive is walked, and which license
 * markers refuse a file are policy, not presentation.
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
 *
 * A NOTE ON WHAT THE SCAN DOES NOT CATCH, since it now matters. Arcticons
 * licenses its app under GPL-3.0 but its ICONS under CC BY-SA 4.0, and its
 * SVGs are bare path data carrying no license text at all. They scan clean and
 * the attestation above is then untrue of them, because BY-SA is neither CC0,
 * MIT, nor your own work: it permits commercial use and modification but
 * requires attribution and forces the same license onto anything derived. Until
 * a BY-SA attestation exists that captures the attribution string, sets like
 * that are drawing reference, exactly as Papirus is. The scan will not stop
 * you, so this comment has to.
 *
 * ─── AND WHY THIS FILE GREW AN ARCHIVE WALKER ───────────────────────────────
 *
 * `expandPicked` unzipped ONE level. Real icon sets do not arrive that way:
 * a release is a zip containing per-flavour zips, or a `.tar.gz`, or a folder
 * of `.tar.gz` files. A nested archive fell through the extension check, missed
 * `IMAGE_EXT`, and was counted in the anonymous `skipped` tally, so picking the
 * right file reported "1 file not SVG, PNG, WEBP, or JPEG, so skipped" and
 * looked like an empty archive. The walker below recurses to a fixed depth
 * instead, and names what it cannot open rather than counting it.
 */

/** Art the pipeline accepts. Everything else in a folder or archive is skipped. */
const IMAGE_EXT: Record<string, string> = {
  svg: 'image/svg+xml',
  png: 'image/png',
  webp: 'image/webp',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
};

/**
 * Non-image files worth carrying out of an archive.
 *
 * `appfilter.xml` is the answer key: every Android icon pack that targets Nova
 * or Lawnchair ships one, and it is an AUTHORED package-id-to-drawable map for
 * the pack's whole catalogue. Reading it turns "Phone" from a filename guess
 * into three exact hits. It is not art, so the image filter would have dropped
 * it, which is why the walker keeps a tiny allowlist.
 */
const KEEP_NAMES = new Set(['appfilter.xml']);

const LICENSE_BLOCK =
  /GNU General Public License|GNU Lesser General Public|\bL?GPL-?[23](\.\d+)?(-only|-or-later)?\b|creativecommons\.org\/licenses\//i;

/**
 * How far in the walker will chase an archive inside an archive, and how many
 * files it will carry out.
 *
 * BOTH ARE GUARDS, NOT BUDGETS. A malformed or hostile archive can nest
 * forever or expand without bound, and this runs in the author's browser tab.
 * Four levels covers every real shape (release zip, flavour zip, tarball,
 * one more for luck) and the file cap is well above the largest icon set in
 * existence, so hitting either means something is wrong rather than large.
 */
const MAX_DEPTH = 4;
const MAX_FILES = 40000;

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

/**
 * One piece of art, NOT YET RENDERED.
 *
 * ─── THE WHOLE REASON THIS TYPE EXISTS ──────────────────────────────────────
 *
 * The builder's `Entry` holds a File, a rendered Blob and a live object URL,
 * and draws a 48px `<img>` per row. That is correct for the forty icons a pack
 * ships and fatal for the fourteen thousand an icon set contains: three
 * artifacts per file in memory, fourteen thousand sequential decode and
 * re-encode passes, fourteen thousand DOM rows. The tab does not survive it.
 *
 * So unmatched art stops at bytes. It is searchable, it is previewable one
 * screenful at a time, and it becomes an `Entry` only when something claims it.
 * Nothing here is ever posted: a draft save and a publish both walk `entries`,
 * so raw art costs no request body no matter how much of it there is.
 */
export interface RawArt {
  /** Stable within one intake. Derived from the path, so it survives sorting. */
  id: string;
  /** Full path inside the archive, for display when two files share a name. */
  path: string;
  name: string;
  /** Lowercased basename with the extension and separators stripped. */
  stem: string;
  bytes: Uint8Array;
  mime: string;
  /**
   * The package this file belongs to according to `appfilter.xml`, or null.
   *
   * This is the payoff of reading the answer key. An unmatched row that knows
   * it is `com.spotify.music` can be claimed correctly with one tap, without
   * anyone typing a reverse-DNS string, and it is the pack's own author saying
   * so rather than this code guessing from a filename.
   */
  knownPkg: string | null;
}

export interface ArchiveIntake {
  /** Art with a confident slot: a core role id, or a package id from appfilter. */
  claimed: { slot: string; art: RawArt }[];
  /** Everything else. Bytes only, never rendered until claimed. */
  unclaimed: RawArt[];
  refused: RefusedFile[];
  /** Which tier did the matching, for the sentence shown to the author. */
  source: 'appfilter' | 'filenames' | 'none';
  /** Mappings read out of appfilter.xml; 0 when the archive had none. */
  appfilterCount: number;
  /** Files dropped because a better copy of the same stem was present. */
  deduped: number;
}

function extOf(name: string): string {
  const m = /\.([A-Za-z0-9]+)$/.exec(name);
  return m ? m[1].toLowerCase() : '';
}

function baseName(path: string): string {
  const parts = path.split('/');
  return parts[parts.length - 1];
}

function stemOf(name: string): string {
  return name
    .replace(/\.[^.]+$/, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

/** Junk an archive or folder walk must never surface as an entry. */
function isNoise(path: string): boolean {
  const base = baseName(path);
  return (
    path.endsWith('/') ||
    path.includes('__MACOSX/') ||
    base.startsWith('.') ||
    base === 'Thumbs.db'
  );
}

// ── archive sniffing ────────────────────────────────────────────────────────

/**
 * What this blob actually is, BY ITS BYTES.
 *
 * Extension-only detection is how a `.zip` that is really a tarball, or an
 * icon set someone renamed, becomes a silent skip. The magic numbers are
 * cheap and they are the truth. `.xz`, `.7z` and `.rar` are recognised
 * precisely so they can be REFUSED BY NAME with something actionable, rather
 * than counted anonymously: none of the three has a small decoder worth
 * shipping to a browser for a case this rare, and "expand it yourself" is a
 * fine answer when it is said out loud.
 */
type ArchiveKind = 'zip' | 'gzip' | 'tar' | 'xz' | '7z' | 'rar' | null;

function sniff(b: Uint8Array): ArchiveKind {
  if (b.length >= 4 && b[0] === 0x50 && b[1] === 0x4b) {
    // PK\x03\x04 local file, PK\x05\x06 empty archive, PK\x07\x08 spanned.
    if (b[2] === 3 || b[2] === 5 || b[2] === 7) return 'zip';
  }
  if (b.length >= 2 && b[0] === 0x1f && b[1] === 0x8b) return 'gzip';
  if (b.length >= 6 && b[0] === 0xfd && b[1] === 0x37 && b[2] === 0x7a && b[3] === 0x58 && b[4] === 0x5a) {
    return 'xz';
  }
  if (b.length >= 6 && b[0] === 0x37 && b[1] === 0x7a && b[2] === 0xbc && b[3] === 0xaf) return '7z';
  if (b.length >= 4 && b[0] === 0x52 && b[1] === 0x61 && b[2] === 0x72 && b[3] === 0x21) return 'rar';
  if (isTar(b)) return 'tar';
  return null;
}

/** ustar magic sits at offset 257 of the first header block. */
function isTar(b: Uint8Array): boolean {
  if (b.length < 265) return false;
  return (
    b[257] === 0x75 && b[258] === 0x73 && b[259] === 0x74 && b[260] === 0x61 && b[261] === 0x72
  );
}

function readAscii(b: Uint8Array, at: number, len: number): string {
  let out = '';
  for (let i = at; i < at + len && i < b.length; i++) {
    if (b[i] === 0) break;
    out += String.fromCharCode(b[i]);
  }
  return out;
}

/**
 * Read a POSIX tar, by hand.
 *
 * BY HAND BECAUSE fflate DOES NOT DO TAR. It handles zip, gzip and zlib, which
 * covers the container but not the format inside a `.tar.gz`, and pulling a
 * second archive dependency into the browser bundle to read 512-byte headers
 * with octal sizes is not a trade worth making. Regular files only: symlinks,
 * long-name extensions and directories are skipped, because an icon set has
 * none of them and guessing at GNU extensions is how a parser starts returning
 * garbage that looks like art.
 */
function untar(bytes: Uint8Array): { path: string; bytes: Uint8Array }[] {
  const out: { path: string; bytes: Uint8Array }[] = [];
  let off = 0;
  while (off + 512 <= bytes.length) {
    const head = bytes.subarray(off, off + 512);
    let allZero = true;
    for (let i = 0; i < 512; i++) {
      if (head[i] !== 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) break;

    const name = readAscii(head, 0, 100);
    const size = parseInt(readAscii(head, 124, 12).trim(), 8) || 0;
    const type = String.fromCharCode(head[156] || 0x30);
    const prefix = readAscii(head, 345, 155);
    const full = prefix ? `${prefix}/${name}` : name;
    off += 512;

    if (type === '0' || type === '\u0000') {
      out.push({ path: full, bytes: bytes.subarray(off, off + size) });
    }
    off += Math.ceil(size / 512) * 512;
  }
  return out;
}

interface Found {
  path: string;
  bytes: Uint8Array;
}

interface WalkState {
  out: Found[];
  refused: RefusedFile[];
  skipped: number;
  capped: boolean;
}

/**
 * Chase [bytes] as an archive, appending every image and allowlisted file.
 *
 * Recursion is bounded by MAX_DEPTH and the running file count by MAX_FILES,
 * and both stop QUIETLY-BUT-NAMED: the caller gets a refusal line saying which
 * archive was too deep or where the cap was hit, because a truncated intake
 * that says nothing is the same bug as the one this replaced.
 */
function walk(label: string, bytes: Uint8Array, depth: number, st: WalkState): void {
  if (st.capped) return;
  if (depth > MAX_DEPTH) {
    st.refused.push({
      name: label,
      reason: `is nested more than ${MAX_DEPTH} archives deep, so it was not opened.`,
    });
    return;
  }

  const kind = sniff(bytes);

  if (kind === 'xz' || kind === '7z' || kind === 'rar') {
    st.refused.push({
      name: label,
      reason: `is a ${kind.toUpperCase()} archive, which cannot be opened in the browser. Expand it and pick the folder instead.`,
    });
    return;
  }

  let entries: { path: string; bytes: Uint8Array }[];

  if (kind === 'zip') {
    try {
      const map = unzipSync(bytes);
      entries = Object.entries(map).map(([path, b]) => ({ path, bytes: b }));
    } catch {
      st.refused.push({ name: label, reason: 'could not be read as a zip.' });
      return;
    }
  } else if (kind === 'gzip') {
    let inner: Uint8Array;
    try {
      inner = gunzipSync(bytes);
    } catch {
      st.refused.push({ name: label, reason: 'could not be decompressed.' });
      return;
    }
    // A `.tar.gz` is a tar once unwrapped; a `.svg.gz` is one file. Sniffing
    // the result rather than trusting the double extension means `.tgz` and a
    // mislabelled `.gz` both land correctly.
    if (isTar(inner)) {
      entries = untar(inner);
    } else {
      walk(label.replace(/\.(gz|tgz)$/i, ''), inner, depth + 1, st);
      return;
    }
  } else if (kind === 'tar') {
    entries = untar(bytes);
  } else {
    // Not an archive at all. The caller only reaches here for a picked file
    // whose extension suggested otherwise, so say so rather than swallow it.
    st.refused.push({ name: label, reason: 'is not a zip, tar, or gzip archive.' });
    return;
  }

  for (const e of entries) {
    if (st.capped) return;
    if (isNoise(e.path)) continue;

    const base = baseName(e.path);
    const ext = extOf(base);

    if (IMAGE_EXT[ext] || KEEP_NAMES.has(base.toLowerCase())) {
      if (st.out.length >= MAX_FILES) {
        st.capped = true;
        st.refused.push({
          name: label,
          reason: `holds more than ${MAX_FILES} files, so intake stopped there. Pick a subfolder instead.`,
        });
        return;
      }
      st.out.push({ path: `${label}/${e.path}`, bytes: e.bytes });
      continue;
    }

    if (sniff(e.bytes)) {
      walk(`${label}/${e.path}`, e.bytes, depth + 1, st);
      continue;
    }

    st.skipped++;
  }
}

/** Collect every picked File into flat Found rows, recursing into archives. */
async function gather(picked: File[]): Promise<WalkState> {
  const st: WalkState = { out: [], refused: [], skipped: 0, capped: false };

  for (const f of picked) {
    if (st.capped) break;
    const rel = (f as File & { webkitRelativePath?: string }).webkitRelativePath || f.name;
    const base = baseName(rel);
    const ext = extOf(base);

    if (IMAGE_EXT[ext] || KEEP_NAMES.has(base.toLowerCase())) {
      if (isNoise(rel)) continue;
      st.out.push({ path: rel, bytes: new Uint8Array(await f.arrayBuffer()) });
      continue;
    }

    const bytes = new Uint8Array(await f.arrayBuffer());
    if (sniff(bytes)) {
      walk(f.name, bytes, 1, st);
      continue;
    }

    st.skipped++;
  }

  return st;
}

function scanSvgBytes(name: string, bytes: Uint8Array, refused: RefusedFile[]): boolean {
  const hit = LICENSE_BLOCK.exec(new TextDecoder().decode(bytes));
  if (!hit) return true;
  refused.push({
    name,
    reason:
      `carries a license marker ('${hit[0]}'). GPL and CC-licensed sets like Papirus ` +
      'and Numix cannot ship over the CDN. CC0, MIT, or your own work only.',
  });
  return false;
}

function toFile(art: RawArt): File {
  // A COPY, not the view. fflate hands back subarrays over one big buffer, and
  // a Blob built from a view keeps that whole buffer alive: claiming six icons
  // out of a 14,000-file archive would pin the entire archive in memory.
  return new File([new Uint8Array(art.bytes)], art.name, { type: art.mime });
}

/**
 * Flatten a pick into renderable image files.
 *
 * UNCHANGED SIGNATURE, deliberately. The distro workspace's app grid calls
 * this and expects `{ files, refused }`, so the archive walker went in
 * underneath rather than through the callers. Nested archives now work for
 * that screen too, which is a fix it never asked for and wanted anyway.
 *
 * Use `expandArchive` instead for anything that might be a whole icon set:
 * this one renders nothing, but it does build a File per image, and at 14,000
 * files that is 14,000 Blobs the caller has no way to defer.
 */
export async function expandPicked(picked: File[]): Promise<ExpandedIntake> {
  const st = await gather(picked);
  const files: File[] = [];

  for (const found of st.out) {
    const base = baseName(found.path);
    const ext = extOf(base);
    const mime = IMAGE_EXT[ext];
    if (!mime) continue; // appfilter.xml and friends are not art
    if (ext === 'svg' && !scanSvgBytes(found.path, found.bytes, st.refused)) continue;
    files.push(new File([new Uint8Array(found.bytes)], base, { type: mime }));
  }

  if (st.skipped > 0) {
    st.refused.push({
      name: `${st.skipped} file${st.skipped === 1 ? '' : 's'}`,
      reason: 'not SVG, PNG, WEBP, or JPEG, so skipped.',
    });
  }

  return { files, refused: st.refused };
}

// ── the answer key ──────────────────────────────────────────────────────────

/**
 * Parse `appfilter.xml` into package id -> drawable name.
 *
 * Regex rather than DOMParser, for two reasons. The format is flat and
 * well-known, and an icon pack's appfilter runs to 15,000 elements, which is a
 * DOM tree nobody needs built. Attribute ORDER IS NOT ASSUMED: the element is
 * matched first and each attribute pulled out of it separately, because
 * `drawable` before `component` is common and a single combined pattern
 * silently matches half a file.
 *
 * `<calendar>` and `<scale>` elements are ignored. The first is a dynamic
 * date-icon prefix that has no single drawable, and the second is a global
 * factor this pipeline has no equivalent for.
 */
export function parseAppFilter(xml: string): Map<string, string> {
  const out = new Map<string, string>();
  const item = /<item\b([^>]*)>/gi;
  let m: RegExpExecArray | null;
  while ((m = item.exec(xml)) !== null) {
    const attrs = m[1];
    const component = /component\s*=\s*"([^"]*)"/i.exec(attrs)?.[1];
    const drawable = /drawable\s*=\s*"([^"]*)"/i.exec(attrs)?.[1];
    if (!component || !drawable) continue;
    // `ComponentInfo{com.whatsapp/com.whatsapp.Main}`, or a bare `pkg/Class`.
    const pkg =
      /\{([^/}]+)\//.exec(component)?.[1] ?? /^:?([A-Za-z0-9_.]+)\//.exec(component)?.[1] ?? null;
    if (!pkg) continue;
    // First wins. A pack listing several activities of one app points them all
    // at the same drawable in practice, and where it does not, the launcher
    // resolves by package, so the first is the one that would be used.
    if (!out.has(pkg)) out.set(pkg, drawable.toLowerCase());
  }
  return out;
}

/**
 * The core role a filename names, by EXACT stem equality.
 *
 * ─── WHY THIS IS NOT `guessPackage` ─────────────────────────────────────────
 *
 * `guessPackage` matches `stem.includes(hint)`, which is right for a handful of
 * hand-picked files and destructive on a real set. Measured against plausible
 * icon-pack filenames, `includes` sends `play_store`, `playstation`, `shopee`,
 * `storeman`, `softwareupdate`, `google_play_books` and `google_play_games` all
 * to `com.android.vending`; `snapchat`, `wechat` and `sms_backup` to Messages;
 * `call_of_duty` to the dialer; `keepassdx` and `notepadpp` to Keep. Every one
 * of those is a DUPLICATE, and `ready` requires `duplicates.size === 0`, so a
 * bulk pick greys out Publish with no indication which of thousands of rows
 * did it.
 *
 * Exact equality is the fix, and it is only safe now that unmatched art has
 * somewhere to go. Before the shelf existed, a miss meant the file vanished,
 * so loose matching was the lesser evil. Now a miss is a searchable row that
 * knows its own package id, which is strictly better than a wrong assignment
 * nobody can find.
 */
export function exactSlot(fileName: string): string | null {
  const m = matchStemStrict(fileName);
  if (m.kind === 'role') return m.role;
  if (m.kind === 'package') return m.pkg;
  // `ambiguous` deliberately falls through to null. `memo` is a hint on both
  // Recorder and Notes, and picking whichever role came first in the array
  // would be an arbitrary answer wearing the costume of a confident one. The
  // file goes to the shelf, where it is searchable and one tap from correct.
  return null;
}

/** Scalable beats raster, and a bigger raster beats a smaller one. */
function scoreOf(path: string): number {
  const px = /(?:^|\/)(\d+)x\1(?:@2x)?\//.exec(path);
  const n = px ? parseInt(px[1], 10) : 0;
  if (path.toLowerCase().endsWith('.svg')) return 100000 + n;
  return n || 1;
}

/**
 * Expand a pick into claimed slots plus an unclaimed shelf.
 *
 * ─── THREE TIERS, AND THE ORDER MATTERS ─────────────────────────────────────
 *
 *   1. `appfilter.xml`, when the archive has one. The pack's own author saying
 *      which drawable serves which package. Not a guess at all.
 *   2. Exact filename stems against the core roles, for the common case of a
 *      zip that is just icons and nothing else.
 *   3. Everything else, kept as bytes, tagged with its appfilter package where
 *      one is known.
 *
 * Tier 1 first because tier 2 cannot be trusted over it: a set whose Files
 * icon is called `nautilus.svg` matches nothing by stem and everything by
 * appfilter, and where both fire they agree.
 *
 * ONE ROLE TAKES ONE PIECE OF ART. A role lists several packages and a pack may
 * point them at different drawables (`phone` for the AOSP dialer,
 * `samsung_phone` for Samsung's), but the pack format maps many packages onto
 * one file and `expandRoleEntries` is what does it. So the first package in
 * role order that resolves wins, and the rest inherit its art, which is the
 * same rule the builder has always applied to a hand-drawn icon.
 */
export async function expandArchive(picked: File[]): Promise<ArchiveIntake> {
  const st = await gather(picked);
  const refused = st.refused;

  // ── the answer key, before anything is matched ───────────────────────────
  let filter = new Map<string, string>();
  for (const f of st.out) {
    if (baseName(f.path).toLowerCase() !== 'appfilter.xml') continue;
    const parsed = parseAppFilter(new TextDecoder().decode(f.bytes));
    // Several flavours in one release each ship an appfilter. Merged rather
    // than last-wins, because a flavour may cover an app the others do not.
    for (const [pkg, drawable] of parsed) if (!filter.has(pkg)) filter.set(pkg, drawable);
  }
  const appfilterCount = filter.size;

  // ── art, deduplicated by stem ────────────────────────────────────────────
  //
  // A desktop-style set ships the same icon at 16, 24, 48 and scalable, and a
  // release zip may carry several flavours of it. Keeping all of them turns
  // 14,000 icons into 60,000 shelf rows that are mostly the same picture, so
  // one best copy per stem survives and the rest are counted.
  const best = new Map<string, { found: Found; score: number }>();
  let deduped = 0;
  for (const found of st.out) {
    const base = baseName(found.path);
    const ext = extOf(base);
    const mime = IMAGE_EXT[ext];
    if (!mime) continue;
    if (ext === 'svg' && !scanSvgBytes(found.path, found.bytes, refused)) continue;

    const stem = stemOf(base);
    if (!stem) continue;
    const score = scoreOf(found.path);
    const prev = best.get(stem);
    if (!prev) {
      best.set(stem, { found, score });
      continue;
    }
    deduped++;
    if (score > prev.score) best.set(stem, { found, score });
  }

  // Drawable name -> package, so an unclaimed row can carry its own id.
  const byDrawable = new Map<string, string>();
  for (const [pkg, drawable] of filter) {
    const key = stemOf(drawable);
    if (!byDrawable.has(key)) byDrawable.set(key, pkg);
  }

  const art: RawArt[] = [];
  for (const [stem, { found }] of best) {
    const base = baseName(found.path);
    art.push({
      id: found.path,
      path: found.path,
      name: base,
      stem,
      bytes: found.bytes,
      mime: IMAGE_EXT[extOf(base)],
      knownPkg: byDrawable.get(stem) ?? null,
    });
  }
  const byStem = new Map(art.map((a) => [a.stem, a]));

  // ── tier 1 ───────────────────────────────────────────────────────────────
  const claimed: { slot: string; art: RawArt }[] = [];
  const takenSlots = new Set<string>();
  const usedArt = new Set<string>();

  if (filter.size > 0) {
    for (const role of CORE_ROLES) {
      for (const pkg of role.packages) {
        const drawable = filter.get(pkg);
        if (!drawable) continue;
        const hit = byStem.get(stemOf(drawable));
        if (!hit || usedArt.has(hit.id)) continue;
        claimed.push({ slot: role.id, art: hit });
        takenSlots.add(role.id);
        usedArt.add(hit.id);
        break;
      }
    }
  }

  // ── tier 2 ───────────────────────────────────────────────────────────────
  for (const a of art) {
    if (usedArt.has(a.id)) continue;
    const slot = exactSlot(a.name);
    if (!slot || takenSlots.has(slot)) continue;
    claimed.push({ slot, art: a });
    takenSlots.add(slot);
    usedArt.add(a.id);
  }

  // ── tier 3 ───────────────────────────────────────────────────────────────
  const unclaimed = art.filter((a) => !usedArt.has(a.id));

  if (st.skipped > 0) {
    refused.push({
      name: `${st.skipped} file${st.skipped === 1 ? '' : 's'}`,
      reason: 'not SVG, PNG, WEBP, or JPEG, so skipped.',
    });
  }

  return {
    claimed,
    unclaimed,
    refused,
    source: appfilterCount > 0 ? 'appfilter' : claimed.length > 0 ? 'filenames' : 'none',
    appfilterCount,
    deduped,
  };
}

/** A shelf row becoming a real entry. One place, so the two callers agree. */
export function fileFromArt(art: RawArt): File {
  return toFile(art);
}

/** The attestation line, one copy, so the two builders cannot word it apart. */
export const LICENSE_ATTESTATION =
  'These icons are CC0, MIT, or my own work. GPL sets (Papirus, Numix) cannot ship over the CDN.';

// ── licence lanes ───────────────────────────────────────────────────────────

/**
 * THERE ARE THREE LANES, AND THE PANEL ONLY HAD TWO.
 *
 * The single checkbox says "CC0, MIT, or my own work", and the scan refuses
 * anything carrying a `creativecommons.org/licenses/` marker. Between those two
 * sits a category the panel could neither accept nor honestly refuse: art under
 * CC BY or CC BY-SA.
 *
 * It is not a hypothetical. Arcticons, the largest free line-icon set in
 * existence, licenses its APP under GPL-3.0 and its ICONS under CC BY-SA 4.0,
 * and its SVGs are bare path data that carry no licence text at all. So they
 * sail through the scan and land under a checkbox that says they are CC0. The
 * gate reported clean on the exact case it exists to catch.
 *
 * ─── WHAT BY-SA COSTS, STATED PLAINLY ───────────────────────────────────────
 *
 * Commercial use is permitted and selling is permitted. Two conditions attach.
 * ATTRIBUTION must travel with the art, which is why this lane demands a
 * non-empty credit line and why that line is written into `pack.json` rather
 * than kept in the panel. SHARE-ALIKE means an adapted set (a recolour is an
 * adaptation) must itself be BY-SA, so the art in that pack is redistributable
 * by whoever receives it. That does not touch the launcher: CC has no linking
 * clause and the icons ship as separate files, so the app stays proprietary.
 * It means the ART is not exclusive.
 *
 * ─── AND WHY GPL STILL HAS NO LANE ──────────────────────────────────────────
 *
 * Not an oversight. GPL's reciprocity reaches the distribution as a whole in a
 * way BY-SA's does not, and a signed pack behind an entitlement is exactly the
 * arrangement it is written to prevent. Papirus and Numix stay reference-only,
 * which is what `tools/iconlab.mjs` is for.
 */
export type LicenseLane = 'own' | 'attributed';

export interface LicenseLaneSpec {
  id: LicenseLane;
  label: string;
  /** Whether a credit line must be supplied before publish is allowed. */
  needsAttribution: boolean;
  note: string;
}

export const LICENSE_LANES: LicenseLaneSpec[] = [
  {
    id: 'own',
    label: 'CC0, MIT, or my own work',
    needsAttribution: false,
    note: 'Nothing has to travel with the pack. This is the usual case and the one every pack published so far has used.',
  },
  {
    id: 'attributed',
    label: 'CC BY or CC BY-SA, credited',
    needsAttribution: true,
    note: 'The credit below is written into pack.json and ships with the art. Under BY-SA the icons in this pack stay redistributable by whoever receives them, including a recoloured set, because a recolour is an adaptation.',
  },
];

/**
 * Is this attestation complete enough to publish?
 *
 * Returns the reason it is not, or null when it is. A string rather than a
 * boolean because the publish button is disabled by it, and a disabled button
 * with no sentence beside it is this codebase's most-repeated bug.
 */
export function licenseProblem(lane: LicenseLane, attribution: string): string | null {
  const spec = LICENSE_LANES.find((l) => l.id === lane);
  if (!spec) return 'Pick how this art is licensed.';
  if (spec.needsAttribution && attribution.trim() === '') {
    return 'CC BY and CC BY-SA both require a credit line, and it has to ship with the pack.';
  }
  return null;
}
