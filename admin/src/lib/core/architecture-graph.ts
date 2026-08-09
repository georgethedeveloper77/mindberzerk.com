import 'server-only';

import { indexIsSigned, readLiveIndex } from '@/lib/core/catalogue';
import { cdnBase } from '@/lib/core/cdn';
import { isAppId } from '@/lib/core/registry';

/**
 * THE ARCHITECTURE MAP, as data.
 *
 * ## Why this is code and the prose is markdown
 *
 * `docs/<app>/architecture.md` holds the explanation and the mermaid diagrams,
 * and it stays markdown because it belongs in a diff beside the code it
 * describes. This is the other half: a graph whose nodes carry LIVE STATUS, and
 * status cannot come from a document. A node saying "credential refused" is
 * reading the same bucket every other screen reads.
 *
 * So the page renders both: this map on top, that document underneath.
 *
 * ## Every node names its source files
 *
 * The point of a map is to get from "something is wrong at this step" to the
 * file that implements it without a search. Paths are relative to the repo
 * root, and a node in the launcher app says so, because those live in a
 * different tree from the panel.
 *
 * ## And every node names the invariant that bites
 *
 * These are the rules that have cost real time: the signature covering exact
 * bytes, generatedAt having to increase, the cache being keyed by pack id
 * rather than version, bundled being checked before installed. They are
 * attached to the step they belong to rather than collected in a list nobody
 * reads twice.
 *
 * ## Positions are hand-placed, deliberately
 *
 * An auto-layout would re-arrange the map every time a node was added, and the
 * value of a diagram you look at weekly is that it stays where you left it. The
 * coordinates are in a 780 by 560 space the client scales.
 */

export type NodeState = 'ok' | 'bad' | 'unknown';

/**
 * WHAT A NODE IS, drawn rather than read.
 *
 * A map is scanned before it is read, and a shape carries "this is storage" or
 * "this is a device" faster than a label does. The set is deliberately small:
 * one icon per KIND of thing, reused across views, so `box` always means a pack
 * payload and `key` always means a signature no matter which tab you are on.
 *
 * Adding a twenty-second icon should feel like a decision. If a node does not
 * fit one of these, the question is usually whether it is really two nodes.
 */
export type IconKey =
  | 'edit'
  | 'key'
  | 'box'
  | 'list'
  | 'cloud'
  | 'refresh'
  | 'shield'
  | 'folder'
  | 'layers'
  | 'files'
  | 'doc'
  | 'download'
  | 'merge'
  | 'sliders'
  | 'grid'
  | 'phone'
  | 'tag'
  | 'database'
  | 'lock'
  | 'globe'
  | 'trash';

export interface GraphNode {
  key: string;
  title: string;
  /** Drawn on the node, so its kind is legible before the label is read. */
  icon: IconKey;
  /** One line under the title. Usually a path or an identifier. */
  sub: string;
  /** Hand-placed, in the 780x560 canvas space. */
  x: number;
  y: number;
  /** Which column this belongs to, for the lane it sits in. */
  lane: 'panel' | 'store' | 'device';
  what: string;
  io: [string, string][];
  /** The rule that bites at this step. */
  invariant: string;
  /** Repo-relative source paths. */
  files: string[];
  /** True when those files live in the launcher app rather than the panel. */
  inLauncher?: boolean;
  /** Where to go to do something about it. */
  goto?: { label: string; href: string };
}

export interface GraphEdge {
  from: string;
  to: string;
  /** An orthogonal path in canvas space. Drawn as given. */
  d: string;
  /** Which node's state decides whether this edge is flowing. */
  gate?: string;
}

export interface Graph {
  nodes: GraphNode[];
  edges: GraphEdge[];
}

/**
 * FOUR VIEWS, because one canvas cannot answer four questions.
 *
 *   delivery  what happens between pressing publish and a phone redrawing
 *   signing   which bytes are covered by which signature, and in what order
 *   device    what the launcher does with a pack once it has one
 *   bucket    what is stored where, and which of it can be deleted
 *
 * They share a status map, so a node key is unique across all four and is
 * prefixed by its view where it could collide.
 */
export type ViewKey = 'delivery' | 'signing' | 'device' | 'bucket';

export interface GraphView {
  key: ViewKey;
  label: string;
  /** One line under the tabs, saying what this view is for. */
  blurb: string;
  graph: Graph;
}

/** Live status per node key, resolved separately from the shape. */
export type GraphStatus = Record<string, { state: NodeState; note: string; live: [string, string][] }>;

// ── the launcher's delivery graph ───────────────────────────────────────────

