'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import {
  getAuth,
  getRedirectResult,
  GoogleAuthProvider,
  signInWithRedirect,
  type UserCredential,
} from 'firebase/auth';

/**
 * PHASE C4 - the browser half of sign-in, and NOTHING ELSE.
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

/** Where the user was headed before the gate sent them here. */
const RETURN_KEY = 'mb.signin.return';

/**
 * Start sign-in. DOES NOT RETURN.
 *
 * ─── REDIRECT, NOT POPUP, AND WHY IT CHANGED ────────────────────────────────
 *
 * `signInWithPopup` needs the opener link between this page and the popup: it
 * polls `window.closed` to notice a cancelled sign-in and calls `close()` when
 * it is done. Google sets `Cross-Origin-Opener-Policy: same-origin` on
 * accounts.google.com, which severs that link from their end. The console fills
 * with "COOP policy would block the window.closed call", the SDK cannot tell a
 * finished sign-in from an abandoned one, and it reports the whole thing as
 * cancelled even when the user signed in perfectly.
 *
 * That header is Google's and cannot be changed from here, so the popup is the
 * wrong mechanism rather than a broken one. Redirect has no opener to sever,
 * and it also drops popup blockers, third-party cookie policy and in-app
 * browsers as failure modes at the same time.
 *
 * The cost is that in-page continuity is lost: the page unloads and comes back
 * as a fresh load. For a panel with one user signing in rarely, that is not a
 * cost worth defending, which is why the return path below is a sessionStorage
 * key rather than anything more careful.
 */
export async function signIn(returnTo?: string): Promise<void> {
  try {
    // Written BEFORE the redirect, because after it there is no "after": this
    // document is gone. Session storage rather than local, so it cannot outlive
    // the tab and send someone to a page they wanted an hour ago.
    if (returnTo) sessionStorage.setItem(RETURN_KEY, returnTo);
  } catch {
    // Private mode, or storage disabled. The redirect still works and lands on
    // the default destination, which is a smaller loss than refusing to sign in.
  }
  await signInWithRedirect(getAuth(app()), new GoogleAuthProvider());
}

export type SignInOutcome =
  /** No redirect was in flight. The ordinary first visit. */
  | { state: 'idle' }
  /** Session cookie set. [returnTo] is where they were headed, if known. */
  | { state: 'ok'; returnTo: string | null }
  | { state: 'error'; error: string };

/**
 * Finish a sign-in that a redirect started.
 *
 * ─── THIS MUST BE CALLED ON MOUNT OR SIGN-IN SILENTLY DOES NOTHING ──────────
 *
 * With a popup, the token exchange happened inside `signIn`. With a redirect
 * there is no such moment: the user comes back as a fresh page load carrying a
 * pending credential that only `getRedirectResult` can collect. If nothing
 * calls this, someone signs in with Google, returns to the panel, and is shown
 * the sign-in screen again with no error and nothing in the log.
 *
 * `{ state: 'idle' }` for a normal visit, so the caller can tell "no redirect
 * happened" from "a redirect happened and failed" and avoid flashing an error
 * on every first load.
 *
 * The ID token is used ONCE and never stored. After this, auth lives entirely
 * in an httpOnly cookie the page cannot read.
 */
export async function completeSignIn(): Promise<SignInOutcome> {
  let credential: UserCredential | null;
  try {
    credential = await getRedirectResult(getAuth(app()));
  } catch {
    return { state: 'error', error: 'Sign-in was cancelled or blocked.' };
  }
  if (!credential) return { state: 'idle' };

  let returnTo: string | null = null;
  try {
    returnTo = sessionStorage.getItem(RETURN_KEY);
    sessionStorage.removeItem(RETURN_KEY);
  } catch {
    // Same as above: no destination is a fallback, not a failure.
  }

  try {
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
      return {
        state: 'error',
        error: 'That account is not authorised for this panel.',
      };
    }
    if (!res.ok) return { state: 'error', error: 'Sign-in failed. Try again.' };

    return { state: 'ok', returnTo };
  } catch {
    return { state: 'error', error: 'Sign-in failed. Try again.' };
  }
}

export async function signOut() {
  await fetch('/api/auth/session', { method: 'DELETE' });
  await getAuth(app()).signOut();
}
