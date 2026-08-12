/**
 * THE BIN, DRAWN ONCE.
 *
 * ─── THREE ROLES, NOT WALLPAPER ──────────────────────────────────────────────
 *
 * A trash can behind every page becomes something you stop seeing inside a day,
 * and a motif nobody sees is a motif that is only costing bytes. So it appears
 * in three places where recovery is genuinely the subject and nowhere else:
 *
 *   watermark  faint, behind a page header, giving the screen a subject
 *   empty      the empty state on a list, with the lid off and nothing inside
 *   filling    the loading state, with contents rising out of it
 *
 * ─── currentColor THROUGHOUT ─────────────────────────────────────────────────
 *
 * Not a hex, anywhere. The console accent is one token in globals.css and this
 * has to follow it: pinning a blue here means the day somebody changes the
 * accent, the one drawing that is supposed to carry the product's identity is
 * the one thing left behind on the old colour.
 *
 * ─── AND IT IS THE SAME DRAWING AS THE APP'S ─────────────────────────────────
 *
 * G Recovery's EscapeArt puts a bin on every empty state in the product, with
 * different cargo coming out of it. This is that bin, still, so the panel and
 * the app look like one thing made by one hand rather than a console that
 * happens to administer an app.
 */
export function BinMark({
  role = 'watermark',
  className = '',
}: {
  role?: 'watermark' | 'empty' | 'filling';
  className?: string;
}) {
  // Escaping cargo, only where it means something. The watermark is a still
  // object behind a heading and adding motion to it would be the wallpaper
  // problem with extra steps.
  const cargo = role !== 'watermark';

  return (
    <svg
      viewBox="0 0 120 120"
      fill="none"
      stroke="currentColor"
      strokeWidth="3.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      {cargo && (
        <g>
          {/* Rounded cards leaving the bin, largest and nearest first. Angled
              rather than upright, because three level rectangles read as a
              stack sitting on the lid rather than as things coming out. */}
          <rect
            x="20"
            y="16"
            width="20"
            height="14"
            rx="3"
            transform="rotate(-18 30 23)"
            opacity="0.9"
          />
          <rect
            x="50"
            y="8"
            width="22"
            height="15"
            rx="3"
            transform="rotate(12 61 15)"
            opacity="0.6"
          />
          <rect
            x="80"
            y="20"
            width="18"
            height="13"
            rx="3"
            transform="rotate(-8 89 26)"
            opacity="0.35"
          />
        </g>
      )}

      {/* The lid, lifted and tilted on the states where something is leaving.
          Level on the watermark, because a closed bin is the resting shape and
          the watermark is not describing an event. */}
      <g transform={cargo ? 'rotate(-9 60 46)' : ''}>
        <path d="M30 46 H90" />
        <path d="M52 38 H68" />
      </g>

      {/* The body. Tapered, because a rectangle reads as a box and a bin is the
          one container people recognise by its slope. */}
      <path d="M36 54 L41 100 A4 4 0 0 0 45 104 H75 A4 4 0 0 0 79 100 L84 54" />

      {/* Three ribs. Fewer looks unfinished at this size and more turns into a
          texture that fights the stroke weight. */}
      <path d="M51 64 V93" opacity="0.55" />
      <path d="M60 64 V93" opacity="0.55" />
      <path d="M69 64 V93" opacity="0.55" />
    </svg>
  );
}

/**
 * A page header with the bin behind it.
 *
 * ─── WHY THIS IS NOT JUST A BACKGROUND IMAGE ─────────────────────────────────
 *
 * It is clipped to the header rather than the page, so it can never end up
 * behind a table of data where a stroke crossing a row of numbers is noise
 * dressed as decoration. It also fades from the right, so the heading sits on
 * flat surface no matter how long the title runs.
 */
export function BinHeader({
  title,
  meta,
  actions,
}: {
  title: string;
  meta?: React.ReactNode;
  actions?: React.ReactNode;
}) {
  return (
    <div className="relative mb-4 overflow-hidden rounded-card border border-line bg-surface-1 px-4 py-4">
      <div
        aria-hidden
        className="pointer-events-none absolute -right-4 -top-8 h-[168px] w-[168px] text-accent opacity-[0.07]"
      >
        <BinMark role="watermark" className="h-full w-full" />
      </div>

      {/* From the surface colour rather than to transparent. A gradient to
          transparent over a stroke leaves the stroke visible at half strength
          through the text, which is worse than not fading at all. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-y-0 left-0 w-2/3 bg-gradient-to-r from-surface-1 via-surface-1 to-transparent"
      />

      <div className="relative flex flex-wrap items-center gap-x-3 gap-y-2">
        <h1 className="text-base font-semibold tracking-tight">{title}</h1>
        {meta && <span className="text-micro text-ink-3 tnum">{meta}</span>}
        {actions && <div className="ml-auto flex gap-2">{actions}</div>}
      </div>
    </div>
  );
}
