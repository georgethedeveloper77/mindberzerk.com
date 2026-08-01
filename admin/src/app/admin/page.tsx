'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signIn } from '@/lib/firebase-client';

/**
 * The only page reachable without a session, and it now lives at `/admin`.
 *
 * IT MOVED FROM `/login`. The panel is served at the root of
 * admin.mindberzerk.com, and `/admin` was previously a convenience redirect
 * that stripped itself, so typing the front door bounced you to `/login`.
 * `proxy.ts` now treats bare `/admin` as a real page and keeps stripping
 * `/admin/<rest>` for pasted deep links. Anything still pointing at `/login`
 * is dead: see the deletion note in that commit.
 *
 * A CLIENT COMPONENT, and it has to be: Firebase's popup sign-in needs a
 * browser. It holds nothing sensitive - the NEXT_PUBLIC_ config identifies the
 * project and authorises nothing, and the ID token it produces is posted once
 * to /api/auth/session and never stored.
 *
 * There is deliberately no "request access" link and no email/password form.
 * Access is an allowlist of UIDs held in Secret Manager; a self-service path to
 * a panel that can rewrite the CDN is not a feature.
 */
export default function AdminSignInPage() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSignIn() {
    setBusy(true);
    setError(null);
    const result = await signIn();
    if (result.ok) {
      // refresh(), not push(): the proxy decides where a session-holding browser
      // lands, and duplicating that decision here means two places to change it.
      router.replace('/');
      router.refresh();
    } else {
      setError(result.error ?? 'Sign-in failed.');
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-[100dvh] items-center justify-center p-6">
      <div className="w-full max-w-xs">
        <div className="flex items-center gap-2.5">
          <span className="grid size-6 shrink-0 place-items-center rounded-md bg-accent font-mono text-micro font-bold text-accent-ink">
            M
          </span>
          <div className="min-w-0">
            <h1 className="text-data font-semibold tracking-tight">Mindberzerk</h1>
            <p className="truncate font-mono text-micro text-ink-3">
              admin.mindberzerk.com
            </p>
          </div>
        </div>

        <button
          onClick={onSignIn}
          disabled={busy}
          className="mt-6 w-full rounded-lg bg-accent px-4 py-2.5 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-50"
        >
          {busy ? 'Signing in' : 'Continue with Google'}
        </button>

        {error && (
          <p className="mt-3 rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
            {error}
          </p>
        )}

        <p className="mt-6 text-micro leading-relaxed text-ink-3">
          Access is a fixed list of accounts. A successful Google sign-in that
          this panel still refuses means your Firebase UID is not on the
          allowlist yet.
        </p>
      </div>
    </main>
  );
}
