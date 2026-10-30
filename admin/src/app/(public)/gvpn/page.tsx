import type { Metadata } from 'next';
import { GvpnFooter, GvpnHeader } from '@/components/g-vpn-site/chrome';
import { COPY, ICON_SRC, MARK_SRC } from '@/components/g-vpn-site/copy';
import { readLiveSnapshot } from '@/components/g-vpn-site/live-servers';
import {
  ClosingCta,
  Exposed,
  Faq,
  Hero,
  HowItWorks,
  KeyCards,
  Screens,
  Tools,
  Why,
} from '@/components/g-vpn-site/sections';
import { readGvpnSiteConfig } from '@/components/g-vpn-site/site-config';

/**
 * mindberzerk.com/gvpn, the G VPN landing.
 *
 * Public because `/gvpn` is listed in proxy.ts's PUBLIC set; that list is
 * exact-match, so any future subpage (privacy, support) needs its own entry.
 * The earlier `/g-vpn` address redirects here, also in proxy.ts.
 *
 * Three live inputs, each with a safe failure:
 *  - store links and minimum Android from Remote Config (admin: G VPN,
 *    Config), defaults when unreadable;
 *  - free server countries and our own servers from the two Worker lists,
 *    seeded here and refreshed every minute in the browser through
 *    /api/g-vpn/live; stats hidden when neither can be read;
 *  - the visitor's IP and spot, fetched in the browser, readouts dropped when
 *    the lookup fails.
 * The page is rebuilt at most every five minutes.
 *
 * `data-surface="gvpn"` repaints <html> in the Meridian background, see
 * globals.css, so overscroll and short viewports match the page.
 */

export const revalidate = 300;

const PATH = '/gvpn';

export const metadata: Metadata = {
  title: COPY.meta.title,
  description: COPY.meta.description,
  alternates: { canonical: PATH },
  icons: { icon: MARK_SRC, apple: ICON_SRC },
  openGraph: {
    title: COPY.meta.title,
    description: COPY.meta.description,
    url: PATH,
    siteName: 'Mindberzerk',
    type: 'website',
    images: [{ url: ICON_SRC, width: 512, height: 512, alt: 'G VPN' }],
  },
};

export default async function GvpnLanding() {
  const [config, live] = await Promise.all([readGvpnSiteConfig(), readLiveSnapshot()]);
  const primary = config.stores[0];
  const play = config.stores.find((s) => s.id === 'play');

  /** Structured data so search results can show the app as an app. */
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: 'G VPN',
    operatingSystem: `Android ${config.minAndroid} or later`,
    applicationCategory: 'UtilitiesApplication',
    description: COPY.meta.description,
    image: `https://mindberzerk.com${ICON_SRC}`,
    ...(play ? { installUrl: play.href } : {}),
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    publisher: { '@type': 'Organization', name: 'Mindberzerk', url: 'https://mindberzerk.com' },
  };

  return (
    <div
      id="top"
      data-surface="gvpn"
      className="min-h-[100dvh] overflow-x-clip bg-gv-bg font-site-sans text-gv-text"
    >
      <script
        type="application/ld+json"
        // Built from constants and admin-validated URLs; `<` is escaped so no
        // value can close the script tag.
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }}
      />
      <GvpnHeader primary={primary} />
      <main>
        <Hero stores={config.stores} live={live} />
        <KeyCards />
        <Exposed />
        <Why />
        <Tools />
        <HowItWorks stores={config.stores} />
        <Screens />
        <Faq minAndroid={config.minAndroid} />
        <ClosingCta stores={config.stores} live={live} />
      </main>
      <GvpnFooter primary={primary} />
    </div>
  );
}
