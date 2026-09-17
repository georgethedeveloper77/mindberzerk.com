import type { PanelJson, ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

/**
 * WHICH PANEL MODULES DUPLICATE ANDROID'S STATUS BAR, AND WHAT TO DO ABOUT IT.
 *
 * ─── THE RULE, IN ONE PLACE ────────────────────────────────────────────────
 *
 * A phone draws a clock, a wifi glyph, a speaker glyph and a battery glyph at
 * the top of the screen, always. A GNOME-family top bar sits a few pixels
 * under that row. Every module here that names one of those four is therefore
 * the same fact printed twice, four pixels apart, which is the opposite of the
 * authenticity the whole theme layer exists for.
 *
 * ─── AND WHY `tray` IS NOT ON THE LIST ─────────────────────────────────────
 *
 * It looked like the worst offender: on a TOP panel the tray stays a single
 * button whose face is a wifi glyph, a speaker glyph and a battery glyph, so
 * it read as a second status bar. But it is also the only visible way into
 * Quick Settings on those shells, and Quick Settings is a control Android's
 * own status bar cannot reach.
 *
 * So the device changed instead: `PanelTrayButton` draws ONE control glyph
 * while the system bar is showing and all three when the distro has hidden it.
 * A button that no longer impersonates a status bar is not duplication, and
 * stripping it here would take the door with the impersonation.
 *
 * ─── A RULE, NOT A TABLE OF EIGHT PACKS ────────────────────────────────────
 *
 * The obvious implementation was a map of packId to the corrected module list.
 * It is wrong for the same reason a `LayoutResolver` allow-list is: it goes
 * stale silently. A pack authored next month with a clock on it would pass an
 * audit built from last month's names, and the fallback would look plausible.
 */

/** Modules Android's own status bar already draws. */
export const DUPLICATE_MODULES = ['clock', 'battery', 'wifi', 'volume'] as const;

export interface PanelFix {
  /** The panels as they should be. Same array when nothing was wrong. */
  panels: PanelJson[];
  /** Modules taken off, in order, for the report. */
  removed: string[];
  changed: boolean;
}

/**
 * Strip duplicates from the TOP panel only.
 *
 * A bottom panel is 700dp from the status bar and duplicates nothing: every
 * desktop that has one puts real readouts on it, which is why Plasma, Mint and
 * Zorin come out of this untouched.
 *
 * A distro that hides the system bar is untouched too. It owns the whole row
 * and is expected to carry the clock, which is what Terminal and Pocket do.
 */
export function fixPanels(spec: ThemeSpecJson): PanelFix {
  const panels = spec.layout.panels ?? [];
  const systemBar = spec.layout.statusBar !== false;

  if (!panels.length || !systemBar) {
    return { panels, removed: [], changed: false };
  }

  const removed: string[] = [];

  const next = panels.map((p) => {
    if (p.side !== 'top') return p;

    const kept = p.modules.filter((m) => {
      const dupe = (DUPLICATE_MODULES as readonly string[]).includes(m);
      if (dupe) removed.push(m);
      return !dupe;
    });

    return { ...p, modules: tidySpacers(kept) };
  });

  return { panels: next, removed, changed: removed.length > 0 };
}

/**
 * Collapse the gaps a removal leaves behind.
 *
 * `activities spacer clock spacer tray` with the clock gone is `activities
 * spacer spacer tray`, which on the device is two Spacers sharing the slack
 * and pushing the tray to the middle rather than the end. Leading and trailing
 * spacers go for the same reason: a Spacer against the edge moves everything
 * off it.
 */
function tidySpacers<T extends string>(modules: T[]): T[] {
  const out: T[] = [];
  for (const m of modules) {
    if (m === 'spacer' && out[out.length - 1] === 'spacer') continue;
    out.push(m);
  }
  while (out[0] === 'spacer') out.shift();
  while (out[out.length - 1] === 'spacer') out.pop();
  return out;
}

/** The top panel's modules, for a report line. Empty when none is authored. */
export function topModules(spec: ThemeSpecJson): string[] {
  return (spec.layout.panels ?? [])
    .filter((p) => p.side === 'top')
    .flatMap((p) => p.modules as string[]);
}
