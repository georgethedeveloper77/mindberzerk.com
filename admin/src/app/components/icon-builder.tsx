'use client';

import { useCallback, useMemo, useState } from 'react';
import {
  markIconDraftPublishedAction,
  saveIconDraftAction,
} from '@/app/apps/[app]/icons/builder/actions';
import { useRouter } from 'next/navigation';

import {
  expandArchive,
  fileFromArt,
  licenseProblem,
  LICENSE_LANES,
  type LicenseLane,
  type RawArt,
  type RefusedFile,
} from '@/lib/g-launcher/bulk-icons';
import { IconShelf } from '@/app/components/icon-shelf';
import { normaliseHex, recolourBytes, isRecolourable } from '@/lib/g-launcher/svg-recolor';
import {
  CORE_ROLES,
  expandRoleEntries,
  buildHeroPackJson,
  fileNameFor,
  guessPackage,
  isPackageName,
} from '@/lib/g-launcher/icon-pack';
import { renderHeroIcon } from '@/lib/core/image-trim';
import { composeIcon, type ComposeSpec } from '@/lib/g-launcher/icon-compose';
import type { GlyphLite } from '@/lib/g-launcher/glyph-blob';
import { glyphToBlob } from '@/lib/g-launcher/glyph-blob';
import { GlyphPicker, IconStyleBar } from '@/app/components/icon-compose-bar';
import { playSkuNote, type PlayLite } from '@/lib/core/play-lite';
import { SKU_PREFIX, iconsSkuFor, skuProblems } from '@/lib/core/skus';
import { PREVIEW_NAME, composePreviewPng } from '@/lib/g-launcher/pack-preview';
import type { RehydratedPack } from '@/lib/core/cdn';
import { ICON_TREATMENTS } from '@/lib/g-launcher/theme-spec';

/**
 * RESTYLED ONTO THE SOFT REGISTER. This file was the one builder that did NOT
 * move when `theme-builder/console.tsx` was retargeted, because it never used
 * the `C` map: it writes Tailwind classes directly, so the console's dark-only
 * tokens were baked into the markup rather than resolved through one variable
 * map. Every colour here is a `site-` token now, which has a value in both
 * modes.
 *
 * PHASE C8 - the hero pack builder, corrected to the launcher's reader.
 *
 * ## What changed after reading HeroIconResolver / IconRenderer
 *
 * The per-icon fit and scale controls are GONE, because the format has neither.
 * `renderHero` draws hero art at native size and ignores foregroundScale, and
 * the `icons` map is packageName -> filename with no per-entry options. What
 * remains is one pack-level `masked` flag: false (the default) for final art
 * with its own transparency, true for square full-bleed art the theme masks.
 *
 * ## The preview mirrors renderHero, not a guess
 *
 *  - masked=false: draw the PNG as-is on a neutral field, because that is
 *    literally `drawLayer(canvas, hero, sizePx, 1.0f, null)`.
 *  - masked=true: clip to the theme's shape and fill the plate behind, because
 *    that is the `clipPath(maskPath)`, `fillBackground`, `drawLayer` branch.
 *
 * So the plate colour and corner radius only affect the preview when masked is
 * on, exactly as they only affect the device then.
 *
 * ## It reuses /api/publish/pack unchanged
 *
 * Browser produces PNGs plus pack.json; posted as files[]/paths[] with
 * packType: hero. Same manifest, signature and rollback floor as every pack.
 */

/**
 * THE SIX SHAPES THE DEVICE CAN ACTUALLY APPLY, AS CSS.
 *
 * Imported from `theme-spec` rather than listed again here, because that array
 * is what a theme's `icons.treatment` is validated against. A seventh shape in
 * the builder that no theme can request would be a control that does nothing,
 * and a shape missing from the builder is one an author cannot check their art
 * against.
 *
 * `original` is the odd one and is the honest answer for a pack of final art:
 * no clip at all, drawn as authored, which is literally what `renderHero` does
 * on the `masked: false` branch.
 */
const SQUIRCLE_CLIP = (() => {
  // A superellipse, |x|^n + |y|^n = 1 with n = 4, sampled as a polygon. The
  // usual shortcut is a large border-radius, which is a rounded rectangle and
  // visibly not the same curve: the difference is exactly the flat run along
  // each edge that makes a squircle read as one.
  const pts: string[] = [];
  const steps = 72;
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * 2 * Math.PI;
    const c = Math.cos(t);
    const sn = Math.sin(t);
    const x = Math.sign(c) * Math.pow(Math.abs(c), 0.5);
    const y = Math.sign(sn) * Math.pow(Math.abs(sn), 0.5);
    pts.push(`${(50 + x * 50).toFixed(2)}% ${(50 + y * 50).toFixed(2)}%`);
  }
  return `polygon(${pts.join(',')})`;
})();

/** How each treatment masks the tile. `radius` is only read by roundedSquare. */
function maskFor(shape: string, radius: number): React.CSSProperties {
  switch (shape) {
    case 'circle':
      return { borderRadius: '50%' };
    case 'square':
      return { borderRadius: 0 };
    case 'squircle':
      return { clipPath: SQUIRCLE_CLIP };
    case 'teardrop':
      // Three rounded corners and one square, which is the AOSP teardrop.
      return { borderRadius: '50% 50% 50% 12%' };
    case 'original':
      // No clip. Art is drawn exactly as authored.
      return {};
    case 'roundedSquare':
    default:
      return { borderRadius: `${radius}%` };
  }
}

/** Sentence-case label for a treatment id. */
function shapeLabel(shape: string): string {
  switch (shape) {
    case 'roundedSquare':
      return 'Rounded';
    case 'squircle':
      return 'Squircle';
    case 'circle':
      return 'Circle';
    case 'square':
      return 'Square';
    case 'teardrop':
      return 'Teardrop';
    case 'original':
      return 'As authored';
    default:
      return shape;
  }
}

interface Entry {
  id: string;
  file: File;
  pkg: string;
  url: string | null;
  blob: Blob | null;
  aspect: number;
  error: string | null;
  busy: boolean;
}

/**
 * Decode one `data:` URL into a Blob, synchronously.
 *
 * Synchronous is the whole point. It means a published pack becomes real
 * entries inside a `useState` initialiser, with no effect, no loading state and
 * no window in which the builder is mounted but empty. It also means nothing
 * re-runs when the parent re-renders: `router.refresh()` fires after every
 * publish, and an effect keyed on `initial` would wipe the author's unsaved
 * edits each time it did.
 */
