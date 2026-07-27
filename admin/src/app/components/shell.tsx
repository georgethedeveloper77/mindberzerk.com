'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { signOut } from '@/lib/firebase-client';
import { MANAGED, appName } from '@/lib/registry';

/**
 * PHASE C5 - the frame, now multi-app.
 *
 * ## What changed and why
 *
 * The old rail listed three flat links, one of which (`/bundles`) had no page
 * behind it and 404'd. Nav is now derived from the registry, so an app appears
 * here exactly when `managed: true`, and a section appears when it has a route.
 * Sections with no route yet are rendered as disabled text rather than omitted:
 * knowing the shape of the thing you are building is worth one grey line, and a
 * link that 404s is worse than a label that does not click.
 *
 * ## MOBILE FIRST, still, and not as a slogan
 *
 * The realistic moment you publish is standing somewhere with a phone, having
 * spotted that an icon is wrong. Below `md` the navigation is a fixed bottom bar
 * because a top bar puts every tap at the far end of the thumb's reach; above it
 * the bar becomes a left rail, because a bottom bar on a wide screen is a phone
 * app in a browser.
 *
 * `pb-[calc(...)]` on the content and `pb-[env(safe-area-inset-bottom)]` on the
 * bar are both load-bearing on iOS: without them the last row of content sits
 * under the nav, and the nav itself sits under the home indicator.
 */

interface Section {
  label: string;
  /** Absent means the screen does not exist yet. Rendered, not linked. */
  href?: string;
}

interface Group {
  label: string;
  sections: Section[];
}

/**
 * GROUPED, because ten flat links is a list you scan rather than a nav you use.
 *
 * The rail grew one entry at a time and ended up as an undifferentiated column
 * where Packs, Commerce and Registry all looked equally likely to be the thing
 * you wanted. Three groups is the smallest split that actually carries meaning,
 * and each answers a different question:
 *
 *   Content   what is in the bucket, and how do I put something there
 *   Store     what does it cost, and can anyone actually buy it
 *   App       everything that configures the app rather than its content
 *
 * The headings are labels, not links. A heading you can click competes with the
 * items under it and neither reads as the target.
 */
function groupsFor(app: string): Group[] {
  return [
    {
      // Not a group heading with one item under it: this is the landing, and
      // giving it a heading would imply siblings it does not have.
      label: '',
      sections: [{ label: 'Overview', href: `/apps/${app}` }],
    },
    {
      label: 'Content',
      sections: [
        // Launcher-only. Listing these under G Recovery would promise something
        // the app does not have.
        //
        // THEMES IS GONE FROM HERE, and that is the point rather than an
        // omission. A theme and a distro were the same artifact behind two
        // names, so the rail offered two entries that led to two views of one
        // list, and "where is Ubuntu" had two answers.
        //
        // Distros points at the INVENTORY, not at the builder. It used to link
        // straight to `/distros/builder`, so the nav's only route into distros
        // was a blank new-distro form and there was nowhere to see what already
        // existed. The builder is reached from a card.
        ...(app === 'g-launcher'
          ? [
              { label: 'Distros', href: `/apps/${app}/distros` },
              { label: 'Icons', href: `/apps/${app}/icons` },
            ]
          : []),
        // G Recovery's product is per-brand OEM recovery guidance, not packs.
        ...(app === 'g-recovery'
          ? [{ label: 'Guides', href: `/apps/${app}/guides` }]
          : []),

        // Upload pack was called "Publish" and sat second, which read as the
        // normal way to work. It is the escape hatch: the only route that can
        // publish a pack type no builder covers, which is not hypothetical,
        // because `simple-icons` is a brand pack of 3,449 glyphs and nothing
        // builds brand packs. It is also the only way in for a pack authored
        // outside the panel. It belongs beside the things it creates.
        { label: 'Upload pack', href: `/apps/${app}/publish` },
      ],
    },
    {
      // ── PACKS IS NOT A PEER OF DISTROS AND ICONS ─────────────────────────
      //
      // It is their SUPERSET, and sitting in the same group implied otherwise.
      // Everything on the CDN is a pack; `packType` says which kind. Distros
      // filters to `theme`, Icons filters to `hero`/`brand`/`icon`, and this
      // shows all of them plus the delivery detail neither product view has:
      // the bucket path, the version, the signed manifest, the file list and
      // every sha256.
      //
      // It also holds two things that exist nowhere else: Unpublish, and
      // `simple-icons` itself, which is a brand pack of 3,449 glyphs that no
      // builder creates and therefore appears on no product screen.
      //
      // So: its own group, and named for what it is. Three products above, one
      // substrate below.
      label: 'Delivery',
      sections: [{ label: 'CDN objects', href: `/apps/${app}/packs` }],
    },
    {
      label: 'Store',
      sections: [
        // Not launcher-only: any app that sells a pack has the same three
        // systems to keep in step (signed index, listing flags, Play), and the
        // same way of being wrong about it.
        { label: 'Commerce', href: `/apps/${app}/commerce` },
        { label: 'Bundles', href: `/apps/${app}/bundles` },
      ],
    },
    {
      label: 'App',
      sections: [
        { label: 'Config', href: `/apps/${app}/config` },
        { label: 'Analytics', href: `/apps/${app}/analytics` },
        ...(app === 'g-launcher'
          ? [{ label: 'Registry', href: `/apps/${app}/registry` }]
          : []),
      ],
    },
  ];
}

