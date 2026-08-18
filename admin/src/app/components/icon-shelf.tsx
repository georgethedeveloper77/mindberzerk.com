'use client';

import { useEffect, useMemo, useRef, useState } from 'react';

import type { RawArt } from '@/lib/g-launcher/bulk-icons';
import { CORE_ROLES, isPackageName } from '@/lib/g-launcher/icon-pack';
import { recolourBytes } from '@/lib/g-launcher/svg-recolor';

/**
 * THE SHELF: everything an archive held that no role claimed.
 *
 * ─── WHY THIS IS NOT JUST MORE ROWS IN THE BUILDER ──────────────────────────
 *
 * The builder's `Entry` list holds a File, a rendered Blob and a live object URL
 * per row, and draws a 48px `<img>` for each. Correct for the forty icons a
 * pack ships. Fatal at fourteen thousand: three artifacts per file in memory,
 * fourteen thousand sequential decode-and-re-encode passes through
 * `renderHeroIcon`, fourteen thousand DOM rows. The tab stops responding, and
 * it stops responding on the exact archives that are worth importing.
 *
 * So the shelf holds BYTES. Three rules follow from that and each one is load
 * bearing:
 *
 *   1. NOTHING IS RENDERED. No canvas pass, no PNG re-encode. The preview is
 *      the source bytes in an `<img>`, which browsers draw natively for SVG as
 *      well as raster, so a preview costs a blob URL and nothing else.
 *   2. ONLY WHAT IS ON SCREEN HOLDS A URL. Each tile creates its object URL when
 *      it scrolls into view and revokes it when it leaves, so the live count
 *      tracks the viewport rather than the archive.
 *   3. NOTHING HERE IS EVER POSTED. Draft save and publish both walk `entries`,
 *      so an unclaimed shelf of any size adds nothing to a request body. That
 *      is what keeps a fifteen-thousand-file import inside the server action
 *      body limit.
 *
 * Claiming is the one path out: it hands the bytes back, the builder renders
 * that single file through the normal pipeline, and it becomes an ordinary row.
 */

/** Rendered at once. Beyond this, `Show more` extends the window. */
const PAGE = 120;

export interface ShelfClaim {
  art: RawArt;
  /** A core role id, or a hand-typed package id. */
  slot: string;
}

export function IconShelf({
  items,
  takenSlots,
  lineColour,
  onClaim,
  onClear,
}: {
  items: RawArt[];
  /** Roles already covered, so the picker cannot offer a slot twice. */
  takenSlots: Set<string>;
  /** Applied to the PREVIEW as well as the claim, so what you see is what ships. */
  lineColour: string | null;
  onClaim: (claim: ShelfClaim) => void;
  onClear: () => void;
}) {
  const [query, setQuery] = useState('');
  const [shown, setShown] = useState(PAGE);
  const [open, setOpen] = useState<string | null>(null);

  // A new archive replaces the shelf, so the window and the search must reset
  // with it. Without this, importing a second set shows page one of the first
  // set's scroll position and a filter nobody typed for these files.
  useEffect(() => {
    setShown(PAGE);
    setOpen(null);
  }, [items]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!q) return items;
    // Substring is right HERE and wrong at intake, and the difference is who
    // acts on it. At intake a loose match assigns art to an app silently; in a
    // search box a loose match shows you more rows and you pick one.
    return items.filter((a) => a.stem.includes(q) || (a.knownPkg ?? '').includes(q));
  }, [items, query]);

  const page = filtered.slice(0, shown);

  if (items.length === 0) return null;

  return (
    <section className="rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
      <header className="flex flex-wrap items-center gap-2 border-b border-site-line px-3 py-2.5 sm:px-4">
        <h2 className="text-[13px] font-medium">Other icons</h2>
        <span className="text-[11.5px] text-site-ink-3">
          {filtered.length === items.length
            ? `${items.length} not matched to a core app`
            : `${filtered.length} of ${items.length}`}
        </span>
        <button
          onClick={onClear}
          className="ml-auto text-[11.5px] text-site-ink-3 transition hover:text-site-plan"
        >
          Clear
        </button>
      </header>

      <div className="px-3 py-2.5 sm:px-4">
        <input
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setShown(PAGE);
          }}
          placeholder="Search by name or package"
          autoCapitalize="none"
          spellCheck={false}
          className="w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 text-[13px]"
        />
        <p className="mt-2 text-[11.5px] leading-relaxed text-site-ink-3">
          These are held as bytes and never rendered or uploaded. Tap one to give it an app, and
          only then does it become a real icon in the pack above.
        </p>
      </div>

      <div className="grid grid-cols-3 gap-2 px-3 pb-3 sm:grid-cols-6 sm:px-4 md:grid-cols-8">
        {page.map((art) => (
          <ShelfTile
            key={art.id}
            art={art}
            lineColour={lineColour}
            open={open === art.id}
            onOpen={() => setOpen((v) => (v === art.id ? null : art.id))}
          />
        ))}
      </div>

      {open && (
        <ClaimBar
          art={filtered.find((a) => a.id === open) as RawArt}
          takenSlots={takenSlots}
          onCancel={() => setOpen(null)}
          onClaim={(slot) => {
            const art = filtered.find((a) => a.id === open);
            if (art) onClaim({ art, slot });
            setOpen(null);
          }}
        />
      )}

      {shown < filtered.length && (
        <div className="border-t border-site-line px-3 py-2.5 sm:px-4">
          <button
            onClick={() => setShown((n) => n + PAGE)}
            className="rounded-lg border border-site-line bg-site-sunk px-3 py-2 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
          >
            Show {Math.min(PAGE, filtered.length - shown)} more
          </button>
          <span className="ml-2 text-[11.5px] text-site-ink-3">
            {filtered.length - shown} still hidden. Searching is faster than scrolling.
          </span>
        </div>
      )}
    </section>
  );
}