function launcherGraph(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'builder',
      icon: 'edit',
      title: 'Distro builder',
      sub: `/apps/${app}/distros/builder`,
      x: 46,
      y: 78,
      lane: 'panel',
      what: 'Where a distro is authored: palette, layout, boot log, wallpapers and its icon pack. Nothing here reaches a device until publish is pressed.',
      io: [
        ['reads', 'admin/theme-drafts.json'],
        ['writes', 'draft plus its assets'],
        ['on publish', 'distro-publish'],
      ],
      invariant:
        'A draft publishes nothing. The pack version only moves on a publish, and a pack only reaches a phone when that number increases.',
      files: [
        'admin/src/components/distro-builder/DistroWorkspace.tsx',
        'admin/src/app/apps/[app]/distros/builder/page.tsx',
        'admin/src/app/apps/[app]/distros/actions.ts',
        'admin/src/lib/g-launcher/theme-spec.ts',
        'admin/src/lib/g-launcher/themes.ts',
      ],
      goto: { label: 'Open Distros', href: `/apps/${app}/distros` },
    },
    {
      key: 'sign',
      icon: 'key',
      title: 'publish-core and sign',
      sub: 'ed25519, one path for every publish',
      x: 46,
      y: 174,
      lane: 'panel',
      what: 'Builds the manifest, signs it, uploads the payload, then merges and re-signs the index. Every publish goes through here, so a pack cannot be written by a route that skips a check.',
      io: [
        ['reads', 'the live index'],
        ['writes', 'manifest.json + .sig'],
        ['then', 'index.json + .sig'],
      ],
      invariant:
        'The signature covers the EXACT bytes written. Parse a manifest, edit it and re-stringify it and it verifies in the panel while failing BadSignature on every device.',
      files: [
        'admin/src/lib/core/sign.ts',
        'admin/src/lib/core/publish-core.ts',
        'admin/src/lib/g-launcher/distro-publish.ts',
        'admin/src/lib/g-launcher/flat-check.ts',
      ],
      goto: { label: 'Open Upload pack', href: `/apps/${app}/publish` },
    },
    {
      key: 'packs',
      icon: 'box',
      title: 'Pack objects',
      sub: 'themes/<packId>/<version>/',
      x: 294,
      y: 78,
      lane: 'store',
      what: 'The payload for one pack at one version: its files, manifest.json and manifest.sig, under a path that carries the version and is therefore immutable.',
      io: [
        ['cache', 'one year, immutable'],
        ['written by', 'publish-core'],
        ['read by', 'the device, and the panel via CDN'],
      ],
      invariant:
        'PackPaths.installedFile refuses slashes, so every asset reference inside a pack must be a bare filename. A nested reference with a flat file renders; the reverse goes black.',
      files: [
        'admin/src/lib/core/r2.ts',
        'admin/src/lib/core/pack-content.ts',
        'admin/src/lib/core/orphans.ts',
      ],
      goto: { label: 'Open CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'index',
      icon: 'list',
      title: 'index.json and index.sig',
      sub: 'the catalogue every device reads first',
      x: 294,
      y: 192,
      lane: 'store',
      what: 'The catalogue. A device reads this before anything else and refuses the lot if the signature does not verify.',
      io: [
        ['cache', 'no-cache'],
        ['merged by', 'publish-core'],
        ['signed by', 'sign'],
      ],
      invariant:
        'generatedAt must increase, and a pack with a perfect manifest inside an unsigned index is invisible: the index is rejected before any pack is read.',
      files: ['admin/src/lib/core/catalogue.ts', 'admin/src/lib/core/sign.ts'],
      goto: { label: 'Open CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'cdn',
      icon: 'cloud',
      title: 'cdn.mindberzerk.com',
      sub: 'the public door, no credential',
      x: 294,
      y: 300,
      lane: 'store',
      what: 'Reads here need no credential, which is why the site renders and icon previews load while the S3 token is being refused.',
      io: [
        ['origin', 'the R2 bucket'],
        ['auth', 'none'],
        ['used by', 'devices and the panel'],
      ],
      invariant:
        'The S3 API and this are different doors. One being refused says nothing about the other, which is why publishing by wrangler works while the panel cannot write.',
      files: ['admin/src/lib/core/cdn.ts'],
    },
    {
      key: 'sync',
      icon: 'refresh',
      title: 'PackSyncWorker',
      sub: 'reads cdn_base_url from Remote Config',
      x: 542,
      y: 78,
      lane: 'device',
      what: 'The device job that fetches the catalogue, compares versions and downloads what changed. Its base URL comes from Remote Config rather than the APK, so the CDN can move without a release.',
      io: [
        ['reads', 'cdn_base_url'],
        ['fetches', 'index.json and index.sig'],
        ['schedules', 'pack downloads'],
      ],
      invariant:
        'refreshCatalogue returns false both for "rejected" and for "nothing changed", so a phone cannot tell you which of the two happened.',
      files: [
        'apps/g_launcher/lib/data/cdn/pack_repository.dart',
        'apps/g_launcher/android/.../packs/PackSyncWorker.kt',
      ],
      inLauncher: true,
      goto: { label: 'Open Config', href: `/apps/${app}/config` },
    },
    {
      key: 'verify',
      icon: 'shield',
      title: 'PackVerifier',
      sub: 'PackKeys.ACCEPTED_HEX',
      x: 542,
      y: 186,
      lane: 'device',
      what: 'Checks the index signature, then each pack manifest, then every file hash. Nothing is installed until all three pass.',
      io: [
        ['key', 'compiled into the APK'],
        ['checks', 'index, manifest, files'],
        ['refuses', 'on any mismatch'],
      ],
      invariant:
        'A missing manifest.sig fails as MissingSignature and the pack is refused outright, which on the phone looks exactly like nothing having been published.',
      files: [
        'apps/g_launcher/android/.../packs/PackVerifier.kt',
        'apps/g_launcher/android/.../packs/PackKeys.kt',
      ],
      inLauncher: true,
    },
    {
      key: 'install',
      icon: 'folder',
      title: 'files/packs/',
      sub: 'where a verified pack lands',
      x: 542,
      y: 294,
      lane: 'device',
      what: 'Once verified, a pack is installed here and its assets are read from disk rather than from the APK bundle.',
      io: [
        ['path', 'files/packs/<packId>/'],
        ['written by', 'PackVerifier'],
        ['read by', 'ThemeSource'],
      ],
      invariant:
        'The disk cache is keyed by pack id, NOT by version, so republishing at the same number changes the bytes in the bucket and nothing at all on a phone.',
      files: [
        'apps/g_launcher/android/.../packs/PackPaths.kt',
        'apps/g_launcher/lib/engine/theme_source.dart',
      ],
      inLauncher: true,
    },
    {
      key: 'engine',
      icon: 'layers',
      title: 'theme_engine',
      sub: 'bundled, then installed, then Ubuntu',
      x: 542,
      y: 402,
      lane: 'device',
      what: 'Decides which theme the launcher draws, and hands an EffectiveTheme to every shell. Shells read that and never a ThemeSpec or a constant.',
      io: [
        ['reads', 'the installed theme.json'],
        ['falls back', 'ubuntu-24-04'],
        ['feeds', 'EffectiveTheme'],
      ],
      invariant:
        'Bundled is checked BEFORE installed, unconditionally, so the three free distros cannot currently be overridden by a CDN pack. That is an open decision rather than a settled rule.',
      files: [
        'apps/g_launcher/lib/engine/theme_engine.dart',
        'apps/g_launcher/lib/engine/effective_theme.dart',
      ],
      inLauncher: true,
      goto: { label: 'Open Distros', href: `/apps/${app}/distros` },
    },
  ];

  // Orthogonal, hand-routed. `gate` names the node whose state decides whether
  // this edge animates: an edge into a refused bucket must not look like
  // traffic.
  const edges: GraphEdge[] = [
    { from: 'builder', to: 'sign', d: 'M130 128 L130 168', gate: 'sign' },
    { from: 'sign', to: 'packs', d: 'M214 190 L250 190 L250 106 L286 106', gate: 'packs' },
    { from: 'sign', to: 'index', d: 'M214 202 L250 202 L250 220 L286 220', gate: 'index' },
    { from: 'packs', to: 'cdn', d: 'M378 134 L378 300', gate: 'cdn' },
    { from: 'index', to: 'cdn', d: 'M420 248 L420 300', gate: 'cdn' },
    { from: 'cdn', to: 'sync', d: 'M462 320 L498 320 L498 106 L534 106', gate: 'cdn' },
    { from: 'sync', to: 'verify', d: 'M626 134 L626 176', gate: 'sync' },
    { from: 'verify', to: 'install', d: 'M626 244 L626 286', gate: 'verify' },
    { from: 'install', to: 'engine', d: 'M626 354 L626 396', gate: 'install' },
  ];

  return { nodes, edges };
}


// ── signing: which bytes, in which order ────────────────────────────────────

