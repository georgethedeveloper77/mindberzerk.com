import type { ThemeFeatureJson, ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

/**
 * ROWS PROPOSED FROM THE SPEC. Not written by it.
 *
 * ─── WHY THIS IS A SUGGESTION AND NOT A PUBLISH STEP ────────────────────────
 *
 * Deriving rows inside `publishDistro` was the obvious version and it is wrong
 * three ways. It would overwrite whatever the author wrote on every republish,
 * so a corrected sentence would survive until the next publish and no longer.
 * It would erase the `[]` that means "this distro names nothing deliberately",
 * a state the panel, `sign.ts` and `theme_catalog` all take trouble to keep
 * distinct from absence, and which `arch-linux-theme` carries in the live index
 * right now. And it would put marketing prose on the far side of review.
 *
 * So this returns candidates and something else decides. The author accepts,
 * edits or deletes, and what ships is what they left behind.
 *
 * ─── `exclusive` IS DECIDED MECHANICALLY, NOT OPTIMISTICALLY ────────────────
 *
 * The rule, which the spec's own doc comments state field by field: a field the
 * user can change in Settings is NOT exclusive, whatever a distro sets it to.
 * `desktopIcons` says it is "a real exclusive row rather than a setting";
 * `panelEdit` is theme-authored only; `drawerScrollStyle` and `drawerGrouping`
 * say they were promoted to global prefs and a promoted value is a choice the
 * distro may not overrule.
 *
 * So the palette, the typeface, the icon treatment and the corner radius never
 * appear here as exclusive, however much they distinguish a distro visually.
 * They are the one non-exclusive row this emits, which is what Ubuntu's floor
 * card has always done with "Aubergine and orange. Ubuntu Sans, Yaru squircles."
 *
 * ─── AND IT WILL RETURN NOTHING FOR SOME DISTROS ────────────────────────────
 *
 * That is the point rather than a shortfall. A reader of fields cannot invent
 * differentiation: a distro whose spec sets no panel, no desktop icons, no
 * panel editing, no boot log and no shell-specific launcher genuinely has
 * nothing the free settings do not already do. Fedora, Zorin, Manjaro and
 * Deepin are in that position, two of them are paid, and an empty return here
 * is that fact stated mechanically instead of discovered after publish.
 */

/** Sentence case for a value that arrives as a lowercase token. */
function cap(s: string): string {
  return s.length === 0 ? s : s[0].toUpperCase() + s.slice(1);
}

/** "a, b and c" from a list, or "" when empty. */
function list(items: string[]): string {
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

/**
 * Candidate rows for [spec], in the order they should sell.
 *
 * ORDER IS NOT ALPHABETICAL AND NOT THE SPEC'S FIELD ORDER. The first two
 * exclusive rows are what the card shows, so the most distro-defining claim has
 * to come first: what the desktop IS beats what it carries, which beats what it
 * does on the way in. The author reorders by dragging; this only decides where
 * the list starts.
 */
export function suggestFeatures(spec: ThemeSpecJson): ThemeFeatureJson[] {
  const out: ThemeFeatureJson[] = [];
  const l = spec.layout;
  const add = (title: string, body: string, exclusive: boolean) =>
    out.push({ title, body, exclusive });

  // ── what the desktop is ───────────────────────────────────────────────────

  // Tiling. `homeLayout: tiled` is the desktop filling edge to edge, which is
  // the single most recognisable thing about the distros that do it.
  if (l?.homeLayout === 'tiled') {
    add(
      'Tiling workspaces',
      'Apps split the screen instead of stacking on it.',
      true,
    );
  }

  // The launcher a tiling distro opens. Read only by `TilingLauncher`, so it is
  // shell-authored with no prefs arm.
  if (l?.tilingLauncher) {
    add(
      `${l.tilingLauncher} launcher`,
      'Type to run, the way the real desktop does it.',
      true,
    );
  }

  // Plasma's Kickoff rail. Same shape: read only by `KickoffDrawer`.
  if (l?.kickoffRail) {
    add(
      'Kickoff menu',
      l.kickoffRail === 'categories'
        ? 'Categories down the side, apps and places beside them.'
        : 'Pinned, apps and places behind one corner button.',
      true,
    );
  }

  // ── what it carries ───────────────────────────────────────────────────────

  // Panels, named by what they actually hold. A module list is the difference
  // between "has a bar" and "has THIS bar", and it is the reason this reads the
  // array rather than the boolean.
  const panels = l?.panels ?? [];
  if (panels.length > 0) {
    const sides = [...new Set(panels.map((p) => p.side))];
    const modules = [
      ...new Set(
        panels
          .flatMap((p) => p.modules ?? [])
          // A spacer is layout, not a readout, and naming it in a sentence
          // about what the bar shows would be describing the gap.
          .filter((m) => m !== 'spacer'),
      ),
    ];
    add(
      sides.length > 1
        ? `${cap(sides[0])} and ${sides[1]} panels`
        : `${cap(sides[0] ?? 'top')} panel`,
      modules.length > 0
        ? `${cap(list(modules))}, live on the bar.`
        : 'A bar the shell draws for itself.',
      true,
    );
  } else if (l?.topBarStats) {
    // The pre-`panels` form. Still real on every theme authored before panels
    // existed, and the device synthesises a panel from it.
    add(
      'Live status bar',
      'Throughput, memory and free space along the top.',
      true,
    );
  }

  // Desktop icons. The spec's own doc calls this a real exclusive row: the
  // distro sets the ceiling and the user may only lower it.
  if (l?.desktopIcons) {
    add(
      'Desktop icons',
      'Apps placed on the workspace itself, not only in the drawer.',
      true,
    );
  }

  // Panel editing. Theme-authored only: whether the user MAY rearrange the
  // panel is not itself something the user sets.
  if (l?.panelEdit) {
    add(
      'Panel edit mode',
      'Hold the panel, add or remove modules, move it to any edge.',
      true,
    );
  }

  // ── what it does on the way in ────────────────────────────────────────────

  // A boot log is authored line by line and there is no setting that produces
  // one, so the count is both honest and the measure of the work in it.
  const bootLines = readBootLineCount(spec);
  if (bootLines >= 3) {
    add(
      'Authored boot log',
      `${bootLines} lines of this distro's own start-up, before the desktop.`,
      true,
    );
  }

  // ── and the row that is never exclusive ───────────────────────────────────

  const look = lookAndFeel(spec);
  if (look) add(look.title, look.body, false);

  return out;
}

/**
 * How many boot lines the spec authors.
 *
 * `boot` is typed `unknown` on `ThemeSpecJson`, because the panel passes it
 * through without modelling it. Read defensively rather than cast: a shape this
 * file does not recognise must produce no row, never a thrown suggestion.
 */
function readBootLineCount(spec: ThemeSpecJson): number {
  const boot = spec.boot;
  if (!boot || typeof boot !== 'object') return 0;
  const lines = (boot as { lines?: unknown }).lines;
  return Array.isArray(lines) ? lines.length : 0;
}

/**
 * The palette-and-typeface row, always `exclusive: false`.
 *
 * Every ingredient here has a prefs arm. Emitting it as exclusive would be the
 * flattering direction and would make the Verdict green on a distro that is
 * selling a palette, which is the exact failure the flag exists to catch.
 *
 * It still earns a place on the detail page, where it is the "Look and feel"
 * block, and it is what Ubuntu's floor card has always carried as its third
 * row.
 */
function lookAndFeel(
  spec: ThemeSpecJson,
): { title: string; body: string } | null {
  const parts: string[] = [];

  const display = spec.typography?.display?.trim();
  if (display) parts.push(display);

  const treatment = spec.icons?.treatment?.trim();
  if (treatment) parts.push(`${treatment} icons`);

  if (parts.length === 0) return null;

  return {
    // Named after the distro rather than after its hex values. "#1793D1 and
    // #0F1A24" is true and unreadable; a person recognises the name.
    title: `${spec.name} palette`,
    body: `${list(parts)}.`,
  };
}
