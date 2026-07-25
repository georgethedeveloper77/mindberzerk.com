import type { Metadata, Viewport } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';
import { ToastProvider } from '@/components/console';

/**
 * THE FONTS WERE NEVER LOADED. globals.css referenced --font-geist-sans and
 * --font-geist-mono, which nothing defined, so `font-sans` fell through to the
 * `font-family: Arial` on the body and `font-mono` to whatever the browser had.
 * These two calls are what make the variables exist.
 *
 * next/font self-hosts at build time: no request to Google at runtime, no CLS,
 * and nothing to fetch on a phone. If a build ever runs without network access,
 * delete these two and drop the `var(--font-geist-*)` entries from globals.css —
 * the stacks behind them are complete on their own.
 */
const sans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const mono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Mindberzerk',
  description: 'Publishing and configuration for the Mindhunter apps',
  // No indexing, ever. This URL is public, it holds the signing key, and its
  // only defence is the UID allowlist. Being findable adds nothing and invites
  // exactly the traffic you do not want.
  robots: { index: false, follow: false },
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'Mindberzerk',
  },
};

export const viewport: Viewport = {
  // viewportFit: 'cover' plus the env(safe-area-inset-*) padding in the shell is
  // what stops the bottom nav sitting under the iPhone home indicator. Without
  // it the primary navigation of a mobile dashboard is partly untappable, which
  // is the sort of thing that only shows up on a real device.
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#0c0e11',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      {/* Colours come from globals.css, not from utilities here: the body is the
          one element that must be painted before any CSS-in-JS or route chunk
          arrives, or the first paint is white on a dark panel. */}
      <body className="min-h-[100dvh] antialiased">
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
