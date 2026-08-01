import type { Metadata } from 'next';

/**
 * THE PUBLIC ROUTE GROUP.
 *
 * Everything under `(public)` is mindberzerk.com, served to anyone. Everything
 * outside it is the console. The group adds no path segment, so this layout is
 * what `/` renders inside.
 *
 * ## Undoing the console's canvas
 *
 * The root globals.css paints `body` with `surface-0` and pins
 * `color-scheme: dark` on `<html>`, because the console is dark-only and that
 * was the right call when it was the only thing here. The landing needs the
 * opposite, and a wrapper div is not enough on its own: overscroll, the
 * scrollbar, and the area below short content are all painted by `<html>`, so
 * a light page on a dark root shows dark bands at both ends.
 *
 * The marker below is what `globals.css` keys the canvas off. It replaced an
 * inline script that wrote `html.style` before paint, which worked and cost a
 * Next 16 warning plus a hydration mismatch React will not patch up. The
 * stored theme preference is replayed once in the root layout instead.
 */

export const metadata: Metadata = {
  metadataBase: new URL('https://mindberzerk.com'),
  title: 'Mindberzerk, an independent app studio',
  description:
    'Apps and games for Android and iOS from an independent studio: finance tracking, RPGs, community tools, and a Linux desktop for your phone.',
  // OVERRIDES THE ROOT'S noindex, and only for this group. The console stays
  // unindexed; the public site is meant to be found.
  robots: { index: true, follow: true },
  openGraph: {
    title: 'Mindberzerk',
    description: 'Apps and games for Android and iOS from an independent studio.',
    url: 'https://mindberzerk.com',
    siteName: 'Mindberzerk',
    type: 'website',
  },
};

export default function PublicLayout({ children }: { children: React.ReactNode }) {
  return (
    <div data-surface="soft" className="min-h-[100dvh] bg-site-page font-site-sans text-site-ink-2">
      {children}
    </div>
  );
}
