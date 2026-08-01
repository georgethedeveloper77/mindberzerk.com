import { APP_STORE_DEV_URL, PLAY_DEV_URL } from '@/lib/apps';

/**
 * The shared chrome: brand, nav, store badges, footer. All server components;
 * nothing here holds state.
 *
 * The store badges are DRAWN, not the official bitmap assets, which keeps the
 * no-uploaded-images rule intact. If brand-exact badges are ever required, they
 * replace these two components and nothing else moves.
 */

export function Brand() {
  return (
    <a href="#top" className="flex items-center gap-2.5 text-[17px] font-bold tracking-tight text-ink">
      <span
        aria-hidden
        className="relative size-[30px] shrink-0 rounded-[9px]"
        style={{
          background:
            'conic-gradient(from 210deg at 60% 40%, #6d4ae8, #a04ae8, #e8703a, #6d4ae8)',
        }}
      >
        <span className="absolute inset-2 rounded-[4px] bg-page" />
      </span>
      Mindberzerk
    </a>
  );
}

function PlayGlyph() {
  return (
    <svg width="20" height="22" viewBox="0 0 20 22" fill="currentColor" aria-hidden>
      <path d="M1.5 1.9c0-1 1.1-1.7 2-1.1l15 8.5c.9.5.9 1.9 0 2.4l-15 8.5c-.9.6-2-.1-2-1.1V1.9z" opacity="0.95" />
    </svg>
  );
}

function AppleGlyph() {
  return (
    <svg width="19" height="22" viewBox="0 0 19 22" fill="currentColor" aria-hidden>
      <path d="M15.6 11.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.9C5.7 6 4.1 7 3.2 8.5c-1.9 3.2-.5 8 1.3 10.6.9 1.3 1.9 2.7 3.3 2.6 1.3-.1 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.2-2.6.7-1 1-2 1.4-3-3-1.1-3.6-3.4-3.6-4.5zM13.2 3.9c.7-.9 1.2-2.1 1.1-3.3-1 0-2.3.7-3 1.5-.7.8-1.3 2-1.1 3.2 1.1.1 2.3-.6 3-1.4z" />
    </svg>
  );
}

export function StoreBadges() {
  return (
    <div className="flex flex-wrap gap-3.5">
      <a
        href={PLAY_DEV_URL}
        className="flex items-center gap-3 rounded-[14px] bg-ink px-[18px] py-2.5 text-white shadow-lift transition hover:-translate-y-px hover:bg-[#2a2138]"
      >
        <PlayGlyph />
        <span className="text-left leading-tight">
          <span className="block text-[9.5px] font-medium uppercase tracking-wider opacity-75">Get it on</span>
          <span className="block text-[15.5px] font-semibold tracking-tight">Google Play</span>
        </span>
      </a>
      <a
        href={APP_STORE_DEV_URL}
        className="flex items-center gap-3 rounded-[14px] bg-ink px-[18px] py-2.5 text-white shadow-lift transition hover:-translate-y-px hover:bg-[#2a2138]"
      >
        <AppleGlyph />
        <span className="text-left leading-tight">
          <span className="block text-[9.5px] font-medium uppercase tracking-wider opacity-75">Download on the</span>
          <span className="block text-[15.5px] font-semibold tracking-tight">App Store</span>
        </span>
      </a>
    </div>
  );
}

export function Nav() {
  return (
    <nav className="sticky top-0 z-40 border-b border-line/70 bg-page/85 backdrop-blur-md">
      <div className="mx-auto flex h-[72px] max-w-[1180px] items-center gap-9 px-7">
        <Brand />
        <div className="hidden gap-7 text-[14.5px] font-semibold text-ink-3 sm:flex">
          <a className="transition hover:text-ink" href="#apps">Apps</a>
          <a className="transition hover:text-ink" href="#next">What&apos;s next</a>
          <a className="transition hover:text-ink" href="#contact">Contact</a>
        </div>
        <div className="flex-1" />
        <a
          href="#contact"
          className="rounded-full bg-ink px-[18px] py-2.5 text-sm font-semibold text-white shadow-lift transition hover:-translate-y-px hover:bg-[#2a2138]"
        >
          Work with us
        </a>
      </div>
    </nav>
  );
}

export function Footer() {
  return (
    <footer className="border-t border-line py-10">
      <div className="mx-auto flex max-w-[1180px] flex-wrap items-center gap-7 px-7 text-sm font-medium text-ink-3">
        <Brand />
        <span>© 2026 Mindberzerk</span>
        <div className="flex-1" />
        <a className="transition hover:text-ink" href={PLAY_DEV_URL}>Google Play</a>
        <a className="transition hover:text-ink" href={APP_STORE_DEV_URL}>App Store</a>
        <a className="transition hover:text-ink" href="#contact">Contact</a>
      </div>
    </footer>
  );
}
