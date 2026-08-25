/**
 * ─── NO `use client` HERE, AND THAT IS LOAD BEARING ─────────────────────────
 *
 * This file is pure data and pure functions. It is imported by client
 * components, which is fine, AND by `publish-derived.ts`, which is
 * `server-only`.
 *
 * With `'use client'` on it, Next replaced every export with a client
 * reference stub on the server side. `BASE_PACK_ID` then interpolated into a
 * template literal as the stub's own source, and the publish route reported:
 *
 *     function() { throw new Error("Attempted to call BASE_PACK_ID() from the
 *     server but BASE_PACK_ID is on the client...") } is not in the catalogue
 *
 * which reads as a missing pack rather than as a module boundary. A module with
 * no directive can be imported from either side, which is what data wants.
 *
 * `import type` rather than `import { type ... }`: the type-only form is
 * guaranteed to be erased, so nothing here pulls in `icon-compose`, which is
 * genuinely client-side because it needs a canvas.
 */
import type { ComposeSpec } from '@/lib/g-launcher/icon-compose';
// THE TABLE ITSELF. See the note below on why it is JSON.
import table from '@/lib/g-launcher/distros.json';

/**
 * THE FOURTEEN OFFICIAL ICON PACKS.
 *
 * ─── WHAT A PACK IS, COMMERCIALLY ───────────────────────────────────────────
 *
 * Every distro ships an icon pack in its own colour, and every one of those
 * packs is a paid product. The two are not in tension: running Kali grants Kali
 * Icons at no charge, and running Kali while wanting Ubuntu orange is a
 * purchase. So each row has BOTH a price and a grant, and which one applies
 * depends on the distro the device is running.
 *
 * That is already how `kali-2024-icons` works: product `icons_kali`, granted by
 * `kali-2024-theme`. This table generalises it to fourteen.
 *
 * ─── ONE GEOMETRY, FOURTEEN PRODUCTS ────────────────────────────────────────
 *
 * Every pack here is a ~200 byte file that points at `arcticons-line` and names
 * a colour. The 13,622 drawings ship once. Baking the colour into fourteen full
 * packs would be 148 MB to say the same thing fourteen times, and a fifteenth
 * distro would cost another 10.58 MB instead of another row in this table.
 *
 * ─── AND WHY ONLY THE COLOUR TRAVELS ────────────────────────────────────────
 *
 * A pack carries its tint and nothing else. Shape, corner radius and inset
 * follow the distro the device is RUNNING, which is what the icons screen means
 * by "Icon shape: following the distro". Buy Ubuntu Icons, run them on Kali, and
 * you get orange outlines in Kali's shape. Baking shape into the pack would make
 * a purchased pack fight the shell it was bought for.
 *
 * `compose` below is therefore for the ADMIN PANEL's preview strip only. The
 * device never reads it.
 *
 * ─── ON THE TINTS ───────────────────────────────────────────────────────────
 *
 * These are the distros' own brand colours, which means six of the fourteen are
 * blue and two are nearly identical: Arch `#1793D1` and Zorin `#0F94D2` differ
 * by 0.7 in CIE76, which nobody can see. That is a known and accepted cost of
 * using real brand colours rather than a spread palette.
 *
 * Every tint clears 3:1 against a dark plate. Fedora's `#3C6EB4` is the tightest
 * at 3.7:1, so a darker plate is the thing that breaks first.
 *
 * Changing a value here changes a SHIPPED PRODUCT's appearance. It is not a
 * design token.
 */

export interface DistroRecipe {
  /**
   * The distro base id this recipe belongs to. Matched by PREFIX against a pack
   * id, the same rule the launcher's icons screen uses to shelve packs, so a
   * recipe and its distro cannot drift apart through a second stored field.
   */
  base: string;
  title: string;
  /** Short label for the strip. */
  short: string;

  /** The theme pack this distro ships as. This is what grants the icons. */
  themeId: string;
  /**
   * The icon pack id this recipe publishes.
   *
   * ─── `-line`, NOT `-icons`, AND THAT IS NOT COSMETIC ──────────────────────
   *
   * `kali-2024-icons` already exists: a HERO pack at v18 carrying 54 hand-drawn
   * PNGs, referenced by `kali-2024-theme`. Republishing that id as a 207 byte
   * BRAND pack would have destroyed those 54 drawings and left a brand pack
   * sitting in a hero slot.
   *
   * Separate ids mean the layering the whole design rests on actually happens:
   * Kali's 54 hand-drawn icons WIN, the 13,622 line icons fill everything else,
   * the generator catches the rest. Today those 54 are the only themed icons on
   * the device and every other app falls through.
   *
   * One SKU grants both, so nobody pays twice.
   */
  packId: string;
  /** Display name, on device and in Play. */
  iconName: string;
  /** Play one-time product id, for buying this pack while on another distro. */
  sku: string;
  /**
   * Whether that product already exists in Play Console.
   *
   * Three do. Recorded rather than assumed, so the catalogue can say "create
   * this in Play" instead of publishing a pack nothing can charge for. That
   * failure is silent: the pack installs, the entitlement never arrives, and the
   * user sees a permanent Buy button on something they cannot buy.
   */
  skuLive: boolean;

