import Image from 'next/image';
import type { ReactNode } from 'react';
import { ConnectDemo } from './connect-demo';
import { COPY, SCREEN_RATIO, SCREENS, STORE_COPY, withMinAndroid, type Screen, type StoreLink } from './copy';
import { Icon } from './icons';
import { LiveStats } from './live-stats';
import type { LiveSnapshot } from './live-types';
import { StoreBadge } from './store-badges';
import { WorldMap } from './world-map';
import styles from './landing.module.css';

/**
 * The landing's sections, top to bottom. Server components throughout; the
 * connect demo and the visitor's map routes are the only client islands, and
 * the FAQ uses native <details> so it works before, and without, hydration.
 */

const WRAP = 'mx-auto w-full max-w-[1200px] px-4 sm:px-6';
const BAND = 'pt-20 sm:pt-[110px]';
const H2 = 'text-balance text-[clamp(30px,4vw,44px)] font-bold leading-[1.08] tracking-[-0.03em] text-gv-text';

// ── Small building blocks ─────────────────────────────────────────────────

function Eyebrow({ children, both = false }: { children: ReactNode; both?: boolean }) {
  const line = 'before:h-px before:w-9 before:bg-current before:opacity-60';
  const after = both ? 'after:h-px after:w-9 after:bg-current after:opacity-60' : '';
  return (
    <span
      className={`inline-flex items-center gap-3 text-xs font-bold uppercase tracking-[0.22em] text-gv-brand before:content-[''] after:content-[''] ${line} ${after}`}
    >
      {children}
    </span>
  );
}

function SplitHead({ eyebrow, heading, aside }: { eyebrow: string; heading: string; aside?: string }) {
  return (
    <div className="mb-11 flex flex-wrap items-end justify-between gap-6">
      <div className="flex max-w-[600px] flex-col gap-[18px]">
        <Eyebrow>{eyebrow}</Eyebrow>
        <h2 className={H2}>{heading}</h2>
      </div>
      {aside && <p className="max-w-[340px] text-gv-muted">{aside}</p>}
    </div>
  );
}

/** A real screenshot in a phone frame. */
function Phone({ screen, className = '', sizes }: { screen: Screen; className?: string; sizes: string }) {
  return (
    <div className={`${styles.phone} ${className}`}>
      <Image src={screen.src} alt={screen.alt} width={SCREEN_RATIO.width} height={SCREEN_RATIO.height} sizes={sizes} />
    </div>
  );
}

// ── Sections ──────────────────────────────────────────────────────────────

export function Hero({ stores, live }: { stores: StoreLink[]; live: LiveSnapshot }) {
  return (
    <section className="relative overflow-hidden pt-14 sm:pt-[72px]">
      <WorldMap live={live} className="top-10" />
      <div className={WRAP}>
        {/* Click-through except on real controls, so map markers under the copy stay reachable. */}
        <div className="pointer-events-none relative mx-auto flex max-w-[860px] flex-col items-center gap-[22px] text-center [&_a]:pointer-events-auto">
          <Eyebrow both>{COPY.hero.eyebrow}</Eyebrow>
          <h1 className="text-balance text-[clamp(42px,6.4vw,76px)] font-bold leading-[1.05] tracking-[-0.04em] text-gv-text">
            {COPY.hero.title} <span className="text-gv-brand">{COPY.hero.accent}</span>
          </h1>
          <p className="max-w-[560px] text-lg text-gv-muted">{COPY.hero.sub}</p>
          <div className="mt-1.5 flex flex-wrap items-center justify-center gap-3">
            {stores.map((store) => (
              <StoreBadge key={store.id} store={store.id} href={store.href} large />
            ))}
            <a
              href="#exposed"
              className="inline-flex min-h-12 items-center rounded-full border border-gv-line bg-gv-surface px-[22px] font-bold text-gv-text transition hover:border-gv-brand"
            >
              {COPY.hero.secondary}
            </a>
          </div>
        </div>

        {/* Hidden, never filled with stand-ins, when no source can be read. */}
        <LiveStats initial={live} />
      </div>
    </section>
  );
}