function blobFromDataUrl(dataUrl: string): Blob {
  const comma = dataUrl.indexOf(',');
  const head = dataUrl.slice(0, comma);
  const mime = /:(.*?);/.exec(head)?.[1] ?? 'image/png';
  const binary = atob(dataUrl.slice(comma + 1));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

/**
 * A published pack's icons as builder entries.
 *
 * `url` is the data URL itself rather than an object URL, deliberately. It is a
 * valid `src`, so the preview works with no extra step, and there is no handle
 * to revoke. `render` calls `URL.revokeObjectURL(entry.url)` when an entry is
 * replaced, and that is a harmless no-op on a `data:` URL, so a rehydrated icon
 * can be swapped for a new upload with no special case anywhere.
 *
 * `aspect` is 1 because these bytes already went through `renderHeroIcon` before
 * they were published, which letterboxes everything to a square. The
 * not-square warning would be a lie here.
 */
function entriesFrom(initial: RehydratedPack | null | undefined): Entry[] {
  if (!initial) return [];
  return initial.icons.map((ic) => {
    const blob = blobFromDataUrl(ic.dataUrl);
    return {
      id: `published-${ic.pkg}`,
      file: new File([blob], ic.file, { type: blob.type || 'image/png' }),
      pkg: ic.pkg,
      url: ic.dataUrl,
      blob,
      aspect: 1,
      error: null,
      busy: false,
    };
  });
}

export function IconBuilder({
  app,
  publishedIds,
  publishedVersion,
  initial,
  preview,
  distros = [],
  play,
}: {
  app: string;
  publishedIds: string[];
  publishedVersion: Record<string, number>;
  /** A published pack to edit, or null for a new one. See `lib/cdn.ts`. */
  initial?: RehydratedPack | null;
  /**
   * Every distro this pack could belong to: base id plus display title, read
   * from the theme drafts and the live theme packs on the server. Belonging is
   * the id-prefix convention, so this list only feeds the picker and the
   * derived "belongs to" line; nothing is stored beyond the pack id itself.
   */
  distros?: { base: string; title: string }[];
  /**
   * The preview settings a DRAFT was saved with.
   *
   * ─── THE DRAFT WAS STORING THESE AND NEVER GETTING THEM BACK ───────────
   *
   * `IconDraft` carries `plate` and `radius` with a comment saying they are
   * "kept so a reopened draft looks the same as the one you left", and the
   * save action has always written them. Nothing ever read them back: the two
   * useState calls below were hardcoded to #E95420 and 22, so reopening a
   * draft silently discarded both and the comment was untrue.
   *
   * A separate prop rather than fields on RehydratedPack, because that type
   * describes a PUBLISHED pack read off the CDN and a published pack genuinely
   * has no preview settings to carry. Only the draft branch passes this.
   */
  preview?: { plate: string; radius: number; shape: string } | null;
  /**
   * What Play actually sells, slimmed, read on the server. `ok: false`
   * degrades the product ID field to the plain input it used to be, with the
   * reason, because publishing does not depend on Play and the field must not
   * become less usable than before Play was consulted.
   */
  play: PlayLite;
}) {
  const router = useRouter();

  const [packId, setPackId] = useState(initial?.packId ?? '');

  /**
   * ── THE DISTRO LINK IS THE ID PREFIX, AND THIS MAKES IT VISIBLE ──────────
   *
   * A hero pack belongs to the distro whose base id prefixes its own:
   * `ubuntu-24-04-icons` and `ubuntu-24-04-circle-icons` both belong to
   * `ubuntu-24-04`. The launcher's icons screen groups its shelves by exactly
   * this rule, derived from ids alone, so the association survives clean
   * builds, needs no schema, and cannot drift between panel and device.
   *
   * The picker below EDITS the id rather than storing a second field: choosing
   * a distro prefixes the pack id, choosing standalone strips the prefix, and
   * `belongsTo` is always re-derived FROM the id so typing in the id field and
   * using the picker can never disagree about where the pack will shelve.
   * Longest base wins, mirroring the device, so `ubuntu` could not claim an
   * `ubuntu-24-04-` pack.
   */
  const knownBases = useMemo(
    () => [...distros].sort((a, b) => b.base.length - a.base.length),
    [distros],
  );
  const belongsTo = useMemo(
    () => knownBases.find((d) => packId.startsWith(`${d.base}-`)) ?? null,
    [packId, knownBases],
  );
  const stripBase = useCallback(
    (id: string) => {
      for (const d of knownBases) {
        if (id.startsWith(`${d.base}-`)) return id.slice(d.base.length + 1);
      }
      return id;
    },
    [knownBases],
  );
  function setBelongs(base: string) {
    // The picker EDITS the pack id, so it is disabled for the same reason the
    // field is: on an existing pack it would fork rather than re-shelve.
    if (initial) return;
    if (!base) {
      setPackId((id) => stripBase(id));
      return;
    }
    setPackId((id) => {
      const rest = stripBase(id);
      return rest && rest !== 'icons' ? `${base}-${rest}` : `${base}-icons`;
    });
  }

  const [name, setName] = useState(initial?.name ?? '');
  const [minAppVersion, setMinAppVersion] = useState(String(initial?.minAppVersion ?? 6));
  const [masked, setMasked] = useState(initial?.masked ?? false);
  const [sku, setSku] = useState(initial?.sku ?? '');
  // Custom mode starts on only when the opened pack carries a sku that is
  // neither in Play nor this pack's derived id; every option path covers the
  // rest, and hiding a real sku behind a mismatched select would discard it.
  const [customSku, setCustomSku] = useState<boolean>(() => {
    const s = initial?.sku ?? '';
    if (s === '' || !play.ok) return false;
    if (play.products.some((p) => p.productId === s)) return false;
    return s !== (initial?.packId ? iconsSkuFor(initial.packId) : '');
  });
  // Preview only, none of the three reach pack.json. Seeded from the draft
  // when one opened; see the `preview` prop for why they were being dropped.
  const [plate, setPlate] = useState(preview?.plate ?? '#E95420');
  const [radius, setRadius] = useState(preview?.radius ?? 22);
  const [shape, setShape] = useState(preview?.shape ?? 'roundedSquare');
  const [entries, setEntries] = useState<Entry[]>(() => entriesFrom(initial));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<string | null>(null);

  // Named refusals from the last intake: license-marked SVGs, unreadable zips,
  // skipped non-images. Replaced per pick rather than accumulated, because the
  // question they answer is "what happened to what I just dropped".
  const [refused, setRefused] = useState<RefusedFile[]>([]);

  // The human half of the license gate; the scan in bulk-icons is the other.
  // Starts true only when editing a pack that already shipped, since that
  // attestation was made when it was first published.
  const [licensed, setLicensed] = useState<boolean>(() => !!initial);

  // ── THE LICENSE LANE, WHICH USED TO BE A SINGLE CHECKBOX ─────────────────
  //
  // Two lanes existed: "CC0, MIT, or my own work" and an implicit refusal of
  // anything the scan caught. Art under CC BY or CC BY-SA fell between them and
  // came out the wrong side: Arcticons licenses its icons BY-SA and ships bare
  // path SVGs with no license text, so they pass the scan and land under a
  // checkbox asserting they are CC0.
  //
  // `attribution` is written into pack.json rather than kept here, because a
  // credit that exists only in an admin screen is not attribution.
  const [lane, setLane] = useState<LicenseLane>('own');
  // NOT seeded from `initial`, and that is a known gap rather than an oversight.
  // `RehydratedPack` is built by `lib/core/cdn.ts`, which reads pack.json for
  // the icon map and does not carry this key, so reopening a published BY-SA
  // pack starts the credit blank. Saying so here is better than a cast that
  // reads as restored and is always undefined. Two lines in `cdn.ts` close it.
  const [attribution, setAttribution] = useState('');

  // ── THE UNCLAIMED SHELF ──────────────────────────────────────────────────
  //
  // Bytes, not entries. See `icon-shelf.tsx` for why the distinction is the
  // whole reason a fifteen-thousand-file archive can be opened at all.
  const [shelf, setShelf] = useState<RawArt[]>([]);
  const [intakeNote, setIntakeNote] = useState<string | null>(null);

  // ── LINE COLOUR ──────────────────────────────────────────────────────────
  //
  // Null means "as authored", which is the default and must stay the default:
  // a builder that opened in a recolouring mode would restyle a republished
  // pack the first time anyone pressed publish, exactly as `style` would.
  //
  // Applied at INTAKE, before rasterisation, so no `IconStyle` field and no
  // Pigeon regeneration is involved. See `svg-recolor.ts`.
  const [lineColour, setLineColour] = useState<string | null>(null);
  const [lineDraft, setLineDraft] = useState('#367BF0');
  const [recolourable, setRecolourable] = useState(0);

  // Display-only. At folder scale the rows needing a human are the point, and
  // they should not be buried under forty that guessed fine.
  const [unmappedFirst, setUnmappedFirst] = useState(false);

  // Advisory, never blocking: a shape Play would refuse is worth saying loudly,
  // but this builder does not get to decide what a valid product ID is. The
  // signing route's `isSafeSku` is the gate, and Play is the final word.
  const skuIssues = sku.trim() === '' ? [] : skuProblems(sku.trim(), 'icons');

  const existing = publishedVersion[packId];
  const version = existing ? existing + 1 : 1;

  /**
   * The composed style, or null for "ship the art as authored".
   *
   * NULL IS THE DEFAULT AND MUST STAY THAT WAY. Every pack published before
   * today was built with `renderHeroIcon` alone, so a builder that opened in a
   * composing mode would silently restyle a republished pack the first time
   * anyone pressed publish on it.
   */
  const [style, setStyle] = useState<ComposeSpec | null>(null);
  const [restyling, setRestyling] = useState(false);
  const [pickingGlyph, setPickingGlyph] = useState(false);

  /**
   * ─── ALWAYS FROM `entry.file`, NEVER FROM `entry.blob` ───────────────────
   *
   * `file` is the SOURCE and `blob` is the output, and the two must not be
   * confused here: composing from the previous output would tint a tinted
   * plate, so the third nudge of a colour slider would produce something no
   * setting describes. The builder already keeps the source for every row,
   * which is what makes the style bar reversible at all.
   *
   * The style is a PARAMETER rather than a closure capture. This function is
   * called from loops that run across many awaits, and a `useCallback` reading
   * `style` would need it in its dependency list, which would rebuild the
   * callback mid-loop and leave half a batch rendered against the old value.
   */
  const render = useCallback(
    async (entry: Entry, styleNow: ComposeSpec | null): Promise<Entry> => {
      try {
        if (entry.url) URL.revokeObjectURL(entry.url);
        if (!styleNow) {
          const out = await renderHeroIcon(entry.file);
          return { ...entry, url: out.url, blob: out.blob, aspect: out.aspect, error: null, busy: false };
        }
        const png = await composeIcon(styleNow, entry.file);
        if (!png) throw new Error('The canvas was unavailable, so nothing was composed.');
        return {
          ...entry,
          url: URL.createObjectURL(png),
          blob: png,
          // A composed icon is square by construction, so there is no aspect to
          // measure. Saying 1 is a fact rather than a default.
          aspect: 1,
          error: null,
          busy: false,
        };
      } catch (e) {
        return { ...entry, url: null, blob: null, error: (e as Error).message, busy: false };
      }
    },
    [],
  );

  /**
   * Recompose every row against [next].
   *
   * SEQUENTIAL, like the intake loop above and for the same reason: each pass
   * decodes and re-encodes a full image, and forty at once stalls the tab long
   * enough to look like a crash.
   */
  async function restyle(next: ComposeSpec | null) {
    setStyle(next);
    const rows = entries;
    if (rows.length === 0) return;
    setRestyling(true);
    setEntries((all) => all.map((e) => ({ ...e, busy: true })));
    for (const entry of rows) {
      const done = await render(entry, next);
      setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
    }
    setRestyling(false);
  }

  /**
   * A picked brand glyph becomes an ordinary intake file.
   *
   * Named `<slug>.svg` on purpose: `guessPackage` already maps `whatsapp` to
   * `com.whatsapp` through the hint table, so a pick arrives mapped with no new
   * code, and a slug no hint recognises arrives unmapped and visible, which is
   * exactly what a dropped file does.
   */
  async function addGlyph(glyph: GlyphLite) {
    setPickingGlyph(false);
    const blob = glyphToBlob(glyph);
    const file = new File([blob], `${glyph.slug}.svg`, { type: 'image/svg+xml' });
    const entry: Entry = {
      id: `${Date.now()}-${glyph.slug}`,
      file,
      pkg: guessPackage(file.name) ?? '',
      url: null,
      blob: null,
      aspect: 1,
      error: null,
      busy: true,
    };
    setEntries((e) => [...e, entry]);
    const done = await render(entry, style);
    setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
  }

  /**
   * Intake, which is now THREE TIERS rather than one flatten.
   *
   * ─── WHAT CHANGED, AND THE FAILURE IT CLOSES ─────────────────────────────
   *
   * This used to call `expandPicked`, turn EVERY expanded file into an `Entry`,
   * and run `guessPackage` over each name. Two things broke at archive scale
   * and both broke silently.
   *
   * `guessPackage` matches by substring, so a real icon set collapses onto a
   * handful of packages: `play_store`, `playstation`, `shopee`, `storeman`,
   * `softwareupdate`, `google_play_books` and `google_play_games` all become
   * `com.android.vending`. Every collapse is a duplicate, `ready` requires
   * `duplicates.size === 0`, and the result is a greyed-out Publish button with
   * nothing on screen saying which of thousands of rows caused it.
   *
   * And every file became an Entry, meaning a File, a Blob, an object URL and a
   * `renderHeroIcon` pass each. At fourteen thousand files the tab dies.
   *
   * `expandArchive` fixes both by answering a different question: what does the
   * archive CONFIDENTLY know? An `appfilter.xml` is the pack author's own
   * package-to-drawable map and is trusted first; exact filename stems come
   * second; everything else goes to the shelf as bytes, where it is searchable
   * and costs nothing until claimed.
   */
  async function addFiles(files: FileList | null) {
    if (!files?.length) return;
    setIntakeNote(null);

    const intake = await expandArchive(Array.from(files));
    setRefused(intake.refused);

    // Offered only when there is something it could actually act on. A recolour
    // control on a set of finished multi-colour art is a control that does
    // nothing, which is worse than an absent one.
    const canRecolour = intake.unclaimed
      .concat(intake.claimed.map((c) => c.art))
      .filter(
        (a) => a.mime === 'image/svg+xml' && isRecolourable(new TextDecoder().decode(a.bytes)),
      ).length;
    setRecolourable(canRecolour);

    setShelf(intake.unclaimed);

    const parts: string[] = [];
    if (intake.appfilterCount > 0) {
      parts.push(
        `Read ${intake.appfilterCount} mappings from appfilter.xml, so these are the pack author\u2019s own, not guesses.`,
      );
    } else if (intake.source === 'filenames') {
      parts.push('No appfilter.xml, so matching used exact file names only.');
    }
    parts.push(
      `${intake.claimed.length} matched a core app, ${intake.unclaimed.length} went to Other icons.`,
    );
    if (intake.deduped > 0) {
      parts.push(`${intake.deduped} duplicate copies of the same icon were dropped, best kept.`);
    }
    setIntakeNote(parts.join(' '));

    if (intake.claimed.length === 0) return;

    // Only CLAIMED art is rendered, and one role holds one file, so this loop
    // is bounded by the core set rather than by the archive.
    const stamp = Date.now();
    const added: Entry[] = [];
    for (let i = 0; i < intake.claimed.length; i++) {
      const c = intake.claimed[i];
      if (covered.has(c.slot)) continue;
      added.push({
        id: `${stamp}-${i}-${c.art.stem}`,
        file: fileFromArt(recolourArt(c.art)),
        pkg: c.slot,
        url: null,
        blob: null,
        aspect: 1,
        error: null,
        busy: true,
      });
    }
    if (added.length === 0) return;
    setEntries((e) => [...e, ...added]);
    // Sequential: each decode reads back a full image, and forty at once stalls
    // a mid-range phone long enough to look like a crash.
    for (const entry of added) {
      const done = await render(entry, style);
      setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
    }
  }

  /** Line colour applied to the bytes, before anything rasterises them. */
  function recolourArt(art: RawArt): RawArt {
    if (!lineColour) return art;
    return { ...art, bytes: recolourBytes(art.bytes, art.mime, lineColour) };
  }

  /**
   * A shelf row becoming a real icon.
   *
   * The bytes were held unrendered until exactly this moment, which is what
   * kept the archive affordable. One file goes through the normal pipeline and
   * the row is indistinguishable from a dropped file afterwards.
   */
  async function claimFromShelf(art: RawArt, slot: string) {
    setShelf((all) => all.filter((a) => a.id !== art.id));
    const entry: Entry = {
      id: `${Date.now()}-${art.stem}`,
      file: fileFromArt(recolourArt(art)),
      pkg: slot,
      url: null,
      blob: null,
      aspect: 1,
      error: null,
      busy: true,
    };
    setEntries((e) => [...e, entry]);
    const done = await render(entry, style);
    setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
  }

  /**
   * Add one file FOR a known package, from the core-set tiles below.
   *
   * The package is not guessed, it is the tile that was tapped, so the row
   * arrives already mapped. Same render pipeline as [addFiles]; a tile pick is
   * one file, so no zip expansion and no refusal list to manage.
   */
  async function addForPackage(pkg: string, file: File) {
    const entry: Entry = {
      id: `${Date.now()}-${pkg}`,
      file,
      pkg,
      url: null,
      blob: null,
      aspect: 1,
      error: null,
      busy: true,
    };
    setEntries((e) => [...e, entry]);
    const done = await render(entry, style);
    setEntries((all) => all.map((e) => (e.id === entry.id ? done : e)));
  }

  function patchPkg(id: string, pkg: string) {
    setEntries((all) => all.map((e) => (e.id === id ? { ...e, pkg } : e)));
  }

  const duplicates = useMemo(() => {
    const seen = new Set<string>();
    const dupes = new Set<string>();
    for (const e of entries) {
      if (seen.has(e.pkg)) dupes.add(e.pkg);
      seen.add(e.pkg);
    }
    return dupes;
  }, [entries]);

  /**
   * A slot is publishable when it is a KNOWN ROLE or a real package id.
   *
   * This used to be `isPackageName(e.pkg)` alone, which was right while every
   * row carried a package. With roles it silently disabled publish for every
   * pack built from the core grid: `phone` and `store` are not package names
   * and never will be, so the button greyed out with nothing on screen saying
   * why. The check now matches what actually ships, since `expandRoleEntries`
   * turns a role into its package list before anything is signed.
   */
  /**
   * Is this slot something the pack can ship?
   *
   * A known ROLE (which expands into its package list at publish) or a real
   * package id typed by hand. Defined once because five places ask the same
   * question: the publish gate, the "N mapped" count, the unmapped warning,
   * the row sort and the row tint. They were all asking `isPackageName`, which
   * says no to every role, so a pack built from the core grid reported itself
   * unmapped and refused to publish with nothing on screen explaining it.
   */
  const slotMapped = useCallback(
    (slot: string) => CORE_ROLES.some((r) => r.id === slot) || isPackageName(slot),
    [],
  );

  // Null when the attestation is complete. A sentence rather than a boolean,
  // because it disables Publish and a disabled button with no reason beside it
  // is this codebase's most-repeated bug.
  const licenceIssue = licensed ? licenseProblem(lane, attribution) : 'The license attestation is needed before publishing.';

  const ready = useMemo(
    () =>
      entries.length > 0 &&
      entries.every(
        (e) => e.blob && slotMapped(e.pkg),
      ) &&
      duplicates.size === 0 &&
      /^[a-z0-9._-]+$/.test(packId) &&
      licenceIssue === null &&
      !busy,
    [entries, duplicates, packId, licenceIssue, busy, slotMapped],
  );

  const covered = new Set(entries.map((e) => e.pkg));
  const missing = CORE_ROLES.filter((r) => !covered.has(r.id));

  // CSS that mirrors renderHero's two branches for the preview tile.
  //
  // The MASK is the chosen treatment on the masked branch, because that branch
  // is `clipPath(maskPath)` on the device and the treatment is what decides the
  // path. On the unmasked branch the art is drawn as authored and there is no
  // clip at all, so the checkerboard keeps a soft corner purely so a
  // transparent PNG reads as a tile rather than bleeding into the page.
  const tileStyle: React.CSSProperties = masked
    ? { background: plate, ...maskFor(shape, radius) }
    : {
        // neutral checkerboard so transparent art is legible without implying a plate
        backgroundImage:
          'linear-gradient(45deg,#20252d 25%,transparent 25%),linear-gradient(-45deg,#20252d 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#20252d 75%),linear-gradient(-45deg,transparent 75%,#20252d 75%)',
        backgroundSize: '10px 10px',
        backgroundPosition: '0 0,0 5px,5px -5px,-5px 0',
        borderRadius: '18%',
      };

  // ── DRAFTS ────────────────────────────────────────────────────────────
  //
  // A pack of two hundred icons is not a one-sitting job, and until this
  // existed the only exit from this screen was publish: closing the tab threw
  // away every blob in `entries`, which is the whole afternoon.
  //
  // A draft saves the SAME blobs to `admin/icon-drafts/<packId>/` and the same
  // metadata beside them, so reopening is the identical rehydration path a
  // published pack uses. It does NOT bump a version, touch the index, or sign
  // anything: a draft is invisible to every device.
  const [draftBusy, setDraftBusy] = useState(false);
  const [draftNote, setDraftNote] = useState<string | null>(null);

  async function saveDraft() {
    // The one rule a draft has to satisfy, because the id is its filename and
    // its address. Everything else may legitimately be unfinished.
    if (!packId.trim()) {
      setError('A pack id is needed before a draft can be saved.');
      return;
    }
    setDraftBusy(true);
    setError(null);
    setDraftNote(null);

    const body = new FormData();
    body.set('app', app);
    body.set('packId', packId.trim());
    body.set('name', name);
    body.set('minAppVersion', minAppVersion);
    body.set('masked', masked ? '1' : '0');
    body.set('sku', sku.trim());
    body.set('plate', plate);
    body.set('radius', String(radius));
    body.set('shape', shape);

    const icons: { pkg: string; file: string }[] = [];
    for (const e of entries) {
      if (!e.blob) continue;
      // Entries with no package yet are still saved, under a name derived from
      // the entry id. Dropping them would lose exactly the work a draft exists
      // to protect: art uploaded but not yet matched to an app.
      const fileName = e.pkg ? fileNameFor(e.pkg) : `unmapped-${e.id}.png`;
      body.append('files', new File([e.blob], fileName, { type: 'image/png' }));
      body.append('paths', fileName);
      icons.push({ pkg: e.pkg, file: fileName });
    }
    body.set('icons', JSON.stringify(icons));

    try {
      const res = await saveIconDraftAction(body);
      if (res.ok) {
        setDraftNote(
          `Draft saved. ${icons.length} ${icons.length === 1 ? 'icon' : 'icons'} kept. Nothing published.`,
        );
      } else {
        setError(res.error);
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setDraftBusy(false);
    }
  }

  async function publish() {
    setBusy(true);
    setError(null);
    setResult(null);

    const body = new FormData();
    body.set('app', app);
    body.set('packId', packId);
    body.set('packType', 'hero');
    body.set('version', String(version));
    body.set('minAppVersion', minAppVersion);
    body.set('title', name || packId);
    body.set('summary', `${entries.length} hero icons`);
    // WAS HARDCODED EMPTY, which meant every icon pack this builder has ever
    // published was free, permanently and silently. `icons_kali`,
    // `icons_garuda` and `icons_pop_cosmic` exist in Play Console and could not
    // be attached to anything, so the standalone icon-pack product had a price
    // in the store and no pack behind it.
    //
    // Blank still means free, which is correct and is the common case.
    body.set('sku', sku.trim());

    // ── SLOTS UPLOAD, PACKAGES SHIP ───────────────────────────────────────
    //
    // An entry's `pkg` is a ROLE ID for anything added from the core grid and
    // a raw package id for anything hand-typed. The file is uploaded ONCE per
    // entry; `expandRoleEntries` then maps every package in the role onto that
    // same filename, so one drawn Phone icon covers the AOSP, Google and
    // Samsung dialers instead of whichever one the author happened to pick.
    for (const e of entries) {
      if (!e.blob) continue;
      const fileName = fileNameFor(e.pkg);
      body.append('files', new File([e.blob], fileName, { type: 'image/png' }));
      body.append('paths', fileName);
    }

    // Credit ships INSIDE the pack, not beside it. `HeroIconResolver` reads
    // four keys by name and ignores the rest, so this is additive: every
    // launcher already in the field keeps working, and a pack with no credit is
    // byte-identical to one built before attribution existed.
    if (lane === 'attributed' && attribution.trim()) {
      body.set('attribution', attribution.trim());
    }

    const pack = buildHeroPackJson(
      packId,
      name || packId,
      masked,
      expandRoleEntries(
        entries.map((e) => ({ slot: e.pkg, file: fileNameFor(e.pkg) })),
      ),
      lane === 'attributed' ? attribution : undefined,
    );
    body.append(
      'files',
      new File([JSON.stringify(pack, null, 2)], 'pack.json', { type: 'application/json' }),
    );
    body.append('paths', 'pack.json');

    // The shelf preview: the pack's own first six icons, composited exactly
    // as the grid above shows them. A listed, signed payload file like any
    // other; old clients ignore it, new ones draw it before install.
    const preview = await composePreviewPng(
      entries.filter((e) => e.blob).map((e) => e.blob as Blob),
    );
    if (preview) {
      body.append('files', new File([preview], PREVIEW_NAME, { type: 'image/png' }));
      body.append('paths', PREVIEW_NAME);
    }

    try {
      const res = await fetch('/api/publish/pack', { method: 'POST', body });
      const json = await res.json();
      if (!res.ok) setError(json.error ?? 'Publish failed');
      else {
        // The draft now MATCHES what devices will have. Without this the
        // builder reopens saying "draft ahead of v8, publishing writes v9"
        // against the v8 it just wrote, forever. Not awaited into the result:
        // a failed stamp is a stale sentence, not a failed publish.
        void markIconDraftPublishedAction(app, packId, Number(json.version));
        setResult(
          `${json.packId} v${json.version} · ${json.fileCount} files · ${(json.sizeBytes / 1024).toFixed(0)} KB` +
            (json.grantedTo ? ` · included with ${json.grantedTo}` : ''),
        );
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      {/* ── THE RAIL AND THE NOTICES ARE MIRRORED, TOP AND BOTTOM ────────────
          This form is over a thousand lines tall and the icon grid alone is
          forty rows, so the two ends of it are never on screen together. The
          rail used to exist only here and the messages only at the far end,
          which meant the two facts you most need were each visible from
          exactly one scroll position: start a publish from the bottom and
          nothing appears to happen, read an error from the top and there is
          nothing to read. Both are rendered at both ends now, from one
          definition each, so whichever end you are looking at is telling you
          the truth. */}
      <BusyRail busy={busy || draftBusy} />
      <Notices error={error} result={result} draftNote={draftNote} />
      {/* ── pack ─────────────────────────────────────────────────────────── */}
      <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Belongs to</label>
            <select
              value={belongsTo?.base ?? ''}
              disabled={!!initial}
              onChange={(e) => setBelongs(e.target.value)}
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
            >
              <option value="">standalone</option>
              {distros.map((d) => (
                <option key={d.base} value={d.base}>
                  {d.title === d.base ? d.base : `${d.title} · ${d.base}`}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Pack id</label>
            {/* ── IMMUTABLE ONCE THE PACK EXISTS ──────────────────────────
                Editing this while a pack was open did not RENAME anything: the
                id is the primary key of the draft, the bucket directory, the
                index entry and the device's install path, so a changed id
                published a SECOND pack at v1 and left the original live and
                orphaned. That is the same fork that produced two Ubuntus, and
                it is closed the same way. A new pack still types freely. */}
            {initial ? (
              <div className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono text-site-ink-2">
                {packId}
              </div>
            ) : (
              <input
                value={packId}
                onChange={(e) => setPackId(e.target.value)}
                placeholder="hero-ubuntu"
                autoCapitalize="none"
                spellCheck={false}
                className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
              />
            )}
            <p className="mt-1 text-[11.5px] text-site-ink-3">
              {belongsTo
                ? `shelves under ${belongsTo.title} on device`
                : packId
                  ? 'shelves under Standalone packs on device'
                  : 'the id decides the shelf: <distro>-<name>-icons'}
            </p>
          </div>
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Name</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ubuntu hero icons"
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2"
            />
          </div>
          <div>
            <label className="block text-[11.5px] text-site-ink-3">Min app version</label>
            <input
              value={minAppVersion}
              onChange={(e) => setMinAppVersion(e.target.value)}
              inputMode="numeric"
              className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
            />
          </div>
        </div>

        {/* ── PRICE ────────────────────────────────────────────────────────
            Blank is free, and free is the common case: the bundled packs and
            every hero pack that ships with a free distro carry no SKU.

            WHEN PLAY CAN BE READ, this is a picker rather than an input: a
            Play product ID is PERMANENT, Play never releases one for reuse,
            and picking an existing product is the case that can never typo.
            The derived `icons_<slug>` id is offered even when Play does not
            have it yet, because naming the product here first and creating it
            in Play second is a legitimate order of operations; the status line
            says exactly what remains to be done in Play Console. Custom
            reveals the plain input.

            WHEN PLAY CANNOT BE READ, this is the input it always was, plus
            the reason nothing can be confirmed. The suggestion button only
            exists on this path; in the picker the derived id is an option. */}
        <div className="mt-3">
          <label className="block text-[11.5px] text-site-ink-3">
            Play product ID <span className="text-site-ink-3/60">· blank means free</span>
          </label>
          {play.ok ? (
            (() => {
              const derived = packId ? iconsSkuFor(packId) : '';
              const listed = play.products.filter((p) =>
                p.productId.startsWith(SKU_PREFIX.icons),
              );
              const rows: { value: string; label: string }[] = [
                { value: '', label: 'free (no product)' },
                ...(derived && !listed.some((p) => p.productId === derived)
                  ? [{ value: derived, label: `${derived} (create in Play)` }]
                  : []),
                ...listed.map((p) => ({
                  value: p.productId,
                  label:
                    p.activeOptions === 0 ? `${p.productId} (not active)` : p.productId,
                })),
                ...(sku &&
                sku !== derived &&
                !listed.some((p) => p.productId === sku)
                  ? [{ value: sku, label: `${sku} (not in Play)` }]
                  : []),
                { value: '__custom', label: 'custom ID' },
              ];
              return (
                <>
                  <select
                    value={customSku ? '__custom' : sku}
                    onChange={(e) => {
                      const v = e.target.value;
                      if (v === '__custom') {
                        setCustomSku(true);
                        return;
                      }
                      setCustomSku(false);
                      setSku(v);
                    }}
                    className="mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                  >
                    {rows.map((r) => (
                      <option key={r.value} value={r.value}>
                        {r.label}
                      </option>
                    ))}
                  </select>
                  {customSku && (
                    <input
                      value={sku}
                      onChange={(e) => setSku(e.target.value)}
                      placeholder="icons_kali"
                      autoCapitalize="none"
                      spellCheck={false}
                      className="mt-2 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                    />
                  )}
                </>
              );
            })()
          ) : (
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <input
                value={sku}
                onChange={(e) => setSku(e.target.value)}
                placeholder="icons_kali"
                autoCapitalize="none"
                spellCheck={false}
                className="min-w-0 flex-1 rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
              />
              {packId && !sku && (
                <button
                  onClick={() => setSku(iconsSkuFor(packId))}
                  className="shrink-0 rounded-lg border border-site-line bg-site-sunk px-2.5 py-2 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
                >
                  {iconsSkuFor(packId)}
                </button>
              )}
            </div>
          )}
          {skuIssues.map((p) => (
            <p key={p} className="mt-1 text-[11.5px] text-site-plan">
              {p}
            </p>
          ))}
          {sku.trim() !== '' && skuIssues.length === 0 && (
            <PlayNoteLine play={play} sku={sku.trim()} />
          )}
        </div>

        {/* masked is the one real switch the format has */}
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <button
            onClick={() => setMasked((m) => !m)}
            className={`flex items-center gap-2 rounded-lg border px-3 py-1.5 text-[13px] transition ${
              masked ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep' : 'border-site-line text-site-ink-2'
            }`}
          >
            <span
              className={`grid size-4 place-items-center rounded ${masked ? 'bg-site-accent text-white' : 'border border-site-line'}`}
            >
              {masked ? '\u2713' : ''}
            </span>
            masked
          </button>
          <span className="text-[11.5px] leading-relaxed text-site-ink-3">
            {masked
              ? 'Art is square and full-bleed; the theme clips its shape and draws the plate behind.'
              : 'Art has its own silhouette and transparency, drawn as authored. This is the usual case.'}
          </span>
        </div>

        {masked && (
          <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-[11.5px] text-site-ink-3">Preview plate</label>
              <div className="mt-1 flex items-center gap-2">
                <span className="size-9 shrink-0 rounded-lg border border-site-line" style={{ background: plate }} />
                <input
                  value={plate}
                  onChange={(e) => setPlate(e.target.value)}
                  className="w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono"
                />
              </div>
              <p className="mt-1 text-[11.5px] text-site-ink-3">Preview only. The real plate comes from the theme.</p>
            </div>
            <div>
              {/* ── THE SHAPE, NAMED AS THE DEVICE NAMES IT ──────────────
                  A free-form radius percentage previews a rounded rectangle
                  and nothing else, so an author working on art destined for a
                  circular distro had no way to see it clipped. These are the
                  six values `icons.treatment` accepts, so what you preview is
                  a mask some theme can genuinely ask for. */}
              <label className="block text-[11.5px] text-site-ink-3">Preview shape</label>
              <div className="mt-1 flex flex-wrap gap-1.5">
                {ICON_TREATMENTS.map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setShape(t)}
                    className={`rounded-lg border px-2.5 py-1.5 text-[12px] ${
                      shape === t
                        ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep'
                        : 'border-site-line text-site-ink-2'
                    }`}
                  >
                    <span
                      className="mr-1.5 inline-block size-3 align-[-1px] bg-current opacity-70"
                      style={maskFor(t, radius)}
                    />
                    {shapeLabel(t)}
                  </button>
                ))}
              </div>
              <p className="mt-1 text-[11.5px] text-site-ink-3">
                Preview only. A pack carries no shape: the distro wearing it decides, so the same
                art is a circle under one and a squircle under another.
              </p>
            </div>

            {/* The radius is only meaningful for the one treatment that has
                one. Shown conditionally rather than greyed, because a slider
                that moves and changes nothing is worse than an absent one. */}
            {shape === 'roundedSquare' && (
              <div>
                <label className="block text-[11.5px] text-site-ink-3">
                  Preview corner radius {radius}%
                </label>
                <input
                  type="range"
                  min={0}
                  max={50}
                  value={radius}
                  onChange={(e) => setRadius(Number(e.target.value))}
                  className="mt-3 w-full"
                />
              </div>
            )}
          </div>
        )}

        <p className="mt-3 text-[11.5px] text-site-ink-3">
          {existing
            ? `v${existing} is published. This publishes v${version} and replaces every file in it.`
            : 'New pack, publishing as v1.'}
        </p>
      </section>

      {/* ── input ────────────────────────────────────────────────────────── */}
      <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
        <div className="flex flex-wrap items-center gap-2">
          <input
            type="file"
            multiple
            accept=".svg,.png,.webp,.jpg,.jpeg,.zip,image/svg+xml,image/png,image/webp,image/jpeg,application/zip"
            onChange={(e) => {
              void addFiles(e.target.files);
              e.target.value = '';
            }}
            className="block min-w-0 flex-1 text-[13px] text-site-ink-3 file:mr-3 file:rounded-lg file:border-0 file:bg-site-accent-soft file:px-3 file:py-2 file:text-[13px] file:text-site-accent-deep"
          />
          {/* A folder pick is its own input: `webkitdirectory` and `multiple`
              on one input mean "folder" wins everywhere it is supported and
              loose files become unpickable. Set via callback ref because the
              attribute is non-standard and not in React's input props. */}
          <input
            type="file"
            ref={(el) => el?.setAttribute('webkitdirectory', '')}
            onChange={(e) => {
              void addFiles(e.target.files);
              e.target.value = '';
            }}
            className="hidden"
            id="icon-folder-pick"
          />
          <label
            htmlFor="icon-folder-pick"
            className="shrink-0 cursor-pointer rounded-lg border border-site-line bg-site-sunk px-3 py-2 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
          >
            Add a folder
          </label>
          <button
            type="button"
            onClick={() => setPickingGlyph((v) => !v)}
            className="rounded-lg border border-site-line bg-site-card px-4 py-2 text-[13px] text-site-ink-2"
          >
            {pickingGlyph ? 'Close glyphs' : 'Brand glyph'}
          </button>
        </div>

        {/* ── COMPOSE, AND WHY IT LIVES HERE ────────────────────────────────
            Beside the intake, because it is intake: a plate and a tint are
            another way of getting art into the pack, not a setting about the
            pack. Everything below this point, the review list, the core-set
            grid, publish, is unchanged and does not know composing exists.

            It is what makes a distro icon pack possible at all without drawn
            files. Kali's own set is GPL-3 and so is Garuda's, so the identity
            has to come from a plate you defined rather than from art somebody
            else licensed. */}
        <div className="mt-3 rounded-[14px] border border-site-line bg-site-sunk p-3">
          <IconStyleBar
            style={style}
            onChange={restyle}
            count={entries.length}
            busy={restyling}
          />
        </div>

        <div className="mt-3">
          <GlyphPicker
            open={pickingGlyph}
            onClose={() => setPickingGlyph(false)}
            onPick={addGlyph}
          />
        </div>
        <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
          SVG, PNG, WEBP, or JPEG, loose, in a folder, or in a zip. Each drawing
          is fitted to a 192 square at its own proportions and written as PNG.
          No trimming or rescaling: what you drew is what ships. Packages are
          guessed from filenames and reviewed below; nothing uploads until you
          publish.
        </p>
        {/* ── LINE COLOUR ──────────────────────────────────────────────────
            Shown only when the intake found monotone SVG art, because that is
            the only kind it can retarget without damage. A two-colour icon is
            left alone rather than flattened: flattening one is a mistake, and
            flattening a whole set silently is the kind nobody notices until it
            is published.

            It rewrites the SVG's paint before rasterisation, so no IconStyle
            field, no Pigeon regeneration and no icon-cache fingerprint is
            involved. The bytes that ship are already the right colour. */}
        {recolourable > 0 && (
          <div className="mt-3 rounded-[14px] border border-site-line bg-site-sunk p-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-[13px] text-site-ink-2">Line colour</span>
              <button
                type="button"
                onClick={() => setLineColour(null)}
                className={`rounded-lg border px-2.5 py-1.5 text-[12px] ${
                  lineColour === null
                    ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep'
                    : 'border-site-line text-site-ink-2'
                }`}
              >
                As authored
              </button>
              <span
                className="size-8 shrink-0 rounded-lg border border-site-line"
                style={{ background: lineDraft }}
              />
              <input
                value={lineDraft}
                onChange={(e) => setLineDraft(e.target.value)}
                autoCapitalize="none"
                spellCheck={false}
                className="w-32 rounded-lg border border-site-line bg-site-card px-2.5 py-1.5 font-mono text-[13px]"
              />
              <button
                type="button"
                onClick={() => setLineColour(normaliseHex(lineDraft))}
                disabled={normaliseHex(lineDraft) === null}
                className={`rounded-lg border px-2.5 py-1.5 text-[12px] disabled:opacity-40 ${
                  lineColour !== null
                    ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep'
                    : 'border-site-line text-site-ink-2'
                }`}
              >
                Recolour
              </button>
            </div>
            <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
              {lineColour
                ? `${recolourable} monotone drawings will ship in ${lineColour}. Art with two or more colours is left exactly as it was.`
                : `${recolourable} of the drawings picked are monotone line art, so they can carry a distro\u2019s own colour. Recolouring an adapted set makes it a derivative work, which matters under CC BY-SA.`}
            </p>
          </div>
        )}

        {/* ── THE LICENSE LANE ─────────────────────────────────────────────
            One checkbox became a checkbox plus a lane, because a lane was
            missing. See LICENSE_LANES in bulk-icons for the case that fell
            through: BY-SA art scans clean and then sits under a claim of CC0. */}
        <label className="mt-3 flex cursor-pointer items-start gap-2 text-[11.5px] leading-relaxed text-site-ink-2">
          <input
            type="checkbox"
            checked={licensed}
            onChange={(e) => setLicensed(e.target.checked)}
            className="mt-0.5"
          />
          <span>
            I have the right to publish this art. GPL sets (Papirus, Numix, Flat Remix) cannot ship
            over the CDN in any form.
          </span>
        </label>

        {licensed && (
          <div className="mt-2 rounded-[14px] border border-site-line bg-site-sunk p-3">
            <div className="flex flex-wrap gap-1.5">
              {LICENSE_LANES.map((l) => (
                <button
                  key={l.id}
                  type="button"
                  onClick={() => setLane(l.id)}
                  className={`rounded-lg border px-2.5 py-1.5 text-[12px] ${
                    lane === l.id
                      ? 'border-site-accent/40 bg-site-accent-soft text-site-accent-deep'
                      : 'border-site-line text-site-ink-2'
                  }`}
                >
                  {l.label}
                </button>
              ))}
            </div>
            <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
              {LICENSE_LANES.find((l) => l.id === lane)?.note}
            </p>
            {lane === 'attributed' && (
              <input
                value={attribution}
                onChange={(e) => setAttribution(e.target.value)}
                placeholder="Based on Arcticons by Team Arcticons, CC BY-SA 4.0, recoloured"
                className="mt-2 w-full rounded-lg border border-site-line bg-site-card px-3 py-2 text-[13px]"
              />
            )}
          </div>
        )}

        {intakeNote && (
          <p className="mt-3 rounded-[14px] bg-site-info-soft px-4 py-3 text-[12.5px] leading-relaxed text-site-info">
            {intakeNote}
          </p>
        )}
        {refused.length > 0 && (
          <div className="mt-3 space-y-1">
            {refused.map((r, i) => (
              <p key={i} className="text-[11.5px] leading-relaxed text-site-plan">
                {r.name} {r.reason}
              </p>
            ))}
          </div>
        )}
      </section>

      {/* ── entries ──────────────────────────────────────────────────────── */}
      {entries.length > 0 && (
        <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
          <header className="flex items-center gap-2 border-b border-site-line px-3 py-2.5 sm:px-4">
            <h2 className="text-[13px] font-medium">{entries.length} icons</h2>
            <span className="text-[11.5px] text-site-ink-3">
              {entries.filter((e) => slotMapped(e.pkg)).length} mapped
            </span>
            {entries.some((e) => !slotMapped(e.pkg)) && (
              <button
                onClick={() => setUnmappedFirst((v) => !v)}
                className={`ml-auto text-[11.5px] transition ${unmappedFirst ? 'text-site-ink' : 'text-site-ink-3 hover:text-site-ink'}`}
              >
                {unmappedFirst ? 'Original order' : 'Unmapped first'}
              </button>
            )}
          </header>

          {/* The common packages as picks, so correcting a guess is a choice
              rather than typing a reverse-DNS string on a laptop keyboard.
              Free text still works: the datalist only suggests. */}
          <datalist id="core-pkgs">
            {CORE_ROLES.map((c) => (
              <option key={c.id} value={c.id}>
                {c.label}
                {c.packages.length > 1 ? ` (${c.packages.length} apps)` : ''}
              </option>
            ))}
          </datalist>

          <div className="divide-y divide-site-line">
            {(unmappedFirst
              ? [...entries].sort(
                  (a, b) => Number(slotMapped(a.pkg)) - Number(slotMapped(b.pkg)),
                )
              : entries
            ).map((e) => (
              <div key={e.id} className="flex flex-wrap items-center gap-3 px-3 py-2.5 sm:px-4">
                <div className="grid size-12 shrink-0 place-items-center overflow-hidden border border-site-line" style={tileStyle}>
                  {/* Busy renders NOTHING. The tile is 48px with a border and a
                      background, so an empty one already reads as "not yet",
                      and the failure case below has its own mark to be
                      distinguished from. A character here was a third state
                      competing with two that already say enough. */}
                  {e.busy ? null : e.url ? (
                    <img src={e.url} alt="" className="size-12" />
                  ) : (
                    <span className="text-[11.5px] text-site-plan">!</span>
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <input
                    value={e.pkg}
                    onChange={(ev) => patchPkg(e.id, ev.target.value)}
                    placeholder="com.example.app"
                    autoCapitalize="none"
                    spellCheck={false}
                    list="core-pkgs"
                    className={`w-full rounded-lg border bg-site-sunk px-2.5 py-1.5 font-mono ${
                      !e.pkg
                        ? 'border-site-plan/50'
                        : !slotMapped(e.pkg) || duplicates.has(e.pkg)
                          ? 'border-site-plan'
                          : 'border-site-line'
                    }`}
                  />
                  <p className="mt-0.5 truncate text-[11.5px] text-site-ink-3">
                    {e.file.name}
                    {e.aspect < 0.8 || e.aspect > 1.25 ? ' · not square, padded' : ''}
                    {duplicates.has(e.pkg) ? ' · duplicate package' : ''}
                    {e.error ? ` · ${e.error}` : ''}
                  </p>
                </div>

                <button
                  onClick={() => {
                    if (e.url) URL.revokeObjectURL(e.url);
                    setEntries((all) => all.filter((x) => x.id !== e.id));
                  }}
                  className="text-[11.5px] text-site-ink-3 transition hover:text-site-plan"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── the unclaimed shelf ──────────────────────────────────────────────
          Between the pack and the core set, which is where it belongs in the
          reading order: these are the icons the archive HAD, sitting below the
          ones it placed and above the slots still empty. Held as bytes; see
          icon-shelf.tsx. */}
      <IconShelf
        items={shelf}
        takenSlots={covered}
        lineColour={lineColour}
        onClaim={({ art, slot }) => void claimFromShelf(art, slot)}
        onClear={() => setShelf([])}
      />

      {/* ── coverage ─────────────────────────────────────────────────────────
          ALWAYS RENDERED, not only once files exist. Hidden behind
          `entries.length > 0` this doubled as the builder's app list and was
          invisible on a new pack, so the screen opened with no package ids
          anywhere and every mapping started from a filename guess. Now it is
          the starting point: tap an app, pick its art, and the row arrives
          already mapped to the right id. */}
      {missing.length > 0 && (
        <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft p-3 sm:p-4">
          <div className="mb-2 flex items-center gap-2">
            <h2 className="text-[13px] font-medium">Core set</h2>
            <span className="text-[11.5px] text-site-ink-3">
              {CORE_ROLES.length - missing.length} of {CORE_ROLES.length} covered
            </span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {missing.map((c) => (
              <label
                key={c.id}
                // Every package the role covers, so the tile can be checked
                // against a real device without opening this file.
                title={c.packages.join('\n')}
                className="cursor-pointer rounded-md border border-dashed border-site-line px-2 py-1 font-mono text-[11.5px] text-site-ink-3 transition hover:border-site-ink-3 hover:text-site-ink"
              >
                + {c.label}
                {c.packages.length > 1 ? (
                  <span className="ml-1 opacity-60">x{c.packages.length}</span>
                ) : null}
                <input
                  type="file"
                  accept="image/png,image/webp,image/jpeg,image/svg+xml"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) void addForPackage(c.id, f);
                    e.target.value = '';
                  }}
                />
              </label>
            ))}
          </div>
          <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
            Tap an app to add its icon with the package id already set; hover
            shows the id. The dock and first drawer page are the only icons a
            user sees. Ranked by what the install base runs, not by what a
            desktop theme ships. A real ranking arrives with the analytics
            export.
          </p>
        </section>
      )}

      <Notices error={error} result={result} draftNote={draftNote} />
      <BusyRail busy={busy || draftBusy} />

      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+4rem)] flex flex-col gap-2.5 md:static md:flex-row md:items-center">
        <button
          onClick={publish}
          disabled={!ready}
          className="w-full rounded-lg bg-site-accent px-4 py-3 text-[13px] font-medium text-white shadow-lg transition hover:brightness-110 disabled:opacity-40 disabled:shadow-none md:w-auto md:py-2"
        >
          {busy ? 'Signing and uploading' : `Publish ${entries.length} icons as v${version}`}
        </button>

        {/* SAVE DRAFT SITS BESIDE PUBLISH AND IS ALWAYS AVAILABLE. It has no
            `ready` gate on purpose: the reason to save a draft is precisely
            that the pack is not ready, so disabling it whenever publish is
            disabled would disable it exactly when it is needed. The only
            requirement is a pack id, which is the draft's address. */}
        <button
          onClick={saveDraft}
          disabled={draftBusy || !packId.trim()}
          className="w-full rounded-lg border border-site-line bg-site-card px-4 py-3 text-[13px] font-semibold text-site-ink transition hover:border-site-ink-3/45 disabled:opacity-40 md:w-auto md:py-2"
        >
          {draftBusy ? 'Saving' : 'Save draft'}
        </button>

        <span className="text-[11.5px] leading-relaxed text-site-ink-3 md:max-w-[34ch]">
          A draft is stored for you alone. It publishes nothing, bumps no version and reaches no
          device.
        </span>
        {licenceIssue && entries.length > 0 && (
          <p className="mt-2 text-[11.5px] text-site-plan">{licenceIssue}</p>
        )}
        {duplicates.size > 0 && (
          <p className="mt-2 text-[11.5px] text-site-plan">
            {duplicates.size} {duplicates.size === 1 ? 'app has' : 'apps have'} two icons, so
            publishing is held: {[...duplicates].slice(0, 4).join(', ')}
            {duplicates.size > 4 ? ' and more' : ''}. Use Unmapped first above to find them.
          </p>
        )}
        {publishedIds.length > 0 && !packId && (
          <p className="mt-2 text-[11.5px] text-site-ink-3">Published hero packs: {publishedIds.join(', ')}</p>
        )}
      </div>
    </div>
  );
}

/**
 * The working rail. INDETERMINATE, and deliberately so.
 *
 * Nothing in this flow reports a fraction. A publish signs, uploads several
 * hundred KB and rewrites the index, and the browser learns about each of those
 * only when it finishes. A percentage here would therefore be an invented
 * figure, which is the one thing this project does not ship, and a bar that
 * sits at 90 percent for forty seconds is worse than no bar at all: it reads as
 * a stall rather than as work.
 *
 * A moving stripe says only "something is happening", which is exactly what is
 * known and exactly what the reader needs.
 *
 * The keyframes ride inline rather than in globals.css because they exist for
 * this one element, and a rule in the global sheet that only one component uses
 * is a rule nobody dares delete later. Two rails render the same block, which
 * is harmless: identical `@keyframes` of the same name resolve to one.
 */
function BusyRail({ busy }: { busy: boolean }) {
  if (!busy) return null;
  return (
    <>
      <style>{'@keyframes ibSlide {0%{transform:translateX(-100%)}100%{transform:translateX(350%)}}'}</style>
      <div
        className="relative h-[3px] overflow-hidden rounded bg-site-line"
        role="progressbar"
        aria-label="Working"
      >
        <div
          className="absolute inset-y-0 left-0 w-1/3 bg-site-ink"
          style={{ animation: 'ibSlide 1.1s linear infinite' }}
        />
      </div>
    </>
  );
}

/**
 * The three outcome messages, rendered identically at both ends of the form.
 *
 * ONE DEFINITION, TWO CALL SITES. The alternative was copying three JSX blocks
 * to the top of the render, and a second copy of a message is a message that
 * eventually disagrees with the first: someone changes the error styling in one
 * place, or adds a fourth state to one and not the other, and the two ends of
 * the same screen start reporting different things about the same publish.
 */
function Notices({
  error,
  result,
  draftNote,
}: {
  error: string | null;
  result: string | null;
  draftNote: string | null;
}) {
  if (!error && !result && !draftNote) return null;
  return (
    <>
      {error && (
        <p className="rounded-card border border-site-plan/40 bg-site-plan-soft px-3 py-2 text-[13px] leading-relaxed text-site-plan">
          {error}
        </p>
      )}
      {result && (
        <p className="rounded-card border border-site-ok/40 bg-site-ok-soft px-3 py-2 font-mono text-[11.5px] text-site-ok">
          {result}
        </p>
      )}
      {draftNote && (
        <p className="rounded-[14px] bg-site-info-soft px-4 py-3 text-[12.5px] leading-relaxed text-site-info">
          {draftNote}
        </p>
      )}
    </>
  );
}

/**
 * The status line under the product ID: can this sku actually be bought?
 * Advisory only, same three states as the Commerce page. It replaces the old
 * static "check the Commerce page after publishing" sentence, which is now the
 * answer rather than the errand.
 */
function PlayNoteLine({ play, sku }: { play: PlayLite; sku: string }) {
  const note = playSkuNote(play, sku);
  const cls =
    note.tone === 'ok' ? 'text-site-ok' : note.tone === 'warn' ? 'text-site-plan' : 'text-site-ink-3';
  return <p className={`mt-1 text-[11.5px] leading-relaxed ${cls}`}>{note.text}</p>;
}
