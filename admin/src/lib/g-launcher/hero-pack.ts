/**
 * ADAPTER over the canonical icon-pack.ts.
 *
 * icon-pack.ts is the source of truth for the hero-pack shape, the package
 * table, and the filename convention (it is read off HeroIconResolver and knows
 * hero art is NOT keyline-resized). This file used to duplicate all of that; now
 * it only adds what the builder needs on top: safe-id / bare-file / sku
 * validators, a byte-stable serializer for signing, and a draft-validation pass.
 * Everything else is re-exported so the builders reach one implementation.
 */

import {
  CORE_ROLES,
  fileNameFor,
  isPackageName,
  type HeroPack,
} from '@/lib/g-launcher/icon-pack';

export {
  CORE_PACKAGES,
  CORE_ROLES,
  expandRoleEntries,
  fileNameFor,
  guessPackage,
  isPackageName,
  roleForPackage,
} from '@/lib/g-launcher/icon-pack';
export type { CoreRole } from '@/lib/g-launcher/icon-pack';
export type { HeroPack as HeroPackJson } from '@/lib/g-launcher/icon-pack';

// ── validators icon-pack.ts does not provide ─────────────────────────────────

const PACK_ID = /^[a-z0-9._-]+$/;
const BARE_FILE = /^[A-Za-z0-9._-]+$/;
const SKU = /^[a-z0-9][a-z0-9_]{0,63}$/;

export function isSafePackId(id: string): boolean {
  return !!id && id.length <= 64 && !id.startsWith('.') && PACK_ID.test(id);
}
export function isBareFilename(f: string): boolean {
  return !!f && !f.includes('/') && !f.includes('\\') && !f.includes('..') && BARE_FILE.test(f);
}
export function isSafeSku(sku: string): boolean {
  return SKU.test(sku);
}
/** Defers to icon-pack's package check so there is one definition. */
export function isValidPackage(pkg: string): boolean {
  return isPackageName(pkg);
}

// ── builder-facing shapes ────────────────────────────────────────────────────

export interface HeroIconEntry {
  pkg: string;
  label: string;
  file: string;
}

export interface HeroPackDraftMeta {
  id: string;
  name: string;
  minAppVersion: number;
  masked: boolean;
  sku: string | null;
}

/** The apps grid, as {pkg,label}. Sourced from CORE_PACKAGES so the builder and
 *  the launcher's own reader agree on which apps matter. */
/**
 * The builder grid: ONE SLOT PER ROLE, not per package.
 *
 * `pkg` carries the ROLE ID now, and it keeps that field name because it is
 * the key every grid, assignment map and saved draft in both builders is
 * already keyed by; renaming it would touch a dozen files to say the same
 * thing. `expandRoleEntries` turns these slots into real package ids at
 * publish, and `packages` is here so a tile can say how many apps it covers.
 */
export const COMMON_APPS: { pkg: string; label: string; packages: string[] }[] =
  CORE_ROLES.map((r) => ({ pkg: r.id, label: r.label, packages: r.packages }));

/**
 * Byte-stable pack.json. Package keys sorted so identical content signs to
 * identical bytes and the manifest hash is stable across re-publishes.
 */
export function canonicalHeroPackJson(pack: HeroPack): string {
  const icons: Record<string, string> = {};
  for (const pkg of Object.keys(pack.icons).sort()) icons[pkg] = pack.icons[pkg];
  const body = { id: pack.id, name: pack.name, masked: pack.masked, icons };
  return JSON.stringify(body, null, 2) + '\n';
}

/** Problems the signer or device would reject, surfaced at edit time. */
export function validateHeroPack(meta: HeroPackDraftMeta, entries: HeroIconEntry[]): string[] {
  const p: string[] = [];
  if (!isSafePackId(meta.id)) p.push(`Pack id '${meta.id}' must be lowercase letters, digits, . _ or -`);
  if (!meta.name.trim()) p.push('Pack name is required');
  if (!Number.isInteger(meta.minAppVersion) || meta.minAppVersion < 0) {
    p.push('Min app version must be a whole number of 0 or more');
  }
  if (meta.sku != null && meta.sku !== '' && !isSafeSku(meta.sku)) {
    p.push(`SKU '${meta.sku}' must match a Play product id`);
  }

  const drawn = entries.filter((e) => e.file);
  if (drawn.length === 0) p.push('Draw or upload at least one icon');

  const seenPkg = new Set<string>();
  // Entries reach here ALREADY EXPANDED by `expandRoleEntries`, so every `pkg`
  // is a real package id and the check below is the same one it always was.
  // A role id would fail it, which is correct: a role that never expanded is a
  // slot that would ship as a package name no device has.
  //
  // ─── THERE IS NO DUPLICATE-FILENAME CHECK, AND THERE MUST NOT BE ──────────
  //
  // This function used to refuse a filename that appeared twice, which was
  // correct when a row was one package and became wrong the moment rows became
  // ROLES. One drawn Phone icon is deliberately mapped onto the AOSP, Google
  // and Samsung dialers by `expandRoleEntries`, so after expansion a three
  // package role produces three entries sharing one file. That is the design,
  // and checking for it here reported the role table working as an error:
  // "Filename 'messages.png' is used twice", once per extra package.
  //
  // Nothing was catching it because `IconBuilder.publish` never calls this; it
  // has its own `duplicates` memo over the UNEXPANDED slots, which is where a
  // repeated filename really is a fault and where it is still caught. The rule
  // belongs upstream of the expansion, so a caller that hands this expanded
  // entries must do its own pre-expansion duplicate check.
  //
  // The PACKAGE check below stays, and is the one that matters after
  // expansion: two roles claiming the same package id would make `pack.json`
  // describe one app with two different drawings.
  for (const e of drawn) {
    if (!isValidPackage(e.pkg)) p.push(`'${e.pkg}' is not a valid Android package name`);
    if (seenPkg.has(e.pkg)) p.push(`Package '${e.pkg}' is listed twice`);
    seenPkg.add(e.pkg);
    if (!isBareFilename(e.file)) p.push(`Filename '${e.file}' must be a bare name`);
  }
  return p;
}
