import 'server-only';

import { readLiveIndex, type AppId } from '@/lib/core/catalogue';
import { canonicalHeroPackJson, type HeroPackJson } from '@/lib/g-launcher/hero-pack';
import { checkThemePackFlat, flatRefusal } from '@/lib/g-launcher/flat-check';
import {
  commitIndex,
  guardIndex,
  nextVersionFor,
  packKeyId,
  uploadPack, shelfOwnerBase } from '@/lib/core/publish-core';
import type { IndexEntitlement, IndexPack, PackFile } from '@/lib/core/sign';
import { canonicalThemeJson, type ThemeSpecJson } from '@/lib/g-launcher/theme-spec';

export interface DistroPublishInput {
  app: AppId;
  theme: {
    packId: string;
    minAppVersion: number;
    sku: string | null;
    title: string;
    summary: string;
    spec: ThemeSpecJson;
    /** Bare-named binaries the theme.json references (wallpapers, logo). */
    assets: { file: string; bytes: Buffer }[];
  };
  icons: {
    /** Optional: a distro can ship a theme with no icon pack. */
    packId: string;
    minAppVersion: number;
    sku: string | null;
    name: string;
    entries: { pkg: string; file: string; bytes: Buffer }[];
    /** preview.png bytes, composited by the workspace. Null for none. */
    preview?: Buffer | null;
  } | null;
  /** The whole-distro SKU that grants both packs. Null = free distro. */
  distroSku: string | null;
  distroTitle: string;
  distroSummary: string;
}

export type DistroPublishResult =
  | {
      ok: true;
      themeVersion: number;
      iconVersion: number | null;
      /**
       * ─── SET AFTER THE PACKS ARE ALREADY LIVE ───────────────────────────
       *
       * Not written by [publishDistro] itself, which has nothing to warn
       * about: by the time it returns, either both packs and the index write
       * succeeded or the result is the `ok: false` branch.
       *
       * This carries the bookkeeping that happens AFTER the publish, in
       * `publishDistroAction`, where the draft that produced the shipped pack
       * is written back. That step runs against a CDN and a signed index that
       * are already updated, so there is no failure of it that makes
       * unpublishing the right answer. It reports and the publish still
       * succeeded.
       *
       * OPTIONAL, so a caller that only publishes and never persists a draft
       * still satisfies the type without inventing a field. Read it as "the
       * publish worked, and here is what to mention", never as a failure.
       */
      warning?: string;
    }
  | { ok: false; error: string };

/**
 * Publish a whole distro in one shot.
 *
 * Both packs are uploaded first, each in its own safe payload/manifest/signature
 * order, then a SINGLE index write adds both entries plus the distro
 * entitlement, bumps generatedAt and re-signs.
 *
 * One index write is the point. A device must never see the theme pack land in
 * the catalogue a sync before its icon pack, or someone who just paid owns half
 * a distro until the next refresh.
 *
 * ─── NOW BUILT ON `publish-core`, AND THREE THINGS CHANGED WITH IT ──────────
 *
 * This used to be a parallel implementation of the pack route's sequence. It
 * agreed on nearly all of it, and the disagreements were the expensive part:
 *
 *   1. it wrote hero packs to `hero/<id>/<v>` while the route's `dirFor` says
 *      `heropacks/`. Both installed correctly, because a device follows the
 *      `path` in the index. But an icon pack published here and then republished
 *      from the icon builder left its old objects orphaned in the other prefix,
 *      where `putPack`'s sweep would never look for them. `dirFor` now has one
 *      home and both callers use it.
 *
 *      EXISTING PACKS PUBLISHED UNDER `hero/` KEEP WORKING: their index entry
 *      still names the old path and their objects are still there. The next
 *      publish moves them, and the stale prefix is cleanable by hand once
 *      nothing points at it.
 *
 *   2. it signed with `live.keyId`, the key the LAST index happened to use, so
 *      rotating `PACK_KEY_ID` took effect on the route and silently did not
 *      here. [packKeyId] is now the only answer.
 *
 *   3. it did not refuse an unreadable bucket. `readLiveIndex` no longer throws
 *      on a failed read, so without [guardIndex] this would have merged into an
 *      empty catalogue and replaced the live index with two packs.
 */
