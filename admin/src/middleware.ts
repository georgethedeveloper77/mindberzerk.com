import { NextResponse, type NextRequest } from 'next/server';

/**
 * PHASE C4 — a redirect, NOT a security boundary.
 *
 * READ THIS BEFORE ADDING A ROUTE.
 *
 * Next middleware runs on the Edge runtime, which has no Node crypto and
 * therefore cannot run firebase-admin. So this cannot verify a session; it can
 * only see whether a cookie is present. Its entire job is sending a logged-out
 * browser to /login without a wasted round trip.
 *
 * Every route handler and server component that reads the signing key, touches
 * R2, or returns anything non-public calls `requireAdmin()` ITSELF. If you ever
 * catch yourself thinking "the middleware already covered that", that is the
 * bug, and it is the classic Next.js auth hole.
 */
export function middleware(request: NextRequest) {
  const hasCookie = request.cookies.has('__session');
  const { pathname } = request.nextUrl;

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
