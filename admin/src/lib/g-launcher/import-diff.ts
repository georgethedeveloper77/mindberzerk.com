import type { ThemeSpecJson } from './theme-spec';

/**
 * What the importer threw away, as a list of human sentences.
 *
 * ─── THREE TIMES IN ONE SESSION ─────────────────────────────────────────────
 *
 * A value is authored, parsed, and then silently removed by an allow-list
 * downstream, and the fallback is something plausible so nothing looks broken:
 *
 *   * `PANEL_MODULES` was five entries, so Arch's `pager` and `clock` vanished
 *     from its bar and it published with a two-module panel.
 *   * `APP_DRAWERS` did not yet know `library`, so Pocket imported without a
 *     drawer and rendered the shared grid.
 *   * Garuda published with `modules: ["spacer"]` where four were authored.
 *
 * Every one was found by a person noticing a screen looked wrong, days later.
 * The panel knew at import time: it holds the file that was fed in AND the
 * canonical form it produced, in the same function, and said nothing.
 *
 * ─── PRESENT-THEN-ABSENT, AND NOTHING ELSE ──────────────────────────────────
 *
 * This reports a field the raw JSON had and the canonical form does not, plus
 * array entries lost from a list that survived. It deliberately does NOT report
 * value changes: the canonicaliser legitimately rewrites and omits things, and a
 * warning that fires on correct behaviour is one people learn to scroll past.
 * That already happened once this session, with a free distro's `sku`.
 *
 * ─── AND IT NAMES THE VALUE, NOT JUST THE PATH ──────────────────────────────
 *
 * "layout.panels[0].modules lost kickoff, tray, clock" is actionable in a way
 * that "modules changed" is not: the three names are the search term for the
 * allow-list that ate them.
 */
export function importDiff(raw: unknown, spec: ThemeSpecJson): string[] {
  const out: string[] = [];
  if (!raw || typeof raw !== 'object') return out;
  walk(
    raw as Record<string, unknown>,
    spec as unknown as Record<string, unknown>,
    '',
    out,
  );
  return out;
}

/**
 * Paths the canonicaliser drops ON PURPOSE.
 *
 * Each is a value equal to the engine's own default, omitted so the theme.json
 * stays diffable and a distro that authored nothing looks like one. Reporting
 * them would be reporting correct behaviour, which is how a warning becomes
 * noise.
 *
 * A PREFIX match, because these are whole subtrees in two cases: `preview` is
 * composited by the workspace rather than authored, and `logo` is rewritten to
 * the uploaded filenames.
 */
const EXPECTED = [
  'version',
  'preview',
  'logo',
  // Legacy, replaced by `panels` on import. Its absence downstream is the
  // migration working, not a loss.
  'layout.topBar',
];

function expected(path: string): boolean {
  return EXPECTED.some((e) => path === e || path.startsWith(`${e}.`));
}

function walk(
  from: Record<string, unknown>,
  to: Record<string, unknown>,
  prefix: string,
  out: string[],
): void {
  for (const [key, value] of Object.entries(from)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value === undefined || value === null) continue;
    if (expected(path)) continue;

    const there = to?.[key];

    if (there === undefined) {
      // The whole field went. This is the case that has bitten three times.
      out.push(`${path} was dropped (${describe(value)})`);
      continue;
    }

    if (Array.isArray(value) && Array.isArray(there)) {
      // ── A LIST THAT SURVIVED WITH FEWER ENTRIES ──────────────────────
      //
      // The `modules` case exactly: the panel arrives, `side` and `height` are
      // intact, and three of four names are gone. Nothing above would have
      // noticed, because the key is present.
      if (value.every((v) => typeof v === 'string')) {
        const kept = new Set(there.map(String));
        const lost = value.map(String).filter((v) => !kept.has(v));
        if (lost.length > 0) {
          out.push(`${path} lost ${lost.join(', ')}`);
        }
        continue;
      }
      // Objects in a list: recurse pairwise, and report a shortened list.
      if (there.length < value.length) {
        out.push(
          `${path} lost ${value.length - there.length} of ${value.length} entries`,
        );
      }
      for (let i = 0; i < Math.min(value.length, there.length); i++) {
        const a = value[i];
        const b = there[i];
        if (a && b && typeof a === 'object' && typeof b === 'object') {
          walk(
            a as Record<string, unknown>,
            b as Record<string, unknown>,
            `${path}[${i}]`,
            out,
          );
        }
      }
      continue;
    }

    if (
      value &&
      there &&
      typeof value === 'object' &&
      typeof there === 'object' &&
      !Array.isArray(value)
    ) {
      walk(
        value as Record<string, unknown>,
        there as Record<string, unknown>,
        path,
        out,
      );
    }
  }
}

/** A short rendering of a dropped value, so the message names what was lost. */
function describe(v: unknown): string {
  if (Array.isArray(v)) {
    return v.length <= 4
      ? v.map((x) => String(x)).join(', ')
      : `${v.length} entries`;
  }
  if (v && typeof v === 'object') return `${Object.keys(v).length} fields`;
  return String(v);
}

/**
 * Blocks the draft already had that this import does not carry.
 *
 * ─── A DIFFERENT LOSS, INVISIBLE TO [importDiff] ────────────────────────────
 *
 * That function compares the FILE against the SPEC and catches an allow-list
 * eating a value on the way in. It is blind to this one, because both sides
 * agree: a layout-only theme.json has no `boot`, the canonicaliser produces no
 * `boot`, nothing was dropped, and nothing is reported.
 *
 * The loss is between the DRAFT and the file. `applyImport` calls
 * `setSpec(imported.spec)`, which replaces everything, so importing a partial
 * theme.json silently discards whatever the draft held and the file omits.
 * Arch lost its boot log, its splash and its desklet skins exactly that way,
 * and it was caught by someone looking at three empty textareas.
 *
 * ─── TOP-LEVEL BLOCKS ONLY ──────────────────────────────────────────────────
 *
 * `boot`, `splash`, `desklets`, `categories`, `wallpapers`, `fonts`: the
 * self-contained ones an author would reasonably leave out of a file about
 * layout. Going deeper would fire on every field the canonicaliser omits as a
 * default, and a warning that cries wolf is one nobody reads. That argument has
 * already cost this codebase once.
 */
export function replacedBlocks(
  draft: ThemeSpecJson,
  incoming: ThemeSpecJson,
): string[] {
  const BLOCKS = [
    'boot',
    'splash',
    'desklets',
    'categories',
    'wallpapers',
    'fonts',
  ] as const;

  const before = draft as unknown as Record<string, unknown>;
  const after = incoming as unknown as Record<string, unknown>;

  const gone = BLOCKS.filter((k) => {
    const had = before[k];
    if (had === undefined || had === null) return false;
    // An EMPTY array in the draft is not worth defending: nothing is lost by
    // replacing `[]` with absent, and saying so would be noise on every import
    // into a fresh distro.
    if (Array.isArray(had) && had.length === 0) return false;
    return after[k] === undefined || after[k] === null;
  });

  return gone.length === 0
    ? []
    : [
        `${gone.join(', ')} ${gone.length === 1 ? 'was' : 'were'} in the draft ` +
          'and this file does not carry ' +
          `${gone.length === 1 ? 'it' : 'them'}. Importing replaces the whole ` +
          'theme, so publishing now ships without ' +
          `${gone.length === 1 ? 'it' : 'them'}.`,
      ];
}