  /** Wallpaper hue, panel thumbnail only. */
  wall: string;
  /** Page background behind it, panel thumbnail only. */
  canvas: string;
  /** Panel preview only. The device gets `tint` and takes shape from its distro. */
  compose: ComposeSpec;
}

/** The one geometry every pack below derives from. */
export const BASE_PACK_ID = table.base.packId;
export const BASE_LICENSE = table.base.license;
export const BASE_ATTRIBUTION = table.base.attribution;

/**
 * `tint` is the product. `strokeWidth` stays null throughout, because weight is
 * a property of the drawing rather than of the distro: a set that reads
 * correctly as Kali reads correctly as Mint at the same weight. Baking a
 * different weight into each would give fourteen subtly different sets
 * pretending to be one.
 */
/** Strip labels, where the full title is too long for a tile. */
const SHORT: Record<string, string> = {
  'kde-plasma-6': 'Plasma',
  'arch-linux': 'Arch',
  'deepin-23': 'Deepin',
  'elementary-os-8': 'elementary',
  endeavouros: 'Endeavour',
  'fedora-40': 'Fedora',
  'garuda-dr460nized': 'Garuda',
  'kali-2024': 'Kali',
  'linux-mint-22': 'Mint',
  'manjaro-kde': 'Manjaro',
  'pop-os-2204': 'Pop',
  'zorin-os-17': 'Zorin',
  'ubuntu-24-04': 'Ubuntu',
  terminal: 'Terminal',
};

/**
 * ─── THE FOURTEEN COME FROM `distros.json`, NOT FROM THIS FILE ──────────────
 *
 * They were declared here, in TypeScript, which meant a shell script could not
 * reach them. Publishing was a button in this panel, and publishing from a
 * script needed a second copy of the same fourteen rows.
 *
 * That copy would have drifted the first time a colour changed in one and not
 * the other, and the symptom is a pack published in a hex the panel never
 * showed. So the rows moved to JSON that both readers open:
 * `build-official-packs.mjs` and `verify-live.mjs` read this exact file.
 *
 * It lives under `admin/` rather than under `tools/` because the constrained
 * reader decides. Node can open any path in the repo; a Next.js bundler cannot
 * import from outside `admin/`.
 *
 * WHAT STAYS HERE is everything the device never sees: `compose` drives the
 * panel's preview strip only, and shape follows the distro a phone is RUNNING
 * rather than the pack it bought.
 */
const PREVIEW: Record<string, { wall: string; canvas: string; treatment: ComposeSpec['treatment']; cornerRadius: number }> = {
  'kde-plasma-6': { wall: '#1D99F3', canvas: '#0C1419', treatment: 'roundedSquare', cornerRadius: 0.18 },
  terminal: { wall: '#0F3D0F', canvas: '#050805', treatment: 'square', cornerRadius: 0 },
  'ubuntu-24-04': { wall: '#772953', canvas: '#120E10', treatment: 'circle', cornerRadius: 0.5 },
  'arch-linux': { wall: '#0F5C86', canvas: '#070C10', treatment: 'roundedSquare', cornerRadius: 0.12 },
  'deepin-23': { wall: '#1B4A8A', canvas: '#060A10', treatment: 'squircle', cornerRadius: 0.28 },
  'elementary-os-8': { wall: '#2E6E9E', canvas: '#0B1620', treatment: 'roundedSquare', cornerRadius: 0.22 },
  endeavouros: { wall: '#4B2470', canvas: '#0C0812', treatment: 'roundedSquare', cornerRadius: 0.2 },
  'fedora-40': { wall: '#294172', canvas: '#080B12', treatment: 'circle', cornerRadius: 0.5 },
  'garuda-dr460nized': { wall: '#7B4BD8', canvas: '#0E0B16', treatment: 'squircle', cornerRadius: 0.3 },
  'kali-2024': { wall: '#B4121C', canvas: '#000000', treatment: 'roundedSquare', cornerRadius: 0.22 },
  'linux-mint-22': { wall: '#3E7A1F', canvas: '#080C08', treatment: 'roundedSquare', cornerRadius: 0.14 },
  'manjaro-kde': { wall: '#1E7038', canvas: '#060C08', treatment: 'roundedSquare', cornerRadius: 0.24 },
  'pop-os-2204': { wall: '#FFB627', canvas: '#080F11', treatment: 'roundedSquare', cornerRadius: 0.16 },
  'zorin-os-17': { wall: '#0B5C85', canvas: '#060B10', treatment: 'roundedSquare', cornerRadius: 0.2 },
};

