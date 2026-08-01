import 'server-only';

// The RESOLVER, not the writer's schema. `theme-spec.ts` describes the file
// the builder emits; this needs what the device's parser makes of it, which
// is the same question this gate asks about asset paths.
import { parseTheme } from '@/lib/theme-resolve';
import type { PackFile } from '@/lib/sign';

/**
 * PHASE C7 — the asset-resolution gate, enforced at publish.
 *
 * ## Why this exists as its own module
 *
 * The pack route is deliberately format-agnostic: it validates paths, signs, and
 * uploads without caring what a pack means. The one exception is that a THEME
 * pack has a resolution rule the route cannot see, and getting it wrong ships a
 * pack that verifies, downloads, installs, and renders a themeless fallback.
 *
 * ─── THE RULE THIS USED TO ENFORCE WAS THE WRONG ONE, IN BOTH DIRECTIONS ────
 *
 * It refused any reference containing a separator, on the grounds that
 * `PackPaths.installedFile` refuses a filename containing one. That conflated
 * two different things. `PackPaths` governs the name of a FILE ON DISK. It does
 * not see the references in theme.json, because those never reach it: the
 * docblock on `ThemeSource.asset` in `theme_source.dart` says a theme.json
 * authored against the bundled layout may still say `wallpapers/dawn.jpg`, that
 * the same authored theme has to work bundled and installed, and that the last
 * path segment is therefore taken and the rest dropped.
 *
 * So the old gate was wrong twice over, and the second way is the expensive one:
 *
 *   REFUSED PACKS THAT WORK. `wallpapers/numbat.webp` beside a payload holding
 *   `numbat.webp` resolves correctly on device and was refused at publish.
 *
 *   PASSED PACKS THAT ARE BROKEN. A reference with no separator that names no
 *   file in the payload has nothing to catch it. `theme.json` saying
 *   `numbat_color.webp` beside a payload holding `wall_ms34zzni.webp` contains
 *   no slash, produced no problem, published, and resolved to nothing. That is
 *   not hypothetical: it is the normal output of `DistroWorkspace` for any
 *   reference `effectiveSpec` does not rewrite, which today means `splash.logo`.
 *
 * ## The rule, as one sentence
 *
 * A reference is fine when its LAST SEGMENT names a file in the payload. That is
 * exactly what the device does, so it refuses everything the device cannot
 * resolve and nothing it can.
 *
 * ## It does not rewrite
 *
 * Rewriting `theme.json` here would change the bytes that get signed, and the
 * whole point is that the theme.json and the files agree. The author fixes both
 * together, or the pack is malformed. The panel says which references resolve to
 * nothing and what is actually in the pack, because the useful half of that
 * message is usually the second half.
 *
 * ## Both publish paths call this
 *
 * `api/publish/pack/route.ts` for a zip or a directory, and `distro-publish.ts`
 * for the workspace. It was wired into the first and not the second, which is
 * worse than being wired into neither: the screen that publishes most themes was
 * the unguarded one, and the gate reads as covered. [flatRefusal] is here rather
 * than at either call site for the same reason `publish-core` exists.
 */

/** One reference the device will not be able to open. */
export interface FlatProblem {
  /** The reference exactly as theme.json wrote it. */
  ref: string;
  /** What `ThemeSource.asset` reduces it to, and looks for in the pack. */
  resolved: string;
}

export interface FlatCheck {
  ok: boolean;
  problems: FlatProblem[];
  /** Bare names of every file in the payload. The other half of the message. */
  payload: string[];
  /** Set when the payload has no theme.json to check. */
  noThemeJson?: boolean;
}

/** The last path segment, which is all the device keeps. */
function bare(p: string): string {
  const last = p.split(/[\\/]/).pop();
  return (last ?? p).trim();
}

export function checkThemePackFlat(files: PackFile[]): FlatCheck {
  const themeJson = files.find((f) => f.path === 'theme.json');
  if (!themeJson) {
    // A theme pack with no theme.json is a different failure, caught elsewhere.
    // Here it just means there is nothing to resolve.
    return { ok: true, problems: [], payload: [], noThemeJson: true };
  }

  const payloadNames = files
    .filter((f) => f.path !== 'theme.json')
    .map((f) => bare(f.path));
  const payload = [...new Set(payloadNames)].sort();

  let parsed: ReturnType<typeof parseTheme>;
  try {
    parsed = parseTheme(JSON.parse(themeJson.bytes.toString('utf8')));
  } catch {
    // Malformed JSON is the route's problem to report, not this gate's. Treat it
    // as nothing to check rather than inventing a second parse error.
    return { ok: true, problems: [], payload };
  }
  if ('error' in parsed) return { ok: true, problems: [], payload };

  const have = new Set(payloadNames);

  const problems: FlatProblem[] = [];
  const seen = new Set<string>();
  for (const ref of parsed.assets) {
    const resolved = bare(ref);
    // An empty reference is not a broken reference. `parseTheme` already drops
    // blanks, and re-reporting one here would refuse a theme for a field the
    // author simply left out.
    if (!resolved) continue;
    if (have.has(resolved)) continue;
    if (seen.has(ref)) continue;
    seen.add(ref);
    problems.push({ ref, resolved });
  }

  return { ok: problems.length === 0, problems, payload };
}

/**
 * The refusal, as one sentence both publish paths send.
 *
 * Naming what IS in the pack matters as much as naming what is missing. The
 * common case is not a typo, it is a reference that was never updated when the
 * file was renamed on upload, and seeing `wall_ms34zzni.webp` sitting there is
 * what makes that obvious.
 */
export function flatRefusal(check: FlatCheck): string {
  const refs = check.problems
    .map((p) => (p.ref === p.resolved ? `'${p.ref}'` : `'${p.ref}' (resolves to '${p.resolved}')`))
    .join(', ');
  const has =
    check.payload.length > 0
      ? `The pack contains: ${check.payload.join(', ')}.`
      : 'The pack contains no files besides theme.json.';
  return (
    `theme.json references ${check.problems.length === 1 ? 'a file' : 'files'} that ` +
    `${check.problems.length === 1 ? 'is' : 'are'} not in the pack, so ` +
    `${check.problems.length === 1 ? 'it resolves' : 'they resolve'} to nothing once installed ` +
    `and the theme falls back silently: ${refs}. ${has} ` +
    'Rename the files or the references so they agree, then publish again.'
  );
}
