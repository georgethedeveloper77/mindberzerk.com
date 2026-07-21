'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { signOut } from '@/lib/firebase-client';
import { useRouter } from 'next/navigation';

/**
 * PHASE C4 — the responsive frame.
 *
 * MOBILE FIRST, and not as a slogan: the realistic moment you publish a pack is
 * standing somewhere with a phone, having spotted that an icon is wrong. A
 * dashboard that needs a laptop is a dashboard you do not use.
 *
 * ## The layout rule
 *
 * Below `md`, navigation is a fixed bottom bar, because a top bar on a phone
 * puts every tap at the far end of the thumb's reach. Above `md` it becomes a
 * left rail, because a bottom bar on a wide screen is a phone app in a browser.
 * Same links, same order, one component.
 *
 * `pb-[calc(...)]` on the content and `pb-[env(safe-area-inset-bottom)]` on the
 * bar are both load-bearing on iOS: without them the last row of content sits
 * under the nav, and the nav itself sits under the home indicator.
 */

const LINKS = [
  { href: '/', label: 'Packs', icon: '▦' },
  { href: '/bundles', label: 'Bundles', icon: '◈' },
  { href: '/publish', label: 'Publish', icon: '↑' },
];

export function Shell({
  children,
  subtitle,
}: {
  children: React.ReactNode;
  subtitle?: string;
}) {
  const pathname = usePathname();
  const router = useRouter();

  return (
    <div className="md:flex">
      {/* Rail, desktop only */}
      <aside className="hidden md:flex md:h-[100dvh] md:w-56 md:shrink-0 md:flex-col md:border-r md:border-neutral-900 md:p-4">
        <div className="px-2">
          <div className="text-sm font-semibold tracking-tight">Mindberzerk</div>
          <div className="mt-0.5 font-mono text-[11px] text-neutral-500">
            {subtitle ?? 'cdn.mindberzerk.com'}
          </div>
        </div>

        <nav className="mt-6 flex flex-col gap-1">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={`rounded-lg px-3 py-2 text-sm transition ${
                pathname === l.href
                  ? 'bg-neutral-800 text-neutral-100'
                  : 'text-neutral-400 hover:bg-neutral-900 hover:text-neutral-200'
              }`}
            >
              {l.label}
            </Link>
          ))}
        </nav>

        <button
          onClick={async () => {
            await signOut();
            router.replace('/login');
            router.refresh();
          }}
          className="mt-auto rounded-lg px-3 py-2 text-left text-sm text-neutral-500 transition hover:text-neutral-200"
        >
          Sign out
        </button>
      </aside>

      <div className="min-w-0 flex-1">
        {/* Header, mobile only */}
        <header className="flex items-baseline justify-between border-b border-neutral-900 px-4 pb-3 pt-[calc(env(safe-area-inset-top)+0.75rem)] md:hidden">
          <div>
            <div className="text-base font-semibold tracking-tight">Mindberzerk</div>
            <div className="font-mono text-[11px] text-neutral-500">
              {subtitle ?? 'cdn.mindberzerk.com'}
            </div>
          </div>
          <button
            onClick={async () => {
              await signOut();
              router.replace('/login');
              router.refresh();
            }}
            className="text-sm text-neutral-500"
          >
            Sign out
          </button>
        </header>

        {/* Bottom padding clears the fixed nav plus the home indicator. */}
        <main className="px-4 pb-[calc(env(safe-area-inset-bottom)+5.5rem)] pt-4 md:mx-auto md:max-w-3xl md:px-8 md:pb-16 md:pt-8">
          {children}
        </main>
      </div>

      {/* Bottom nav, mobile only */}
      <nav className="fixed inset-x-0 bottom-0 z-20 flex border-t border-neutral-900 bg-neutral-950/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
        {LINKS.map((l) => (
          <Link
            key={l.href}
            href={l.href}
            className={`flex flex-1 flex-col items-center gap-0.5 py-2.5 text-[11px] transition ${
              pathname === l.href ? 'text-neutral-100' : 'text-neutral-500'
            }`}
          >
            <span className="text-base leading-none">{l.icon}</span>
            {l.label}
          </Link>
        ))}
      </nav>
    </div>
  );
}
