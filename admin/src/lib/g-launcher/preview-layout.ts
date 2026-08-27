import type { PanelJson, ThemeSpecJson } from './theme-spec';

/**
 * What the storefront card should DRAW, decided here and shipped in the index.
 *
 * ─── WHY THIS IS COMPUTED AT PUBLISH ────────────────────────────────────────
 *
 * The device holds only the index; this holds the whole theme.json. The card
 * used to pick its picture from `previewShell` alone, because that was the only
 * layout signal the index carried, and it was wrong for ten of fifteen distros
 * once `dock`, `dockStyle`, `dockReveal` and `homeLayout` became real fields.
 *
 * Shipping the five source fields instead would put this switch on the device
 * as well, in a second place, where the two would drift.
 *
 * ─── ORDER MATTERS, AND IT IS MOST-SPECIFIC FIRST ───────────────────────────
 *
 * A tiled Pop!_OS is also a distro with no dock, and a Fedora with a revealed
 * dash is also `dock: bottom`. Every arm below is reachable only because the
 * ones above it have already claimed the distros they describe.
 */
export type PreviewLayoutName =
  | 'dockLeft'
  | 'dockBottom'
  | 'dockFlat'
  | 'dockMagnified'
  | 'noDock'
  | 'barBottom'
  | 'dash'
  | 'tiled'
  | 'terminal';

export function previewLayoutFor(spec: ThemeSpecJson): PreviewLayoutName {
  const L = spec.layout ?? {};
  const dock = L.dock ?? 'bottom';
  const style = L.dockStyle ?? 'magnified';

  // A terminal is not a desktop with pieces missing; it is its own picture.
  if (spec.shell === 'tui') return 'terminal';

  // The desktop itself is the subject. Arch and Pop, and it outranks whatever
  // they do or do not do with a dock.
  if (L.homeLayout === 'tiled') return 'tiled';

  // There IS a dock, and it is not on the desktop. Only Fedora, and drawing it
  // as `noDock` would lose the one thing that distro is selling.
  if (L.dockReveal === 'apps') return 'dash';

  if (dock === 'off') {
    // A bottom PANEL and a bottom DOCK are different pictures, and no preview
    // ever drew the difference: every card painted a bar at the top whatever
    // the distro did. KDE, Mint and Zorin all live here.
    const panels = L.panels ?? [];
    const bottom = panels.some((p: PanelJson) => p.side === 'bottom');
    return bottom ? 'barBottom' : 'noDock';
  }

  if (dock === 'left') return 'dockLeft';

  // Bottom, and the style is what tells the three apart: Plank sits ON the
  // edge, a Latte dock swells, everything else floats clear.
  if (style === 'flat') return 'dockFlat';
  if (style === 'magnified') return 'dockMagnified';
  return 'dockBottom';
}
