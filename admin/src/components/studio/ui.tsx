import Link from 'next/link';

import {
  appStoreConnectUrl,
  appStoreUrl,
  playConsoleUrl,
  playListingUrl,
  type AppMeta,
} from '@/lib/core/registry';

/**
 * THE STUDIO REGISTER, a third one, and the reason is worth stating.
 *
 * `ui.tsx` holds two: the TOOL register (bordered, tight, above a table) and
 * the DASHBOARD register (borderless, larger numbers). Both are dark-only,
 * because the console was dark-only when they were written.
 *
 * This screen is neither. It is the first thing opened in the morning, it is
 * the one console screen a person might show someone else, and it now shares an
 * origin with a public site that has a light mode. So it is built on the
 * `site-` tokens, which already carry a light and a dark value for every
 * colour, and it gets its own primitives rather than bending the other two.
 *
 * NOTHING HERE FABRICATES, and that rule is inherited, not restated for fun.
 * [Slab] renders an unmeasured figure in the dim colour and says why, and
 * [Cond] shows a blocker rather than hiding it. A dashboard that looks calm
 * while something is broken is a dashboard that trained you to ignore it.
 *
 * No `'use client'`. These hold no state.
 */

// ── the slab ────────────────────────────────────────────────────────────────

/**
 * The dark command surface the page opens with.
 *
 * It stays dark in BOTH modes, deliberately. Its job is to be the one object on
 * the page that is unmistakably the summary, and a surface that inverts with
 * the theme cannot do that. The gradients are the launcher's own aubergine and
 * orange, so the panel and the product rhyme.
 */
export function Slab({
  eyebrow,
  title,
  sub,
  children,
}: {
  eyebrow: string;
  title: string;
  sub?: string;
  children: React.ReactNode;
}) {
  return (
    <section
      className="relative overflow-hidden rounded-[24px] shadow-[0_20px_50px_rgba(23,16,31,0.24)]"
      style={{
        background:
          'radial-gradient(680px 340px at 8% -20%, rgba(141,101,255,0.42), transparent 62%), radial-gradient(520px 320px at 96% 120%, rgba(233,84,32,0.30), transparent 60%), linear-gradient(150deg, #221a33 0%, #16101f 52%, #100b17 100%)',
      }}
    >
      {/* A faint grid, masked so it fades out before it becomes wallpaper. */}
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-50"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.045) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.045) 1px, transparent 1px)',
          backgroundSize: '46px 46px',
          maskImage: 'radial-gradient(760px 340px at 20% 0%, #000 0%, transparent 75%)',
          WebkitMaskImage: 'radial-gradient(760px 340px at 20% 0%, #000 0%, transparent 75%)',
        }}
      />
      <div className="relative z-10 px-6 pb-6 pt-7 sm:px-7">
        <span className="inline-flex items-center gap-2 text-[10.5px] font-bold uppercase tracking-[0.1em] text-[#c3b2ff]">
          <span className="size-1.5 rounded-full bg-[#5ee0a8] shadow-[0_0_0_3px_rgba(94,224,168,0.18)]" />
          {eyebrow}
        </span>
        <h1 className="mt-3 font-site-display text-[26px] font-extrabold tracking-[-0.03em] text-[#f4f0fb]">
          {title}
        </h1>
        {sub && <p className="mt-1.5 max-w-[52ch] text-[13px] leading-relaxed text-[#a99cc4]">{sub}</p>}
        {children}
      </div>
    </section>
  );
}

/** The four headline figures, hairline-separated inside the slab. */
export function SlabGrid({ children }: { children: React.ReactNode }) {
  return (
    <div className="mt-6 grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-white/10 bg-white/[0.09] lg:grid-cols-4">
      {children}
    </div>
  );
}

export function SlabCell({
  label,
  value,
  note,
  of,
  measured = true,
}: {
  label: string;
  value: React.ReactNode;
  note?: string;
  /** A denominator, rendered smaller. "3 of 7" reads better than a bare 3. */
  of?: React.ReactNode;
  /**
   * False means this figure could not be read. It renders dim and small, and
   * the caller passes the reason as [note]. It is NEVER a zero: zero is a
   * measurement, and this is the absence of one.
   */
  measured?: boolean;
}) {
  return (
    <div className="bg-[rgba(18,12,26,0.72)] px-4 py-4">
      <div className="text-[10.5px] font-bold uppercase tracking-[0.08em] text-[#9a8cb8]">{label}</div>
      <div
        className={
          measured
            ? 'mt-2 font-site-display text-[34px] font-extrabold leading-none tracking-[-0.045em] text-[#f4f0fb]'
            : 'mt-2 font-site-display text-[19px] font-semibold leading-none tracking-[-0.02em] text-[#8d80ab]'
        }
      >
        {value}
        {of && <span className="text-[17px] font-semibold tracking-[-0.02em] text-[#7e719c]"> {of}</span>}
      </div>
      {note && <div className="mt-1.5 text-[11.5px] font-medium text-[#8d80ab]">{note}</div>}
    </div>
  );
}

