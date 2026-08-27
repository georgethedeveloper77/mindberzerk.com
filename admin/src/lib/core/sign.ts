import 'server-only';

import {
  createHash,
  createPrivateKey,
  createPublicKey,
  sign as nodeSign,
  verify as nodeVerify,
} from 'node:crypto';

/**
 * PHASE C4 - pack and index signing, server-side.
 *
 * `import 'server-only'` IS THE LOAD-BEARING FIRST LINE. It makes the build fail
 * if any client component ever imports this module, however indirectly. Without
 * it, one stray import in a `'use client'` file would bundle the key-handling
 * code into the browser, and the failure is silent and total.
 *
 * ## This is a port of tools/sign-pack.mjs and must stay byte-compatible
 *
 * Three implementations of the manifest format now exist: this one, the Node
 * CLI, and `PackVerifierTest.buildPackInto` in Kotlin. The signature covers the
 * EXACT serialised bytes, so reordering a key or changing the indentation in
 * one of them produces packs that verify perfectly in the editor and fail with
 * BadSignature on every device.
 *
 * The CLI has no dependencies specifically so this port was a copy rather than
 * a rewrite. Keep them edited together.
 *
 * ## Never a re-serialisation
 *
 * The signature is over the bytes that get uploaded. Do not parse a manifest,
 * modify it, and re-stringify before signing: any JSON round trip normalises
 * whitespace and can reorder keys.
 */

const FORMAT_VERSION = 1;
export const MANIFEST_NAME = 'manifest.json';
export const SIGNATURE_NAME = 'manifest.sig';
export const INDEX_NAME = 'index.json';
export const INDEX_SIGNATURE_NAME = 'index.sig';

export const KNOWN_PACK_TYPES = [
  'theme', 'brand', 'hero', 'icon',
  // G Recovery content. Same signing path, same key, different payload:
  // registries and articles rather than themes and icons.
  'registry', 'article', 'guide',
] as const;
export type PackType = (typeof KNOWN_PACK_TYPES)[number];

/** Fixed-length DER prefix for a PKCS8 ed25519 private key. */
const PRIV_DER_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');

/** Fixed-length DER prefix for an SPKI ed25519 public key. */
const PUB_DER_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

/**
 * The public keys devices actually accept, by key id. MIRRORS
 * `PackKeys.ACCEPTED_HEX` in the launcher; keep them edited together.
 *
 * ─── WHY THIS TABLE EXISTS IN THE PANEL AT ALL ──────────────────────────────
 *
 * The first index this panel ever signed was signed with a PACK_SIGNING_KEY
 * that did not match this key, and the failure was the worst shape a failure
 * can take: publish reported success, the index was valid JSON, `keyId` SAID
 * mh-2026-07, and every device silently rejected the signature and showed an
 * empty catalogue. Nothing errored anywhere on either end.
 *
 * [assertTrustedKey] closes that hole: before anything is signed for a key id
 * this table knows, a probe is signed and verified against the pubkey devices
 * hold. A wrong secret now fails the publish with one precise sentence instead
 * of blanking every phone's store.
 *
 * A key id NOT in this table is deliberately let through unchecked: during a
 * rotation the panel may legitimately sign with a key the table has not
 * learned yet, and devices report those visibly as UnknownKey rather than
 * silently.
 */
const ACCEPTED_PUBKEYS: Record<string, string> = {
  'mh-2026-07': 'a5482077e685b0078706166a55836e094fd63143c926f097e7f340fe9781bea0',
};

const trustedKeyChecked = new Set<string>();

export function assertTrustedKey(keyId: string): void {
  if (trustedKeyChecked.has(keyId)) return;
  const acceptedHex = ACCEPTED_PUBKEYS[keyId];
  if (!acceptedHex) return;

  const pub = createPublicKey({
    key: Buffer.concat([PUB_DER_PREFIX, Buffer.from(acceptedHex, 'hex')]),
    format: 'der',
    type: 'spki',
  });
  const probe = Buffer.from('mindberzerk-signing-probe');
  const ok = nodeVerify(null, probe, pub, nodeSign(null, probe, privateKey()));
  if (!ok) {
    throw new Error(
      `PACK_SIGNING_KEY does not match the public key devices trust for key id '${keyId}'. ` +
        'Publishing with it would make every device silently reject the whole catalogue. ' +
        'Fix the Secret Manager value behind PACK_SIGNING_KEY in apphosting.yaml.',
    );
  }
  trustedKeyChecked.add(keyId);
}

