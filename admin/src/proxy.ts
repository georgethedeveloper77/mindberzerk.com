import { NextResponse, type NextRequest } from 'next/server';

/**
 * PHASE C4 — a redirect, NOT a security boundary.
 *
 * READ THIS BEFORE ADDING A ROUTE.
 *
 * This runs on the Edge runtime, which has no Node crypto and therefore cannot
 * run firebase-admin. So it cannot verify a session; it can only see whether a
 * cookie is present. Its entire job is sending a logged-out browser to /login
 * without a wasted round trip.
 *
 * Every route handler and server component that reads the signing key, touches
 * R2, or returns anything non-public calls `requireAdmin()` ITSELF. If you ever
 * catch yourself thinking "the proxy already covered that", that is the bug,
 * and it is the classic Next.js auth hole.
 *
 * NAMED proxy.ts, NOT middleware.ts. Next 16 renamed the convention; the old
 * name still runs but warns, and it will stop working. The file must be a
 * DEFAULT export, unlike `middleware` which was a named one — keeping the named
 * export as well would silently do nothing.
 */
export default function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // ── /admin/* → /* ─────────────────────────────────────────────────────────
  //
  // A CONVENIENCE REDIRECT, NOT A BASE PATH, and the difference is the point.
  //
  // The Next app's project directory is `admin/`, so typing /admin is the
  // natural reflex, and it 404s because a project directory is not a URL
  // segment. The panel is served at the root of admin.mindberzerk.com.
  //
  // The alternative was `basePath: '/admin'` in next.config.ts, which was
  // rejected: the host is ALREADY `admin.`, so every URL would read
  // admin.mindberzerk.com/admin/…, and basePath quietly changes the asset
  // prefix, the cookie path the session route writes, and what `pathname` means
  // inside this very function. That is three subtle breakages to buy a
  // redundant path segment.
  //
  // The prefix is stripped rather than the request being sent to `/`, so a
  // pasted deep link like /admin/apps/g-launcher/commerce lands where it meant
  // to. This runs BEFORE the auth check so /admin/login resolves too.
  if (pathname === '/admin' || pathname.startsWith('/admin/')) {
    const url = request.nextUrl.clone();
    url.pathname = pathname.slice('/admin'.length) || '/';
    return NextResponse.redirect(url);
  }

  const hasCookie = request.cookies.has('__session');

  if (!hasCookie && pathname !== '/login') {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }

  if (hasCookie && pathname === '/login') {
    const url = request.nextUrl.clone();
    url.pathname = '/';
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  // /api is deliberately EXCLUDED. Those routes do their own verification and
  // must return 401 JSON, not a 307 to an HTML login page — a redirect there
  // turns an auth failure into a confusing parse error at the caller.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