/**
 * One tile. Holds a blob URL ONLY while it is on screen.
 *
 * `IntersectionObserver` rather than rendering every URL up front, because the
 * window can be extended to thousands and a revoked-on-unmount-only policy
 * would then hold thousands of live URLs at once. `rootMargin` runs ahead of
 * the viewport so a tile is already drawn by the time it is scrolled to,
 * instead of flashing empty.
 */
function ShelfTile({
  art,
  lineColour,
  open,
  onOpen,
}: {
  art: RawArt;
  lineColour: string | null;
  open: boolean;
  onOpen: () => void;
}) {
  const box = useRef<HTMLButtonElement | null>(null);
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    const el = box.current;
    if (!el) return;

    let live: string | null = null;
    const drop = () => {
      if (live) URL.revokeObjectURL(live);
      live = null;
      setUrl(null);
    };
    const make = () => {
      if (live) return;
      // The preview is recoloured too. A swatch that changes the published art
      // but not the thumbnail would be a control that lies about its effect.
      const bytes = lineColour ? recolourBytes(art.bytes, art.mime, lineColour) : art.bytes;
      live = URL.createObjectURL(new Blob([new Uint8Array(bytes)], { type: art.mime }));
      setUrl(live);
    };

    const io = new IntersectionObserver(
      (rows) => {
        for (const row of rows) (row.isIntersecting ? make : drop)();
      },
      { rootMargin: '400px' },
    );
    io.observe(el);
    return () => {
      io.disconnect();
      drop();
    };
  }, [art, lineColour]);

  return (
    <button
      ref={box}
      type="button"
      onClick={onOpen}
      title={`${art.path}${art.knownPkg ? `\n${art.knownPkg}` : ''}`}
      className={`flex flex-col items-center gap-1 rounded-lg border p-2 transition ${
        open ? 'border-site-accent/50 bg-site-accent-soft' : 'border-site-line hover:bg-site-sunk'
      }`}
    >
      <span className="grid size-10 place-items-center overflow-hidden">
        {url ? <img src={url} alt="" className="size-10 object-contain" /> : null}
      </span>
      <span className="w-full truncate text-center font-mono text-[10.5px] text-site-ink-3">
        {art.stem}
      </span>
      {art.knownPkg && (
        <span className="w-full truncate text-center text-[10px] text-site-ok">mapped</span>
      )}
    </button>
  );
}

/**
 * Assigning one shelf item to an app.
 *
 * The package field is prefilled from `appfilter.xml` when the pack's own
 * author said which app the drawing serves. That is the payoff of reading the
 * answer key: claiming Spotify out of fifteen thousand files is a search and a
 * tap, with nobody typing a reverse-DNS string on a laptop keyboard.
 */
function ClaimBar({
  art,
  takenSlots,
  onClaim,
  onCancel,
}: {
  art: RawArt;
  takenSlots: Set<string>;
  onClaim: (slot: string) => void;
  onCancel: () => void;
}) {
  const [pkg, setPkg] = useState(art.knownPkg ?? '');

  const free = CORE_ROLES.filter((r) => !takenSlots.has(r.id));
  const ok = pkg.trim() !== '' && isPackageName(pkg.trim());

  return (
    <div className="border-t border-site-line px-3 py-3 sm:px-4">
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-[12px] text-site-ink-2">{art.name}</span>
        <button
          onClick={onCancel}
          className="ml-auto text-[11.5px] text-site-ink-3 transition hover:text-site-ink"
        >
          Cancel
        </button>
      </div>

      {free.length > 0 && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {free.map((r) => (
            <button
              key={r.id}
              onClick={() => onClaim(r.id)}
              title={r.packages.join('\n')}
              className="rounded-md border border-dashed border-site-line px-2 py-1 font-mono text-[11.5px] text-site-ink-3 transition hover:border-site-ink-3 hover:text-site-ink"
            >
              {r.label}
              {r.packages.length > 1 ? <span className="ml-1 opacity-60">x{r.packages.length}</span> : null}
            </button>
          ))}
        </div>
      )}

      <div className="mt-2 flex flex-wrap items-center gap-2">
        <input
          value={pkg}
          onChange={(e) => setPkg(e.target.value)}
          placeholder="com.example.app"
          autoCapitalize="none"
          spellCheck={false}
          className="min-w-0 flex-1 rounded-lg border border-site-line bg-site-sunk px-2.5 py-1.5 font-mono text-[13px]"
        />
        <button
          onClick={() => onClaim(pkg.trim())}
          disabled={!ok}
          className="shrink-0 rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-[13px] text-site-ink transition disabled:opacity-40"
        >
          Add
        </button>
      </div>
      <p className="mt-1 text-[11.5px] leading-relaxed text-site-ink-3">
        {art.knownPkg
          ? 'The package came from this pack\u2019s own appfilter.xml, so it is the author\u2019s mapping rather than a guess.'
          : 'Pick a core app above, or give it any package id. One icon, one app.'}
      </p>
    </div>
  );
}