export function KeyCards() {
  return (
    <section id="features" className="relative scroll-mt-20 overflow-hidden pb-6 pt-10 md:pt-16">
      <div className={styles.arc} aria-hidden />
      <div className={WRAP}>
        <div className="relative mx-auto grid max-w-[960px] gap-[18px] md:grid-cols-3 md:items-end">
          {COPY.keys.items.map((item, i) => (
            <article
              key={item.title}
              className={`relative flex flex-col items-center justify-end overflow-hidden rounded-[22px] border p-[26px] pt-14 text-center ${styles.keyCard} ${
                i === 1 ? 'border-gv-brand/40 md:min-h-[240px] md:-translate-y-10' : 'border-gv-line md:min-h-[200px]'
              }`}
            >
              {item.protocols && (
                <span className="absolute right-5 top-4 font-mono text-[11px] text-gv-muted">{item.protocols}</span>
              )}
              <div>
                <h3 className="text-[22px] font-bold leading-tight tracking-[-0.02em] text-gv-text">{item.title}</h3>
                <p className="mt-2 text-sm text-gv-muted">{item.body}</p>
              </div>
            </article>
          ))}
        </div>
        <p className="relative mt-2.5 text-center">
          <Eyebrow both>{COPY.keys.label}</Eyebrow>
        </p>
      </div>
    </section>
  );
}

export function Exposed() {
  const c = COPY.exposed;
  return (
    <section id="exposed" className={`${BAND} scroll-mt-20`}>
      <div className={`${WRAP} grid items-center gap-14 md:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)]`}>
        <div className="min-w-0">
          <Eyebrow>{c.eyebrow}</Eyebrow>
          <h2 className={`${H2} mt-[18px]`}>{c.heading}</h2>
          <p className="mt-4 max-w-[460px] text-gv-muted">{c.body}</p>
          <ul className="mt-7 grid gap-3.5">
            {c.points.map((p) => (
              <li key={p.lead} className="flex items-start gap-3 text-gv-muted">
                <Icon name="check" size={18} strokeWidth={2} className="mt-1 shrink-0 text-gv-brand" />
                <span>
                  <b className="font-bold text-gv-text">{p.lead}</b> {p.text}
                </span>
              </li>
            ))}
          </ul>
        </div>
        <ConnectDemo />
      </div>
    </section>
  );
}