function privateKey(): ReturnType<typeof createPrivateKey> {
  const hex = (process.env.PACK_SIGNING_KEY ?? '').trim();
  if (!/^[0-9a-f]{64}$/i.test(hex)) {
    // Length, not content, in the message. A key material fragment in a log is
    // a key material fragment in a log aggregator.
    throw new Error(
      `PACK_SIGNING_KEY must be 64 hex characters; got ${hex.length}. ` +
        'Check the Secret Manager binding in apphosting.yaml.',
    );
  }
  return createPrivateKey({
    key: Buffer.concat([PRIV_DER_PREFIX, Buffer.from(hex, 'hex')]),
    format: 'der',
    type: 'pkcs8',
  });
}

export const sha256 = (buf: Buffer) => createHash('sha256').update(buf).digest('hex');

/** Detached ed25519 signature over exactly [message]. Always 64 bytes. */
export function signBytes(message: Buffer): Buffer {
  return nodeSign(null, message, privateKey());
}

// ── validation, mirroring PackManifest.kt ────────────────────────────────────

/**
 * THE TRAVERSAL GATE, and it is here as well as on the device on purpose.
 *
 * `PackVerifier` would reject an unsafe path anyway, but by then the pack is
 * published, every device has failed to install it, and you are debugging from
 * the wrong end. Failing at publish time costs one error message.
 */
export function isSafeRelativePath(p: string): boolean {
  if (!p || p.length > 200) return false;
  if (p.startsWith('/') || p.endsWith('/')) return false;
  if (p.includes('\\') || p.includes('\0')) return false;
  if (p.length >= 2 && p[1] === ':') return false;
  return p
    .split('/')
    .every(
      (s) =>
        s &&
        s !== '.' &&
        s !== '..' &&
        !s.startsWith(' ') &&
        !s.endsWith(' ') &&
        /^[A-Za-z0-9._-]+$/.test(s),
    );
}

export function isSafePackId(id: string): boolean {
  return !!id && id.length <= 64 && !id.startsWith('.') && /^[a-z0-9._-]+$/.test(id);
}

/** Play's own product-ID rule. */
export function isSafeSku(sku: string): boolean {
  return /^[a-z0-9][a-z0-9_]{0,63}$/.test(sku);
}

// ── manifests ────────────────────────────────────────────────────────────────

export interface PackFile {
  path: string;
  bytes: Buffer;
}

export interface SignedPack {
  manifest: Buffer;
  signature: Buffer;
  /** Everything to upload, including the manifest and its signature. */
  objects: { path: string; bytes: Buffer; contentType: string }[];
}

/**
 * Build and sign a manifest over [files].
 *
 * Files are sorted by path so the same input always produces the same manifest.
 * Two-space indent, this key order, no trailing newline: matched by the CLI and
 * by the Kotlin test fixture.
 */
