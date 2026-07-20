import { cookies } from 'next/headers';
import { cert, getApp, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';

/**
 * PHASE C4 — the front door.
 *
 * This panel can write to the CDN that every installed launcher trusts, and it
 * holds the ed25519 private key those launchers verify against. It is the
 * highest-value target in the whole ecosystem, and it is a public URL. So the
 * auth here is deliberately more paranoid than a one-user tool would normally
 * justify.
 *
 * ## An allowlist, not a role check
 *
 * There is no sign-up, no invite flow, and no "admin" claim to be granted. A
 * hardcoded set of Firebase UIDs, supplied as a SECRET rather than a config
 * value, because "who may sign in" here is a credential and not a setting.
 * Adding a person is a Secret Manager edit and a redeploy, which is the correct
 * amount of friction for something that can push signed content to every
 * device.
 *
 * ## Why session cookies and not Bearer tokens
 *
 * Next middleware runs on the Edge runtime, which has no Node crypto and
 * therefore cannot run firebase-admin. So the split is:
 *
 *   middleware  — checks a cookie EXISTS, cheap, no verification. Purely to
 *                 redirect a logged-out browser to /login without a round trip.
 *   this file   — the real check, in Node, on every route handler and server
 *                 component that touches anything.
 *
 * THE MIDDLEWARE IS NOT A SECURITY BOUNDARY and must never be treated as one.
 * Anything that reads the key or writes to R2 calls [requireAdmin] itself. If
 * you find yourself adding a route and thinking "middleware already covered
 * it", that is the bug.
 *
 * Session cookies also revoke properly: `revokeRefreshTokens` invalidates them
 * server-side, which a stored ID token does not.
 */

function adminApp() {
  if (getApps().length) return getApp();

  // In App Hosting, application-default credentials are present and correct.
  // Locally they are not, so a service-account JSON in the env is the fallback.
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) {
    return initializeApp({ credential: cert(JSON.parse(raw)) });
  }
  return initializeApp({ credential: applicationDefault() });
}

export const SESSION_COOKIE = '__session';

/**
 * `__session` is not an arbitrary name. Firebase Hosting and App Hosting strip
 * every cookie except one called exactly this before the request reaches the
 * origin, so any other name works locally and vanishes in production — a
 * failure that looks like "auth randomly stops working once deployed".
 */

/** UIDs allowed in. Empty set means nobody, which is the right default. */
function allowedUids(): Set<string> {
  const raw = process.env.ADMIN_UIDS ?? '';
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

export class NotAuthorised extends Error {
  constructor(message = 'Not authorised') {
    super(message);
  }
}

/**
 * Verify the session cookie and the allowlist. Throws [NotAuthorised].
 *
 * `checkRevoked: true` costs a round trip to Google and is worth it here: it is
 * what makes signing someone out actually sign them out, rather than leaving a
 * valid cookie working until it expires.
 */
export async function requireAdmin(): Promise<DecodedIdToken> {
  const store = await cookies();
  const session = store.get(SESSION_COOKIE)?.value;
  if (!session) throw new NotAuthorised('No session');

  let decoded: DecodedIdToken;
  try {
    decoded = await getAuth(adminApp()).verifySessionCookie(session, true);
  } catch {
    // Deliberately not distinguishing expired from forged from malformed. The
    // answer to the browser is the same, and the difference is only useful to
    // someone probing.
    throw new NotAuthorised('Invalid session');
  }

  const allowed = allowedUids();
  if (allowed.size === 0) {
    // ADMIN_UIDS unset means the secret is missing, not that everyone is an
    // admin. Fail closed and say so in the log, because the alternative is a
    // misconfigured deploy silently becoming an open panel.
    console.error('ADMIN_UIDS is empty — refusing all access');
    throw new NotAuthorised('Not authorised');
  }
  if (!allowed.has(decoded.uid)) {
    console.warn(`Rejected sign-in for uid ${decoded.uid}`);
    throw new NotAuthorised('Not authorised');
  }

  return decoded;
}

/** Exchange a freshly minted ID token for a session cookie. */
export async function createSession(idToken: string, maxAgeMs: number) {
  const auth = getAuth(adminApp());

  // Verify BEFORE minting, including the allowlist. Without this the endpoint
  // would happily issue a session cookie to any valid Firebase user in the
  // project, and the allowlist would only be enforced on the next request —
  // which is one refactor away from not being enforced at all.
  const decoded = await auth.verifyIdToken(idToken, true);
  if (!allowedUids().has(decoded.uid)) {
    throw new NotAuthorised('Not authorised');
  }

  return auth.createSessionCookie(idToken, { expiresIn: maxAgeMs });
}

export async function revokeSession() {
  const store = await cookies();
  const session = store.get(SESSION_COOKIE)?.value;
  if (!session) return;
  try {
    const auth = getAuth(adminApp());
    const decoded = await auth.verifySessionCookie(session);
    // Kills every session for this user everywhere, not just this cookie. For a
    // single-admin panel that is exactly what "sign out" should mean.
    await auth.revokeRefreshTokens(decoded.sub);
  } catch {
    // Already invalid. Nothing to revoke.
  }
}