function signingGraph(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'sig.files',
      icon: 'files',
      title: 'The picked files',
      sub: 'a folder or a zip',
      x: 46, y: 88, lane: 'panel',
      what: 'What the publisher chose. Relative paths matter: they become the manifest, so a folder picked at the wrong level ships a pack whose every reference is one directory off.',
      io: [['from', 'the builder or Upload pack'], ['checked by', 'flat-check'], ['becomes', 'the manifest']],
      invariant:
        'A pack asset must be a bare filename on the device, so flat-check refuses anything the launcher could not resolve after install.',
      files: ['admin/src/lib/g-launcher/flat-check.ts', 'admin/src/app/components/publish-form.tsx'],
      goto: { label: 'Open Upload pack', href: `/apps/${app}/publish` },
    },
    {
      key: 'sig.manifest',
      icon: 'doc',
      title: 'manifest.json',
      sub: 'path, size and sha256 per file',
      x: 46, y: 200, lane: 'panel',
      what: 'The list of every file in the pack with its hash. Built once, serialised once, and signed as exactly those bytes.',
      io: [['built by', 'sign.ts'], ['covers', 'every file hash'], ['newline', 'none at the end']],
      invariant:
        'NO TRAILING NEWLINE, and never re-stringified. Parse this, change a field and write it back and it verifies in the panel while failing BadSignature on every phone.',
      files: ['admin/src/lib/core/sign.ts'],
    },
    {
      key: 'sig.msig',
      icon: 'key',
      title: 'manifest.sig',
      sub: 'ed25519 over those exact bytes',
      x: 46, y: 312, lane: 'panel',
      what: 'The detached signature for one pack. Written beside the manifest, in the same versioned directory.',
      io: [['algorithm', 'ed25519'], ['key id', 'mh-2026-07'], ['verified by', 'PackVerifier']],
      invariant:
        'Present but unreadable is the same as missing: the device reports MissingSignature and refuses the pack, which looks exactly like nothing having been published.',
      files: ['admin/src/lib/core/sign.ts', 'admin/src/lib/core/publish-core.ts'],
    },
    {
      key: 'sig.read',
      icon: 'download',
      title: 'Read the live index',
      sub: 'before anything is merged',
      x: 294, y: 88, lane: 'store',
      what: 'The current catalogue is fetched first. A publish is a merge into what is live, not a replacement of it, so this read has to succeed before a write is allowed.',
      io: [['reads', 'index.json'], ['guards', 'guardIndex'], ['refuses on', 'unreachable or corrupt']],
      invariant:
        'An unreadable index must never become the merge base. Merging into an empty read would drop every pack from the store in one write.',
      files: ['admin/src/lib/core/publish-core.ts', 'admin/src/lib/core/catalogue.ts'],
    },
    {
      key: 'sig.merge',
      icon: 'merge',
      title: 'Merge and stamp',
      sub: 'generatedAt must increase',
      x: 294, y: 200, lane: 'store',
      what: 'The new pack entry replaces any older one with the same id, and the document is stamped with a fresh generatedAt.',
      io: [['adds', 'one pack entry'], ['stamps', 'generatedAt'], ['keeps', 'every other pack']],
      invariant:
        'generatedAt must exceed what is live. It is what stops a stale edge or a replayed document from hiding an update indefinitely.',
      files: ['admin/src/lib/core/publish-core.ts'],
    },
    {
      key: 'sig.isig',
      icon: 'key',
      title: 'index.json + index.sig',
      sub: 'trailing newline, no-cache',
      x: 294, y: 312, lane: 'store',
      what: 'The catalogue and its detached signature, written together and served without caching.',
      io: [['newline', 'one, at the end'], ['cache', 'no-cache'], ['read first by', 'every device']],
      invariant:
        'index.json HAS a trailing newline and manifest.json does not. Both are signed as written, so the difference is not cosmetic.',
      files: ['admin/src/lib/core/sign.ts'],
      goto: { label: 'Open CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'sig.verify',
      icon: 'shield',
      title: 'Verification on device',
      sub: 'index, then manifest, then files',
      x: 542, y: 200, lane: 'device',
      what: 'Three checks in order. The index signature gates everything; a pack manifest gates that pack; each file hash gates the install.',
      io: [['1', 'index.sig'], ['2', 'manifest.sig'], ['3', 'every sha256']],
      invariant:
        'The order matters. A perfectly signed pack inside an unsigned index is invisible, because the index is rejected before any pack is looked at.',
      files: ['apps/g_launcher/android/.../packs/PackVerifier.kt'],
      inLauncher: true,
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'sig.files', to: 'sig.manifest', d: 'M130 138 L130 194', gate: 'sig.manifest' },
    { from: 'sig.manifest', to: 'sig.msig', d: 'M130 250 L130 306', gate: 'sig.msig' },
    { from: 'sig.msig', to: 'sig.isig', d: 'M214 336 L250 336 L250 336 L286 336', gate: 'sig.isig' },
    { from: 'sig.read', to: 'sig.merge', d: 'M378 138 L378 194', gate: 'sig.read' },
    { from: 'sig.merge', to: 'sig.isig', d: 'M378 250 L378 306', gate: 'sig.isig' },
    { from: 'sig.isig', to: 'sig.verify', d: 'M462 336 L500 336 L500 226 L534 226', gate: 'sig.verify' },
  ];

  return { nodes, edges };
}

// ── on device: what the launcher does with a pack ───────────────────────────

function deviceGraph(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'dev.rc',
      icon: 'sliders',
      title: 'Remote Config',
      sub: 'cdn_base_url',
      x: 46, y: 88, lane: 'panel',
      what: 'The one value the launcher reads remotely. It decides where packs are fetched from, so the CDN can move without an app release.',
      io: [['key', 'cdn_base_url'], ['read by', 'PackSyncWorker'], ['managed at', 'Config']],
      invariant:
        'Devices fetch on their own schedule, typically within twelve hours or on a cold start, so a change here is not immediate anywhere.',
      files: ['admin/src/lib/core/remote-config.ts', 'apps/g_launcher/lib/data/cdn/cdn_config.dart'],
      goto: { label: 'Open Config', href: `/apps/${app}/config` },
    },
    {
      key: 'dev.sync',
      icon: 'refresh',
      title: 'PackSyncWorker',
      sub: 'fetch, compare, download',
      x: 294, y: 88, lane: 'store',
      what: 'Fetches the catalogue, compares each pack version against what is installed, and downloads only what moved.',
      io: [['fetches', 'index.json + sig'], ['compares', 'version per pack'], ['downloads', 'the difference']],
      invariant:
        'refreshCatalogue returns false for both "rejected" and "nothing changed", so a device cannot report which of the two happened.',
      files: ['apps/g_launcher/lib/data/cdn/pack_repository.dart'],
      inLauncher: true,
    },
    {
      key: 'dev.install',
      icon: 'folder',
      title: 'files/packs/',
      sub: 'keyed by pack id',
      x: 294, y: 200, lane: 'store',
      what: 'Where a verified pack is unpacked. Assets are read from here rather than from the APK once a theme is installed.',
      io: [['path', 'files/packs/<packId>/'], ['flat', 'bare filenames only'], ['read by', 'ThemeSource']],
      invariant:
        'THE CACHE IS KEYED BY PACK ID, NOT VERSION. Republishing at the same number changes the bucket and nothing on the phone.',
      files: ['apps/g_launcher/android/.../packs/PackPaths.kt'],
      inLauncher: true,
    },
    {
      key: 'dev.engine',
      icon: 'layers',
      title: 'theme_engine',
      sub: 'bundled, installed, fallback',
      x: 294, y: 312, lane: 'store',
      what: 'Resolves which theme is active and produces the EffectiveTheme every shell reads.',
      io: [['order', 'bundled, installed, ubuntu'], ['produces', 'EffectiveTheme'], ['prefs', 'per theme bucket']],
      invariant:
        'Bundled is checked BEFORE installed, unconditionally, so the three free distros cannot be overridden by a CDN pack. That is an open decision, not a settled rule.',
      files: ['apps/g_launcher/lib/engine/theme_engine.dart', 'apps/g_launcher/lib/engine/effective_theme.dart'],
      inLauncher: true,
      goto: { label: 'Open Distros', href: `/apps/${app}/distros` },
    },
    {
      key: 'dev.icons',
      icon: 'grid',
      title: 'IconCache',
      sub: 'hero, brand, then generated',
      x: 542, y: 200, lane: 'device',
      what: 'Layers icon sources: a hero pack image if one exists, then a brand glyph, then the native generator using the theme recipe.',
      io: [['memory', 'LRU'], ['disk', 'keyed by pack id'], ['falls back', 'the generator']],
      invariant:
        'Adding one field to IconStyle touches eight places, and missing either the cache id or the fingerprint fails silently by serving stale bitmaps that look identical to unwired code.',
      files: ['apps/g_launcher/android/.../icons/IconCache.kt', 'apps/g_launcher/android/.../icons/IconRenderer.kt'],
      inLauncher: true,
      goto: { label: 'Open Icons', href: `/apps/${app}/icons` },
    },
    {
      key: 'dev.shell',
      icon: 'phone',
      title: 'The shell',
      sub: 'gnome, plasma, tui, aqua',
      x: 542, y: 312, lane: 'device',
      what: 'Draws the desktop: top bar, dock, workspaces. Each shell reads EffectiveTheme and nothing else.',
      io: [['reads', 'EffectiveTheme'], ['never reads', 'ThemeSpec or constants'], ['wallpaper', 'the system wallpaper']],
      invariant:
        'The system wallpaper is the ONLY route to a visible wallpaper, because gnome_shell runs transparent over the WindowManager.',
      files: ['apps/g_launcher/lib/shells/'],
      inLauncher: true,
    },
    {
      key: 'dev.billing',
      icon: 'tag',
      title: 'Entitlements',
      sub: 'Play Billing, resolved locally',
      x: 542, y: 88, lane: 'device',
      what: 'Decides whether a paid pack is usable: free, owned directly, or granted by a bundle carried in the index.',
      io: [['reads', 'Play Billing'], ['plus', 'index entitlements'], ['gates', 'paid packs only']],
      invariant:
        'A product ID that does not exist in Play resolves to not-owned forever, so a price advertised for a missing product is a purchase nobody can complete.',
      files: ['apps/g_launcher/lib/data/billing/', 'admin/src/lib/core/commerce.ts'],
      inLauncher: true,
      goto: { label: 'Open Commerce', href: `/apps/${app}/commerce` },
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'dev.rc', to: 'dev.sync', d: 'M214 114 L286 114', gate: 'dev.sync' },
    { from: 'dev.sync', to: 'dev.install', d: 'M378 138 L378 194', gate: 'dev.install' },
    { from: 'dev.install', to: 'dev.engine', d: 'M378 250 L378 306', gate: 'dev.engine' },
    { from: 'dev.install', to: 'dev.icons', d: 'M462 226 L534 226', gate: 'dev.icons' },
    { from: 'dev.engine', to: 'dev.shell', d: 'M462 338 L534 338', gate: 'dev.shell' },
    { from: 'dev.icons', to: 'dev.shell', d: 'M626 250 L626 306', gate: 'dev.shell' },
    { from: 'dev.billing', to: 'dev.install', d: 'M626 138 L626 160 L500 160 L500 226 L462 226', gate: 'dev.install' },
  ];

  return { nodes, edges };
}

