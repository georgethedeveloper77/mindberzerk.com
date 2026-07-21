'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signIn } from '@/lib/firebase-client';

/**
 * The only page reachable without a session.
 *
 * A CLIENT COMPONENT, and it has to be: Firebase's popup sign-in needs a
 * browser. It holds nothing sensitive — the NEXT_PUBLIC_ config identifies the
 * project and authorises nothing, and the ID token it produces is posted once
 * to /api/auth/session and never stored.
 *
 * There is deliberately no "request access" link and no email/password form.
 * Access is an allowlist of UIDs held in Secret Manager; a self-service path to
 * a panel that can rewrite the CDN is not a feature.
 */
export default function LoginPage() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSignIn() {
    setBusy(true);
    setError(null);
    const result = await signIn();
    if (result.ok) {
      // refresh(), not push(): the middleware decides where a session-holding
      // browser lands, and duplicating that decision here means two places to
      // change it.
      router.replace('/');
      router.refresh();
    } else {
      setError(result.error ?? 'Sign-in failed.');
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <h1 className="text-xl font-semibold tracking-tight">Mindberzerk</h1>
        <p className="mt-1 text-sm text-neutral-400">Pack publishing</p>

        <button
          onClick={onSignIn}
          disabled={busy}
          className="mt-8 w-full rounded-lg bg-neutral-100 px-4 py-2.5 text-sm font-medium text-neutral-900 transition hover:bg-white disabled:opacity-50"
        >
          {busy ? 'Signing in…' : 'Continue with Google'}
        </button>

        {error && (
          <p className="mt-4 rounded-lg border border-red-900/60 bg-red-950/40 px-3 py-2 text-sm text-red-300">
            {error}
          </p>
        )}

        <p className="mt-8 text-xs leading-relaxed text-neutral-500">
          Access is limited to a fixed list of accounts. If your Google sign-in
          succeeds and this panel still refuses you, that is expected: your
          Firebase UID has to be added to the allowlist first.
        </p>
      </div>
    </main>
  );
}
