import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Mindberzerk',
  description: 'Pack publishing for the Mindhunter apps',
  // No indexing, ever. This URL is public, it holds the signing key, and its
  // only defence is the UID allowlist. Being findable adds nothing and invites
  // exactly the traffic you do not want.
  robots: { index: false, follow: false },
  appleWebApp: { capable: true, statusBarStyle: 'black-translucent', title: 'Mindberzerk' },
};

export const viewport: Viewport = {
  // viewportFit: 'cover' plus the env(safe-area-inset-*) padding in the shell is
  // what stops the bottom nav sitting under the iPhone home indicator. Without
  // it the primary navigation of a mobile dashboard is partly untappable, which
  // is the sort of thing that only shows up on a real device.
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#0a0a0a',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-[100dvh] bg-neutral-950 text-neutral-100 antialiased">
        {children}
      </body>
    </html>
  );
}
