'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';

/**
 * PHASE C4 — the browser half of sign-in, and NOTHING ELSE.
 *
 * The only job here is producing an ID token to post to /api/auth/session. It
 * holds no credentials worth having: the NEXT_PUBLIC_ config identifies the
 * Firebase project, it does not authorise anything, and every real check runs
 * server-side against the UID allowlist.
 *
 * Nothing in this file may import from lib/sign.ts or lib/r2.ts. Both are
 * marked `server-only` so the build would fail, which is the point of the
 * marker.
 */
function app() {
  if (getApps().length) return getApp();
  return initializeApp({
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  });
}

/**
 * Sign in and exchange for a session cookie.
 *
 * The ID token is used ONCE and never stored. After this returns, auth lives
 * entirely in an httpOnly cookie the page cannot read.
 */
export async function signIn(): Promise<{ ok: boolean; error?: string }> {
  try {
    const credential = await signInWithPopup(getAuth(app()), new GoogleAuthProvider());
    const idToken = await credential.user.getIdToken();

    const res = await fetch('/api/auth/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    });

    if (res.status === 403) {
      // Signed in to Firebase successfully, and not on the allowlist. Sign back
      // out locally so the next attempt is a clean one rather than silently
      // reusing the same rejected account.
      await getAuth(app()).signOut();
      return { ok: false, error: 'That account is not authorised for this panel.' };
    }
    if (!res.ok) return { ok: false, error: 'Sign-in failed. Try again.' };

    return { ok: true };
  } catch {
    return { ok: false, error: 'Sign-in was cancelled or blocked.' };
  }
}

export async function signOut() {
  await fetch('/api/auth/session', { method: 'DELETE' });
  await getAuth(app()).signOut();
}