/** One condition in the ribbon. Blockers first is the caller's job. */
export function Cond({ tone, children }: { tone: 'ok' | 'warn' | 'bad'; children: React.ReactNode }) {
  const styles = {
    ok: 'border-white/12 bg-white/5 text-[#c8bce0]',
    warn: 'border-[rgba(255,178,122,0.26)] bg-[rgba(255,178,122,0.09)] text-[#ffc79a]',
    bad: 'border-[rgba(255,139,131,0.28)] bg-[rgba(255,139,131,0.10)] text-[#ffb0a8]',
  }[tone];
  const dot = { ok: 'bg-[#5ee0a8]', warn: 'bg-[#ffb27a]', bad: 'bg-[#ff8b83]' }[tone];
  return (
    <span className={`inline-flex items-center gap-2 rounded-full border py-1.5 pl-2.5 pr-3 text-[11.5px] font-semibold ${styles}`}>
      <span className={`size-1.5 rounded-full ${dot}`} />
      {children}
    </span>
  );
}

export function Ribbon({ children }: { children: React.ReactNode }) {
  return <div className="mt-5 flex flex-wrap gap-2">{children}</div>;
}

// ── panels ──────────────────────────────────────────────────────────────────

export function SoftPanel({
  title,
  note,
  right,
  flush,
  children,
}: {
  title: string;
  note?: string;
  right?: React.ReactNode;
  /** True when the body is a list of rows that own their own padding. */
  flush?: boolean;
  children: React.ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-[18px] border border-site-line bg-site-card shadow-site-soft">
      <header className="flex items-center gap-2.5 px-[18px] py-3.5">
        <h2 className="font-site-display text-[15px] font-bold tracking-[-0.015em] text-site-ink">{title}</h2>
        {note && <span className="text-[11.5px] text-site-ink-3">{note}</span>}
        {right && <div className="ml-auto flex items-center gap-2">{right}</div>}
      </header>
      <div className={flush ? '' : 'px-[18px] pb-[18px]'}>{children}</div>
    </section>
  );
}

export function SoftButton({
  children,
  href,
  variant = 'plain',
  external,
}: {
  children: React.ReactNode;
  href: string;
  variant?: 'plain' | 'primary';
  external?: boolean;
}) {
  const cls =
    variant === 'primary'
      ? 'border-site-accent bg-site-accent text-white hover:bg-site-accent-deep'
      : 'border-site-line bg-site-card text-site-ink hover:border-site-ink-3/45';
  const inner = `inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold transition ${cls}`;
  return external ? (
    <a className={inner} href={href} target="_blank" rel="noreferrer">
      {children}
    </a>
  ) : (
    <Link className={inner} href={href}>
      {children}
    </Link>
  );
}

export function KVRow({ k, v, tone }: { k: string; v: React.ReactNode; tone?: 'bad' | 'warn' | 'ok' }) {
  const colour = tone
    ? { bad: 'text-site-plan font-bold', warn: 'text-site-plan font-bold', ok: 'text-site-ok font-bold' }[tone]
    : 'text-site-ink';
  return (
    <div className="flex justify-between gap-3 border-b border-site-line py-2.5 text-[12.5px] last:border-b-0">
      <span className="font-medium text-site-ink-3">{k}</span>
      <span className={colour}>{v}</span>
    </div>
  );
}

// ── app rows ────────────────────────────────────────────────────────────────

const PLAY_GLYPH = (
  <svg width="13" height="14" viewBox="0 0 20 22" fill="currentColor" aria-hidden>
    <path d="M1.5 1.9c0-1 1.1-1.7 2-1.1l15 8.5c.9.5.9 1.9 0 2.4l-15 8.5c-.9.6-2-.1-2-1.1V1.9z" />
  </svg>
);

const APPLE_GLYPH = (
  <svg width="13" height="14" viewBox="0 0 19 22" fill="currentColor" aria-hidden>
    <path d="M15.6 11.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.9C5.7 6 4.1 7 3.2 8.5c-1.9 3.2-.5 8 1.3 10.6.9 1.3 1.9 2.7 3.3 2.6 1.3-.1 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.2-2.6.7-1 1-2 1.4-3-3-1.1-3.6-3.4-3.6-4.5zM13.2 3.9c.7-.9 1.2-2.1 1.1-3.3-1 0-2.3.7-3 1.5-.7.8-1.3 2-1.1 3.2 1.1.1 2.3-.6 3-1.4z" />
  </svg>
);

