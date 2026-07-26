import { NextResponse } from 'next/server';
import { createSession, NotAuthorised, revokeSession, SESSION_COOKIE } from '@/lib/auth';

/**
 * PHASE C4 - exchange a Firebase ID token for a session cookie.
 *
 * The client signs in with the Firebase JS SDK, gets an ID token, and posts it
 * here exactly once. From then on the browser holds an httpOnly cookie and the
 * ID token is never stored anywhere, which is the point: a token in
 * localStorage is readable by any script that gets onto the page.
 */

/** Five days. Firebase caps session cookies at 14. */
const MAX_AGE_MS = 5 * 24 * 60 * 60 * 1000;

export async function POST(request: Request) {
  let idToken: string;
  try {
    ({ idToken } = await request.json());
  } catch {
    return NextResponse.json({ error: 'Bad request' }, { status: 400 });
  }
  if (!idToken) return NextResponse.json({ error: 'Bad request' }, { status: 400 });

  try {
    const cookie = await createSession(idToken, MAX_AGE_MS);
    const response = NextResponse.json({ ok: true });
    response.cookies.set({
      name: SESSION_COOKIE,
      value: cookie,
      maxAge: MAX_AGE_MS / 1000,
      // httpOnly: unreadable from JS, which is the whole reason for the
      // exchange. secure + lax: this is a same-site login, and strict would
      // break the redirect back from the Google sign-in popup on some browsers.
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      path: '/',
    });
    return response;
  } catch (e) {
    if (e instanceof NotAuthorised) {
      // Same 403 whether the UID is unknown or the token is forged. The
      // difference is only useful to someone probing.
      return NextResponse.json({ error: 'Not authorised' }, { status: 403 });
    }
    console.error('Session creation failed', e);
    return NextResponse.json({ error: 'Sign-in failed' }, { status: 500 });
  }
}

export async function DELETE() {
  await revokeSession();
  const response = NextResponse.json({ ok: true });
  response.cookies.delete(SESSION_COOKIE);
  return response;
}
