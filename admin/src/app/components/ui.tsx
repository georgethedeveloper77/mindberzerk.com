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