/**
 * Play products that already exist in the console.
 *
 * Recorded so the catalogue can say "create this in Play" rather than
 * publishing a pack nothing can charge for. That failure is silent: the pack
 * installs, the entitlement never arrives, and the user sees a permanent Buy
 * button on something that cannot be bought.
 *
 * All fourteen now exist, so this is every sku. It stays as a set rather than
 * becoming `true` everywhere, because the next distro added starts outside it.
 */
const SKUS_LIVE = new Set<string>([
  'icons_kde_plasma', 'icons_terminal', 'icons_ubuntu', 'icons_arch_linux',
  'icons_deepin', 'icons_elementary_os', 'icons_endeavouros', 'icons_fedora',
  'icons_garuda', 'icons_kali', 'icons_linux_mint', 'icons_manjaro',
  'icons_pop_cosmic', 'icons_zorin_os',
]);

export const DISTRO_RECIPES: DistroRecipe[] = table.distros.map((d) => {
  const preview = PREVIEW[d.base];
  if (!preview) {
    // A row in the JSON with no preview here would render a black tile in the
    // strip and look like a broken image rather than a missing entry.
    throw new Error(`distro-recipes: no preview for '${d.base}'. Add one to PREVIEW.`);
  }
  return {
    base: d.base,
    title: d.title,
    short: SHORT[d.base] ?? d.title,
    themeId: d.themeId,
    packId: d.packId,
    iconName: `${d.title} Icons`,
    sku: d.sku,
    skuLive: SKUS_LIVE.has(d.sku),
    wall: preview.wall,
    canvas: preview.canvas,
    compose: {
      plate: { kind: 'colour', colour: preview.canvas },
      treatment: preview.treatment,
      cornerRadius: preview.cornerRadius,
      inset: 0.12,
      // Weight is a property of the drawing, not of the distro: a set that
      // reads correctly as Kali reads correctly as Mint at the same weight.
      strokeWidth: null,
      tint: d.tint,
    },
  };
});

/**
 * The recipe that OWNS this pack id. Exact match only.
 *
 * ─── IDENTITY AND SHELVING ARE DIFFERENT QUESTIONS ──────────────────────────
 *
 * This was one prefix match answering both, and the two want opposite things.
 *
 * "Which distro does this pack belong under on the icons screen" wants to be
 * generous: a user's own `kali-mine-icons` should sit under Kali Linux. That is
 * [shelfForPack] below.
 *
 * "Which recipe publishes this pack, and which SKU grants it" must be exact. A
 * prefix match said `terminal-emulator-icons` was the Terminal distro's official
 * pack, because `terminal` is four characters and a prefix of plenty. Publishing
 * off that answer would have written a third-party pack id into the official
 * catalogue and attached `icons_terminal` to it.
 *
 * Anything that decides money, publishing or entitlement uses this one.
 */
export function recipeForPack(packId: string): DistroRecipe | null {
  return DISTRO_RECIPES.find((r) => r.packId === packId) ?? null;
}

/**
 * The distro a pack id should be SHELVED under, by longest matching prefix.
 *
 * Longest wins, mirroring `IconBuilder`'s `belongsTo` and the device's own
 * shelving rule: `kali-2024` and a future `kali-2025` would both match a bare
 * `kali`. Display only. Never use this to decide what something costs.
 */
export function shelfForPack(packId: string): DistroRecipe | null {
  return (
    [...DISTRO_RECIPES]
      .sort((a, b) => b.base.length - a.base.length)
      .find((r) => packId === r.base || packId.startsWith(`${r.base}-`)) ?? null
  );
}

/** The recipe for a distro's theme id, which is how a grant is resolved. */
export function recipeForTheme(themeId: string): DistroRecipe | null {
  return DISTRO_RECIPES.find((r) => r.themeId === themeId) ?? null;
}

/**
 * The pack id this recipe would produce from [packId]'s suffix.
 *
 * Keeps whatever the author called the set and swaps only the distro prefix, so
 * `kali-2024-icons` retargeted to Mint becomes `linux-mint-22-icons` rather than
 * a generic `mint-icons`. A pack with no recognised prefix gets one prepended
 * rather than rewritten.
 */
export function retargetPackId(packId: string, to: DistroRecipe): string {
  // Shelf, not identity: this runs on whatever pack is open in the builder,
  // including a draft that is not in the official catalogue at all.
  const from = shelfForPack(packId);
  if (!from) return `${to.base}-${packId}`;
  const suffix = packId.slice(from.base.length).replace(/^-/, '');
  // `-line` matches what these recipes actually publish. A bare fallback of
  // `-icons` would mint an id that collides with the hand-drawn hero packs,
  // which is the exact collision the rename above exists to avoid.
  return suffix ? `${to.base}-${suffix}` : `${to.base}-line`;
}

/** Recipes whose Play product does not exist yet. The catalogue's to-do list. */
export function missingSkus(): DistroRecipe[] {
  return DISTRO_RECIPES.filter((r) => !r.skuLive);
}