export function signPack(opts: {
  packType: PackType;
  packId: string;
  version: number;
  minAppVersion: number;
  keyId: string;
  files: PackFile[];
}): SignedPack {
  if (!isSafePackId(opts.packId)) throw new Error(`unsafe packId '${opts.packId}'`);
  if (!KNOWN_PACK_TYPES.includes(opts.packType)) {
    throw new Error(`unknown packType '${opts.packType}'`);
  }
  if (!Number.isInteger(opts.version) || opts.version < 1) {
    throw new Error('version must be an integer >= 1');
  }
  if (opts.files.length === 0) {
    throw new Error('a pack with no payload is not a pack');
  }

  assertTrustedKey(opts.keyId);

  const files = [...opts.files].sort((a, b) => a.path.localeCompare(b.path));

  const seen = new Set<string>();
  for (const f of files) {
    if (!isSafeRelativePath(f.path)) {
      throw new Error(`unsafe path '${f.path}' - the device will refuse this pack`);
    }
    // A duplicate path would let the manifest describe one file twice with two
    // different hashes: one to satisfy the check, one to describe what lands.
    if (seen.has(f.path)) throw new Error(`duplicate path '${f.path}'`);
    seen.add(f.path);
  }

  const entries = files
    .map(
      (f) =>
        `    {"path": "${f.path}", "size": ${f.bytes.length}, "sha256": "${sha256(f.bytes)}"}`,
    )
    .join(',\n');

  const manifest = Buffer.from(
    `{
  "formatVersion": ${FORMAT_VERSION},
  "packType": "${opts.packType}",
  "packId": "${opts.packId}",
  "version": ${opts.version},
  "minAppVersion": ${opts.minAppVersion},
  "keyId": "${opts.keyId}",
  "files": [
${entries}
  ]
}`,
    'utf8',
  );

  const signature = signBytes(manifest);

  return {
    manifest,
    signature,
    objects: [
      ...files.map((f) => ({
        path: f.path,
        bytes: f.bytes,
        contentType: contentTypeFor(f.path),
      })),
      { path: MANIFEST_NAME, bytes: manifest, contentType: 'application/json' },
      { path: SIGNATURE_NAME, bytes: signature, contentType: 'application/octet-stream' },
    ],
  };
}

// ── the index ────────────────────────────────────────────────────────────────

export interface IndexPack {
  packId: string;
  packType: PackType;
  path: string;
  version: number;
  minAppVersion: number;
  sizeBytes: number;
  title: string;
  summary: string;
  sku?: string | null;

  /**
   * The pack's colour, as `#rrggbb`.
   *
   * ─── THE ONE FIELD THE FOURTEEN DIFFER BY ─────────────────────────────────
   *
   * Every official icon pack points at `arcticons-line` for its 13,622 drawings
   * and supplies only a tint. The colour IS the product, so a catalogue that
   * lists products without it cannot describe what is for sale.
   *
   * What it buys concretely: the storefront previews a pack on the user's real
   * apps WITHOUT installing it. The geometry is already on the device, free and
   * required by whatever pack they own, so a preview needs the hex and nothing
   * else. Without this the device would have to download a product to show
   * someone what they would be buying.
   *
   * OMITTED when absent, never written as an empty string, for the same reason
   * `requires` is: `signIndex` emits whatever is defined, so `"tint": ""` would
   * enter the signed bytes of every pack that has no colour.
   */
  /**
   * Pack ids this one cannot work without.
   *
   * ─── A DERIVED PACK IS A POINTER ──────────────────────────────────────────
   *
   * An official icon pack is ~200 bytes naming a colour and extending
   * `arcticons-line`, which carries the drawings. Without this declaration the
   * downloader has no reason to fetch the base, so the pointer installs,
   * verifies, and renders nothing.
   *
   * OMITTED when empty rather than written as `[]`, because `signIndex` emits
   * whatever is defined and an empty array would enter the signed bytes of
   * every pack that depends on nothing.
   */
  requires?: string[];

  tint?: string | null;

  /**
   * The storefront preview: which shell to draw, and the six palette colours.
   *
   * ─── OPTIONAL, AND OMITTED ENTIRELY WHEN ABSENT ───────────────────────────
   *
   * The device already knows how to draw a miniature desktop for any shell; the
   * bundled distros have used that renderer since the storefront shipped. What
   * a CDN distro lacked was the DATA, so every downloadable pack fell back to a
   * flat rectangle, which made a paid distro the emptiest card on the screen.
   *
   * Roughly 120 bytes per entry.
   *
   * ─── AND IT CHANGES WHAT GETS SIGNED ──────────────────────────────────────
   *
   * The index is signed over its bytes, so an entry that gains fields is a
   * different document. That is fine because the panel re-signs on every
   * publish, but it does mean a pack only carries a preview once it has been
   * REPUBLISHED. Nothing published by `tools/publish-index.sh` or by an older
   * deploy gains one retroactively, and the device treats its absence exactly
   * as it treats an old index: falls back, draws nothing invented.
   *
   * Serialised as a nested `preview` object rather than six flat keys, because
   * an index entry is hand-read often enough that one named block beats six
   * prefixed siblings. The bridge flattens it on the far side, where a nested
   * class would have cost a Pigeon codec id.
   */
  preview?: IndexPreview;

