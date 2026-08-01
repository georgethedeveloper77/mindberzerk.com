import type { Metadata, Viewport } from 'next';
import { Bricolage_Grotesque, Geist, Geist_Mono, Plus_Jakarta_Sans } from 'next/font/google';
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
 * delete these two and drop the `var(--font-geist-*)` entries from globals.css -
 * the stacks behind them are complete on their own.
 */
const sans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const mono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

/**
 * THE PUBLIC SITE'S FACES, loaded here because a font variable has to be on
 * <html> to reach a route group's subtree. They cost nothing on console routes:
 * next/font subsets and preloads per page, so a screen that never uses
 * `font-site-display` never asks for Bricolage.
 */
const siteSans = Plus_Jakarta_Sans({ variable: '--font-jakarta', subsets: ['latin'] });
const siteDisplay = Bricolage_Grotesque({ variable: '--font-bricolage', subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Mindberzerk',
  description: 'Publishing and configuration for the Mindhunter apps',
  // NOINDEX IS THE DEFAULT, AND IT STAYS THE DEFAULT. This origin holds the
  // signing key and the console, and its only defence is the UID allowlist.
  //
  // The public route group OVERRIDES this in its own layout, so exactly one
  // subtree is indexable and everything else inherits the refusal. Written this
  // way round on purpose: a new console route is unindexed without anyone
  // remembering to say so.
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

/**
 * THE THEME REPLAY, and why it lives here rather than in a route layout.
 *
 * The toggle stores 'light' or 'dark' under `mb-theme`, and the two soft routes
 * need that choice applied to `<html>` BEFORE first paint or a dark-mode
 * visitor sees a white flash. Reading localStorage needs JavaScript; there is
 * no CSS-only version of "what did this person choose last time".
 *
 * IT GOES IN <head>, AND ONLY THERE. Two wrong turns were taken first, so the
 * reasons are worth keeping:
 *
 *  1. A raw <script> in a ROUTE layout earns a Next 16 warning, because such a
 *     tag is inlined into the SSR HTML but never executed on a client
 *     navigation. Correct warning; that version is gone.
 *  2. `next/script` with `beforeInteractive` as a child of <html> is invalid
 *     HTML. A <script> cannot be a sibling of <head> and <body>, so React
 *     reports a nesting error and a hydration mismatch on top of it.
 *
 * A plain <script> inside an explicit <head> is the standard no-flash pattern,
 * it is valid HTML, it runs parser-blocking before first paint, and it needs no
 * component wrapper. On a client navigation it does not re-run, which is
 * correct: <html> already carries the attribute by then.
 *
 * It writes `data-theme` onto <html>, which is a server/client difference by
 * design, which is what `suppressHydrationWarning` on <html> is for. Scoped to
 * that one element: a genuine mismatch anywhere inside the app still reports.
 */
const THEME_REPLAY = `try{var t=localStorage.getItem('mb-theme');if(t==='light'||t==='dark'){document.documentElement.dataset.theme=t}}catch(e){}`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      className={`${sans.variable} ${mono.variable} ${siteSans.variable} ${siteDisplay.variable}`}
      suppressHydrationWarning
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_REPLAY }} />
      </head>
      {/* Colours come from globals.css, not from utilities here: the body is the
          one element that must be painted before any CSS-in-JS or route chunk
          arrives, or the first paint is white on a dark panel. */}
      {/* suppressHydrationWarning, and ONLY on <body>.

          The hydration mismatch reported here was `cz-shortcut-listen="true"`,
          which is ColorZilla. Browser extensions inject attributes onto <body>
          before React hydrates, so the server HTML and the client tree differ
          on an attribute this app never wrote. React cannot tell that from a
          real mismatch and warns loudly about a bug that is not in the code.

          Scoped to this one element deliberately. It suppresses the warning for
          <body>'s own attributes and nothing below it, so a genuine mismatch
          inside the app still reports. Putting it on <html>, or on a component,
          is how a real hydration bug goes quiet for a month. */}
      <body className="min-h-[100dvh] antialiased" suppressHydrationWarning>
        <ToastProvider>{children}</ToastProvider>
      </body>
    </html>
  );
}
