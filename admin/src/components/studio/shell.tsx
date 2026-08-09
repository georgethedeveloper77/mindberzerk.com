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

/**
 * ICONS FOR THE SUB NAV, one per screen.
 *
 * Every item below the app used to be text at one size, so a rail of eleven
 * links had nothing findable by shape and you read all of them every time. Same
 * 16 box and 1.6 stroke as the studio nav above, so the two halves are one
 * navigation rather than a list bolted under a menu.
 */
const GLYPH: Record<string, React.ReactNode> = {
  overview: (
    <>
      <rect x="2" y="2.5" width="12" height="11" rx="2" />
      <path d="M2 6.5h12" />
    </>
  ),
  coverage: (
    <>
      <path d="M2.5 4.5h4l1.2 1.6H13.5v6.4a1 1 0 01-1 1h-9a1 1 0 01-1-1z" />
      <path d="M5.5 9.5h5" />
    </>
  ),
  storage: (
    <>
      <ellipse cx="8" cy="4" rx="5.5" ry="2" />
      <path d="M2.5 4v8c0 1.1 2.5 2 5.5 2s5.5-.9 5.5-2V4" />
      <path d="M2.5 8c0 1.1 2.5 2 5.5 2s5.5-.9 5.5-2" />
    </>
  ),
  learn: (
    <>
      <circle cx="8" cy="8" r="6" />
      <path d="M8 11.5v.01M6.5 6.2A1.6 1.6 0 018 5.2c1 0 1.7.6 1.7 1.5 0 1.3-1.7 1.3-1.7 2.6" />
    </>
  ),
  brand: (
    <>
      <path d="M8 2l5.2 2.4v4.2c0 2.6-2.1 4.4-5.2 5.4-3.1-1-5.2-2.8-5.2-5.4V4.4z" />
    </>
  ),
  cdn: (
    <>
      <path d="M4.6 12.5a3 3 0 01-.3-6 4 4 0 017.7-1 2.8 2.8 0 01.3 5.5" />
      <path d="M8 8v5.5M6 11.6L8 13.6l2-2" />
    </>
  ),
  upload: (
    <>
      <path d="M8 12.5V3.5M5.4 6.1L8 3.5l2.6 2.6" />
      <path d="M2.8 12.8v.7h10.4v-.7" />
    </>
  ),
  commerce: (
    <>
      <path d="M2.5 3.5h1.8l1.5 7h6.2l1.5-5H5" />
      <circle cx="6.6" cy="13" r="1" />
      <circle cx="11.6" cy="13" r="1" />
    </>
  ),
  bundles: (
    <>
      <rect x="2.5" y="5.5" width="11" height="8" rx="1.5" />
      <path d="M2.5 8.5h11M8 5.5v8" />
    </>
  ),
  config: (
    <>
      <path d="M3 5h10M3 8h10M3 11h10" />
      <circle cx="6" cy="5" r="1.4" />
      <circle cx="10.5" cy="11" r="1.4" />
    </>
  ),
  analytics: (
    <>
      <path d="M2.5 13.5h11" />
      <path d="M4.5 11V7M7.5 11V3.5M10.5 11V8.5" />
    </>
  ),
  legal: (
    <>
      <path d="M4 2.5h5l3 3v8a1 1 0 01-1 1H4a1 1 0 01-1-1v-10a1 1 0 011-1z" />
      <path d="M6 8.5h4M6 11h4" />
    </>
  ),
  architecture: (
    <>
      <rect x="5.5" y="2" width="5" height="3.5" rx="1" />
      <rect x="1.5" y="10.5" width="4.5" height="3.5" rx="1" />
      <rect x="10" y="10.5" width="4.5" height="3.5" rx="1" />
      <path d="M8 5.5v2.8M3.8 10.5V8.3h8.4v2.2" />
    </>
  ),
  registry: (
    <>
      <rect x="2" y="2.5" width="12" height="11" rx="2" />
      <path d="M2 6h12M6 6v7.5" />
    </>
  ),
  distros: (
    <>
      <rect x="2.5" y="2.5" width="11" height="8" rx="1.5" />
      <path d="M5.5 13.5h5" />
    </>
  ),
  icons: (
    <>
      <rect x="2.5" y="2.5" width="4.5" height="4.5" rx="1.2" />
      <rect x="9" y="2.5" width="4.5" height="4.5" rx="1.2" />
      <rect x="2.5" y="9" width="4.5" height="4.5" rx="1.2" />
      <rect x="9" y="9" width="4.5" height="4.5" rx="1.2" />
    </>
  ),
};

interface Section {
  label: string;
  /** Absent means the screen does not exist yet. Rendered, not linked. */
  href?: string;
  /** Key into [GLYPH]. */
  icon: string;
}

/**
 * TWO GROUPS, and the reason is arithmetic before it is taste.
 *
 * It was four: Content, Delivery, Store, App. For G Recovery that produced
 * fifteen lines in the rail for eleven destinations, and the footer with Sign
 * out fell off the bottom of a laptop screen. Store held one item and Delivery
 * held two, which is more heading than list.
 *
 * The split that survives is the one a person actually navigates by: CONTENT is
 * what you write and publish, MANAGE is everything else about the app. Overview
 * stays ungrouped above both, because it is where you land.
 */