  /**
   * The rows the storefront card names, in AUTHORED ORDER.
   *
   * ─── ORDER IS THE EDITORIAL DECISION ──────────────────────────────────────
   *
   * The card shows the first two `exclusive` rows and the detail page shows the
   * rest, so the order they are written in is the order they sell in. Sorting
   * this anywhere in the pipeline would quietly take that decision away from
   * whoever wrote them.
   *
   * ─── OMITTED WHEN ABSENT, EMPTY WHEN DELIBERATE ───────────────────────────
   *
   * Absent and `[]` are NOT the same thing here, which is unusual for this file
   * and is the reason this comment exists. Absent means the entry predates the
   * block, and the device keeps whatever its floor card authored. `[]` means
   * the entry has the block and names nothing, which is a real answer for a
   * free distro that is honestly just a palette. Collapsing them would make the
   * second impossible to express.
   *
   * Same republish caveat as `preview`: the index is signed over its bytes, so
   * a pack carries rows only once it has been republished.
   */
  features?: IndexFeature[];
}

/** One row on a storefront card. */
export interface IndexFeature {
  /** Two or three words. The bold half of the row. */
  title: string;

  /** One short sentence. It sits beside the title on a phone card. */
  body: string;

  /**
   * Whether the all-access settings can reproduce this.
   *
   * REQUIRED, not optional with a default. A missing answer reads as `true`,
   * which is the flattering direction, and this bool is the entire price
   * argument: a paid distro whose rows are all `false` is selling a palette.
   * Whoever writes the row states it.
   */
  exclusive: boolean;
}

/** The six values a card needs to draw a distro it has never installed. */
export interface IndexPreview {
  /** "gnome" | "plasma" | "aqua" | "tiling" | "tui". Picks the miniature. */
  shell: string;

  /**
   * Colours exactly as the theme.json authors them: "#RRGGBB" or "#AARRGGBB".
   *
   * Strings, not numbers. That is how the palette is written, how the panel
   * stores it, and how the device parses it, so passing it through untouched
   * keeps one representation rather than three.
   */
  bgTop: string;
  bgBottom: string;
  bar: string;
  dock: string;
  accent: string;

  /**
   * What the card should DRAW, computed at publish from the whole theme.json.
   *
   * ─── `shell` WAS NEVER ENOUGH, AND IT WAS THE ONLY SIGNAL ─────────────────
   *
   * The device picked its miniature from `shell` alone, because these six
   * fields are all the index carried: gnome drew a left dock, plasma a bottom
   * one, aqua a magnifying one. That was true when a shell decided everything
   * and wrong for TWELVE of fifteen distros once `dock`, `dockStyle`,
   * `dockReveal` and `homeLayout` became real. KDE and Mint were drawn with
   * docks they do not have; Kali and Manjaro with the dock on the wrong edge;
   * elementary and Pocket magnifying when neither swells.
   *
   * Shipping the four source fields instead would put the same switch on the
   * device as well, where the two copies would drift. This side holds the whole
   * spec and the device holds only the index, so the decision belongs here.
   *
   * OPTIONAL, so a pack published before the field still parses and falls back
   * to the shell guess on the device: exactly as wrong as it always was, which
   * is the right amount of wrong for an old pack.
   */
  layout?: string;
}

export interface IndexEntitlement {
  sku: string;
  title: string;
  summary: string;
  /** Pack ids, or ['*'] for everything present and future. */
  grants: string[];
}

/**
 * Build and sign the catalogue.
 *
 * [generatedAt] MUST be greater than whatever is currently live. The device
 * refuses an older index, which is what stops a stale edge or a replay from
 * hiding an update forever. The caller is expected to read the live index
 * first; this only enforces that the value is sane, because it cannot know what
 * is on the bucket.
 */