// ── bucket layout: what is stored where ─────────────────────────────────────

function bucketGraph(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'buk.root',
      icon: 'database',
      title: 'mindberzerk-cdn',
      sub: 'one bucket, two prefixes',
      x: 46, y: 200, lane: 'panel',
      what: 'Everything the studio serves lives here: the launcher catalogue under its app id, and the public site under site/.',
      io: [['origin for', 'cdn.mindberzerk.com'], ['written by', 'the panel and wrangler'], ['auth', 'S3 for writes']],
      invariant:
        'The S3 API and the CDN are different doors. A refused token blocks the panel and not wrangler, which uses account OAuth.',
      files: ['admin/src/lib/core/r2.ts', 'admin/src/lib/core/cdn.ts'],
    },
    {
      key: 'buk.index',
      icon: 'list',
      title: 'g-launcher/index.json',
      sub: 'plus index.sig, no-cache',
      x: 294, y: 88, lane: 'store',
      what: 'The catalogue. Never swept, never cached, and the first thing a device reads.',
      io: [['cache', 'no-cache'], ['signed', 'always'], ['swept', 'never']],
      invariant: 'This can never appear in an orphan sweep, whatever else is in the directory.',
      files: ['admin/src/lib/core/catalogue.ts'],
      goto: { label: 'Open CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'buk.packs',
      icon: 'box',
      title: 'themes, heropacks, brandpacks',
      sub: '<packId>/<version>/',
      x: 294, y: 200, lane: 'store',
      what: 'Pack payloads, one directory per version. Immutable, because the version is in the path.',
      io: [['cache', 'one year'], ['immutable', 'yes'], ['superseded', 'become orphans']],
      invariant:
        'An old version is left behind on purpose when a new one publishes, so a device mid-download finishes rather than failing an install.',
      files: ['admin/src/lib/core/publish-core.ts', 'admin/src/lib/core/orphans.ts'],
    },
    {
      key: 'buk.admin',
      icon: 'lock',
      title: 'g-launcher/admin/',
      sub: 'drafts, listing, product ids',
      x: 294, y: 312, lane: 'store',
      what: 'Panel state that no device ever reads: theme drafts, icon drafts and their assets, listing flags, the Play snapshot and the hand-kept product ids.',
      io: [['read by', 'the panel only'], ['served', 'never to devices'], ['swept', 'never']],
      invariant:
        'Nothing under admin/ is ever listed as an orphan, which is what makes it safe to keep half-finished drafts here.',
      files: ['admin/src/lib/g-launcher/themes.ts', 'admin/src/lib/g-launcher/icon-drafts.ts', 'admin/src/lib/core/product-ids.ts'],
    },
    {
      key: 'buk.site',
      icon: 'globe',
      title: 'site/',
      sub: 'content, registry, legal',
      x: 542, y: 140, lane: 'device',
      what: 'What mindberzerk.com renders: the hero and featured order, the app registry, and every legal document with its rendered HTML.',
      io: [['cache', '300 seconds'], ['read by', 'the public site'], ['signed', 'never']],
      invariant:
        'Unsigned on purpose. No device reads these, so a signature would be ceremony, and the five minute cache is why a publish is not instant.',
      files: ['admin/src/lib/studio/site-content.ts', 'admin/src/lib/studio/legal.ts', 'admin/src/lib/studio/apps.ts'],
      goto: { label: 'Open Site content', href: '/site' },
    },
    {
      key: 'buk.orphans',
      icon: 'trash',
      title: 'Orphans',
      sub: 'stale, unpublished, loose',
      x: 542, y: 300, lane: 'device',
      what: 'Objects nothing references: superseded versions, packs never in the index, and files outside the pack layout. Reviewed and swept only on an explicit confirm.',
      io: [['grouped by', 'kind'], ['deleted', 'on confirm only'], ['recomputed', 'at delete time']],
      invariant:
        'The catalogue, admin state, site files and every live pack current version are never listed here and can never be swept.',
      files: ['admin/src/lib/core/orphans.ts', 'admin/src/components/packs/SweepOrphans.tsx'],
      goto: { label: 'Open CDN objects', href: `/apps/${app}/packs` },
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'buk.root', to: 'buk.index', d: 'M214 226 L250 226 L250 114 L286 114', gate: 'buk.index' },
    { from: 'buk.root', to: 'buk.packs', d: 'M214 226 L286 226', gate: 'buk.packs' },
    { from: 'buk.root', to: 'buk.admin', d: 'M214 226 L250 226 L250 338 L286 338', gate: 'buk.admin' },
    { from: 'buk.root', to: 'buk.site', d: 'M130 250 L130 470 L500 470 L500 166 L534 166', gate: 'buk.site' },
    { from: 'buk.packs', to: 'buk.orphans', d: 'M462 226 L498 226 L498 326 L534 326', gate: 'buk.orphans' },
  ];

  return { nodes, edges };
}

// ── G Recovery ──────────────────────────────────────────────────────────────

/**
 * THE RECOVERY GRAPHS.
 *
 * Same pipeline, different payload. Where the launcher ships a desktop, this
 * ships three documents, and the one that matters is a map of where other
 * people's phones hide deleted files.
 *
 * THE PACK IDS ARE LITERALS HERE and their source of truth is `CONTENT_PACKS`
 * in `lib/g-recovery/content-packs.ts`. They are not imported, because `core`
 * must never import from an app folder: the arrow points down only, and one
 * exception is how that rule stops being a rule. Three strings duplicated
 * across a boundary is the cheaper mistake.
 */
/**
 * The documents this app publishes, by id.
 *
 * LITERALS, and their source of truth is `CONTENT_PACKS` in
 * `lib/g-recovery/content-packs.ts`. Not imported, because `core` must never
 * import from an app folder: the arrow points down only, and one exception is
 * how that stops being a rule. Four strings duplicated across a boundary is the
 * cheaper mistake, and a missing one shows up here as a document that never
 * reports its version.
 */
