'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
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
 *
 * ─── GOOGLE IS THE ONLY WAY IN, AND THE PASSWORD FORM IS GONE ───────────────
 *
 * The one account on this project has ONE provider, Google. There is no
 * password credential attached to it, so `signInWithEmailAndPassword` could
 * only ever return `auth/invalid-credential`, which the form rendered as "that
 * email and password did not match". That message was true and useless: there
 * was nothing to match against.
 *
 * Keeping a form that cannot succeed costs a real thing. It is a box a stranger
 * can throw guesses at, against an account that has no password to guess, and
 * every guess looks exactly like the operator getting it wrong. Deleted.
 */

/**
 * ─── WHY authDomain IS THE CURRENT HOST AND NOT THE PROJECT'S ───────────────
 *
 * This is the fix for the popup failure, and it is Firebase's own documented
 * one (Option 3, "Proxy auth requests to firebaseapp.com").
 *
 * The SDK runs its sign-in helper in an iframe on `authDomain`. With that set
 * to `mindberzerk-3eaf5.firebaseapp.com` while the app runs on
 * mindberzerk.com, the iframe is a THIRD-PARTY ORIGIN, and every current
 * browser partitions or blocks storage there. The SDK cannot read back the
 * result, so a sign-in that actually succeeded is reported as cancelled. That
 * is the whole bug, and no amount of retrying or switching to redirect fixes
 * it, because redirect uses the same iframe.
 *
 * Pointing authDomain at the host the browser is already on makes the helper
 * SAME-ORIGIN. No third-party storage, no partitioning, no COOP severing the
 * opener. `proxy.ts` forwards `/__/auth/*` to the real helper so the code the
 * iframe loads is still Firebase's.
 *
 * READ FROM `window` RATHER THAN HARDCODED, because this backend answers on
 * more than one hostname (the custom domain and the App Hosting default) and
 * the correct value is whichever one the browser is on. A hardcoded value
 * would be wrong on one of them, and wrong here means back to the third-party
 * iframe.
 *
 * ─── BUT NOT ON localhost, AND THE REASON IS EXACT ──────────────────────────
 *
 * Firebase builds the handler URL as `https://<authDomain>/__/auth/handler`.
 * ALWAYS https, and an authDomain carries NO PORT. So on http://localhost:3000
 * a hostname-derived authDomain sends the popup to `https://localhost/__/auth/
 * handler`, which is port 443 on a machine serving 3000 over http, and the
 * popup dies on ERR_CONNECTION_REFUSED before it reaches any Firebase code.
 *
 * The test is therefore not "is there a window" but "can this origin actually
 * answer https on the default port". Anything else falls back to the project
 * domain, which is what dev used before and what dev keeps.
 *
 * THAT MEANS LOCAL SIGN-IN STILL USES THE THIRD-PARTY IFRAME, with whatever
 * flakiness the browser's storage partitioning brings. It is the honest
 * trade: the proxy fix needs a real https origin, and localhost is not one.
 * Sign in against the deployed backend when the popup matters.
 *
 * BOTH PRODUCTION HOSTS MUST BE REGISTERED or you get
 * `auth/unauthorized-domain`:
 *   - Firebase console, Authentication, Settings, Authorized domains
 *   - Google Cloud console, Credentials, the Web client's Authorized redirect
 *     URIs, as `https://<host>/__/auth/handler` (the suffix is required)
 *
 * `localhost` belongs in the Firebase list too, for the fallback path.
 */
function authDomain(): string | undefined {
  const fallback = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN;
  if (typeof window === 'undefined') return fallback;

  const { protocol, port, hostname } = window.location;

  // Not https, so `https://<hostname>/` is a guess about a server that may not
  // exist. This is the localhost:3000 case.
  if (protocol !== 'https:') return fallback;

  // https on a non-default port. An authDomain cannot express the port, so the
  // handler URL would silently target 443 instead.
  if (port !== '' && port !== '443') return fallback;

  return hostname;
}

function app() {
  if (getApps().length) return getApp();
  return initializeApp({
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: authDomain(),
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  });
}

/**
 * Trade a Firebase credential for the session cookie.
 *
 * The ID token is used ONCE and never stored. After this returns, auth lives
 * entirely in an httpOnly cookie the page cannot read.
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
    await getAuth(app()).signOut();
    return { ok: false, error: 'That account is not authorised for this panel.' };
  }
  if (!res.ok) return { ok: false, error: 'Sign-in failed. Try again.' };

  return { ok: true };
}

/**
 * ─── ONE MESSAGE PER FAILURE, NOT ONE MESSAGE FOR ALL OF THEM ───────────────
 *
 * Every failure used to collapse to "Sign-in was cancelled or blocked", which
 * covered a closed window, a blocked popup, and a domain missing from the
 * Firebase allowlist. Those need three different actions and one of them is a
 * console setting, so the flat message cost days.
 *
 * NAMING `unauthorized-domain` OUT LOUD IS DELIBERATE. It is a configuration
 * fault on a panel with one operator, and the alternative is staring at
 * "blocked" while the fix sits in a console tab. A stranger learns only that
 * this is a Firebase app, which the network tab already says.
 */
const MESSAGES: Record<string, string> = {
  'auth/popup-closed-by-user': 'The Google window closed before it finished.',
  'auth/cancelled-popup-request': 'Another sign-in window was already open.',
  'auth/popup-blocked':
    'The browser blocked the Google window. Allow popups for this site, then try again.',
  'auth/unauthorized-domain':
    'This hostname is not in the Firebase authorised domains list. Add it under Authentication, Settings.',
  // Seen when the popup opened but could not load the handler at all. The
  // usual cause is an authDomain pointing at a host that does not answer
  // https on port 443. See [authDomain].
  'auth/internal-error':
    'The Google window could not load the sign-in handler. Check that authDomain resolves over https.',
  'auth/network-request-failed': 'The network dropped during sign-in.',
  'auth/operation-not-allowed':
    'Google sign-in is disabled for this Firebase project.',
};

/**
 * Sign in with Google. The only path in.
 *
 * POPUP RATHER THAN REDIRECT, on purpose. With a same-origin authDomain both
 * work, and popup keeps the page mounted, so there is no `getRedirectResult`
 * to run on load and no window where a half-finished flow is indistinguishable
 * from a cold start.
 */
export async function signIn(): Promise<{ ok: boolean; error?: string }> {
  try {
    const credential = await signInWithPopup(
      getAuth(app()),
      new GoogleAuthProvider(),
    );
    return await exchange(credential);
  } catch (e) {
    const code = (e as { code?: string }).code ?? '';
    // The raw code is appended for anything unmapped. An unknown failure with
    // its Firebase code attached is diagnosable; "sign-in failed" is not.
    return {
      ok: false,
      error: MESSAGES[code] ?? `Sign-in failed. (${code || 'unknown error'})`,
    };
  }
}

export async function signOut() {
  await fetch('/api/auth/session', { method: 'DELETE' });
  await getAuth(app()).signOut();
}
