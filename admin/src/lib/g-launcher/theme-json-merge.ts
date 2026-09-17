/**
 * MERGE A theme.json PATCH OVER A DRAFT.
 *
 * ─── PARTIAL, BECAUSE A WHOLE FILE IS THE WRONG UNIT TO TYPE ───────────────
 *
 * A published theme.json runs past a hundred keys: boot lines, wallpapers,
 * desklet starters, feature rows. Changing a panel by pasting the whole file
 * means every one of those keys is retyped by hand, and the day someone drops
 * a `wallpapers` array while fixing a clock is the day a distro loses its art
 * with no error anywhere.
 *
 * So the editor takes what CHANGES. `{ "layout": { "panels": [...] } }` keeps
 * the rest of the draft untouched.
 *
 * ─── ARRAYS ARE REPLACED WHOLE, AND THAT IS NOT LAZINESS ───────────────────
 *
 * A deep merge of a list has no honest answer. Merge by index and reordering
 * `modules` becomes a rewrite of every entry after the first change; merge by
 * identity and the entries need ids they do not have; concatenate and a panel
 * grows a second clock every time it is saved.
 *
 * Whole replacement is the one rule a person can predict from the text they
 * typed: the array you wrote is the array that is stored. It also matches what
 * the author means when they paste a `modules` list, which is always "these,
 * in this order", never "add these to whatever is there".
 *
 * ─── AND `null` DELETES ────────────────────────────────────────────────────
 *
 * Without it a partial patch can add and change but never REMOVE, and half of
 * fixing a spec is taking something out. `"topBarStats": null` drops the key
 * and lets the device's own default come back, which is a different result
 * from `false` and the reason inherit-shaped keys are absent rather than
 * false throughout this file.
 */
export function mergeThemeJson(
  base: unknown,
  patch: unknown,
): Record<string, unknown> {
  const out: Record<string, unknown> = isPlainObject(base) ? { ...base } : {};
  if (!isPlainObject(patch)) return out;

  for (const [key, value] of Object.entries(patch)) {
    if (value === null) {
      delete out[key];
      continue;
    }
    if (isPlainObject(value)) {
      out[key] = mergeThemeJson(out[key], value);
      continue;
    }
    // Arrays and scalars both land here: replaced, never combined.
    out[key] = value;
  }

  return out;
}

/**
 * The keys a patch touches, deepest path first, for the report.
 *
 * `layout.panels` rather than `layout`, so a one-line result says what was
 * actually edited instead of naming the branch it lives on.
 */
export function patchPaths(patch: unknown, prefix = ''): string[] {
  if (!isPlainObject(patch)) return [];
  const out: string[] = [];

  for (const [key, value] of Object.entries(patch)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (isPlainObject(value) && Object.keys(value).length) {
      out.push(...patchPaths(value, path));
    } else {
      out.push(value === null ? `${path} (removed)` : path);
    }
  }

  return out;
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === 'object' && !Array.isArray(v);
}