function sectionsFor(app: string): { label: string; items: Section[] }[] {
  return [
    { label: '', items: [{ label: 'Overview', href: `/apps/${app}`, icon: 'overview' }] },
    {
      label: 'Content',
      items: [
        ...(app === 'g-launcher'
          ? [
              { label: 'Distros', href: `/apps/${app}/distros`, icon: 'distros' },
              { label: 'Icons', href: `/apps/${app}/icons`, icon: 'icons' },
            ]
          : []),
        // COVERAGE FIRST. It is the screen this app's whole pipeline exists for.
        // Storage second, because it is what a person reads first. Learn is the
        // short answer behind an info icon rather than a manual, so it sits
        // under both.
        ...(app === 'g-recovery'
          ? [
              { label: 'Coverage', href: `/apps/${app}/coverage`, icon: 'coverage' },
              { label: 'Storage', href: `/apps/${app}/storage`, icon: 'storage' },
              { label: 'Learn', href: `/apps/${app}/learn`, icon: 'learn' },
              { label: 'Brand guidance', href: `/apps/${app}/guides`, icon: 'brand' },
            ]
          : []),
      ],
    },
    {
      label: 'Manage',
      items: [
        { label: 'CDN objects', href: `/apps/${app}/packs`, icon: 'cdn' },
        // An escape hatch that publishes any pack type by hand, so it belongs
        // beside the objects rather than beside the editors.
        { label: 'Upload pack', href: `/apps/${app}/publish`, icon: 'upload' },
        { label: 'Commerce', href: `/apps/${app}/commerce`, icon: 'commerce' },
        // BUNDLES IS LAUNCHER ONLY. A bundle grants a named list of paid packs.
        // G Recovery sells one unlock and no packs.
        ...(app === 'g-launcher'
          ? [{ label: 'Bundles', href: `/apps/${app}/bundles`, icon: 'bundles' }]
          : []),
        { label: 'Config', href: `/apps/${app}/config`, icon: 'config' },
        { label: 'Analytics', href: `/apps/${app}/analytics`, icon: 'analytics' },
        ...(app === 'g-launcher'
          ? [{ label: 'Registry', href: `/apps/${app}/registry`, icon: 'registry' }]
          : []),
        { label: 'Legal', href: `/apps/${app}/legal`, icon: 'legal' },
        { label: 'Architecture', href: `/apps/${app}/architecture`, icon: 'architecture' },
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
      {/* THE FOOTER IS PINNED AND THE MIDDLE SCROLLS.

          It used to be one scrolling column with `mt-auto` on the footer, which
          works right up until the list is taller than the viewport. For G
          Recovery it was: fifteen lines pushed Sign out below the fold, and the
          notification badge landed on top of what was left of it. A nav you
          have to scroll to sign out of is a nav with a bug in it. */}
      <aside className="sticky top-0 hidden h-[100dvh] w-[236px] shrink-0 flex-col border-r border-site-line bg-site-card lg:flex">
        <Link href="/dashboard" className="flex items-center gap-2.5 px-5 pb-4 pt-4">
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

        <div className="min-h-0 flex-1 overflow-y-auto px-3">
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
                <div className="mb-1.5 ml-3 pl-1">
                  {sectionsFor(a.id).map((group, gi) => (
                    <div key={group.label || `g${gi}`}>
                      {group.label && (
                        <div className="px-2.5 pb-1 pt-2.5 text-[9.5px] font-bold uppercase tracking-[0.09em] text-site-ink-3">
                          {group.label}
                        </div>
                      )}
                      {group.items.map((s) => {
                        const on = !!s.href && active(s.href);
                        const body = (
                          <>
                            {/* THE ACTIVE MARK IS A BAR, NOT A FILL.

                                A filled block read as a separate widget sitting
                                inside the group rather than as one item in it,
                                and it was heavier than the app row above it,
                                which is its parent. A 2px bar in the app tint
                                says "you are here" without outweighing the
                                thing it belongs to. */}
                            <span
                              aria-hidden
                              className="absolute inset-y-[3px] left-0 w-[2px] rounded-full"
                              style={{ background: on ? a.tint : 'transparent' }}
                            />
                            <svg
                              width="15"
                              height="15"
                              viewBox="0 0 16 16"
                              fill="none"
                              stroke="currentColor"
                              strokeWidth="1.6"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              className="shrink-0"
                              aria-hidden
                            >
                              {GLYPH[s.icon] ?? GLYPH.overview}
                            </svg>
                            <span className="truncate">{s.label}</span>
                          </>
                        );

                        const shell =
                          'relative flex items-center gap-2.5 rounded-lg py-[6px] pl-3 pr-2.5 text-[13px] transition';

                        return s.href ? (
                          <Link
                            key={s.label}
                            href={s.href}
                            className={`${shell} ${
                              on
                                ? 'font-semibold text-site-ink'
                                : 'text-site-ink-2 hover:bg-site-sunk hover:text-site-ink'
                            }`}
                            style={
                              on
                                ? { background: `color-mix(in srgb, ${a.tint} 10%, transparent)` }
                                : undefined
                            }
                          >
                            {body}
                          </Link>
                        ) : (
                          <span
                            key={s.label}
                            title="Not built yet"
                            className={`${shell} cursor-default text-site-ink-3/60`}
                          >
                            {body}
                          </span>
                        );
                      })}
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}

        </div>

        <div className="border-t border-site-line p-3">
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
