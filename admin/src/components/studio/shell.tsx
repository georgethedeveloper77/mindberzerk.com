'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

import { ThemeToggle } from '@/components/site/theme-toggle';
import { signOut } from '@/lib/core/firebase-client';
import { MANAGED, appMeta } from '@/lib/core/registry';

/**
 * THE SHELL, studio and per-app.
 *
 * `app/components/shell.tsx` is still the console frame: dark-only, built on
 * the `surface-*` tokens, wrapping the per-app screens that have not been
 * redesigned yet. This is the same navigation in the soft register, and it now
 * takes an optional `app`, which is how the console frame gets retired one
 * screen at a time rather than in one unreviewable change.
 *
 * A screen migrates by swapping `Shell` for `StudioShell`. When the last one
 * has moved, `app/components/shell.tsx` is deleted.
 *
 * ## `data-surface="soft"` LIVES HERE, ON THE ROOT
 *
 * `globals.css` keys the page canvas off that attribute, because `body` is
 * painted `surface-0` for the console and `html` is pinned to dark. Putting the
 * marker on this component rather than on a route layout means a screen gets
 * the correct canvas by using this shell, and cannot get it wrong by forgetting
 * a layout file. A per-app route layout would have been worse than wrong: it
 * would have lit up every sibling screen that is still dark.
 *
 * ## THE APP SECTION IS TINTED BY THE REGISTRY
 *
 * `AppMeta.tint` carries no status meaning, which is exactly why it is safe for
 * recognition. The section's left border, the active item's wash and the slab
 * on the page all use it, so which app you are inside is legible from colour
 * before you read a label.
 */

const STUDIO_NAV = [
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

interface Section {
  label: string;
  /** Absent means the screen does not exist yet. Rendered, not linked. */
  href?: string;
}

/**
 * The launcher's sections, grouped.
 *
 * Ten flat links is a list you scan rather than a nav you use. Each heading
 * answers a different question: Content is what is in the bucket and how to put
 * something there, Delivery is the substrate everything else sits on, Store is
 * what it costs and whether anyone can buy it, App is everything that
 * configures the app rather than its content.
 */
function sectionsFor(app: string): { label: string; items: Section[] }[] {
  return [
    { label: '', items: [{ label: 'Overview', href: `/apps/${app}` }] },
    {
      label: 'Content',
      items: [
        ...(app === 'g-launcher'
          ? [
              { label: 'Distros', href: `/apps/${app}/distros` },
              { label: 'Icons', href: `/apps/${app}/icons` },
            ]
          : []),
        ...(app === 'g-recovery' ? [{ label: 'Guides', href: `/apps/${app}/guides` }] : []),
        { label: 'Upload pack', href: `/apps/${app}/publish` },
      ],
    },
    { label: 'Delivery', items: [{ label: 'CDN objects', href: `/apps/${app}/packs` }] },
    {
      label: 'Store',
      items: [
        { label: 'Commerce', href: `/apps/${app}/commerce` },
        { label: 'Bundles', href: `/apps/${app}/bundles` },
      ],
    },
    {
      label: 'App',
      items: [
        { label: 'Config', href: `/apps/${app}/config` },
        { label: 'Analytics', href: `/apps/${app}/analytics` },
        ...(app === 'g-launcher' ? [{ label: 'Registry', href: `/apps/${app}/registry` }] : []),
        { label: 'Legal', href: `/apps/${app}/legal` },
        // Built now. It renders admin/docs/<app>/architecture.md, and an app
        // with no doc gets an explanation rather than a 404, so this is a real
        // link for every app rather than only for the ones with diagrams.
        { label: 'Architecture', href: `/apps/${app}/architecture` },
      ],
    },
  ];
}

export function StudioShell({ app, children }: { app?: string; children: React.ReactNode }) {
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

  /**
   * PREFIX MATCH, not equality. With `pathname === href`, opening a pack detail
   * at `/apps/g-launcher/packs/kali-theme` highlighted nothing in the rail: the
   * one moment you most want to know where you are is two levels deep. The
   * trailing slash matters, or `/packs` would light for `/packs-archive`.
   */
  const active = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  const meta = app ? appMeta(app) : undefined;

  return (
    <div
      data-surface="soft"
      className="flex min-h-[100dvh] bg-site-page font-site-sans text-site-ink-2"
    >
      <aside className="sticky top-0 hidden h-[100dvh] w-[236px] shrink-0 flex-col overflow-y-auto border-r border-site-line bg-site-card p-3 lg:flex">
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
            <span className="block truncate font-mono text-[11px] text-site-ink-3">
              {meta?.pkg ?? 'mindberzerk.com'}
            </span>
          </span>
        </Link>

        {STUDIO_NAV.map((n) => (
          <Link key={n.href} href={n.href} className={item(pathname === n.href)}>
            <svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" aria-hidden>
              {n.icon}
            </svg>
            {n.label}
          </Link>
        ))}

        <div className="mt-4 px-2.5 pb-1.5 text-[10.5px] font-bold uppercase tracking-[0.08em] text-site-ink-3">
          Apps
        </div>

        {MANAGED.map((a) => {
          const current = a.id === app;
          return (
            <div key={a.id}>
              <Link
                href={`/apps/${a.id}`}
                className={`flex items-center gap-2.5 rounded-[9px] px-2.5 py-[7px] text-[13.5px] transition ${
                  current ? 'font-semibold text-site-ink' : 'font-medium text-site-ink-2 hover:bg-site-sunk'
                }`}
              >
                <span className="size-1.5 shrink-0 rounded-full" style={{ background: a.tint }} />
                {a.name}
              </Link>

              {current && (
                <div
                  className="mb-1.5 ml-2.5 border-l-2 pl-2.5"
                  style={{ borderColor: a.tint }}
                >
                  {sectionsFor(a.id).map((group, gi) => (
                    <div key={group.label || `g${gi}`}>
                      {group.label && (
                        <div className="px-2.5 pb-1 pt-2 text-[9.5px] font-bold uppercase tracking-[0.09em] text-site-ink-3">
                          {group.label}
                        </div>
                      )}
                      {group.items.map((s) =>
                        s.href ? (
                          <Link
                            key={s.label}
                            href={s.href}
                            className="block rounded-lg px-2.5 py-1.5 text-[13px] text-site-ink-2 transition hover:bg-site-sunk"
                            style={
                              active(s.href)
                                ? {
                                    background: `color-mix(in srgb, ${a.tint} 15%, transparent)`,
                                    color: 'var(--color-site-ink)',
                                    fontWeight: 600,
                                  }
                                : undefined
                            }
                          >
                            {s.label}
                          </Link>
                        ) : (
                          <span
                            key={s.label}
                            title="Not built yet"
                            className="block cursor-default px-2.5 py-1.5 text-[13px] text-site-ink-3/60"
                          >
                            {s.label}
                          </span>
                        ),
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}

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
