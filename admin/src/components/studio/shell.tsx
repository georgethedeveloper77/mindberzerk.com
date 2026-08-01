'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

import { ThemeToggle } from '@/components/site/theme-toggle';
import { signOut } from '@/lib/core/firebase-client';
import { MANAGED } from '@/lib/core/registry';

/**
 * THE STUDIO SHELL, and it is deliberately temporary.
 *
 * `app/components/shell.tsx` is the console frame: dark-only, built on the
 * `surface-*` tokens, wrapping every per-app screen. This is the same
 * navigation in the soft register, and for now it wraps ONE screen.
 *
 * Two frames coexisting is a cost, and it is the smaller one. The alternative
 * was to flip `--color-surface-*` and `--color-ink*` to mode-aware values in a
 * single edit, which would light-mode the entire console at once, including
 * twenty screens nobody has looked at in this register and several that paint
 * text directly onto a tint. That is the right MECHANISM for the full restyle
 * and the wrong size of change to make while the dashboard is the only screen
 * that has been designed for it.
 *
 * So: this ships with the dashboard, the console keeps its frame, and the
 * restyle phase moves the rest and deletes one of these two files. Clicking
 * into an app crosses a visible seam until then. That seam is a to-do, not a
 * design.
 */

const NAV = [
  {
    href: '/dashboard',
    label: 'Dashboard',
    icon: (
      <>
        <rect x="2" y="2" width="5" height="5" rx="1.2" />
        <rect x="9" y="2" width="5" height="5" rx="1.2" />
        <rect x="2" y="9" width="5" height="5" rx="1.2" />
        <rect x="9" y="9" width="5" height="5" rx="1.2" />
      </>
    ),
  },
  {
    href: '/site',
    label: 'Site content',
    icon: (
      <>
        <rect x="2" y="3" width="12" height="10" rx="2" />
        <path d="M2 6.5h12" />
      </>
    ),
  },
  {
    href: '/legal/studio',
    label: 'Studio legal',
    icon: (
      <>
        <path d="M4 2.5h5l3 3v8a1 1 0 01-1 1H4a1 1 0 01-1-1v-10a1 1 0 011-1z" />
        <path d="M6 8.5h4M6 11h4" />
      </>
    ),
  },
  {
    // The STUDIO's apps, not the launcher's third-party list. That one lives at
    // /apps/g-launcher/registry and stays there.
    href: '/registry',
    label: 'App registry',
    icon: (
      <>
        <rect x="2" y="2.5" width="12" height="11" rx="2" />
        <path d="M2 6h12M6 6v7.5" />
      </>
    ),
  },
];

export function StudioShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();

  async function out() {
    await signOut();
    router.replace('/admin');
    router.refresh();
  }

  const item = (active: boolean) =>
    `flex items-center gap-2.5 rounded-[9px] px-2.5 py-[7px] text-[13.5px] transition ${
      active
        ? 'bg-site-accent-soft font-semibold text-site-accent-deep'
        : 'font-medium text-site-ink-2 hover:bg-site-sunk'
    }`;

  return (
    <div className="flex min-h-[100dvh] bg-site-page font-site-sans text-site-ink-2">
      <aside className="sticky top-0 hidden h-[100dvh] w-[228px] shrink-0 flex-col border-r border-site-line bg-site-card p-3 lg:flex">
        <Link href="/dashboard" className="flex items-center gap-2.5 px-2 pb-4 pt-1.5">
          <span
            aria-hidden
            className="relative size-7 shrink-0 rounded-[9px]"
            style={{
              background: 'conic-gradient(from 210deg at 60% 40%, #6d4ae8, #a04ae8, #e8703a, #6d4ae8)',
            }}
          >
            <span className="absolute inset-2 rounded-[3px] bg-site-card" />
          </span>
          <span className="min-w-0">
            <span className="block text-sm font-bold tracking-tight text-site-ink">Mindberzerk</span>
            <span className="block truncate text-[11px] text-site-ink-3">mindberzerk.com</span>
          </span>
        </Link>

        {NAV.map((n) => (
          <Link key={n.href} href={n.href} className={item(pathname === n.href)}>
            <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden>
              {n.icon}
            </svg>
            {n.label}
          </Link>
        ))}

        <div className="mt-[18px] px-2.5 pb-1.5 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
          Apps
        </div>
        {MANAGED.map((a) => (
          <Link key={a.id} href={`/apps/${a.id}`} className={item(false)}>
            <span className="size-1.5 shrink-0 rounded-full" style={{ background: a.tint }} />
            {a.name}
          </Link>
        ))}

        <div className="mt-auto border-t border-site-line pt-3">
          <a href="/" target="_blank" rel="noreferrer" className={item(false)}>
            View the site
          </a>
          <button onClick={out} className={`${item(false)} w-full text-left`}>
            Sign out
          </button>
        </div>
      </aside>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2.5 px-5 py-3.5 sm:px-6">
          {/* The brand repeats below lg, where the rail is gone entirely. */}
          <Link href="/dashboard" className="flex items-center gap-2 lg:hidden">
            <span
              aria-hidden
              className="relative size-6 shrink-0 rounded-lg"
              style={{
                background: 'conic-gradient(from 210deg at 60% 40%, #6d4ae8, #a04ae8, #e8703a, #6d4ae8)',
              }}
            >
              <span className="absolute inset-[7px] rounded-[2px] bg-site-page" />
            </span>
            <span className="text-sm font-bold tracking-tight text-site-ink">Mindberzerk</span>
          </Link>
          <div className="flex-1" />
          <ThemeToggle />
          <button
            onClick={out}
            className="rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-ink-3/45 lg:hidden"
          >
            Sign out
          </button>
        </div>

        <main className="flex flex-col gap-4 px-5 pb-16 sm:px-6">{children}</main>
      </div>
    </div>
  );
}