const CONTENT_IDS = ['trashmap', 'storage-map', 'learn-en', 'oem-guide'];

function recoveryDelivery(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'rec.editor',
      icon: 'edit',
      title: 'Coverage editor',
      sub: `/apps/${app}/coverage`,
      x: 46,
      y: 78,
      lane: 'panel',
      what: 'Where a trash path is added for a phone nobody here owns. Structured rows rather than a JSON box, because role and fidelity decide behaviour on the device and a typo in either is a support thread.',
      io: [
        ['reads', 'the live trashmap'],
        ['writes', 'nothing until publish'],
      ],
      invariant:
        'The editor starts from the LIVE document. Starting from an empty one and saving would replace the registry rather than update it, which is why an unreachable bucket disables the button.',
      files: [
        'admin/src/components/g-recovery/CoverageEditor.tsx',
        'admin/src/app/apps/[app]/coverage/page.tsx',
        'admin/src/lib/g-recovery/content-read.ts',
      ],
      goto: { label: 'Open Coverage', href: `/apps/${app}/coverage` },
    },
    {
      key: 'rec.publish',
      icon: 'key',
      title: 'Validate and sign',
      sub: 'one publish path, ed25519',
      x: 46,
      y: 190,
      lane: 'panel',
      what: 'Shape is checked before anything is signed: closed sets for role, fidelity and confidence, and a refusal for any path that is absolute or contains a parent segment.',
      io: [
        ['reads', 'PACK_SIGNING_KEY'],
        ['writes', 'manifest.json and manifest.sig'],
      ],
      invariant:
        'Paths are candidates and are NOT checked for existence. That is what makes it safe to publish a guess for hardware nobody owns: a wrong path costs one stat call on the device.',
      files: [
        'admin/src/app/api/publish/content/route.ts',
        'admin/src/lib/g-recovery/content-packs.ts',
        'admin/src/lib/core/sign.ts',
      ],
    },
    {
      key: 'rec.pack',
      icon: 'box',
      title: 'Pack object',
      sub: 'registries/trashmap/vN',
      x: 286,
      y: 78,
      lane: 'store',
      what: 'The document and its signature at a versioned key. The version is in the path, so every object is immutable and cacheable for a year.',
      io: [
        ['writes', 'trashmap.json'],
        ['writes', 'manifest.sig'],
      ],
      invariant:
        'Pack versions are monotonic integers. Reusing one leaves devices holding a cached copy of the old bytes with no way to know.',
      files: ['admin/src/lib/core/publish-core.ts'],
      goto: { label: 'CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'rec.index',
      icon: 'list',
      title: 'index.json',
      sub: 'g-recovery/index.json',
      x: 286,
      y: 190,
      lane: 'store',
      what: 'The catalogue that advertises every published document. Read, merged, bumped, signed and written on every publish, never rebuilt from memory.',
      io: [
        ['reads', 'the live index'],
        ['writes', 'index.json and index.sig'],
      ],
      invariant:
        'generatedAt must strictly increase or every device that has already synced ignores the new index while reporting nothing.',
      files: ['admin/src/lib/core/catalogue.ts', 'admin/src/lib/core/publish-core.ts'],
    },
    {
      key: 'rec.cdn',
      icon: 'globe',
      title: 'Public door',
      sub: 'cdn.mindberzerk.com',
      x: 286,
      y: 302,
      lane: 'store',
      what: 'The unauthenticated read path devices use. Separate from the S3 credential this panel writes with, which is why the two can disagree.',
      io: [
        ['serves', 'g-recovery/'],
        ['auth', 'none'],
      ],
      invariant:
        'A working panel does not imply a working CDN. The bucket can be writable while the public hostname serves nothing, and only this node distinguishes them.',
      files: ['admin/src/lib/core/cdn.ts'],
    },
    {
      key: 'rec.sync',
      icon: 'refresh',
      title: 'Content sync',
      sub: 'on launch, then daily',
      x: 534,
      y: 78,
      lane: 'device',
      what: 'The app fetches the index, compares versions, and downloads only what moved.',
      io: [
        ['reads', 'index.json'],
        ['writes', 'the local pack store'],
      ],
      invariant:
        'A failed sync is not an error state. The device keeps the copy it already trusted, and the copy built into the APK is the floor.',
      files: ['apps/g_recovery/lib/core/content/'],
      inLauncher: true,
    },
    {
      key: 'rec.verify',
      icon: 'shield',
      title: 'Verify',
      sub: 'ed25519, key pinned in the APK',
      x: 534,
      y: 190,
      lane: 'device',
      what: 'Signature checked against the public key compiled into the app before a single byte is applied.',
      io: [
        ['reads', 'manifest.sig'],
        ['refuses', 'anything unsigned'],
      ],
      invariant:
        'Refusing keeps the previous copy. The first index this pipeline signed used the wrong key, publish reported success, and every device silently showed nothing.',
      files: ['apps/g_recovery/lib/core/content/pack_keys.dart'],
      inLauncher: true,
    },
    {
      key: 'rec.map',
      icon: 'database',
      title: 'Trash map',
      sub: 'paths per app and per brand',
      x: 534,
      y: 302,
      lane: 'device',
      what: 'The parsed registry. Every entry carries a role, a fidelity stamp, and optionally how much the path is trusted.',
      io: [
        ['reads', 'trashmap.json'],
        ['feeds', 'the scanner'],
      ],
      invariant:
        'A malformed entry is skipped rather than fatal, which is correct on a phone and is exactly why the shape is validated in the panel instead.',
      files: ['apps/g_recovery/lib/core/scan/trash_map.dart'],
      inLauncher: true,
    },
    {
      key: 'rec.scan',
      icon: 'folder',
      title: 'Scanner',
      sub: 'probes each candidate',
      x: 534,
      y: 414,
      lane: 'device',
      what: 'Stats every candidate path and reports only what exists and holds files. A wrong guess costs one syscall and shows the user nothing.',
      io: [
        ['reads', 'shared storage'],
        ['reads', 'MediaStore IS_TRASHED'],
      ],
      invariant:
        'Nothing is promised before it is found. A path published with confidence "reported" has never been seen to work here, and the app should offer a manual browse rather than imply a result.',
      files: ['packages/device_probe/android/', 'apps/g_recovery/lib/features/recover/'],
      inLauncher: true,
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'rec.editor', to: 'rec.publish', d: 'M130 130 L130 190', gate: 'rec.publish' },
    { from: 'rec.publish', to: 'rec.pack', d: 'M214 216 L250 216 L250 104 L286 104', gate: 'rec.pack' },
    { from: 'rec.pack', to: 'rec.index', d: 'M370 130 L370 190', gate: 'rec.index' },
    { from: 'rec.index', to: 'rec.cdn', d: 'M370 242 L370 302', gate: 'rec.cdn' },
    { from: 'rec.cdn', to: 'rec.sync', d: 'M454 328 L494 328 L494 104 L534 104', gate: 'rec.sync' },
    { from: 'rec.sync', to: 'rec.verify', d: 'M618 130 L618 190', gate: 'rec.verify' },
    { from: 'rec.verify', to: 'rec.map', d: 'M618 242 L618 302', gate: 'rec.map' },
    { from: 'rec.map', to: 'rec.scan', d: 'M618 354 L618 414', gate: 'rec.scan' },
  ];

  return { nodes, edges };
}

