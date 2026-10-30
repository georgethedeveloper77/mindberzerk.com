import Image from 'next/image';
import Link from 'next/link';
import { ThemeToggle } from '@/components/site/theme-toggle';
import { CONTACT_EMAIL, COPY, MARK_SRC, PRIVACY_URL, TERMS_URL, type StoreLink } from './copy';
import { StoreBadge } from './store-badges';

/**
 * Header and footer for the G VPN landing. Server components: the only
 * client island here is the shared theme toggle, restyled to Meridian.
 */

const TOGGLE_CLASS =
  'grid size-11 shrink-0 place-items-center rounded-xl border border-gv-line bg-gv-surface text-gv-text transition hover:border-gv-brand';

/** The app's real shield mark, from apps/g_vpn/assets/brand. */
export function GvpnMark({ size = 36 }: { size?: number }) {
  return <Image src={MARK_SRC} alt="" width={size} height={size} priority className="shrink-0" />;
}

function Brand() {
  return (
    <a href="#top" className="flex items-center gap-2.5 text-[19px] font-extrabold tracking-[-0.02em] text-gv-text" aria-label="G VPN home">
      <GvpnMark />
      G VPN
    </a>
  );
}

export function GvpnHeader({ primary }: { primary: StoreLink | undefined }) {
  return (
    <header className="sticky top-[env(safe-area-inset-top,0px)] z-20 border-b border-gv-line/70 bg-gv-bg/80 backdrop-blur-md">
      <div className="mx-auto flex min-h-[72px] w-full max-w-[1200px] items-center gap-7 px-4 sm:px-6">
        <Brand />
        <nav aria-label="Main" className="hidden flex-1 gap-1 md:flex">
          {COPY.nav.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="rounded-[10px] px-3 py-2.5 text-[14.5px] font-semibold text-gv-muted transition hover:text-gv-text"
            >
              {item.label}
            </a>
          ))}
        </nav>
        <div className="ms-auto flex items-center gap-3 md:ms-0">
          <ThemeToggle className={TOGGLE_CLASS} />
          {primary && (
            <span className="hidden md:block">
              <StoreBadge store={primary.id} href={primary.href} />
            </span>
          )}
        </div>
      </div>
    </header>
  );
}

const FOOT_LINK = 'text-[14.5px] text-gv-muted transition hover:text-gv-text';
const FOOT_HEAD = 'mb-3.5 text-[13px] font-bold uppercase tracking-[0.14em] text-gv-brand';

export function GvpnFooter({ primary }: { primary: StoreLink | undefined }) {
  const f = COPY.footer;
  return (
    <footer className="mt-20 border-t border-gv-line pb-8 pt-14 sm:mt-[110px]">
      <div className="mx-auto w-full max-w-[1200px] px-4 sm:px-6">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div className="col-span-2 flex max-w-[300px] flex-col gap-4 md:col-span-1">
            <Brand />
            <p className="text-[14.5px] text-gv-muted">{f.about}</p>
            {primary && (
              <div>
                <StoreBadge store={primary.id} href={primary.href} />
              </div>
            )}
          </div>
          <div>
            <h4 className={FOOT_HEAD}>{f.columns.product}</h4>
            <ul className="grid gap-2.5">
              {COPY.nav.map((item) => (
                <li key={item.href}>
                  <a className={FOOT_LINK} href={item.href}>
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h4 className={FOOT_HEAD}>{f.columns.support}</h4>
            <ul className="grid gap-2.5">
              <li><a className={FOOT_LINK} href="#faq">{f.help}</a></li>
              <li><a className={FOOT_LINK} href={PRIVACY_URL}>{f.privacy}</a></li>
              <li><a className={FOOT_LINK} href={TERMS_URL}>{f.terms}</a></li>
              <li><a className={FOOT_LINK} href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a></li>
            </ul>
          </div>
          <div>
            <h4 className={FOOT_HEAD}>{f.columns.studio}</h4>
            <ul className="grid gap-2.5">
              <li><Link className={FOOT_LINK} href="/">{f.studioSite}</Link></li>
              <li><Link className={FOOT_LINK} href="/#apps">{f.moreApps}</Link></li>
            </ul>
          </div>
        </div>
        <div className="mt-12 flex flex-wrap justify-between gap-3 border-t border-gv-line pt-6 text-[13.5px] text-gv-faint">
          <span>{f.copyright}</span>
          <span>{f.by}</span>
        </div>
      </div>
    </footer>
  );
}
