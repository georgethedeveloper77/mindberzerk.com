import type { Metadata } from 'next';
import { GvpnFooter, GvpnHeader } from '@/components/g-vpn-site/chrome';
import { COPY, ICON_SRC, MARK_SRC } from '@/components/g-vpn-site/copy';
import { Download, Faq, Hero, Servers, Tools, TrustStrip } from '@/components/g-vpn-site/sections';
import { readGvpnSiteConfig } from '@/components/g-vpn-site/site-config';

/**
 * mindberzerk.com/g-vpn, the G VPN landing.
 *
 * Public because `/g-vpn` is listed in proxy.ts's PUBLIC set; that list is
 * exact-match, so any future subpage (privacy, support) needs its own entry.
 *
 * Store links and the minimum Android version come from Remote Config, edited
 * in the admin under G VPN, Config. The page is rebuilt at most every five
 * minutes, so a change there shows here without a deploy, and an unreadable
 * template renders the defaults rather than an error.
 *
 * `data-surface="gvpn"` repaints <html> in the Meridian background, see
 * globals.css, so overscroll and short viewports match the page.
 */

export const revalidate = 300;

const PATH = '/g-vpn';

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
  const config = await readGvpnSiteConfig();
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
    <div id="top" data-surface="gvpn" className="min-h-[100dvh] bg-gv-bg font-site-sans text-gv-text">
      <script
        type="application/ld+json"
        // Built from constants and admin-validated URLs; `<` is escaped so no
        // value can close the script tag.
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c') }}
      />
      <GvpnHeader />
      <main>
        <Hero stores={config.stores} />
        <TrustStrip />
        <Servers />
        <Tools />
        <Download stores={config.stores} minAndroid={config.minAndroid} />
        <Faq minAndroid={config.minAndroid} />
      </main>
      <GvpnFooter />
    </div>
  );
}
