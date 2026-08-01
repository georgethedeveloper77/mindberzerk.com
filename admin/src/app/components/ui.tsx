import Link from 'next/link';

/**
 * PHASE C5 - the primitives every screen is built from.
 *
 * NO `'use client'`. Nothing here holds state, so these stay server components
 * and cost zero JavaScript. The moment one of them needs an event handler it
 * should become its own client file rather than pulling this whole module into
 * the browser bundle.
 *
 * ## The density rule
 *
 * A card holds a number, a label, and at most one qualifier. If a sentence is
 * needed to explain why a number matters, it belongs in a `title` tooltip, a
 * docs link, or nowhere. The previous pass at this panel put a paragraph in
 * every card and the result read as a memo rather than a dashboard.
 *
 * The exceptions are [Banner] and [Empty]: an error has to say what went wrong
 * and what to do about it, and a blank screen has to say what to do next.
 */

// ── page frame ──────────────────────────────────────────────────────────────

export function PageHead({
  title,
  meta,
  actions,
}: {
  title: string;
  /** One short right-aligned fact. A count, a timestamp, an id. */
  meta?: React.ReactNode;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-4 flex flex-wrap items-center gap-x-3 gap-y-2">
      <h1 className="text-base font-semibold tracking-tight">{title}</h1>
      {meta && <span className="text-micro text-ink-3 tnum">{meta}</span>}
      {actions && <div className="ml-auto flex gap-2">{actions}</div>}
    </div>
  );
}

export function Grid({
  cols = 4,
  children,
}: {
  cols?: 2 | 3 | 4;
  children: React.ReactNode;
}) {
  // Explicit strings: Tailwind scans source text, so a template literal like
  // `grid-cols-${cols}` produces a class that is never generated.
  const at = { 2: 'sm:grid-cols-2', 3: 'sm:grid-cols-3', 4: 'sm:grid-cols-2 lg:grid-cols-4' }[cols];
  return <div className={`grid grid-cols-2 gap-2 sm:gap-3 ${at}`}>{children}</div>;
}

// ── cards ───────────────────────────────────────────────────────────────────

export function Card({
  title,
  right,
  flush,
  children,
}: {
  title?: string;
  right?: React.ReactNode;
  /** Drop the body padding, for a card that is entirely a table. */
  flush?: boolean;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-card border border-line-soft bg-surface-1">
      {(title || right) && (
        <header className="flex items-center gap-2 border-b border-line-soft px-3 py-2.5 sm:px-4">
          {title && <h2 className="text-data font-medium">{title}</h2>}
          {right && <div className="ml-auto flex items-center gap-2">{right}</div>}
        </header>
      )}
      <div className={flush ? '' : 'p-3 sm:p-4'}>{children}</div>
    </section>
  );
}

/**
 * A number with a label. `sub` is a unit or a qualifier, never a sentence.
 *
 * `href` makes the whole tile a link, because a stat you cannot click is a stat
 * you have to go find the page for.
 */
export function Stat({
  label,
  value,
  sub,
  tone = 'plain',
  href,
}: {
  label: string;
  value: React.ReactNode;
  sub?: React.ReactNode;
  tone?: 'plain' | 'ok' | 'warn' | 'bad';
  href?: string;
}) {
  const colour = {
    plain: 'text-ink',
    ok: 'text-ok',
    warn: 'text-warn',
    bad: 'text-bad',
  }[tone];

  const body = (
    <>
      <div className="text-micro uppercase tracking-wider text-ink-3">{label}</div>
      <div className={`mt-1.5 text-2xl font-semibold tracking-tight tnum ${colour}`}>
        {value}
      </div>
      {sub && <div className="mt-0.5 text-micro text-ink-3 tnum">{sub}</div>}
    </>
  );

  const base = 'rounded-card border border-line-soft bg-surface-1 px-3 py-3 sm:px-4';
  return href ? (
    <Link href={href} className={`${base} block transition hover:border-line`}>
      {body}
    </Link>
  ) : (
    <div className={base}>{body}</div>
  );
}