function recoveryDevice(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'rec.dev.guide',
      icon: 'doc',
      title: 'Brand guidance',
      sub: `/apps/${app}/guides`,
      x: 46,
      y: 78,
      lane: 'panel',
      what: 'Per manufacturer advice, published as a document rather than compiled in, so a note about a Tecno recycle folder ships without a release.',
      io: [
        ['reads', 'the live oem-guide'],
        ['writes', 'guides/oem-guide/vN'],
      ],
      invariant:
        'Brand keys are lowercase because Build.MANUFACTURER is lowercased before the comparison. A capital matches nothing and the publish is refused rather than shipped.',
      files: [
        'admin/src/components/g-recovery/GuidanceEditor.tsx',
        'admin/src/lib/g-recovery/content-packs.ts',
      ],
      goto: { label: 'Open Brand guidance', href: `/apps/${app}/guides` },
    },
    {
      key: 'rec.dev.docs',
      icon: 'files',
      title: 'Four documents',
      sub: 'trashmap, storage-map, learn-en, oem-guide',
      x: 286,
      y: 78,
      lane: 'store',
      what: 'Everything the app knows about somebody else\u2019s phone, as data. A new manufacturer is a document, not a build.',
      io: [
        ['registry', 'trashmap and storage-map'],
        ['article', 'learn-en'],
        ['guide', 'oem-guide'],
      ],
      invariant:
        'minAppVersion stays 0 unless a document uses something a shipped build cannot render. Setting it high to be safe silently withholds the pack from every device below it.',
      files: ['admin/src/lib/g-recovery/content-packs.ts'],
    },
    {
      key: 'rec.dev.match',
      icon: 'tag',
      title: 'Brand match',
      sub: 'Build.MANUFACTURER, lowercased',
      x: 534,
      y: 78,
      lane: 'device',
      what: 'First matching brand or alias wins, and everything else reads the fallback, which is most of the install base.',
      io: [
        ['reads', 'oem-guide'],
        ['falls back to', 'fallback.blocks'],
      ],
      invariant:
        'A duplicate brand is not a merge. The device takes the first and the second is unreachable, which is why the publish refuses one.',
      files: ['apps/g_recovery/lib/features/learn/'],
      inLauncher: true,
    },
    {
      key: 'rec.dev.probe',
      icon: 'folder',
      title: 'Path probes',
      sub: 'stat each candidate',
      x: 534,
      y: 166,
      lane: 'device',
      what: 'Every path in the map, checked against this device. Absent paths cost a syscall and are never shown.',
      io: [
        ['reads', 'Android/data and shared storage'],
        ['returns', 'what exists and holds files'],
      ],
      invariant:
        'Android 11 closed Android/data to direct reads. What a path probe can see depends on the API level, and the same map produces different results on two phones by design.',
      files: ['packages/device_probe/android/'],
      inLauncher: true,
    },
    {
      key: 'rec.dev.media',
      icon: 'trash',
      title: 'MediaStore bin',
      sub: 'IS_TRASHED, API 30 and up',
      x: 534,
      y: 254,
      lane: 'device',
      what: 'The OS trash bin, which is the only recovery route the platform actually blesses. Available from Android 11 onwards and absent below it.',
      io: [
        ['reads', 'MediaStore IS_TRASHED'],
        ['writes', 'untrash on restore'],
      ],
      invariant:
        'This is the feature that pins the minimum API level. Below 30 it does not exist, and the app has to fall back to direct file access rather than pretend.',
      files: ['packages/device_probe/android/'],
      inLauncher: true,
    },
    {
      key: 'rec.dev.review',
      icon: 'grid',
      title: 'Review',
      sub: 'swipe to keep or clear',
      x: 534,
      y: 342,
      lane: 'device',
      what: 'What was found, shown with its fidelity stamp so a thumbnail is never mistaken for the original.',
      io: [
        ['reads', 'scan results'],
        ['writes', 'nothing until confirmed'],
      ],
      invariant:
        'Fidelity is shown before the action, not after. A preview quality recovery presented as a full one is the complaint this whole product exists to avoid.',
      files: ['apps/g_recovery/lib/features/recover/'],
      inLauncher: true,
    },
    {
      key: 'rec.dev.restore',
      icon: 'download',
      title: 'Restore',
      sub: 'copied, never moved',
      x: 534,
      y: 430,
      lane: 'device',
      what: 'Files are copied into the restore folder under shared storage. The original is left where it was found.',
      io: [
        ['writes', 'restoreFolder'],
        ['reads', 'the trashmap'],
      ],
      invariant:
        'restoreFolder is a plain relative folder, refused if absolute or containing a parent segment, because it is a directory the app writes into.',
      files: ['apps/g_recovery/lib/features/recover/'],
      inLauncher: true,
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'rec.dev.guide', to: 'rec.dev.docs', d: 'M214 104 L286 104', gate: 'rec.dev.docs' },
    { from: 'rec.dev.docs', to: 'rec.dev.match', d: 'M454 104 L534 104', gate: 'rec.dev.match' },
    { from: 'rec.dev.match', to: 'rec.dev.probe', d: 'M618 130 L618 166', gate: 'rec.dev.probe' },
    { from: 'rec.dev.probe', to: 'rec.dev.media', d: 'M618 218 L618 254', gate: 'rec.dev.media' },
    { from: 'rec.dev.media', to: 'rec.dev.review', d: 'M618 306 L618 342', gate: 'rec.dev.review' },
    { from: 'rec.dev.review', to: 'rec.dev.restore', d: 'M618 394 L618 430', gate: 'rec.dev.restore' },
  ];

  return { nodes, edges };
}

function recoveryBucket(app: string): Graph {
  const nodes: GraphNode[] = [
    {
      key: 'rec.buk.root',
      icon: 'cloud',
      title: 'g-recovery/',
      sub: process.env.R2_BUCKET ?? 'mindberzerk-cdn',
      x: 46,
      y: 200,
      lane: 'panel',
      what: 'One prefix per app inside one bucket. Everything below is written by the same publish path and read by the same public door.',
      io: [
        ['written by', 'the panel'],
        ['read by', 'every install'],
      ],
      invariant:
        'The prefix is the app id. A pack published under the wrong one is invisible to the app that wants it and orphaned forever, since nothing sweeps a prefix nobody reads.',
      files: ['admin/src/lib/core/r2.ts'],
      goto: { label: 'CDN objects', href: `/apps/${app}/packs` },
    },
    {
      key: 'rec.buk.index',
      icon: 'list',
      title: 'index.json',
      sub: 'plus index.sig',
      x: 286,
      y: 88,
      lane: 'store',
      what: 'The catalogue. Everything a device knows about what exists starts here.',
      io: [['contains', 'one entry per pack']],
      invariant:
        'An index without its signature is refused by every device, which then keeps the catalogue it already had. The failure is silent on both ends.',
      files: ['admin/src/lib/core/sign.ts'],
    },
    {
      key: 'rec.buk.registries',
      icon: 'database',
      title: 'registries/',
      sub: 'trashmap/vN, storage-map/vN',
      x: 286,
      y: 172,
      lane: 'store',
      what: 'The trash map and the storage map. Both are keyed by path and looked up rather than read, which is what puts them here instead of under articles.',
      io: [['payload', 'trashmap.json']],
      invariant:
        'dirFor is an exhaustive switch over pack types, so a new type fails the typecheck rather than quietly landing in the wrong directory. Two publish paths once disagreed here and orphaned files for months.',
      files: ['admin/src/lib/core/publish-core.ts'],
      goto: { label: 'Open Coverage', href: `/apps/${app}/coverage` },
    },
    {
      key: 'rec.buk.articles',
      icon: 'doc',
      title: 'articles/',
      sub: 'learn-en/vN',
      x: 286,
      y: 256,
      lane: 'store',
      what: 'The in app guide to how Android storage works, as blocks rather than markdown.',
      io: [['payload', 'learn-en.json']],
      invariant:
        'The block vocabulary is a contract with ContentBlockView. An unknown type renders as nothing on the phone and as valid JSON here, so it is refused at publish.',
      files: ['admin/src/lib/g-recovery/content-packs.ts'],
      goto: { label: 'Open Learn', href: `/apps/${app}/learn` },
    },
    {
      key: 'rec.buk.guides',
      icon: 'layers',
      title: 'guides/',
      sub: 'oem-guide/vN',
      x: 286,
      y: 340,
      lane: 'store',
      what: 'Per brand guidance, sharing the article block vocabulary so the device needs no second renderer.',
      io: [['payload', 'oem-guide.json']],
      invariant:
        'A device that matches no brand reads the fallback. Without one it gets an empty screen, which reads as a broken app rather than as an absence of advice.',
      files: ['admin/src/components/g-recovery/GuidanceEditor.tsx'],
      goto: { label: 'Open Brand guidance', href: `/apps/${app}/guides` },
    },
  ];

  const edges: GraphEdge[] = [
    { from: 'rec.buk.root', to: 'rec.buk.index', d: 'M214 226 L250 226 L250 114 L286 114', gate: 'rec.buk.index' },
    { from: 'rec.buk.root', to: 'rec.buk.registries', d: 'M214 226 L250 226 L250 198 L286 198', gate: 'rec.buk.registries' },
    { from: 'rec.buk.root', to: 'rec.buk.articles', d: 'M214 226 L250 226 L250 282 L286 282', gate: 'rec.buk.articles' },
    { from: 'rec.buk.root', to: 'rec.buk.guides', d: 'M214 226 L250 226 L250 366 L286 366', gate: 'rec.buk.guides' },
  ];

  return { nodes, edges };
}