export async function publishDistro(
  input: DistroPublishInput,
): Promise<DistroPublishResult> {
  try {
    const live = await readLiveIndex(input.app);
    const refusal = guardIndex(input.app, live);
    if (refusal) return { ok: false, error: refusal };

    const keyId = packKeyId();

    // ── theme pack ─────────────────────────────────────────────────────────
    const themeVersion = nextVersionFor(live, input.theme.packId);
    const themeFiles: PackFile[] = [
      {
        path: 'theme.json',
        bytes: Buffer.from(canonicalThemeJson(input.theme.spec), 'utf8'),
      },
      // FLAT, BARE FILENAMES. `PackPaths.installedFile` on the device refuses a
      // name containing a separator, so a nested path here produces a theme
      // that installs perfectly and renders a black rectangle where its
      // wallpaper should be.
      ...input.theme.assets.map((a) => ({ path: a.file, bytes: a.bytes })),
    ];

    // ── THE ASSET-RESOLUTION GATE ──────────────────────────────────────────
    //
    // The paragraph above asserts that these names are flat and resolvable. It
    // asserted it for a while without anything checking, and `route.ts` ran the
    // check while this path did not, so the screen that publishes most themes
    // was the unguarded one.
    //
    // It runs HERE rather than before `themeFiles` is built, because the check
    // compares the references in theme.json against the payload, and `themeFiles`
    // is the first point where both exist together. Before `uploadPack`, because
    // after it the bytes are in the bucket.
    const flat = checkThemePackFlat(themeFiles);
    if (!flat.ok) return { ok: false, error: flatRefusal(flat) };

    const themeEntry = await uploadPack(
      input.app,
      {
        packType: 'theme',
        packId: input.theme.packId,
        version: themeVersion,
        minAppVersion: input.theme.minAppVersion,
        title: input.theme.title,
        summary: input.theme.summary,
        sku: input.theme.sku,
        // ── THE STOREFRONT PREVIEW ──────────────────────────────────────
        //
        // Derived from the spec being published, not authored separately, so it
        // cannot disagree with the pack it describes. There is no second place
        // to keep in sync and nothing new for anyone to fill in: republish a
        // distro and its card gains a real miniature.
        //
        // The DARK palette specifically. `paletteLight` exists on some specs and
        // the storefront is dark, so previewing a light variant would draw a
        // card that looks nothing like the screen it lands on.
        preview: {
          shell: input.theme.spec.shell,
          bgTop: input.theme.spec.palette.bgTop,
          bgBottom: input.theme.spec.palette.bgBottom,
          bar: input.theme.spec.palette.bar,
          dock: input.theme.spec.palette.dock,
          accent: input.theme.spec.palette.accent,
        },
        files: themeFiles,
      },
      keyId,
    );

    // ── icon pack, optional ────────────────────────────────────────────────
    let iconEntry: IndexPack | null = null;
    let iconVersion: number | null = null;

    if (input.icons && input.icons.entries.length > 0) {
      const ic = input.icons;
      iconVersion = nextVersionFor(live, ic.packId);

      const iconsMap: Record<string, string> = {};
      for (const e of ic.entries) iconsMap[e.pkg] = e.file;

      // `masked: false` is the format's usual case and is not configurable from
      // this screen: a distro's own icon set is final art with its own
      // silhouette, and masking it would slice the corners off a shape its
      // author chose. The icon builder exposes the flag for packs that need it.
      const packJson: HeroPackJson = {
        id: ic.packId,
        name: ic.name,
        masked: false,
        icons: iconsMap,
      };

      const iconFiles: PackFile[] = [
        { path: 'pack.json', bytes: Buffer.from(canonicalHeroPackJson(packJson), 'utf8') },
        ...ic.entries.map((e) => ({ path: e.file, bytes: e.bytes })),
        // A payload file like any other: listed, hashed, signed, immutable.
        // pack.json does not name it, so HeroIconResolver never opens it and
        // clients that predate previews are unaffected.
        ...(ic.preview ? [{ path: 'preview.png', bytes: ic.preview }] : []),
      ];

      iconEntry = await uploadPack(
        input.app,
        {
          packType: 'hero',
          packId: ic.packId,
          version: iconVersion,
          minAppVersion: ic.minAppVersion,
          title: ic.name,
          summary: `${ic.entries.length} ${ic.entries.length === 1 ? 'icon' : 'icons'}`,
          sku: ic.sku,
          files: iconFiles,
        },
        keyId,
      );
    }

    // ── the distro entitlement ─────────────────────────────────────────────
    //
    // Owning `distroSku` grants both packs. The icon pack ALSO carries its own
    // `icons_x` sku on the pack entry, so it stays buyable alone and needs no
    // entitlement of its own. A free distro writes none.
    //
    // NAMED GRANTS, never a wildcard. A `*` grant promises every pack published
    // from now until the app dies, and cannot be withdrawn from anyone who
    // already bought it.
    let entitlements = live.entitlements;
    if (input.distroSku) {
      /**
       * A pack this distro NAMES but does not publish.
       *
       * The workspace can point a distro at a hero pack that already exists
       * instead of building one, in which case there is no `iconEntry` and the
       * link is `icons.heroPack` in the theme.json. Granting it is the same
       * relationship an inline pack already has: buying the distro unlocks the
       * icons the distro ships with. Without this the theme names a pack the
       * buyer does not own, entitlement refuses it, and every app falls to the
       * generator with nothing reported.
       *
       * ONLY IF IT IS IN THE INDEX, and the exclusion is deliberate rather than
       * defensive. A theme may legitimately name a pack that is not in the
       * catalogue at all: the bundled sets ship inside the APK, and bundled
       * implies free, so they have no entitlement to be added to. Granting an id
       * that names nothing would put an unbuyable string in a signed index
       * forever.
       */
      const named = input.theme.spec.icons?.heroPack ?? null;
      const namedIsPublished =
        !!named &&
        named !== iconEntry?.packId &&
        live.packs.some((p) => p.packId === named);

      /**
       * THE SHELF SWEEP. Replacing this entitlement wholesale used to wipe any
       * shelf grants added since the last distro publish, so republishing Kali
       * would silently revoke packs its buyers already owned. Instead, every
       * PAID hero pack in the index that this distro's base owns (longest
       * prefix, same rule as everywhere) is granted here, which both preserves
       * earlier route-side appends and picks up shelf packs that were
       * published before the distro's entitlement first existed.
       */
      const base = themeEntry.packId.endsWith('-theme')
        ? themeEntry.packId.slice(0, -'-theme'.length)
        : themeEntry.packId;
      const shelfGrants = live.packs
        .filter(
          (p) =>
            p.packType === 'hero' &&
            p.sku &&
            p.packId !== iconEntry?.packId &&
            shelfOwnerBase(p.packId, live) === base,
        )
        .map((p) => p.packId);

      const next: IndexEntitlement = {
        sku: input.distroSku,
        title: input.distroTitle,
        summary: input.distroSummary,
        grants: [
          ...new Set([
            themeEntry.packId,
            ...(iconEntry ? [iconEntry.packId] : []),
            ...(namedIsPublished && named ? [named] : []),
            ...shelfGrants,
          ]),
        ],
      };
      entitlements = [
        ...entitlements.filter((e) => e.sku !== input.distroSku),
        next,
      ];
    }

    await commitIndex(
      input.app,
      live,
      iconEntry ? [themeEntry, iconEntry] : [themeEntry],
      entitlements,
    );

    return { ok: true, themeVersion, iconVersion };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
