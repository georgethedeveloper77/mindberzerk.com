import Image from 'next/image';
import Link from 'next/link';
import { ThemeToggle } from '@/components/site/theme-toggle';
import { COPY, MARK_SRC, PRIVACY_URL, TERMS_URL } from './copy';

/**
 * Header and footer for the G VPN landing. Server components: the only
 * client island here is the shared theme toggle, restyled to Meridian.
 */

const TOGGLE_CLASS =
  'grid size-11 place-items-center rounded-xl border border-gv-line bg-gv-surface text-gv-text transition hover:border-gv-brand';

/** The app's real shield mark, from apps/g_vpn/assets/brand. */
export function GvpnMark({ size = 40 }: { size?: number }) {
  return <Image src={MARK_SRC} alt="" width={size} height={size} priority className="shrink-0" />;
}

export function GvpnHeader() {
  return (
    <header className="mx-auto flex max-w-[1240px] flex-wrap items-center gap-x-4 gap-y-2 px-4 py-5 sm:px-10">
      <a href="#top" className="flex items-center gap-2.5 text-gv-text" aria-label="G VPN home">
        <GvpnMark />
        <span className="text-xl font-extrabold tracking-[-0.02em]">G VPN</span>
      </a>

      <nav
        aria-label="Main"
        className="order-last -mx-1 flex w-full gap-1 overflow-x-auto sm:order-none sm:mx-0 sm:w-auto sm:flex-1"
      >
        {COPY.nav.map((item) => (
          <a
            key={item.href}
            href={item.href}
            className="flex min-h-11 shrink-0 items-center rounded-xl px-2 text-sm font-semibold sm:px-3.5 sm:text-[15px] text-gv-text transition hover:bg-gv-brand-soft hover:text-gv-brand"
          >
            {item.label}
          </a>
        ))}
      </nav>

      <div className="ms-auto flex items-center gap-2 sm:ms-0">
        <ThemeToggle className={TOGGLE_CLASS} />
        <a
          href="#download"
          className="hidden min-h-11 items-center rounded-xl bg-gv-brand-solid px-[18px] text-[15px] font-bold text-white transition hover:bg-gv-brand-hover sm:flex"
        >
          {COPY.download}
        </a>
      </div>
    </header>
  );
}

const FOOTER_LINK =
  'inline-flex min-h-11 items-center px-3 font-semibold text-gv-muted transition hover:text-gv-text';

export function GvpnFooter() {
  return (
    <footer className="border-t border-gv-line">
      <div className="mx-auto flex max-w-[1240px] flex-wrap items-center justify-between gap-4 px-4 py-8 sm:px-10">
        <span className="text-sm text-gv-muted">{COPY.footer.by}</span>
        <div className="-mx-3 flex flex-wrap text-[15px]">
          <a className={FOOTER_LINK} href={PRIVACY_URL}>
            {COPY.footer.privacy}
          </a>
          <a className={FOOTER_LINK} href={TERMS_URL}>
            {COPY.footer.terms}
          </a>
          <Link className={FOOTER_LINK} href="/">
            {COPY.footer.studio}
          </Link>
        </div>
      </div>
    </footer>
  );
}
