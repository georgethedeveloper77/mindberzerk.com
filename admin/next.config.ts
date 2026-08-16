import type { NextConfig } from 'next';

/**
 * ─── THE CONSOLE MUST NOT BE CACHED AT AN EDGE ──────────────────────────────
 *
 * `/admin` came back `304` with `Cache-Control: s-maxage=31536000`,
 * `Cdn-Cache-Status: hit` and `Age: 48438`. That is a THIRTEEN HOUR OLD copy of
 * the app shell, served from Firebase App Hosting's CDN, whose default for a
 * static-shell route is a year.
 *
 * The consequence is worse than slow: every deploy is invisible until someone
 * forces a reload, so a change can be shipped, looked at, judged broken and
 * "fixed" twice while the browser has never seen it. This project has already
 * paid for the same mistake once, when `site/content.json` was uploaded with
 * `max-age=31536000 immutable` and publishing was a silent no-op at the edge.
 *
 * ─── WHY THESE ROUTES AND NOT ALL OF THEM ───────────────────────────────────
 *
 * `/` is the public marketing site and SHOULD be cached hard: it is read far
 * more than it is written, and a stale landing page for a few minutes costs
 * nothing. Everything below is the console, which has one user, is written
 * constantly, and is behind an allowlist, so there is no version of it worth
 * keeping at an edge.
 *
 * `no-store` rather than `no-cache` on `/admin` specifically: `no-cache` still
 * stores a copy and revalidates, which is fine for a dashboard and wrong for a
 * sign-in page, where the stored copy can carry a stale auth state.
 *
 * `/_next/static` is untouched and must stay that way. Those filenames are
 * content-hashed, so they are genuinely immutable and caching them for a year
 * is correct.
 */
const consoleRoutes = [
  '/admin',
  '/dashboard',
  '/apps/:path*',
  '/site',
  '/registry',
  '/legal/:path*',
];

const nextConfig: NextConfig = {
  /**
   * THE ARCHITECTURE DOCS ARE READ BY PATH AT RUNTIME, NOT IMPORTED.
   *
   * The standalone build copies files it can see being imported. `readFile` on
   * a path is invisible to that trace, so without this the docs directory is
   * simply absent in production and every architecture page reports "no
   * document yet" while the file sits happily in the repo.
   *
   * Keyed by route so only that page carries them.
   */
  outputFileTracingIncludes: {
    '/apps/[app]/architecture': ['./docs/**/*'],
  },

  async headers() {
    return [
      {
        source: '/admin',
        headers: [
          {
            key: 'Cache-Control',
            // `private` keeps it out of any shared cache; `no-store` keeps it
            // out of the browser's too. A sign-in page held anywhere is a page
            // that can show a signed-out shell to someone who just signed in.
            value: 'private, no-store, max-age=0, must-revalidate',
          },
        ],
      },
      ...consoleRoutes
        .filter((s) => s !== '/admin')
        .map((source) => ({
          source,
          headers: [
            {
              key: 'Cache-Control',
              // The browser may keep a copy and revalidate; the CDN may not
              // keep one at all. `s-maxage=0` is the half that matters here,
              // since the shared cache is what served a thirteen hour old
              // shell.
              value: 'private, no-cache, s-maxage=0, must-revalidate',
            },
          ],
        })),
    ];
  },

  experimental: {
    serverActions: {
      /**
       * A DRAFT SAVE IS BINARY, AND 1MB IS THE DEFAULT.
       *
       * Every draft in this panel travels through a Server Action carrying the
       * actual bytes: wallpapers, two logos, and up to thirty-nine composed
       * icons at 192px. A single webp wallpaper clears the default limit on its
       * own, and the failure is a red toast reading "Body exceeded 1 MB limit"
       * with the work still unsaved.
       *
       * 12mb rather than something larger, deliberately. This is a ceiling
       * against a runaway upload, not a target: the number should be high
       * enough that authoring a real distro never hits it and low enough that a
       * mistake still fails fast. A full icon pack of forty composed PNGs plus
       * a wallpaper lands around 2 to 4mb, so this leaves room for a pack twice
       * that size before anyone has to think about it again.
       *
       * PUBLISH IS UNAFFECTED and always was. That path is a route handler with
       * FormData, not a Server Action, which is why publishing large packs has
       * worked all along while saving a draft of the same pack did not.
       */
      bodySizeLimit: '12mb',
    },
  },
};

export default nextConfig;