// ── small parts ─────────────────────────────────────────────────────────────

export type Tone = 'plain' | 'ok' | 'warn' | 'bad' | 'info' | 'accent';

export function Chip({ tone = 'plain', children }: { tone?: Tone; children: React.ReactNode }) {
  const styles: Record<Tone, string> = {
    plain: 'border-line text-ink-2',
    ok: 'border-ok/30 bg-ok-dim text-ok',
    warn: 'border-warn/30 bg-warn-dim text-warn',
    bad: 'border-bad/30 bg-bad-dim text-bad',
    info: 'border-info/30 bg-info-dim text-info',
    accent: 'border-accent/40 bg-accent-dim text-accent',
  };
  return (
    <span
      className={`inline-flex items-center rounded-md border px-1.5 py-px font-mono text-micro ${styles[tone]}`}
    >
      {children}
    </span>
  );
}

export function Button({
  href,
  variant = 'quiet',
  children,
}: {
  href: string;
  variant?: 'quiet' | 'primary';
  children: React.ReactNode;
}) {
  const styles = {
    quiet: 'border-line bg-surface-2 text-ink hover:bg-surface-3',
    // ONE primary per screen. More than one and neither reads as the action.
    primary: 'border-accent bg-accent font-medium text-accent-ink hover:brightness-110',
  }[variant];
  return (
    <Link
      href={href}
      className={`inline-flex items-center rounded-lg border px-2.5 py-1.5 text-data transition ${styles}`}
    >
      {children}
    </Link>
  );
}

/** A label and a value on one line. Values are mono because they are data. */
export function KV({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-line-soft py-1.5 text-data last:border-b-0">
      <span className="text-ink-3">{k}</span>
      <span className="text-right font-mono text-micro text-ink-2 tnum">{v}</span>
    </div>
  );
}

// ── tables ──────────────────────────────────────────────────────────────────

/**
 * Tables are wrapped rather than styled inline so column alignment and hairline
 * colour are decided once. Horizontal scroll is on the wrapper, so a wide table
 * on a phone scrolls its own row rather than the page.
 */
