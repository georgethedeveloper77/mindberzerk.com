/**
 * No `use client`. Imported by the icons page's catalogue card AND by
 * `publish-derived.ts`, which is `server-only`, and a directive here would make
 * every export a client stub on the server. See the note in `distro-recipes.ts`
 * for what that looked like when it happened.
 *
 * Nothing in this file touches the DOM: `TextEncoder` is in Node too.
 */
import {
  BASE_ATTRIBUTION,
  BASE_LICENSE,
  BASE_PACK_ID,
  DISTRO_RECIPES,
  type DistroRecipe,
} from '@/lib/g-launcher/distro-recipes';

/**
 * A DERIVED PACK: 200 BYTES THAT POINT AT 10.58 MB.
 *
 * ─── THE SHAPE ──────────────────────────────────────────────────────────────
 *
 *   { "v": 1, "id": "kali-2024-icons", "name": "Kali Icons",
 *     "extends": "arcticons-line", "tint": "#367BF0",
 *     "license": "CC-BY-SA-4.0",
 *     "attribution": "Arcticons by Donnnno, CC BY-SA 4.0" }
 *
 * No `icons`, no `glyphs`. `BrandIconResolver` sees `extends`, loads that pack's
 * geometry through the path it already has, and stamps `tint` onto every glyph.
 *
 * ─── ATTRIBUTION IS REPEATED, NOT INHERITED ─────────────────────────────────
 *
 * It would be tidier for a derived pack to inherit its credit from the base, and
 * it would be wrong. CC BY-SA requires the credit to travel with the work, and
 * these fourteen are the things a user actually receives and pays for. A pack
 * that arrives without its attribution is the licence problem regardless of
 * where its geometry came from, and "the file it points at has the credit" is
 * not a defence anybody would accept.
 *
 * Seventy bytes each. Cheap insurance.
 *
 * ─── WHAT THIS DELIBERATELY DOES NOT CARRY ──────────────────────────────────
 *
 * Shape, corner radius and inset. Those follow the distro the device is RUNNING,
 * not the pack it bought, so Ubuntu Icons on Kali means orange outlines in
 * Kali's shape. Putting them here would make a purchased pack fight the shell it
 * was bought for.
 */

export interface DerivedPack {
  v: 1;
  id: string;
  name: string;
  extends: string;
  tint: string;
  license: string;
  attribution: string;
}

/**
 * The index entry a derived pack needs.
 *
 * Mirrors `IndexPack` from `core/sign.ts`, including `title` and `summary`,
 * which are REQUIRED there. An entry missing them fails at sign time rather
 * than at publish, and the message names the field, but building it wrong here
 * would mean fourteen entries to correct instead of one.
 */
export interface DerivedEntry {
  packId: string;
  packType: 'brand';
  path: string;
  version: number;
  minAppVersion: number;
  sizeBytes: number;
  title: string;
  summary: string;
  sku?: string;
  /**
   * ─── WITHOUT THIS THE PACK INSTALLS AND DRAWS NOTHING ─────────────────────
   *
   * A derived pack is 200 bytes of pointer. A device that installs it without
   * `arcticons-line` gets a valid, verified, signed pack containing no geometry,
   * and every icon silently falls through to the generator. Nothing logs,
   * nothing fails, and the user has paid for a pack that does nothing.
   *
   * Declaring the dependency is the only way the downloader can know to fetch
   * the base first.
   */
  requires: string[];
}

/**
 * ─── THE VERSION THAT ENFORCES `requires` ───────────────────────────────────
 *
 * `CdnIndex.parseTrusted` reads named keys with defaults, so a build that does
 * not know about `requires` IGNORES it rather than refusing the index. That
 * tolerance is what makes the field safe to add, and it is also exactly the
 * failure: such a build installs a 200 byte pointer on its own and every icon
 * falls through to the generator, silently.
 *
 * So this must be the first release whose downloader follows the field. It is 7
 * rather than 6 for that reason alone, and raising it is what actually protects
 * the fourteen packs; the field only describes the dependency.
 */
export const DERIVED_MIN_APP_VERSION = 7;

const HEX = /^#[0-9a-fA-F]{6}$/;
const PACK_ID = /^[a-z0-9][a-z0-9._-]*$/;

