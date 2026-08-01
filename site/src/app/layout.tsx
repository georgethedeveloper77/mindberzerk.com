import type { Metadata, Viewport } from 'next';
import { Bricolage_Grotesque, JetBrains_Mono, Plus_Jakarta_Sans } from 'next/font/google';
import Script from 'next/script';
import './globals.css';

/**
 * next/font self-hosts at build time, so nothing is fetched from Google at
 * runtime and there is no layout shift. The three variables are what the
 * token system in globals.css resolves its stacks from.
 */
const jakarta = Plus_Jakarta_Sans({ variable: '--font-jakarta', subsets: ['latin'] });
const bricolage = Bricolage_Grotesque({ variable: '--font-bricolage', subsets: ['latin'] });
const jbmono = JetBrains_Mono({ variable: '--font-jbmono', subsets: ['latin'] });

export const metadata: Metadata = {
  metadataBase: new URL('https://mindberzerk.com'),
  title: 'Mindberzerk, an independent app studio',
  description:
    'Apps and games for Android and iOS from an independent studio: finance tracking, RPGs, community tools, and a Linux desktop for your phone.',
  openGraph: {
    title: 'Mindberzerk',
    description: 'Apps and games for Android and iOS from an independent studio.',
    url: 'https://mindberzerk.com',
    siteName: 'Mindberzerk',
    type: 'website',
  },
  // The public site, so indexing is the point. The admin panel is the one that
  // pins robots to noindex; do not copy that here.
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#faf9f7',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // Analytics only exists when the id does. No id, no script tags at all, which
  // is the correct amount of tracking for a site that promises little of it.
  const ga = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID;

  return (
    <html lang="en" className={`${jakarta.variable} ${bricolage.variable} ${jbmono.variable}`}>
      <body className="min-h-[100dvh] antialiased" suppressHydrationWarning>
        {children}
        {ga && (
          <>
            <Script src={`https://www.googletagmanager.com/gtag/js?id=${ga}`} strategy="afterInteractive" />
            <Script id="ga-init" strategy="afterInteractive">
              {`window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '${ga}');`}
            </Script>
          </>
        )}
      </body>
    </html>
  );
}
