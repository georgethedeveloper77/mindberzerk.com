import { NextResponse, type NextRequest } from 'next/server';

/**
 * PHASE C4 - a redirect, NOT a security boundary.
 *
 * READ THIS BEFORE ADDING A ROUTE.
 *
 * This runs on the Edge runtime, which has no Node crypto and therefore cannot
 * run firebase-admin. So it cannot verify a session; it can only see whether a
 * cookie is present. Its entire job is sending a logged-out browser to the
 * sign-in page without a wasted round trip.
 *
 * Every route handler and server component that reads the signing key, touches
 * R2, or returns anything non-public calls `requireAdmin()` ITSELF. If you ever
 * catch yourself thinking "the proxy already covered that", that is the bug,
 * and it is the classic Next.js auth hole.
 *
 * NAMED proxy.ts, NOT middleware.ts. Next 16 renamed the convention; the old
 * name still runs but warns, and it will stop working. The file must be a
 * DEFAULT export, unlike `middleware` which was a named one - keeping the named
 * export as well would silently do nothing.
 */

/** Where a signed-out browser is sent. A real page, not a redirect target. */
const SIGN_IN = '/admin';

/** Where a signed-in browser lands. Was `/`; `/` is the public site now. */
const CONSOLE = '/dashboard';

/**
 * ── THE PUBLIC ALLOWLIST ─────────────────────────────────────────────────
 *
 * This app now serves two things from one origin: mindberzerk.com for anyone,
 * and the console for an allowlisted admin. The default is still "signed out
 * means sign in", so public routes are named here EXPLICITLY rather than being
 * whatever happens to fall through. An allowlist that must be edited to expose
 * a path is the version of this that fails safe.
 *
 * Exact matches only. A prefix rule here would be one careless entry away from
 * exposing a console route that merely starts with the same characters.
 */
const PUBLIC = new Set<string>(['/']);

export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // ── /admin IS THE SIGN-IN PAGE; /admin/* IS STILL STRIPPED ────────────────
  //
  // A URL like mindberzerk.com/admin/apps/g-launcher/commerce is the app
  // directory name leaking into the path. That prefix is still stripped, so a
  // pasted deep link lands where it meant to.
  //
  // BARE `/admin` NO LONGER STRIPS, because it is now a page: the sign-in
  // screen lives at `app/admin/page.tsx`. That is the one visible URL an
  // unauthenticated visitor sees, and `/admin` reads as the front door in a way
  // `/login` does not.
  //
  // The order matters. Checking `startsWith('/admin/')` BEFORE the equality
  // check would send `/admin` itself into the strip branch and redirect it to
  // the console, which redirects back to `/admin`, which is a loop. The exact
  // match is handled by falling through to the auth checks below.
  //
  // The strip target is CONSOLE, not '/'. Stripping to '/' now lands a deep
  // link on the public homepage, which is not where the person was going.
  if (pathname !== SIGN_IN && pathname.startsWith('/admin/')) {
    const url = request.nextUrl.clone();
    url.pathname = pathname.slice('/admin'.length) || CONSOLE;
    return NextResponse.redirect(url);
  }

  // The public site is served to anyone, cookie or not. Checked before the
  // cookie branches so a signed-in admin can still read their own homepage
  // instead of being bounced into the console by their session.
  if (PUBLIC.has(pathname)) return NextResponse.next();

  const hasCookie = request.cookies.has('__session');

  if (!hasCookie && pathname !== SIGN_IN) {
    const url = request.nextUrl.clone();
    url.pathname = SIGN_IN;
    return NextResponse.redirect(url);
  }

  if (hasCookie && pathname === SIGN_IN) {
    const url = request.nextUrl.clone();
    url.pathname = CONSOLE;
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  // /api is deliberately EXCLUDED. Those routes do their own verification and
  // must return 401 JSON, not a 307 to an HTML login page - a redirect there
  // turns an auth failure into a confusing parse error at the caller.
  //
  // That exclusion is also what keeps /api/contact reachable for a public
  // visitor: it is a public endpoint by design and enforces its own limits
  // (honeypot, rate limit, validation) rather than a session.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
