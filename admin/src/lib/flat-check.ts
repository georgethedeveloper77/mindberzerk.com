import 'server-only';

import { parseTheme } from './theme-spec';
import type { PackFile } from './sign';

/**
 * PHASE C7 — the flat-path gate, enforced at publish.
 *
 * ## Why this exists as its own module
 *
 * The pack route is deliberately format-agnostic: it validates paths, signs, and
 * uploads without caring what a pack means. The one exception is that a THEME
 * pack has a resolution rule the route cannot see, and getting it wrong ships a
 * pack that verifies, downloads, installs, and renders a themeless fallback.
 *
 * `PackPaths.installedFile` in the launcher resolves a downloaded asset as
 * `packs/<packId>/<filename>` and refuses any filename containing a slash. So a
 * theme whose `theme.json` points at `wallpapers/numbat.webp` or
 * `assets/themes/…/logo.svg` resolves against nothing once downloaded, even
 * though both are legal relative paths. The device shows no error; the theme
 * simply falls back to Ubuntu, which is the single hardest failure in this
 * system to diagnose from the outside.
 *
 * This check runs only for `packType === 'theme'`, reads the theme.json out of
 * the already-collected payload, and refuses the publish if any asset reference
 * is not a bare filename. The message names the fix, because "unsafe path" would
 * be wrong — the path is safe, it is just unresolvable.
 *
 * ## It does not rewrite
 *
 * Rewriting `theme.json` here would change the bytes that get signed, and the
 * whole point of a flat pack is that the theme.json and the files agree. The
 * author flattens both together, or the pack is malformed. The panel says which
 * references are wrong and what they should read.
 */

export interface FlatCheck {
  ok: boolean;
  /** For each bad reference, the fix. Empty when ok. */
  problems: { ref: string; flat: string }[];
  /** Set when the payload has no theme.json to check. */
  noThemeJson?: boolean;
}

export function checkThemePackFlat(files: PackFile[]): FlatCheck {
  const themeJson = files.find((f) => f.path === 'theme.json');
  if (!themeJson) {
    // A theme pack with no theme.json is a different failure, caught elsewhere.
    // Here it just means there is nothing to flatten-check.
    return { ok: true, problems: [], noThemeJson: true };
  }

  let parsed: ReturnType<typeof parseTheme>;
  try {
    parsed = parseTheme(JSON.parse(themeJson.bytes.toString('utf8')));
  } catch {
    // Malformed JSON is the route's problem to report, not this gate's. Treat it
    // as nothing to check rather than inventing a second parse error.
    return { ok: true, problems: [] };
  }
  if ('error' in parsed) return { ok: true, problems: [] };

  const problems = parsed.assets
    .filter((a) => a.includes('/') || a.includes('\\'))
    .map((ref) => ({ ref, flat: ref.split(/[\\/]/).pop() ?? ref }));

  return { ok: problems.length === 0, problems };
}
