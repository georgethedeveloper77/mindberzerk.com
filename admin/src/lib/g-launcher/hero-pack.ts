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

import { CORE_PACKAGES, fileNameFor, isPackageName, type HeroPack } from '@/lib/g-launcher/icon-pack';

export { CORE_PACKAGES, fileNameFor, guessPackage, isPackageName } from '@/lib/g-launcher/icon-pack';
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
export const COMMON_APPS: { pkg: string; label: string }[] = CORE_PACKAGES.map(({ pkg, label }) => ({
  pkg,
  label,
}));

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
  const seenFile = new Set<string>();
  for (const e of drawn) {
    if (!isValidPackage(e.pkg)) p.push(`'${e.pkg}' is not a valid Android package name`);
    if (seenPkg.has(e.pkg)) p.push(`Package '${e.pkg}' is listed twice`);
    seenPkg.add(e.pkg);
    if (!isBareFilename(e.file)) p.push(`Filename '${e.file}' must be a bare name`);
    if (seenFile.has(e.file)) p.push(`Filename '${e.file}' is used twice`);
    seenFile.add(e.file);
  }
  return p;
}