export function viewsFor(app: string): GraphView[] {
  if (!isAppId(app)) return [];

  if (app === 'g-recovery') {
    return [
      {
        key: 'delivery',
        label: 'Delivery',
        blurb: 'from a coverage edit to a phone finding a deleted file',
        graph: recoveryDelivery(app),
      },
      {
        key: 'device',
        label: 'On device',
        blurb: 'what the app does with a document once it has one',
        graph: recoveryDevice(app),
      },
      {
        key: 'bucket',
        label: 'Bucket layout',
        blurb: 'the three documents and where each one lives',
        graph: recoveryBucket(app),
      },
    ];
  }

  if (app !== 'g-launcher') return [];

  return [
    {
      key: 'delivery',
      label: 'Delivery',
      blurb: 'from a publish to a phone drawing a new desktop',
      graph: launcherGraph(app),
    },
    {
      key: 'signing',
      label: 'Signing',
      blurb: 'which bytes are covered by which signature, and in what order',
      graph: signingGraph(app),
    },
    {
      key: 'device',
      label: 'On device',
      blurb: 'what the launcher does with a pack once it has one',
      graph: deviceGraph(app),
    },
    {
      key: 'bucket',
      label: 'Bucket layout',
      blurb: 'what is stored where, and which of it can be deleted',
      graph: bucketGraph(app),
    },
  ];
}

/**
 * Resolve live status for every node.
 *
 * READS THE SAME SOURCES AS EVERY OTHER SCREEN, so the map cannot disagree with
 * the Overview. Nothing is invented: a node that cannot be measured reports
 * `unknown` rather than a cheerful green.
 */