export function signIndex(opts: {
  generatedAt: number;
  keyId: string;
  packs: IndexPack[];
  entitlements?: IndexEntitlement[];
}): { index: Buffer; signature: Buffer } {
  if (!Number.isInteger(opts.generatedAt) || opts.generatedAt <= 0) {
    throw new Error('generatedAt must be positive unix seconds');
  }
  if (opts.packs.length === 0) throw new Error('an index with no packs is not useful');
  assertTrustedKey(opts.keyId);

  const seen = new Set<string>();
  for (const p of opts.packs) {
    if (!isSafePackId(p.packId)) throw new Error(`unsafe packId '${p.packId}'`);
    if (seen.has(p.packId)) throw new Error(`duplicate packId '${p.packId}'`);
    seen.add(p.packId);
    if (!isSafeRelativePath(p.path)) throw new Error(`unsafe path '${p.path}'`);
    if (p.sku && !isSafeSku(p.sku)) throw new Error(`unsafe sku '${p.sku}'`);
    // A dependency must be a real pack in the SAME index, and must not be
    // itself. A dangling requirement is a pack that can never install, and the
    // device's only symptom is a download that stops with no cause.
    for (const need of p.requires ?? []) {
      if (!isSafePackId(need)) throw new Error(`unsafe requires '${need}'`);
      if (need === p.packId) throw new Error(`'${p.packId}' requires itself`);
      // The dependency has to be IN THIS INDEX. Checked against the full pack
      // list rather than the entry, because a requirement pointing at something
      // that was never published, or was removed in the same edit, produces a
      // pack that can never install and a device whose only symptom is a
      // download that stops with no stated cause.
      if (!opts.packs.some((q) => q.packId === need)) {
        throw new Error(`'${p.packId}' requires '${need}', which is not in the index`);
      }
    }

    // Six hex digits, hash required. Checked HERE rather than on the device:
    // the panel can refuse a publish and ask the author to fix it, while a
    // phone reading a malformed colour can only shrug and draw nothing.
    if (p.tint && !/^#[0-9a-fA-F]{6}$/.test(p.tint)) {
      throw new Error(`unsafe tint '${p.tint}' on '${p.packId}'`);
    }
  }

  const seenSkus = new Set<string>();
  for (const e of opts.entitlements ?? []) {
    if (!isSafeSku(e.sku)) throw new Error(`unsafe sku '${e.sku}'`);
    if (seenSkus.has(e.sku)) throw new Error(`duplicate sku '${e.sku}'`);
    seenSkus.add(e.sku);
    if (e.grants.length === 0) throw new Error(`empty grants for '${e.sku}'`);
    for (const g of e.grants) {
      // A grant may name a pack that has not shipped yet, deliberately: a
      // bundle can be announced before its contents are live.
      if (g !== '*' && !isSafePackId(g)) throw new Error(`unsafe grant '${g}'`);
    }
  }

  /**
   * Refuse to sign an entry that lost a field on the way in.
   *
   * ─── WHY THIS EXISTS, AND WHAT IT ALREADY COST ────────────────────────────
   *
   * The rebuild above copies entries FIELD BY FIELD, deliberately: this is the
   * document a signature is verified over, so it must contain exactly what this
   * file intends and not whatever a caller hung on the object.
   *
   * The price of that safety is that a new field on `IndexPack` reaches here
   * and is thrown away unless someone remembers to name it. That is precisely
   * what happened with `preview`: the type, the upload, the Kotlin parse, the
   * bridge and the card were all correct, six themes published with no preview,
   * and nothing anywhere reported a problem. It took a manual trace to find.
   *
   * So the rebuild stays and the silence goes. If the source entry carries a
   * key the rebuilt one does not, that is a field someone added and forgot to
   * copy, and publishing is the wrong moment to be relaxed about it.
   *
   * ─── IT THROWS RATHER THAN WARNING ────────────────────────────────────────
   *
   * A warning in a server log is a warning nobody reads. A publish that fails
   * loudly costs one confused minute; a publish that succeeds while dropping a
   * field costs an afternoon, which is the measured price of the last one.
   *
   * Undefined values do not count as present, so an optional field left unset
   * is not a dropped field.
   */
  function assertNothingDropped(built: IndexPack, i: number): IndexPack {
    const source = opts.packs[i];

    // THROUGH `unknown`, because `IndexPack` is an interface with no index
    // signature and TypeScript refuses a direct assertion to a keyed record:
    // the two types do not overlap enough for it to assume the cast is safe.
    // Widening to `unknown` first is the sanctioned way to say "I am reading
    // this by key on purpose", and it is exactly what the compiler suggests.
    const asRecord = source as unknown as Record<string, unknown>;

    const lost = Object.keys(source).filter(
      (k) => asRecord[k] !== undefined && !(k in built),
    );

    // ─── AND ONE LEVEL INTO `preview` ─────────────────────────────────
    //
    // The check above compares TOP-LEVEL keys, and `preview` is spread whole,
    // so a field added inside it is invisible here: the object arrives, the
    // key is present, and whatever went missing inside it went missing
    // quietly. That is the same blindness that let six themes publish with no
    // preview at all before this guard existed, one level down.
    //
    // Only `preview`, and only one level. A general deep walk would need a
    // rule for every nested shape in the file and would fire on `features`,
    // where an empty array is a meaningful value rather than a loss.
    if (source.preview && built.preview) {
      const src = source.preview as unknown as Record<string, unknown>;
      const out = built.preview as unknown as Record<string, unknown>;
      for (const k of Object.keys(src)) {
        if (src[k] !== undefined && !(k in out)) lost.push(`preview.${k}`);
      }
    }

    if (lost.length > 0) {
      throw new Error(
        `buildIndex dropped ${lost.join(', ')} from '${source.packId}'. ` +
          'Every field is copied by name in this file; add the missing ones ' +
          'to the packs.map above.',
      );
    }
    return built;
  }

  const body = {
    formatVersion: FORMAT_VERSION,
    generatedAt: opts.generatedAt,
    keyId: opts.keyId,
    packs: opts.packs.map((p) => ({
      packId: p.packId,
      packType: p.packType,
      path: p.path,
      version: p.version,
      minAppVersion: p.minAppVersion,
      sizeBytes: p.sizeBytes,
      title: p.title,
      summary: p.summary,
      ...(p.sku ? { sku: p.sku } : {}),
      // Spread-when-present, matching `sku` and `requires`. A pack with no
      // colour must not carry `"tint": ""` into the signed bytes.
      ...(p.requires && p.requires.length > 0 ? { requires: p.requires } : {}),
      ...(p.tint ? { tint: p.tint } : {}),
      // ─── AND THE PREVIEW, WHICH THIS BLOCK SILENTLY DROPPED ─────────────
      //
      // Every entry is rebuilt here FIELD BY FIELD rather than spread, so a
      // field added to `IndexPack` reaches this function and is thrown away.
      // That is why six published themes had no preview while `uploadPack`
      // was correctly attaching one: type, upload, bridge and card were all
      // right, and the last step before signing quietly copied nine fields out
      // of ten.
      //
      // The rebuild itself is deliberate and stays: this is the document every
      // device verifies a signature over, so it must contain exactly what this
      // file intends and not whatever a caller happened to hang on the object.
      // The cost of that safety is precisely this: a new field is not published
      // until it is named HERE.
      ...(p.preview ? { preview: p.preview } : {}),
      // NAMED HERE, which is the whole point of the note above. `features` is
      // the first field added to `IndexPack` since `preview` was dropped, and
      // it would have been dropped in exactly the same way.
      //
      // `!= null` rather than truthy: `[]` is falsy and is a meaningful value
      // here, so a truthiness test would publish "names nothing deliberately"
      // as "predates the field" and the device would fall back to floor-card
      // rows the author had removed on purpose.
      ...(p.features != null ? { features: p.features } : {}),
    })).map(assertNothingDropped),
    // ALWAYS PRESENT, even when empty. Every index publish-index.sh ever wrote
    // carried this field, so the on-device parser has only ever been exercised
    // against indexes that have it; the one index that omitted it was also the
    // first one this panel signed, and untested shapes do not belong in a
    // document every phone parses. An empty list and an absent field mean the
    // same thing to us and are not guaranteed to mean the same thing to a
    // parser written against the other one.
    entitlements: opts.entitlements ?? [],
  };

  // Stringify ONCE and sign those exact bytes. The temptation is to pretty-print
  // for the bucket and sign a compact form; do not.
  const index = Buffer.from(JSON.stringify(body, null, 2) + '\n', 'utf8');
  return { index, signature: signBytes(index) };
}

function contentTypeFor(path: string): string {
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.webp')) return 'image/webp';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.ttf')) return 'font/ttf';
  return 'application/octet-stream';
}