const CONSOLE_GLYPH = (
  <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden>
    <path d="M3 12.5V8M6.5 12.5V4M10 12.5V9.5M13.5 12.5V6" />
  </svg>
);

const CONNECT_GLYPH = (
  <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d="M2.5 5.5A1.5 1.5 0 014 4h8a1.5 1.5 0 011.5 1.5v6A1.5 1.5 0 0112 13H4a1.5 1.5 0 01-1.5-1.5v-6z" />
    <path d="M5.5 7.5h5M5.5 10h3" />
  </svg>
);

/**
 * One link, or the space where one would be.
 *
 * A missing link renders DIMMED rather than omitted, because the gap is the
 * information: four slots in a fixed order means "no App Store record" is
 * readable at a glance across the whole list. Private console links are sunk
 * and dashed so they never read as somewhere you would send a user.
 */
function StoreLink({
  href,
  title,
  glyph,
  privateLink,
}: {
  href: string | null;
  title: string;
  glyph: React.ReactNode;
  privateLink?: boolean;
}) {
  const base = 'grid size-[29px] place-items-center rounded-lg border text-site-ink-3 transition';
  const skin = privateLink
    ? 'border-dashed border-site-line bg-site-sunk'
    : 'border-site-line bg-site-card';
  if (!href) {
    return (
      <span className={`${base} ${skin} opacity-30`} title={title} aria-hidden>
        {glyph}
      </span>
    );
  }
  return (
    <a
      className={`${base} ${skin} hover:border-site-ink-3/45 hover:text-site-ink`}
      href={href}
      target="_blank"
      rel="noreferrer"
      title={title}
    >
      {glyph}
    </a>
  );
}

export function StoreLinks({ app }: { app: AppMeta }) {
  return (
    <span className="hidden gap-1.5 lg:flex">
      <StoreLink href={playListingUrl(app)} title="Google Play listing" glyph={PLAY_GLYPH} />
      <StoreLink href={appStoreUrl(app)} title="App Store listing" glyph={APPLE_GLYPH} />
      <StoreLink href={playConsoleUrl(app)} title="Play Console dashboard" glyph={CONSOLE_GLYPH} privateLink />
      <StoreLink href={appStoreConnectUrl(app)} title="App Store Connect" glyph={CONNECT_GLYPH} privateLink />
    </span>
  );
}

export function StatePill({ state }: { state: AppMeta['state'] }) {
  const skin = {
    live: 'bg-site-ok-soft text-site-ok',
    build: 'bg-site-info-soft text-site-info',
    planned: 'bg-site-sunk text-site-ink-3',
    external: 'bg-site-accent-soft text-site-accent-deep',
  }[state];
  return (
    <span className={`rounded-full px-2 py-[2.5px] text-[10px] font-bold uppercase tracking-[0.05em] ${skin}`}>
      {state}
    </span>
  );
}

/**
 * A registry row, with the app's own tint doing the work an icon would.
 *
 * The tint is a registry field that carries NO meaning (the comment on
 * `AppMeta.tint` says so), which is exactly why it is safe to use for
 * recognition: it identifies without claiming a status. Status is the pill and
 * the line beside it.
 */
export function AppRow({
  app,
  status,
  action,
}: {
  app: AppMeta;
  /** One short fact, already coloured by the caller. Absent renders nothing. */
  status?: React.ReactNode;
  action?: React.ReactNode;
}) {
  return (
    <div
      className="relative flex items-center gap-3.5 border-t border-site-line px-[18px] py-3.5"
      style={{ ['--tint' as string]: app.tint }}
    >
      <span aria-hidden className="absolute inset-y-0 left-0 w-[3px] opacity-90" style={{ background: app.tint }} />
      <span
        aria-hidden
        className="grid size-9 shrink-0 place-items-center rounded-[11px] font-site-display text-[15px] font-extrabold text-white"
        style={{
          background: `linear-gradient(140deg, color-mix(in srgb, ${app.tint} 78%, #fff 22%), ${app.tint})`,
          boxShadow: `0 4px 12px color-mix(in srgb, ${app.tint} 34%, transparent)`,
        }}
      >
        {app.mark}
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2 text-[13.5px] font-semibold text-site-ink">
          <span className="truncate">{app.name}</span>
          <StatePill state={app.state} />
        </span>
        <span className="block truncate font-mono text-[11px] text-site-ink-3">
          {app.pkg ?? 'no package yet'}
        </span>
      </span>
      {status && <span className="hidden text-[11.5px] text-site-ink-3 sm:block">{status}</span>}
      <StoreLinks app={app} />
      {action}
    </div>
  );
}


