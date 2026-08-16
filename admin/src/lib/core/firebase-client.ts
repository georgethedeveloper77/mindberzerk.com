'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
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

/**
 * Sign in and exchange for a session cookie.
 *
 * The ID token is used ONCE and never stored. After this returns, auth lives
 * entirely in an httpOnly cookie the page cannot read.
 */
/**
 * Trade a Firebase credential for the session cookie.
 *
 * ONE EXCHANGE, TWO WAYS IN. Google and email produce the same thing, an ID
 * token, and everything after that point is identical: the allowlist decides,
 * the 403 branch signs back out, and the cookie is httpOnly. Duplicating this
 * per provider is how the two paths would eventually disagree about what a
 * rejection means.
 */
async function exchange(
  credential: UserCredential,
): Promise<{ ok: boolean; error?: string }> {
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
    //
    // WORTH KNOWING FOR THE EMAIL PATH: a password account has a DIFFERENT UID
    // from the Google account of the same person, so an allowlist carrying only
    // the Google UID lands here. That is the correct behaviour and the message
    // says what to do about it.
    await getAuth(app()).signOut();
    return { ok: false, error: 'That account is not authorised for this panel.' };
  }
  if (!res.ok) return { ok: false, error: 'Sign-in failed. Try again.' };

  return { ok: true };
}

/**
 * Sign in with email and password.
 *
 * ─── WHY THIS EXISTS AT ALL ─────────────────────────────────────────────────
 *
 * Google popup sign-in stopped working, and the cause is not in this codebase.
 * Firebase delivers the popup's credential through a hidden iframe on the AUTH
 * DOMAIN, which is `mindberzerk-3eaf5.firebaseapp.com` while the app runs on
 * mindberzerk.com and localhost. That iframe needs storage on a third-party
 * origin, and browsers have been closing that off. The console fills with
 * "Cross-Origin-Opener-Policy would block the window.close call" from Firebase's
 * own popup module, the SDK cannot see its popup finish, and a successful
 * sign-in is reported as cancelled. Redirect fails on the same root cause with
 * a quieter symptom.
 *
 * Email and password touches none of that: no popup, no iframe, no third-party
 * storage, no opener to sever. For a panel with one user it is not a downgrade,
 * it is the mechanism that has the fewest ways to break.
 *
 * ─── AND IT WEAKENS NOTHING ─────────────────────────────────────────────────
 *
 * Signing in only produces a UID. `requireAdmin` still checks it against the
 * allowlist server-side, and that is where access is actually decided. What
 * changes is how someone proves who they are, not what that proof buys.
 *
 * ERRORS ARE DELIBERATELY VAGUE. Firebase distinguishes `user-not-found` from
 * `wrong-password`, and repeating that distinction tells a stranger which of
 * the two halves they got right. One message for both.
 */
export async function signInWithEmail(
  email: string,
  password: string,
): Promise<{ ok: boolean; error?: string }> {
  try {
    const credential = await signInWithEmailAndPassword(
      getAuth(app()),
      email.trim(),
      password,
    );
    return await exchange(credential);
  } catch {
    return { ok: false, error: 'That email and password did not match.' };
  }
}

/**
 * Send a reset email.
 *
 * ALWAYS REPORTS SUCCESS, even for an address with no account. Saying "no such
 * user" turns this box into a way to test whether an address can reach the
 * panel, and the person who is allowed in already knows their own address.
 */
export async function sendReset(email: string): Promise<{ ok: boolean }> {
  try {
    await sendPasswordResetEmail(getAuth(app()), email.trim());
  } catch {
    // Swallowed on purpose. See above.
  }
  return { ok: true };
}

/**
 * Sign in with Google.
 *
 * KEPT, below the form, despite currently failing. The fault is a browser
 * storage policy rather than anything here, so it may simply start working
 * again, and deleting a path that costs four lines to keep would mean writing
 * it a third time. See [signInWithEmail] for why it is no longer the primary.
 */
export async function signIn(): Promise<{ ok: boolean; error?: string }> {
  try {
    const credential = await signInWithPopup(
      getAuth(app()),
      new GoogleAuthProvider(),
    );
    return await exchange(credential);
  } catch {
    return { ok: false, error: 'Sign-in was cancelled or blocked.' };
  }
}

export async function signOut() {
  await fetch('/api/auth/session', { method: 'DELETE' });
  await getAuth(app()).signOut();
}