/** Turn a recipe into the file that ships. Pure, so it is testable without a CDN. */
export function derivedPack(r: DistroRecipe): DerivedPack {
  const tint = r.compose.tint;
  if (!tint || !HEX.test(tint)) {
    throw new Error(`${r.packId}: tint must be a 6 digit hex, got ${String(tint)}`);
  }
  if (!PACK_ID.test(r.packId)) {
    throw new Error(`${r.packId}: not a safe pack id`);
  }
  if (r.packId === BASE_PACK_ID) {
    // A pack extending itself is an infinite loop in the resolver, and the
    // resolver is on the icon path, so it would hang the drawer rather than
    // throwing somewhere visible.
    throw new Error(`${r.packId}: a pack cannot extend itself`);
  }
  return {
    v: 1,
    id: r.packId,
    name: r.iconName,
    extends: BASE_PACK_ID,
    tint: tint.toLowerCase(),
    license: BASE_LICENSE,
    attribution: BASE_ATTRIBUTION,
  };
}

/** All fourteen, with the same validation applied to every one. */
export function allDerivedPacks(): DerivedPack[] {
  const packs = DISTRO_RECIPES.map(derivedPack);
  const ids = new Set(packs.map((p) => p.id));
  if (ids.size !== packs.length) {
    // Two recipes writing one pack id means the second silently overwrites the
    // first at publish, and the distro that lost is left pointing at a pack
    // wearing another distro's colour.
    const seen = new Set<string>();
    const dupe = packs.find((p) => (seen.has(p.id) ? true : (seen.add(p.id), false)));
    throw new Error(`duplicate pack id: ${dupe?.id}`);
  }
  return packs;
}

/** Exact bytes, so a caller can size and hash without re-serialising. */
export function derivedPackJson(pack: DerivedPack): string {
  return JSON.stringify(pack, null, 2) + '\n';
}

export function derivedEntry(
  r: DistroRecipe,
  version: number,
  sizeBytes: number,
  path: string,
): DerivedEntry {
  const entry: DerivedEntry = {
    packId: r.packId,
    packType: 'brand',
    // The version is IN the path, which `uploadPack` owns. Rebuilding it here
    // from a guess would produce an entry pointing at a URL nothing wrote.
    path,
    version,
    minAppVersion: DERIVED_MIN_APP_VERSION,
    sizeBytes,
    title: r.iconName,
    summary: `${r.title} outline icons, over 13,000 apps`,
    requires: [BASE_PACK_ID],
  };
  // A blank sku would publish the pack as free rather than as unpriced, and a
  // free pack cannot later become paid without every existing install keeping
  // it. Omitted entirely instead.
  if (r.sku) entry.sku = r.sku;
  return entry;
}

/**
 * What a purchase grants.
 *
 * TWO packs, not one. The base is free and every device needs it, but granting
 * it explicitly means a purchase never half-lands: a user who buys Ubuntu Icons
 * while running Kali has no other reason to hold `arcticons-line`, and an
 * entitlement that names only the derived pack would leave them with a pointer
 * to geometry they were never granted.
 */
export function grantsFor(r: DistroRecipe): { sku: string; packIds: string[] } {
  return { sku: r.sku, packIds: [r.packId, BASE_PACK_ID] };
}

export interface PublishPlan {
  packs: { recipe: DistroRecipe; pack: DerivedPack; json: string; bytes: number }[];
  /** Recipes whose Play product does not exist yet. Publishing anyway is fine. */
  missingSkus: DistroRecipe[];
  totalBytes: number;
}

/**
 * Everything a publish would write, computed before anything is written.
 *
 * Fourteen packs is not undoable in one gesture, and a plan that reports its
 * size and its gaps first is the difference between a considered publish and a
 * button somebody presses twice.
 */
export function planPublish(): PublishPlan {
  const packs = DISTRO_RECIPES.map((recipe) => {
    const pack = derivedPack(recipe);
    const json = derivedPackJson(pack);
    return { recipe, pack, json, bytes: new TextEncoder().encode(json).length };
  });
  return {
    packs,
    missingSkus: DISTRO_RECIPES.filter((r) => !r.skuLive),
    totalBytes: packs.reduce((a, p) => a + p.bytes, 0),
  };
}