// ── the per-app slab ────────────────────────────────────────────────────────

/**
 * The app header, tinted by the registry.
 *
 * TWO HEIGHTS, and the choice is about what the screen is for. `metrics` makes
 * it the tall version, which the Overview earns because those figures are the
 * point of the screen. Every working screen (Distros, CDN objects, Commerce)
 * passes none and gets one line: mark, breadcrumb, title, actions. Same tint,
 * same grid, a third of the height, and the vertical space goes to the rows
 * that the screen actually exists to show.
 *
 * It stays dark in both modes, like the studio slab, for the same reason: its
 * job is to be the one object on the page that is unmistakably the header, and
 * a surface that inverts with the theme cannot do that.
 */
export function AppSlab({
  tint,
  mark,
  crumb,
  title,
  meta,
  actions,
  metrics,
  children,
}: {
  tint: string;
  mark: string;
  /** The parent label, e.g. the app name. The title is the current screen. */
  crumb: string;
  title: string;
  /** One short line under the title. Absent on working screens. */
  meta?: React.ReactNode;
  actions?: React.ReactNode;
  /** Pass SlabCells to get the tall variant. */
  metrics?: React.ReactNode;
  /** Anything below the metrics, e.g. a Ribbon. */
  children?: React.ReactNode;
}) {
  return (
    <section
      className="relative overflow-hidden rounded-[20px] shadow-[0_14px_34px_rgba(23,16,31,0.2)]"
      style={{
        background: `radial-gradient(520px 220px at 3% -40%, color-mix(in srgb, ${tint} 52%, transparent), transparent 64%), radial-gradient(380px 200px at 99% 150%, rgba(141,101,255,0.4), transparent 62%), linear-gradient(140deg, #241a26, #171020 58%, #100b17)`,
      }}
    >
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-45"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
          maskImage: 'radial-gradient(560px 220px at 10% 0%, #000, transparent 78%)',
          WebkitMaskImage: 'radial-gradient(560px 220px at 10% 0%, #000, transparent 78%)',
        }}
      />
      <div className={`relative z-10 px-5 sm:px-6 ${metrics ? 'pb-6 pt-5' : 'py-4'}`}>
        <div className="flex flex-wrap items-center gap-3.5">
          <span
            aria-hidden
            className="grid size-9 shrink-0 place-items-center rounded-[11px] font-site-display text-[14px] font-extrabold text-white"
            style={{
              background: `linear-gradient(140deg, color-mix(in srgb, ${tint} 76%, #fff 24%), ${tint})`,
              boxShadow: `0 5px 14px color-mix(in srgb, ${tint} 38%, transparent)`,
            }}
          >
            {mark}
          </span>
          <div className="min-w-0">
            <div className="font-mono text-[11px] text-white/50">
              {crumb} <span className="opacity-40">/</span>{' '}
              <span className="text-white/80">{title}</span>
            </div>
            <h1 className="mt-0.5 font-site-display text-[21px] font-extrabold text-[#f6f2fd]">
              {title}
            </h1>
            {meta && <div className="mt-1 text-[12px] text-white/55">{meta}</div>}
          </div>
          <div className="flex-1" />
          {actions}
        </div>
        {metrics && (
          <div className="mt-5 grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-white/10 bg-white/[0.09] lg:grid-cols-4">
            {metrics}
          </div>
        )}
        {children}
      </div>
    </section>
  );
}

/** An action styled for the slab's dark surface. */
export function SlabButton({
  children,
  href,
  primary,
  external,
}: {
  children: React.ReactNode;
  href: string;
  primary?: boolean;
  external?: boolean;
}) {
  const cls = `inline-flex items-center gap-1.5 rounded-[10px] border px-3.5 py-2 text-[13px] font-semibold transition ${
    primary
      ? 'border-white bg-white text-[#1a1226] hover:bg-white/90'
      : 'border-white/20 bg-white/10 text-[#f4f0fb] hover:bg-white/15'
  }`;
  return external ? (
    <a className={cls} href={href} target="_blank" rel="noreferrer">
      {children}
    </a>
  ) : (
    <Link className={cls} href={href}>
      {children}
    </Link>
  );
}

// ── tasks ───────────────────────────────────────────────────────────────────

/**
 * One task in the "what needs doing" list.
 *
 * A LINK when a screen fixes it, a plain row when the fact is just a fact.
 * "Bucket readable, index signed" has nowhere to go, and a row that looks
 * clickable and is not is worse than one that plainly does not.
 */
