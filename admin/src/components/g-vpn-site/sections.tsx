import { COPY, STORE_COPY, withMinAndroid, type Card, type StoreLink, type Tone } from './copy';
import { ConnectDemo } from './connect-demo';
import { Icon } from './icons';
import { StoreBadge, StoreLogo } from './store-badges';

/**
 * The landing's sections, top to bottom. Server components throughout; the
 * connect demo is the only client island, and the FAQ uses native
 * <details> so it works before, and without, hydration.
 */

const WRAP = 'mx-auto max-w-[1240px] px-4 sm:px-10';
const H2 = 'text-[32px] font-extrabold leading-tight tracking-[-0.03em] sm:text-[40px]';

const TONE_TEXT: Record<Tone, string> = {
  brand: 'text-gv-brand',
  good: 'text-gv-good',
  violet: 'text-gv-violet',
  bad: 'text-gv-bad',
};

const TONE_CHIP: Record<Tone, string> = {
  brand: 'bg-gv-brand-soft text-gv-brand',
  good: 'bg-gv-good-soft text-gv-good',
  violet: 'bg-gv-brand-soft text-gv-violet',
  bad: 'bg-gv-bad-soft text-gv-bad',
};

export function Hero({ stores }: { stores: StoreLink[] }) {
  return (
    <section className={`${WRAP} flex flex-wrap items-center gap-12 pb-6 pt-6 sm:pt-10`}>
      <div className="flex min-w-0 flex-[1_1_440px] flex-col gap-[22px]">
        <h1 className="text-[40px] font-extrabold leading-[1.05] tracking-[-0.035em] text-gv-text sm:text-[60px]">
          {COPY.hero.title}
        </h1>
        <p className="max-w-[560px] text-[19px] leading-relaxed text-gv-muted">{COPY.hero.sub}</p>
        <div className="flex flex-wrap gap-3">
          {stores.map((store) => (
            <StoreBadge key={store.id} store={store.id} href={store.href} large />
          ))}
          <a
            href="#tools"
            className="flex min-h-14 items-center rounded-2xl border border-gv-line bg-gv-surface px-[26px] text-[17px] font-bold text-gv-text transition hover:border-gv-brand"
          >
            {COPY.hero.secondary}
          </a>
        </div>
      </div>
      <ConnectDemo />
    </section>
  );
}

export function TrustStrip() {
  return (
    <section className={`${WRAP} py-6`}>
      <ul className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-3">
        {COPY.trust.map((item) => (
          <li
            key={item.title}
            className="flex items-start gap-3.5 rounded-[22px] border border-gv-line bg-gv-surface p-5"
          >
            <Icon name={item.icon} size={26} className="shrink-0 text-gv-brand" />
            <div>
              <div className="font-bold text-gv-text">{item.title}</div>
              <div className="mt-1 text-sm text-gv-muted">{item.body}</div>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function Servers() {
  const { heading, options, features } = COPY.servers;
  return (
    <section id="features" className={`${WRAP} flex scroll-mt-6 flex-col gap-7 pb-6 pt-16`}>
      <h2 className={H2}>{heading}</h2>
      <div className="grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-4">
        {options.map((option) => (
          <article
            key={option.title}
            className="flex flex-col gap-3.5 rounded-[26px] border border-gv-line bg-gv-surface p-7"
          >
            <div className="flex items-center justify-between gap-3">
              <span className={`text-[13px] font-extrabold tracking-[0.08em] ${TONE_TEXT[option.tone]}`}>
                {option.tag}
              </span>
              <span className="font-mono text-[13px] text-gv-muted">{option.protocols}</span>
            </div>
            <h3 className="text-2xl font-extrabold text-gv-text">{option.title}</h3>
            <p className="leading-relaxed text-gv-muted">{option.body}</p>
          </article>
        ))}
      </div>
      <ul className="grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-3">
        {features.map((feature) => (
          <li key={feature.title} className="rounded-[20px] bg-gv-surface-2 px-5 py-[18px]">
            <div className="font-bold text-gv-text">{feature.title}</div>
            <div className="mt-1 text-sm text-gv-muted">{feature.body}</div>
          </li>
        ))}
      </ul>
    </section>
  );
}

function ToolCard({ item }: { item: Card }) {
  return (
    <li className="flex flex-col gap-3 rounded-[22px] border border-gv-line bg-gv-surface p-[22px]">
      <span className={`grid size-11 place-items-center rounded-[14px] ${TONE_CHIP[item.tone ?? 'brand']}`}>
        <Icon name={item.icon} size={22} strokeWidth={2} />
      </span>
      <div className="text-[17px] font-bold text-gv-text">{item.title}</div>
      <div className="text-sm text-gv-muted">{item.body}</div>
    </li>
  );
}

export function Tools() {
  return (
    <section id="tools" className={`${WRAP} flex scroll-mt-6 flex-col gap-7 pb-6 pt-16`}>
      <h2 className={H2}>{COPY.tools.heading}</h2>
      <ul className="grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-3.5">
        {COPY.tools.items.map((item) => (
          <ToolCard key={item.title} item={item} />
        ))}
      </ul>
    </section>
  );
}

export function Download({ stores, minAndroid }: { stores: StoreLink[]; minAndroid: string }) {
  if (stores.length === 0) return null;

  return (
    <section id="download" className={`${WRAP} flex scroll-mt-6 flex-col gap-7 pb-6 pt-16`}>
      <h2 className={H2}>{COPY.platforms.heading}</h2>
      <div className="grid grid-cols-[repeat(auto-fit,minmax(280px,1fr))] gap-3.5">
        {stores.map((store) => {
          const copy = STORE_COPY[store.id];
          return (
            <div
              key={store.id}
              className="flex flex-wrap items-center justify-between gap-5 rounded-3xl border border-gv-line bg-gv-surface p-6 sm:p-8"
            >
              <div className="flex items-center gap-4">
                <span className="grid size-14 shrink-0 place-items-center rounded-2xl bg-gv-surface-2 text-gv-text">
                  <StoreLogo store={store.id} size={28} />
                </span>
                <div className="flex flex-col gap-1">
                  <span className="text-[22px] font-extrabold text-gv-text">{copy.name}</span>
                  <span className="text-sm text-gv-muted">{withMinAndroid(copy.requirement, minAndroid)}</span>
                </div>
              </div>
              <StoreBadge store={store.id} href={store.href} />
            </div>
          );
        })}
      </div>
    </section>
  );
}

export function Faq({ minAndroid }: { minAndroid: string }) {
  return (
    <section id="faq" className="mx-auto flex max-w-[900px] scroll-mt-6 flex-col gap-5 px-4 pb-20 pt-16 sm:px-10">
      <h2 className={H2}>{COPY.faq.heading}</h2>
      {COPY.faq.items.map((item) => (
        <details
          key={item.q}
          name="gvpn-faq"
          className="group rounded-[20px] border border-gv-line bg-gv-surface"
        >
          <summary className="flex min-h-14 cursor-pointer list-none items-center justify-between gap-4 px-[22px] py-5 text-[17px] font-bold text-gv-text [&::-webkit-details-marker]:hidden">
            <span>{item.q}</span>
            <span aria-hidden className="text-[22px] leading-none text-gv-muted">
              <span className="group-open:hidden">+</span>
              <span className="hidden group-open:inline">−</span>
            </span>
          </summary>
          <p className="px-[22px] pb-[22px] leading-[1.65] text-gv-muted">{withMinAndroid(item.a, minAndroid)}</p>
        </details>
      ))}
    </section>
  );
}
