import 'server-only';

import type { IndexContents } from '@/lib/core/sign';
import type { ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

/**
 * What a theme pack contains, counted from the spec being published.
 *
 * ─── WHY THIS IS COMPUTED HERE AND NOT ON THE DEVICE ────────────────────────
 *
 * The storefront card needs a floor: something true on every distro, including
 * the ones with no exclusive feature worth naming. Manjaro, Fedora, Zorin and
 * Deepin are in exactly that position, two of them are paid, and their cards
 * are a name over a rectangle.
 *
 * The phone cannot work any of it out. For a distro nobody has bought it holds
 * the index entry and nothing else: `packCoverage` needs the pack on disk,
 * `readInstalledTheme` needs it installed. This side holds the whole theme.json
 * and the device holds only what the index carries, which is the same argument
 * `IndexPreview.layout` makes about itself.
 *
 * ─── AND WHY IT IS NOT DERIVED FROM THE SHELL ───────────────────────────────
 *
 * The obvious cheap version is to guess from `shell`, and the storefront has
 * just finished removing a DE tag that did precisely that: it printed GNOME on
 * Kali, whose chrome and menus are Xfce throughout. A shell is not a bill of
 * materials, and a guess on a card that is asking for money is worse than an
 * empty corner.
 */

/**
 * The contents block for [spec], or undefined when it should not carry one.
 *
 * [resolveIconTitle] answers with a pack's display title, or null when that id
 * is not in the catalogue. PASSED IN rather than imported, so this file needs
 * neither the live index nor the R2 client and can be called from either
 * publish path with whatever each already holds.
 */
export function contentsFor(
  spec: ThemeSpecJson,
  resolveIconTitle: (packId: string) => string | null,
): IndexContents {
  const contents: IndexContents = {
    // ─── `wallpapers.length`, AND NOT `wallpapersLight` ──────────────────
    //
    // The light array is the SAME set in a light variant, not additional
    // pictures, so adding it would roughly double every count on the distros
    // that ship one and leave the rest alone. The device reads the two exactly
    // that way in `ThemeSpec._wallpapers`.
    //
    // Zero is published rather than omitted. See [IndexContents.wallpapers]:
    // a counted none and an uncounted pack are different answers and the block
    // has to be able to say the first.
    wallpapers: spec.wallpapers?.length ?? 0,
  };

  const icon = iconPackTitleFor(spec, resolveIconTitle);
  if (icon) contents.iconPack = icon;

  const font = fontNameFor(spec);
  if (font) contents.font = font;

  return contents;
}

/**
 * The icon set's title, or null.
 *
 * `heroPack` before `brandPack`, which is the precedence the entitlement grant
 * in `distro-publish.ts` already uses and the same one the device's icon
 * resolver follows. Ubuntu is the single distro naming a real hero set; every
 * other one names its pack in `brandPack`.
 *
 * Null when the named pack is not in the catalogue. That is not a failure: the
 * bundled icon sets ship inside the APK and have no index entry to take a title
 * from, so the card carries one fewer chip and says nothing untrue.
 */
function iconPackTitleFor(
  spec: ThemeSpecJson,
  resolveIconTitle: (packId: string) => string | null,
): string | null {
  const named = spec.icons?.heroPack ?? spec.icons?.brandPack ?? null;
  if (!named) return null;
  return resolveIconTitle(named);
}

/**
 * The typeface the device will actually render, or null.
 *
 * ─── NAMING A FACE AND SHIPPING ONE ARE DIFFERENT THINGS ────────────────────
 *
 * `typography` names a family. `fonts[]` carries the files, and a downloaded
 * pack cannot declare a family in pubspec, so a name with no matching entry
 * falls back to the platform default with nothing reported. Kali, KDE,
 * elementary and Deepin are all in that state right now.
 *
 * Publishing `typography.display` unchecked would put that bug on the
 * storefront: a paid card reading Hack over a preview rendering Roboto. Gating
 * it means the chip appears only when it is true, and the packs missing their
 * font files are identifiable by which cards have no font chip.
 *
 * ─── `display` FIRST, THEN `mono` ───────────────────────────────────────────
 *
 * The card shows one face and `display` is the one the interface is set in.
 * The fallback is for the TUI distro, whose interface IS its monospace face, so
 * taking `display` alone would report nothing for the one distro whose typeface
 * is the most visible thing about it.
 */
function fontNameFor(spec: ThemeSpecJson): string | null {
  const shipped = new Set(
    (spec.fonts ?? [])
      // Both halves, matching `ThemeFont.isUsable` on the device: a family with
      // a name and no files registers nothing, so it is not shipped in any
      // sense the card should claim.
      .filter((f) => f.family?.trim() && (f.files?.length ?? 0) > 0)
      .map((f) => f.family.trim()),
  );

  for (const named of [spec.typography?.display, spec.typography?.mono]) {
    const family = named?.trim();
    if (family && shipped.has(family)) return family;
  }

  return null;
}