export function Shell({
  app,
  children,
  subtitle,
}: {
  /** The managed app this screen belongs to. Absent on the overview. */
  app?: string;
  children: React.ReactNode;
  /** Kept for the pages that predate this component. Shown under the brand. */
  subtitle?: string;
}) {
  const pathname = usePathname();
  const router = useRouter();

  async function out() {
    await signOut();
    router.replace('/login');
    router.refresh();
  }

  const groups = app ? groupsFor(app) : [];
  const sections = groups.flatMap((g) => g.sections);

  /**
   * PREFIX MATCH, not equality, and this was a real bug.
   *
   * With `pathname === href`, opening a pack detail at
   * `/apps/g-launcher/packs/kali-theme` highlighted NOTHING in the rail: the
   * only screens that ever lit up were the top level of each section. The one
   * moment you most want to know where you are is two levels deep.
   *
   * The trailing slash matters. A bare `startsWith` would light `/packs` for a
   * hypothetical `/packs-archive`, which is the classic version of this fix
   * going slightly wrong.
   */
  const active = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  return (
    <div className="md:flex">
      {/* ── rail, desktop ───────────────────────────────────────────────── */}
      <aside className="hidden md:flex md:h-[100dvh] md:w-60 md:shrink-0 md:flex-col md:border-r md:border-line-soft md:bg-surface-1 md:p-3">
        <Link href="/" className="mb-4 flex items-center gap-2.5 px-2 py-1">
          <span className="grid size-6 shrink-0 place-items-center rounded-md bg-accent font-mono text-micro font-bold text-accent-ink">
            M
          </span>
          <span className="min-w-0">
            <span className="block text-data font-semibold tracking-tight">Mindberzerk</span>
            <span className="block truncate font-mono text-micro text-ink-3">
              {subtitle ?? 'admin.mindberzerk.com'}
            </span>
          </span>
        </Link>

        <Link
          href="/"
          className={`rounded-lg px-2.5 py-1.5 text-data transition ${
            pathname === '/' ? 'bg-surface-3 text-ink' : 'text-ink-2 hover:bg-surface-2'
          }`}
        >
          All apps
        </Link>

        <Link
          href="/site"
          className={`rounded-lg px-2.5 py-1.5 text-data transition ${
            pathname === '/site' ? 'bg-surface-3 text-ink' : 'text-ink-2 hover:bg-surface-2'
          }`}
        >
          Public site
        </Link>

        <nav className="mt-4 flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto">
          {MANAGED.map((a) => {
            const isCurrent = a.id === app;
            return (
              <div key={a.id}>
                <Link
                  href={`/apps/${a.id}/packs`}
                  className={`flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-data transition ${
                    isCurrent ? 'text-ink' : 'text-ink-2 hover:bg-surface-2'
                  }`}
                >
                  <span
                    className="size-1.5 shrink-0 rounded-full"
                    style={{ background: isCurrent ? a.tint : 'var(--color-ink-3)' }}
                  />
                  {a.name}
                </Link>

                {isCurrent && (
                  <div className="mt-1 ml-3 border-l border-line-soft pl-2">
                    {groups.map((g) => (
                      <div key={g.label} className="mb-2 last:mb-0">
                        {/* A blank label is the ungrouped case (Overview). It
                            renders no heading rather than an empty one, which
                            would leave a stray gap above the first item. */}
                        {g.label && (
                          <div className="px-2.5 pb-0.5 text-micro uppercase tracking-wider text-ink-3/70">
                            {g.label}
                          </div>
                        )}
                        {g.sections.map((s) =>
                          s.href ? (
                            <Link
                              key={s.label}
                              href={s.href}
                              className={`block rounded-md px-2.5 py-1 text-data transition ${
                                active(s.href)
                                  ? 'bg-surface-3 text-ink'
                                  : 'text-ink-2 hover:bg-surface-2'
                              }`}
                            >
                              {s.label}
                            </Link>
                          ) : (
                            <span
                              key={s.label}
                              className="block cursor-default px-2.5 py-1 text-data text-ink-3/60"
                              title="Not built yet"
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
        </nav>

        {/* mb-10 clears Next's dev indicator, which is fixed to the bottom-left
            and sat directly on top of this button. It cost nothing in
            production and made Sign out untappable in development, which is
            where this panel is used most. */}
        <button
          onClick={out}
          className="mt-3 mb-10 rounded-lg px-2.5 py-1.5 text-left text-data text-ink-3 transition hover:text-ink md:mb-10"
        >
          Sign out
        </button>
      </aside>

      <div className="min-w-0 flex-1">
        {/* ── header, mobile ───────────────────────────────────────────── */}
        <header className="border-b border-line-soft md:hidden">
          <div className="flex items-baseline justify-between px-4 pb-2 pt-[calc(env(safe-area-inset-top)+0.75rem)]">
            <Link href="/">
              <span className="block text-data font-semibold tracking-tight">
                {app ? appName(app) : 'Mindberzerk'}
              </span>
              <span className="block font-mono text-micro text-ink-3">
                {subtitle ?? 'admin.mindberzerk.com'}
              </span>
            </Link>
            <button onClick={out} className="text-data text-ink-3">
              Sign out
            </button>
          </div>

          {/* Sections scroll horizontally rather than wrapping: a nav that
              changes height as you move between apps shifts the content under
              your thumb. */}
          {sections.length > 0 && (
            <div className="no-bar flex gap-1 overflow-x-auto px-4 pb-2">
              {sections.map((s) =>
                s.href ? (
                  <Link
                    key={s.label}
                    href={s.href}
                    className={`shrink-0 rounded-md px-2.5 py-1 text-data transition ${
                      active(s.href) ? 'bg-surface-3 text-ink' : 'text-ink-3'
                    }`}
                  >
                    {s.label}
                  </Link>
                ) : (
                  <span
                    key={s.label}
                    className="shrink-0 px-2.5 py-1 text-data text-ink-3/50"
                  >
                    {s.label}
                  </span>
                ),
              )}
            </div>
          )}
        </header>

        {/* Bottom padding clears the fixed nav plus the home indicator. */}
        <main className="px-3 pb-[calc(env(safe-area-inset-bottom)+5rem)] pt-3 sm:px-4 md:mx-auto md:max-w-6xl md:px-6 md:pb-14 md:pt-6">
          {children}
        </main>
      </div>

      {/* ── bottom nav, mobile ─────────────────────────────────────────── */}
      <nav className="fixed inset-x-0 bottom-0 z-20 flex border-t border-line-soft bg-surface-1/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
        {[
          { href: '/', label: 'Apps', icon: '\u25A6' },
          // Defaulting to g-launcher keeps the bar's shape constant on the
          // overview, where there is no current app to be contextual about.
          { href: `/apps/${app ?? 'g-launcher'}/packs`, label: 'Packs', icon: '\u25C8' },
          { href: `/apps/${app ?? 'g-launcher'}/publish`, label: 'Publish', icon: '\u2191' },
        ].map((l) => (
          <Link
            key={l.label}
            href={l.href}
            className={`flex flex-1 flex-col items-center gap-0.5 py-2 text-micro transition ${
              pathname === l.href ? 'text-ink' : 'text-ink-3'
            }`}
          >
            <span className="text-sm leading-none">{l.icon}</span>
            {l.label}
          </Link>
        ))}
      </nav>
    </div>
  );
}