export function Table({ head, children }: { head: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-max text-data">
        <thead>
          <tr className="border-b border-line-soft">{head}</tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

export function Th({ children, num }: { children?: React.ReactNode; num?: boolean }) {
  return (
    <th
      className={`px-3 py-2 text-micro font-medium uppercase tracking-wider text-ink-3 sm:px-4 ${
        num ? 'text-right' : 'text-left'
      }`}
    >
      {children}
    </th>
  );
}

export function Td({
  children,
  num,
  mono,
  dim,
}: {
  children?: React.ReactNode;
  num?: boolean;
  mono?: boolean;
  dim?: boolean;
}) {
  return (
    <td
      className={`px-3 py-2.5 sm:px-4 ${num ? 'text-right tnum' : ''} ${
        mono || num ? 'font-mono text-micro' : ''
      } ${dim ? 'text-ink-3' : ''}`}
    >
      {children}
    </td>
  );
}

export function Tr({ children }: { children: React.ReactNode }) {
  return <tr className="border-b border-line-soft last:border-b-0 hover:bg-surface-2">{children}</tr>;
}

// ── list and inspector ──────────────────────────────────────────────────────

/**
 * THE LIST-PLUS-INSPECTOR PRIMITIVES.
 *
 * The card grid these replace spent roughly 300px of vertical space per distro
 * on a preview, so five distros was a scroll and the fields that actually
 * differ between them (state, version, price) were three lines apart. A row is
 * one line, the column is scannable, and the preview moves to the inspector
 * where exactly one renders at a size worth looking at.
 *
 * SELECTION LIVES IN THE URL, not in React state. These are server components
 * with no JavaScript, selection survives the `router.refresh()` that follows
 * every delete and listing toggle, and a link to one distro is a link someone
 * can paste. That is the whole reason [Row] is a `Link` rather than a button.
 */

export function Toolbar({ children }: { children: React.ReactNode }) {
  return <div className="mb-3 flex flex-wrap gap-1">{children}</div>;
}

/** A filter as a link, so filtering costs no JavaScript and is bookmarkable. */
export function Filter({
  href,
  active,
  children,
}: {
  href: string;
  active: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className={`rounded-md px-2 py-1 font-mono text-micro transition ${
        active ? 'bg-surface-3 text-ink' : 'text-ink-3 hover:text-ink-2'
      }`}
    >
      {children}
    </Link>
  );
}

export function Rows({ children }: { children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-card border border-line-soft bg-surface-1">
      {children}
    </div>
  );
}

/**
 * One row. [chip] carries state, [right] carries the one number or word that
 * differs down the column, and everything else belongs in the inspector.
 */
export function Row({
  href,
  selected,
  thumb,
  title,
  subtitle,
  chip,
  right,
  tone,
}: {
  href: string;
  selected?: boolean;
  thumb?: React.ReactNode;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  chip?: React.ReactNode;
  right?: React.ReactNode;
  /**
   * A severity edge down the left of the row.
   *
   * For lists whose job is spotting a problem rather than picking an item:
   * Commerce sorts worst-first and the edge is what makes that sort legible at
   * a glance. A list with no severity leaves this off, and most do.
   */
  tone?: 'bad' | 'warn';
}) {
  const edge =
    tone === 'bad'
      ? 'border-l-2 border-l-bad'
      : tone === 'warn'
        ? 'border-l-2 border-l-warn'
        : '';
  return (
    <Link
      href={href}
      className={`flex items-center gap-2.5 border-b border-line-soft px-2.5 py-2 transition last:border-b-0 sm:px-3 ${edge} ${
        selected ? 'bg-surface-2' : 'hover:bg-surface-2/60'
      }`}
    >
      {thumb}
      <span className="min-w-0 flex-1">
        <span className={`block truncate text-data ${selected ? 'text-ink' : 'text-ink-2'}`}>
          {title}
        </span>
        {subtitle && (
          <span className="block truncate font-mono text-micro text-ink-3">{subtitle}</span>
        )}
      </span>
      {chip}
      {right && (
        <span className="shrink-0 text-right font-mono text-micro text-ink-3 tnum">{right}</span>
      )}
    </Link>
  );
}

/**
 * The row thumbnail: a two-stop gradient with an accent mark.
 *
 * NOT a scaled `ThemePreview`. At 26px wide the dock, bar and watermark are
 * noise, and rendering one per row would also mean fetching every published
 * theme.json to draw something illegible. A distro is identified at this size
 * by its gradient and its accent, which is all this draws. The real preview
 * renders once, in the inspector.
 */
export function Swatch({
  top,
  bottom,
  accent,
}: {
  top: string;
  bottom: string;
  accent: string;
}) {
  return (
    <span
      className="block h-[42px] w-[26px] shrink-0 overflow-hidden rounded border border-line-soft"
      style={{ background: `linear-gradient(180deg, ${top}, ${bottom})` }}
    >
      <span
        className="mt-1.5 ml-1.5 block size-2 rounded-[2px]"
        style={{ background: accent }}
      />
    </span>
  );
}

/**
 * The detail panel. Sticky beside the list on a wide screen, and a block below
 * it on a phone, where `id="detail"` is the anchor rows link to so a tap lands
 * on the panel rather than leaving it offscreen.
 */
export function Inspector({ children }: { children: React.ReactNode }) {
  return (
    <aside
      id="detail"
      className="w-full shrink-0 rounded-card border border-line-soft bg-surface-1 p-3 lg:sticky lg:top-6 lg:w-60"
    >
      {children}
    </aside>
  );
}

// ── dashboard register ──────────────────────────────────────────────────────

/**
 * THE SECOND REGISTER, AND WHY THERE ARE TWO.
 *
 * [Stat] and [Card] are the TOOL register: bordered, tight, built to sit above
 * a table you are working in. They are right on the screens where you are
 * hunting for one item among many.
 *
 * These are the DASHBOARD register: borderless surfaces, larger numbers, room
 * for a bar. They are right on the three screens you open to find out how
 * things are rather than to change something: the landing, an app's overview,
 * and analytics.
 *
 * Two registers is a deliberate cost. The alternative was one compromise that
 * made the dashboards look like spreadsheets or the tools look like a pitch,
 * and having tried the first, it read as a tool that had forgotten it was also
 * the first thing you see every morning.
 *
 * NOTHING HERE FABRICATES. A bar with no data renders as an empty track and a
 * dash, never as a plausible shape. That rule is why `analytics.ts` returns a
 * discriminated result instead of zeroes, and these components have to honour
 * it or the rule stops meaning anything.
 */

export function Metric({
  label,
  value,
  sub,
  tone = 'plain',
  href,
}: {
  label: string;
  value: React.ReactNode;
  sub?: React.ReactNode;
  tone?: 'plain' | 'ok' | 'warn' | 'bad';
  href?: string;
}) {
  const colour = {
    plain: 'text-ink',
    ok: 'text-ok',
    warn: 'text-warn',
    bad: 'text-bad',
  }[tone];
  const subColour = {
    plain: 'text-ink-3',
    ok: 'text-ok',
    warn: 'text-warn',
    bad: 'text-bad',
  }[tone];

  const body = (
    <>
      <div className="text-micro uppercase tracking-wider text-ink-3">{label}</div>
      <div className={`mt-1 text-2xl leading-tight font-semibold tracking-tight tnum ${colour}`}>
        {value}
      </div>
      {sub && <div className={`mt-0.5 font-mono text-micro tnum ${subColour}`}>{sub}</div>}
    </>
  );

  const base = 'rounded-card bg-surface-1 px-3 py-3 sm:px-4';
  return href ? (
    <Link href={href} className={`${base} block transition hover:bg-surface-2`}>
      {body}
    </Link>
  ) : (
    <div className={base}>{body}</div>
  );
}

/** A borderless card. Same slots as [Card], dashboard weight. */
export function Panel({
  title,
  right,
  flush,
  children,
}: {
  title?: string;
  right?: React.ReactNode;
  flush?: boolean;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-card bg-surface-1">
      {(title || right) && (
        <header className="flex items-center gap-2 px-3 pt-3 sm:px-4">
          {title && <h2 className="text-data font-medium">{title}</h2>}
          {right && <div className="ml-auto flex items-center gap-2">{right}</div>}
        </header>
      )}
      <div className={flush ? 'mt-2' : 'p-3 sm:p-4'}>{children}</div>
    </section>
  );
}

export type BarTone = 'accent' | 'info' | 'ok' | 'warn' | 'bad' | 'plain';

const BAR_FILL: Record<BarTone, string> = {
  accent: 'bg-accent',
  info: 'bg-info',
  ok: 'bg-ok',
  warn: 'bg-warn',
  bad: 'bg-bad',
  plain: 'bg-ink-3',
};

/**
 * One labelled bar. [pct] is 0 to 100 and is clamped, because a value larger
 * than its own maximum is a bug in the caller and a bar wider than its track is
 * a bug you cannot see.
 */
export function BarRow({
  label,
  value,
  pct,
  tone = 'accent',
  dim,
}: {
  label: React.ReactNode;
  value: React.ReactNode;
  pct: number;
  tone?: BarTone;
  dim?: boolean;
}) {
  const w = Math.max(0, Math.min(100, Math.round(pct)));
  return (
    <div className={`flex items-center gap-2.5 ${dim ? 'opacity-70' : ''}`}>
      <span className="w-24 shrink-0 truncate font-mono text-micro text-ink-2 sm:w-32">
        {label}
      </span>
      <span className="h-3.5 min-w-0 flex-1 overflow-hidden rounded bg-surface-2">
        <span className={`block h-full ${BAR_FILL[tone]}`} style={{ width: `${w}%` }} />
      </span>
      <span className="w-14 shrink-0 text-right font-mono text-micro text-ink-3 tnum">
        {value}
      </span>
    </div>
  );
}

/**
 * A composition bar: one track, several segments, a legend under it.
 *
 * Segments with a zero value are dropped rather than rendered at zero width,
 * because a legend entry with no visible segment reads as a rendering fault.
 */
export function SplitBar({
  segments,
}: {
  segments: { label: string; value: number; tone: BarTone }[];
}) {
  const shown = segments.filter((s) => s.value > 0);
  const total = shown.reduce((n, s) => n + s.value, 0);
  if (total === 0) {
    return <div className="h-1.5 rounded-full bg-surface-2" />;
  }
  return (
    <>
      <div className="flex h-1.5 overflow-hidden rounded-full bg-surface-2">
        {shown.map((s) => (
          <span
            key={s.label}
            className={BAR_FILL[s.tone]}
            style={{ width: `${(s.value / total) * 100}%` }}
          />
        ))}
      </div>
      <div className="mt-1.5 flex flex-wrap gap-x-3 gap-y-1">
        {shown.map((s) => (
          <span key={s.label} className="flex items-center gap-1.5 text-micro text-ink-3">
            <span className={`size-1.5 rounded-full ${BAR_FILL[s.tone]}`} />
            {s.label}
          </span>
        ))}
      </div>
    </>
  );
}

// ── states ──────────────────────────────────────────────────────────────────

/**
 * Errors say what happened and what to do. No apology, no "Error:" prefix, and
 * never a raw exception string on its own.
 */
export function Banner({ tone, children }: { tone: 'bad' | 'warn'; children: React.ReactNode }) {
  const styles = {
    bad: 'border-bad/40 bg-bad-dim text-bad',
    warn: 'border-warn/40 bg-warn-dim text-warn',
  }[tone];
  return (
    <p className={`mb-3 rounded-card border px-3 py-2 text-data leading-relaxed ${styles}`}>
      {children}
    </p>
  );
}

/** An empty screen is an invitation to act, so it always carries the action. */
export function Empty({ children, action }: { children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="rounded-card border border-dashed border-line px-4 py-8 text-center">
      <p className="text-data text-ink-3">{children}</p>
      {action && <div className="mt-3 flex justify-center">{action}</div>}
    </div>
  );
}

// ── formatting ──────────────────────────────────────────────────────────────

/**
 * `#RRGGBB` or `#AARRGGBB` to a CSS colour, honouring the alpha byte.
 *
 * A SECOND COPY of `cssColor` from `theme-builder/console.tsx`, deliberately.
 * That file is `'use client'`, so importing its helper into a server component
 * would drag the builder's module across the boundary to normalise a string.
 * This one is server-safe and stays here with the other formatters; the
 * builders keep theirs, and neither has to move for the other.
 */
export function hexColor(hex: string | null | undefined, fallback = 'transparent'): string {
  if (!hex) return fallback;
  const s = hex.trim().replace(/^#/, '');
  if (s.length === 6) return `#${s}`;
  if (s.length === 8) {
    const a = parseInt(s.slice(0, 2), 16) / 255;
    const r = parseInt(s.slice(2, 4), 16);
    const g = parseInt(s.slice(4, 6), 16);
    const b = parseInt(s.slice(6, 8), 16);
    if ([a, r, g, b].some(Number.isNaN)) return fallback;
    return `rgba(${r},${g},${b},${a.toFixed(3)})`;
  }
  return fallback;
}

/** Bytes at one decimal, switching unit at 1024. Never "0.0 MB". */
export function bytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

/**
 * `generatedAt` is unix SECONDS, not milliseconds. Multiplying is not optional:
 * seconds passed to Date() render as 1970 and look like a corrupt index.
 */
export function when(unixSeconds: number): string {
  if (!unixSeconds) return 'never';
  const d = new Date(unixSeconds * 1000);
  const mins = Math.round((Date.now() - d.getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  if (mins < 60 * 24) return `${Math.round(mins / 60)}h ago`;
  return d.toISOString().slice(0, 10);
}