export function TaskRow({
  level,
  title,
  detail,
  href,
  where,
}: {
  level: 'bad' | 'warn' | 'ok';
  title: string;
  detail: React.ReactNode;
  href?: string;
  where?: string;
}) {
  const edge = { bad: 'bg-site-plan', warn: 'bg-site-plan', ok: 'bg-site-ok' }[level];
  const chip = {
    bad: 'bg-site-plan-soft text-site-plan',
    warn: 'bg-site-plan-soft text-site-plan',
    ok: 'bg-site-ok-soft text-site-ok',
  }[level];
  const heading = {
    bad: 'text-site-plan',
    warn: 'text-site-ink',
    ok: 'text-site-ok',
  }[level];

  const glyph =
    level === 'ok' ? (
      <path d="M3 8.5l3.2 3L13 5" />
    ) : level === 'bad' ? (
      <>
        <path d="M8 2.5l6 11H2l6-11z" />
        <path d="M8 6.6v3M8 11.7v.01" />
      </>
    ) : (
      <>
        <circle cx="8" cy="8" r="6" />
        <path d="M8 5v3.4M8 10.9v.01" />
      </>
    );

  const body = (
    <>
      <span aria-hidden className={`absolute inset-y-0 left-0 w-[3px] ${edge} ${level === 'ok' ? 'opacity-55' : ''}`} />
      <span className={`grid size-[26px] shrink-0 place-items-center rounded-lg ${chip}`}>
        <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.85" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          {glyph}
        </svg>
      </span>
      <span className="min-w-0 flex-1">
        <span className={`block text-[13.5px] font-semibold ${heading}`}>{title}</span>
        <span className="mt-0.5 block text-[11.5px] leading-relaxed text-site-ink-3">{detail}</span>
      </span>
      {where && (
        <span className="hidden shrink-0 items-center gap-1.5 text-[11.5px] font-semibold text-site-ink-3 sm:inline-flex">
          {where}
          <svg width="12" height="12" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
            <path d="M3 7h8M8 3.5L11.5 7 8 10.5" />
          </svg>
        </span>
      )}
    </>
  );

  const shell = 'relative flex items-center gap-3.5 border-t border-site-line px-[18px] py-3';
  return href ? (
    <Link href={href} className={`${shell} transition hover:bg-site-sunk`}>
      {body}
    </Link>
  ) : (
    <div className={shell}>{body}</div>
  );
}

// ── measures ────────────────────────────────────────────────────────────────

/** A composition bar. Zero-value segments are dropped, not drawn as slivers. */
export function Split({ segments }: { segments: { label: string; value: number; colour: string }[] }) {
  const total = segments.reduce((n, s) => n + s.value, 0);
  const shown = segments.filter((s) => s.value > 0);
  return (
    <div>
      <div className="flex h-2.5 overflow-hidden rounded-full bg-site-sunk">
        {shown.map((s) => (
          <span
            key={s.label}
            title={s.label}
            style={{ width: `${total ? (s.value / total) * 100 : 0}%`, background: s.colour }}
          />
        ))}
      </div>
      <div className="mt-2.5 flex flex-wrap gap-x-3.5 gap-y-1.5">
        {segments.map((s) => (
          <span key={s.label} className="inline-flex items-center gap-1.5 text-[11px] text-site-ink-3">
            <span className="size-[7px] rounded-full" style={{ background: s.colour }} />
            {s.label}
          </span>
        ))}
      </div>
    </div>
  );
}

/** One horizontal bar. `pct` is relative to the largest row, not to a total. */
export function Bar({
  label,
  value,
  pct,
  colour,
}: {
  label: string;
  value: string;
  pct: number;
  colour: string;
}) {
  return (
    <div className="flex items-center gap-3 py-[3px]">
      <span className="w-[110px] shrink-0 truncate font-mono text-[11.5px] text-site-ink-2">{label}</span>
      <span className="h-[15px] min-w-0 flex-1 overflow-hidden rounded-md bg-site-sunk">
        <span
          className="block h-full rounded-md"
          style={{ width: `${Math.max(2, Math.min(100, pct))}%`, background: colour }}
        />
      </span>
      <span className="w-[62px] shrink-0 text-right font-mono text-[11.5px] text-site-ink-3">{value}</span>
    </div>
  );
}

/** Pack-type colours, shared by Split and Bar so a legend always matches. */
export const PACK_COLOURS: Record<string, string> = {
  theme: '#e95420',
  brand: '#4c8dff',
  hero: '#3fb950',
  icon: '#d29922',
};
