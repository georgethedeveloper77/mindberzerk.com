'use client';

import { GlyphStore } from '@/lib/g-launcher/glyph-store';
import { roleForPackage, type CoreRole } from '@/lib/g-launcher/icon-pack';

/**
 * A LIST OF INSTALLED PACKAGES BECOMES A PACK.
 *
 * ─── WHY THIRTY ICONS IS NOT A PACK ─────────────────────────────────────────
 *
 * Filling a set one app at a time is fine for the dock and hopeless past it.
 * The index already holds 32,951 package ids mapped to 13,623 drawings by hand,
 * and a phone runs a couple of hundred apps, so the intersection is the pack.
 * Nothing needs to be guessed and nothing needs to be drawn; the work is a
 * lookup that a person should not be doing by hand two hundred times.
 *
 * ─── COLLAPSING TO ROLES IS THE WHOLE TRICK ─────────────────────────────────
 *
 * A package list off a real device contains `com.android.dialer` AND
 * `com.google.android.dialer` AND `com.samsung.android.dialer`. Added as three
 * rows they are three entries, three duplicate drawings, and a Publish button
 * that greys out on `duplicates.size === 0` with nothing on screen saying why.
 *
 * All three are the `phone` ROLE. Collapsed, they are one row, one drawing, and
 * `expandRoleEntries` puts it back onto all three package ids at publish, plus
 * every other dialer in the role table that this particular phone happens not
 * to have installed. So collapsing does not lose coverage, it GAINS it.
 *
 * ─── WHAT THIS DELIBERATELY DOES NOT DO ─────────────────────────────────────
 *
 * It does not compose or rasterise. It returns art and slots, and the caller
 * runs them through the same intake every dropped file goes through, so a bulk
 * fill and a hand-picked icon are indistinguishable afterwards and the style
 * bar restyles both. A separate bulk path would be a second pipeline to keep
 * in step with the first, and this codebase has already paid for that twice.
 */

export interface FillRow {
  /** Role id when a role claimed it, otherwise the raw package id. */
  slot: string;
  slug: string;
  svg: string;
  label: string;
  /** True when several packages folded into this one row. */
  viaRole: boolean;
  /** Every package this row will cover at publish. */
  packages: string[];
}

export interface FillPlan {
  rows: FillRow[];
  /** Packages the index has no drawing for. The work that remains. */
  missed: string[];
  /** How many listed packages folded into a smaller number of role rows. */
  collapsed: number;
  /** Rows skipped because the slot is already filled in the builder. */
  alreadyCovered: number;
  /** Packages that were not valid Android ids, usually list formatting. */
  malformed: string[];
}

/** Package ids from pasted text: one per line, comments and blanks dropped. */
export function parsePackageList(text: string): string[] {
  return text
    .split(/[\n,]/)
    // `adb shell` on macOS emits CRLF, and a surviving carriage return makes
    // every id miss the map. That failure reads as "the index is broken"
    // rather than "the file has invisible characters in it", so it is stripped
    // here as well as in the sync script.
    .map((l) => l.trim().replace(/^package:/, ''))
    .filter((l) => l.length > 0 && !l.startsWith('#'));
}

const PACKAGE_ID = /^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$/i;

/**
 * What a fill would add, without adding it.
 *
 * Separated from the doing so the count can be shown before the button is
 * pressed. Adding two hundred rows is not undoable in one gesture, and a
 * control that large should say what it will do first.
 */
export function planFill(
  store: GlyphStore,
  packages: string[],
  taken: ReadonlySet<string>,
): FillPlan {
  const rows: FillRow[] = [];
  const missed: string[] = [];
  const malformed: string[] = [];
  const bySlot = new Map<string, FillRow>();
  let collapsed = 0;
  let alreadyCovered = 0;

  for (const pkg of packages) {
    if (!PACKAGE_ID.test(pkg)) {
      malformed.push(pkg);
      continue;
    }

    const slug = store.slugFor(pkg);
    if (!slug) {
      missed.push(pkg);
      continue;
    }
    const svg = store.svgFor(slug);
    if (!svg) {
      // The map knows the drawing and the bundle does not carry it. A different
      // fact from "no drawing exists", and one the caller reports differently:
      // this is fixed by re-running the sync, not by drawing anything.
      missed.push(pkg);
      continue;
    }

    const role: CoreRole | null = roleForPackage(pkg);
    const slot = role ? role.id : pkg;

    if (taken.has(slot)) {
      alreadyCovered += 1;
      continue;
    }

    const existing = bySlot.get(slot);
    if (existing) {
      collapsed += 1;
      // The role's own package list already covers every vendor id, so nothing
      // is appended here. Recording the fold is the only thing left to do.
      continue;
    }

    const row: FillRow = {
      slot,
      slug,
      svg,
      label: role ? role.label : pkg,
      viaRole: !!role,
      packages: role ? role.packages : [pkg],
    };
    bySlot.set(slot, row);
    rows.push(row);
  }

  return { rows, missed, collapsed, alreadyCovered, malformed };
}

/**
 * Coverage of a list, as a sentence's worth of numbers.
 *
 * Reported against the LIST rather than against the index, because "we matched
 * 8% of Arcticons" is true and useless, and "191 of your 249 apps have a
 * drawing" is the number that decides whether this pack is worth publishing.
 */
export function fillSummary(plan: FillPlan, listed: number): string {
  const add = plan.rows.length;
  const parts = [`${add} ${add === 1 ? 'icon' : 'icons'} from ${listed} apps`];
  if (plan.collapsed > 0) {
    parts.push(`${plan.collapsed} folded into shared roles`);
  }
  if (plan.alreadyCovered > 0) {
    parts.push(`${plan.alreadyCovered} already in the pack`);
  }
  if (plan.missed.length > 0) {
    parts.push(`${plan.missed.length} with no drawing`);
  }
  if (plan.malformed.length > 0) {
    parts.push(`${plan.malformed.length} not package ids`);
  }
  return parts.join(', ');
}