export async function graphStatus(app: string): Promise<GraphStatus> {
  // NARROWED, NOT CAST. `readLiveIndex` takes an AppId and this takes a string
  // off a route param, so the two only met by luck. A cast would have compiled
  // and then read the catalogue of an app that does not exist, which surfaces
  // as an empty index: exactly the shape that means "the bucket is unreachable"
  // everywhere else in this panel. An unknown app is honestly unmeasurable, so
  // it reports the same `null` a failed read does and every node degrades to
  // `unknown` rather than to a cheerful green.
  const appId = isAppId(app) ? app : null;
  const live = appId ? await readLiveIndex(appId).catch(() => null) : null;
  const signed =
    appId && live?.exists ? await indexIsSigned(appId).catch(() => false) : false;

  const bucketOk = !!live && !live.unreachable && !live.corrupt;
  const bucketNote = !live
    ? 'the read threw'
    : live.unreachable
      ? 'S3 credential refused'
      : live.corrupt
        ? 'index does not parse'
        : 'reachable';

  // The PUBLIC door, probed separately, because it is the whole point of the
  // cdn node that these two can disagree.
  let cdnOk = false;
  let cdnNote = 'not reachable';
  try {
    const res = await fetch(`${cdnBase()}/${app}/index.json`, {
      method: 'HEAD',
      cache: 'no-store',
    });
    cdnOk = res.ok;
    cdnNote = res.ok ? 'serving' : `HTTP ${res.status}`;
  } catch (e) {
    cdnNote = (e as Error).message || 'not reachable';
  }

  const packCount = live?.packs.length ?? 0;
  const bytes = live?.packs.reduce((n, p) => n + p.sizeBytes, 0) ?? 0;

  /**
   * Is a named document live, and at what version.
   *
   * BY PACK ID, off the index that was already read, so these cost nothing and
   * cannot disagree with the Overview. Both return an honest absence on an
   * unreachable bucket rather than treating "we could not look" as "it is not
   * there": those look identical in a status dot and mean opposite things.
   */
  const packs = live?.packs ?? [];
  const hasPack = (id: string) => bucketOk && packs.some((p) => p.packId === id);
  const packVersion = (id: string) => {
    if (!bucketOk) return 'unknown';
    const found = packs.find((p) => p.packId === id);
    return found ? `v${found.version}` : 'not published';
  };

  const unknown = (note: string, live2: [string, string][] = []): GraphStatus[string] => ({
    state: 'unknown',
    note,
    live: live2,
  });

  return {
    builder: {
      state: 'ok',
      note: 'available',
      live: [['runs in', 'the panel']],
    },
    sign: {
      state: process.env.PACK_SIGNING_KEY ? 'ok' : 'unknown',
      note: process.env.PACK_SIGNING_KEY ? 'key loaded' : 'no signing key configured',
      live: [
        ['key id', process.env.PACK_KEY_ID ?? '-'],
        ['algorithm', 'ed25519'],
      ],
    },
    packs: {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketNote,
      live: bucketOk
        ? [
            ['packs', String(packCount)],
            ['bytes', String(bytes)],
          ]
        : [['packs', 'unknown']],
    },
    index: {
      state: bucketOk ? (signed ? 'ok' : 'bad') : 'bad',
      note: !bucketOk ? bucketNote : signed ? 'signed' : 'published without a signature',
      live: bucketOk
        ? [
            ['generatedAt', String(live?.generatedAt ?? 0)],
            ['key id', live?.keyId || '-'],
          ]
        : [['generatedAt', 'unknown']],
    },
    cdn: {
      state: cdnOk ? 'ok' : 'bad',
      note: cdnNote,
      live: [
        ['host', cdnBase().replace(/^https?:\/\//, '')],
        ['auth', 'none'],
      ],
    },
    // The device side cannot be measured from here, and saying so is the point.
    // A green dot on PackVerifier would be a claim about somebody's phone.
    sync: unknown('not measurable from the panel', [['cadence', 'about 12 hours']]),
    verify: unknown('not measurable from the panel', [['key', 'compiled into the APK']]),
    install: unknown('not measurable from the panel'),
    engine: unknown('not measurable from the panel'),

    // ── signing ────────────────────────────────────────────────────────────
    // These describe a publish that is happening rather than a resource that
    // can be probed, so most are `ok` in the sense of "this step is wired" and
    // the two that touch the bucket carry the bucket's real state.
    'sig.files': { state: 'ok', note: 'checked by flat-check', live: [] },
    'sig.manifest': {
      state: process.env.PACK_SIGNING_KEY ? 'ok' : 'unknown',
      note: process.env.PACK_SIGNING_KEY ? 'signable' : 'no signing key configured',
      live: [['newline', 'none']],
    },
    'sig.msig': {
      state: process.env.PACK_SIGNING_KEY ? 'ok' : 'unknown',
      note: process.env.PACK_SIGNING_KEY ? 'key loaded' : 'no signing key configured',
      live: [['key id', process.env.PACK_KEY_ID ?? '-']],
    },
    'sig.read': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketNote,
      live: [['packs read', bucketOk ? String(packCount) : 'unknown']],
    },
    'sig.merge': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketOk ? 'mergeable' : 'no base to merge into',
      live: [['generatedAt', bucketOk ? String(live?.generatedAt ?? 0) : 'unknown']],
    },
    'sig.isig': {
      state: bucketOk ? (signed ? 'ok' : 'bad') : 'bad',
      note: !bucketOk ? bucketNote : signed ? 'signed' : 'published without a signature',
      live: [['newline', 'one']],
    },
    'sig.verify': unknown('not measurable from the panel'),

    // ── on device ──────────────────────────────────────────────────────────
    // Only the Remote Config side is visible from here. Everything past it is
    // a phone, and a green dot on any of it would be a claim about someone
    // else's device.
    'dev.rc': {
      state: process.env.GCP_PROJECT || process.env.GOOGLE_CLOUD_PROJECT ? 'ok' : 'unknown',
      note:
        process.env.GCP_PROJECT || process.env.GOOGLE_CLOUD_PROJECT
          ? 'project configured'
          : 'GCP_PROJECT is not set',
      live: [['key', 'cdn_base_url']],
    },
    'dev.sync': unknown('not measurable from the panel', [['cadence', 'about 12 hours']]),
    'dev.install': unknown('not measurable from the panel'),
    'dev.engine': unknown('not measurable from the panel'),
    'dev.icons': unknown('not measurable from the panel'),
    'dev.shell': unknown('not measurable from the panel'),
    'dev.billing': unknown('not measurable from the panel'),

    // ── bucket ─────────────────────────────────────────────────────────────
    'buk.root': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketNote,
      live: [['bucket', process.env.R2_BUCKET ?? 'mindberzerk-cdn']],
    },
    'buk.index': {
      state: bucketOk ? (signed ? 'ok' : 'bad') : 'bad',
      note: !bucketOk ? bucketNote : signed ? 'signed' : 'unsigned',
      live: [['packs', bucketOk ? String(packCount) : 'unknown']],
    },
    'buk.packs': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketNote,
      live: [['bytes', bucketOk ? String(bytes) : 'unknown']],
    },
    // Read by the panel alone, so its reachability is the bucket's.
    'buk.admin': { state: bucketOk ? 'ok' : 'bad', note: bucketNote, live: [] },
    // Served over the public door, which is the one that currently works.
    'buk.site': {
      state: cdnOk ? 'ok' : 'unknown',
      note: cdnOk ? 'served publicly' : 'not probed',
      live: [['cache', '300 seconds']],
    },
    'buk.orphans': {
      state: bucketOk ? 'ok' : 'unknown',
      note: bucketOk ? 'computable' : 'needs the bucket',
      live: [],
    },

    // ── G Recovery ─────────────────────────────────────────────────────────
    // Same sources, different payload. A document that is not published is
    // `unknown` rather than `bad`: not publishing a guide yet is a state, not
    // a fault, and the Overview's task list is where that gets chased.
    'rec.editor': { state: 'ok', note: 'available', live: [['runs in', 'the panel']] },
    'rec.publish': {
      state: process.env.PACK_SIGNING_KEY ? 'ok' : 'unknown',
      note: process.env.PACK_SIGNING_KEY ? 'key loaded' : 'no signing key configured',
      live: [
        ['key id', process.env.PACK_KEY_ID ?? '-'],
        ['algorithm', 'ed25519'],
      ],
    },
    'rec.pack': {
      state: !bucketOk ? 'bad' : hasPack('trashmap') ? 'ok' : 'unknown',
      note: !bucketOk ? bucketNote : hasPack('trashmap') ? 'published' : 'no trashmap published',
      live: [['version', packVersion('trashmap')]],
    },
    'rec.index': {
      state: bucketOk ? (signed ? 'ok' : 'bad') : 'bad',
      note: !bucketOk ? bucketNote : signed ? 'signed' : 'published without a signature',
      live: bucketOk
        ? [
            ['generatedAt', String(live?.generatedAt ?? 0)],
            ['documents', String(packCount)],
          ]
        : [['generatedAt', 'unknown']],
    },
    'rec.cdn': {
      state: cdnOk ? 'ok' : 'bad',
      note: cdnNote,
      live: [
        ['host', cdnBase().replace(/^https?:\/\//, '')],
        ['auth', 'none'],
      ],
    },
    'rec.sync': unknown('not measurable from the panel', [['cadence', 'launch, then daily']]),
    'rec.verify': unknown('not measurable from the panel', [['key', 'compiled into the APK']]),
    'rec.map': unknown('not measurable from the panel'),
    'rec.scan': unknown('not measurable from the panel'),

    'rec.dev.guide': {
      state: !bucketOk ? 'bad' : hasPack('oem-guide') ? 'ok' : 'unknown',
      note: !bucketOk ? bucketNote : hasPack('oem-guide') ? 'published' : 'nothing published yet',
      live: [['version', packVersion('oem-guide')]],
    },
    'rec.dev.docs': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketOk
        ? `${CONTENT_IDS.filter(hasPack).length} of ${CONTENT_IDS.length} published`
        : bucketNote,
      live: CONTENT_IDS.map((id) => [id, packVersion(id)] as [string, string]),
    },
    'rec.dev.match': unknown('not measurable from the panel'),
    'rec.dev.probe': unknown('not measurable from the panel'),
    'rec.dev.media': unknown('not measurable from the panel', [['requires', 'API 30 and up']]),
    'rec.dev.review': unknown('not measurable from the panel'),
    'rec.dev.restore': unknown('not measurable from the panel'),

    'rec.buk.root': {
      state: bucketOk ? 'ok' : 'bad',
      note: bucketNote,
      live: [
        ['bucket', process.env.R2_BUCKET ?? 'mindberzerk-cdn'],
        ['bytes', bucketOk ? String(bytes) : 'unknown'],
      ],
    },
    'rec.buk.index': {
      state: bucketOk ? (signed ? 'ok' : 'bad') : 'bad',
      note: !bucketOk ? bucketNote : signed ? 'signed' : 'unsigned',
      live: [['documents', bucketOk ? String(packCount) : 'unknown']],
    },
    'rec.buk.registries': {
      state: !bucketOk ? 'bad' : hasPack('trashmap') ? 'ok' : 'unknown',
      note: !bucketOk ? bucketNote : hasPack('trashmap') ? 'trashmap live' : 'empty',
      live: [['version', packVersion('trashmap')]],
    },
    'rec.buk.articles': {
      state: !bucketOk ? 'bad' : hasPack('learn-en') ? 'ok' : 'unknown',
      note: !bucketOk ? bucketNote : hasPack('learn-en') ? 'learn-en live' : 'empty',
      live: [['version', packVersion('learn-en')]],
    },
    'rec.buk.guides': {
      state: !bucketOk ? 'bad' : hasPack('oem-guide') ? 'ok' : 'unknown',
      note: !bucketOk ? bucketNote : hasPack('oem-guide') ? 'oem-guide live' : 'empty',
      live: [['version', packVersion('oem-guide')]],
    },
  };
}