export function Why() {
  const c = COPY.why;
  return (
    <section className={BAND}>
      <div className={WRAP}>
        <SplitHead eyebrow={c.eyebrow} heading={c.heading} aside={c.aside} />
        <div className="grid gap-7 md:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
          <div
            className={`relative grid min-h-[440px] place-items-center overflow-hidden rounded-[26px] border border-gv-line bg-gv-bg-2 px-5 pt-9 ${styles.poolTop}`}
          >
            <Phone screen={SCREENS.home} sizes="250px" className="-mb-[120px] w-[min(250px,70%)] self-end" />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            {c.items.map((item) => (
              <article
                key={item.title}
                className={`relative flex flex-col gap-3.5 overflow-hidden rounded-[22px] border border-gv-line bg-gv-surface p-6 ${styles.glowTop}`}
              >
                <h3 className="relative mt-auto pt-10 text-lg font-bold tracking-[-0.01em] text-gv-text">{item.title}</h3>
                <p className="relative -mt-1.5 text-sm text-gv-muted">{item.body}</p>
              </article>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export function Tools() {
  const c = COPY.tools;
  return (
    <section id="tools" className={`${BAND} scroll-mt-20`}>
      <div className={WRAP}>
        <SplitHead eyebrow={c.eyebrow} heading={c.heading} aside={c.aside} />
        <ul className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-4">
          {c.items.map((tool) => (
            <li
              key={tool.title}
              className="flex flex-col gap-2 rounded-[22px] border border-gv-line bg-gv-surface p-[22px] transition hover:-translate-y-0.5 hover:border-gv-brand/50"
            >
              <b className="text-base text-gv-text">{tool.title}</b>
              <span className="text-[13.5px] text-gv-muted">{tool.body}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

export function HowItWorks({ stores }: { stores: StoreLink[] }) {
  const c = COPY.how;
  const primary = stores[0];
  return (
    <section id="how" className={`${BAND} scroll-mt-20`}>
      <div className={WRAP}>
        <SplitHead eyebrow={c.eyebrow} heading={c.heading} aside={c.aside} />
        <ol className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-[minmax(0,0.85fr)_repeat(3,minmax(0,1fr))]">
          <li
            className={`relative grid min-h-[280px] place-items-end overflow-hidden rounded-[22px] border border-gv-line bg-gv-bg-2 ${styles.poolBottom}`}
            aria-hidden
          >
            <Phone screen={SCREENS.servers} sizes="180px" className="-mb-[60px] w-[62%]" />
          </li>
          {c.steps.map((step, i) => (
            <li key={step.title} className="relative flex flex-col gap-3 rounded-[22px] border border-gv-line bg-gv-surface p-6">
              <span className="absolute right-[22px] top-[18px] text-[34px] font-extrabold tracking-[-0.03em] text-gv-line" aria-hidden>
                {String(i + 1).padStart(2, '0')}
              </span>
              <h3 className="mt-14 text-lg font-bold text-gv-text">{step.title}</h3>
              <p className="flex-1 text-sm text-gv-muted">{step.body}</p>
              {i === 0 && primary && (
                <div className="mt-2">
                  <StoreBadge store={primary.id} href={primary.href} />
                </div>
              )}
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

export function Screens() {
  const list = Object.values(SCREENS);
  return (
    <section className={BAND}>
      <div className={WRAP}>
        <SplitHead eyebrow={COPY.screens.eyebrow} heading={COPY.screens.heading} />
        <ul
          className="-mx-1 flex snap-x snap-mandatory gap-[22px] overflow-x-auto px-1 pb-8 pt-2.5"
          tabIndex={0}
          aria-label={COPY.screens.heading}
        >
          {list.map((screen) => (
            <li key={screen.src} className="flex w-[220px] shrink-0 snap-center flex-col items-center gap-3.5">
              <Phone screen={screen} sizes="220px" className="w-full" />
              <span className="text-center text-sm font-semibold text-gv-muted">{screen.caption}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

export function Faq({ minAndroid }: { minAndroid: string }) {
  const c = COPY.faq;
  const half = Math.ceil(c.items.length / 2);
  const columns = [c.items.slice(0, half), c.items.slice(half)];
  return (
    <section id="faq" className={`${BAND} scroll-mt-20`}>
      <div className={WRAP}>
        <div className="mb-9 grid items-end gap-6 md:grid-cols-2">
          <span className="self-center">
            <Eyebrow>{c.eyebrow}</Eyebrow>
          </span>
          <h2 className={H2}>{c.heading}</h2>
        </div>
        <div className="grid items-start gap-3.5 md:grid-cols-2">
          {columns.map((items, col) => (
            <div key={col} className="grid gap-3.5">
              {items.map((item, i) => (
                <details
                  key={item.q}
                  name="gvpn-faq"
                  open={col === 0 && i === 0}
                  className={`rounded-2xl border border-gv-line bg-gv-surface ${styles.faq}`}
                >
                  <summary className="flex min-h-14 cursor-pointer list-none items-center justify-between gap-4 px-5 py-[18px] text-[15.5px] font-bold text-gv-text">
                    {item.q}
                    <Icon name="chevron" size={18} strokeWidth={2} className={`shrink-0 text-gv-brand transition ${styles.chevron}`} />
                  </summary>
                  <p className="px-5 pb-5 text-[14.5px] text-gv-muted">{withMinAndroid(item.a, minAndroid)}</p>
                </details>
              ))}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function ClosingCta({ stores, live }: { stores: StoreLink[]; live: LiveSnapshot }) {
  const c = COPY.cta;
  return (
    <section className={BAND}>
      <div className={WRAP}>
        <div className="relative flex flex-col items-center gap-5 overflow-hidden rounded-[30px] border border-gv-line bg-gv-bg-2 px-6 pt-[72px] text-center sm:px-8 [&>*:not(:first-child)]:pointer-events-none [&_a]:pointer-events-auto">
          <WorldMap live={live} className="-top-10 opacity-60" />
          <div className={styles.arcLow} aria-hidden />
          <span className="relative">
            <Eyebrow both>{stores.length === 1 ? c.eyebrowOneStore.replace('{store}', STORE_COPY[stores[0].id].name) : c.eyebrow}</Eyebrow>
          </span>
          <h2 className="relative max-w-[760px] text-balance text-[clamp(32px,4.6vw,54px)] font-bold leading-[1.08] tracking-[-0.03em] text-gv-text">
            {c.heading}
          </h2>
          <p className="relative max-w-[520px] text-gv-muted">{c.body}</p>
          <div className="relative flex flex-wrap justify-center gap-3">
            {stores.map((store) => (
              <StoreBadge key={store.id} store={store.id} href={store.href} large />
            ))}
          </div>
          <div className="relative z-[1] mt-7 flex h-[260px] justify-center gap-[18px] overflow-hidden" aria-hidden>
            <Phone screen={SCREENS.country} sizes="200px" className="hidden w-[200px] self-start sm:block" />
            <Phone screen={SCREENS.tools} sizes="200px" className="-mt-6 w-[200px] self-start" />
            <Phone screen={SCREENS.rules} sizes="200px" className="hidden w-[200px] self-start sm:block" />
          </div>
        </div>
      </div>
    </section>
  );
}
