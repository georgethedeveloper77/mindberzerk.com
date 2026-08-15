'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { completeSignIn, signIn } from '@/lib/core/firebase-client';

/**
 * The only page reachable without a session, at `/admin`.
 *
 * A CLIENT COMPONENT, and it has to be: Firebase's popup sign-in needs a
 * browser. It holds nothing sensitive. The NEXT_PUBLIC_ config identifies the
 * project and authorises nothing, and the ID token it produces is posted once
 * to /api/auth/session and never stored.
 *
 * ─── THE HERO IS RENDERED, NOT UPLOADED ─────────────────────────────────────
 *
 * A two-column sign-in wants an image on one side, and every version of that
 * costs an asset: a screenshot that dates the moment a distro changes, a stock
 * photograph that belongs to nobody, an illustration that has to be commissioned
 * and then maintained.
 *
 * So the left column is DRAWN. It is the launcher's own boot sequence and
 * desktop, in CSS, from the same palette the panel and the product share. It
 * cannot go stale because there is nothing to regenerate, it adds no bytes to
 * fetch, and it is the one image that could not belong to any other company's
 * login page. The product is a Linux desktop emulator; this is that, at the
 * front door.
 *
 * The boot lines advance on a timer and then stop at a prompt. They stop on
 * purpose: an animation that loops forever competes with the button it sits
 * beside, and this screen has exactly one thing to do.
 *
 * ─── AND NO EXPLANATION OF THE AUTH MODEL ───────────────────────────────────
 *
 * This page used to end with a paragraph saying access is a fixed list of UIDs
 * and that a successful Google sign-in could still be refused. It was written
 * for an audience of one while the panel was being built. In production the
 * audience is anyone who reaches the URL, and every sentence of it is
 * reconnaissance: it confirms the panel is live, names the auth model, and tells
 * a stranger that signing in with any account probes whether that account is on
 * the list. The person who is allowed in already knew.
 *
 * The refusal still explains itself, and only to someone who got through
 * Google: `signIn` returns "That account is not authorised for this panel" on a
 * 403. By then the visitor has proved something about themselves, so it is an
 * answer rather than a notice.
 */

const BOOT = [
  { ok: true, text: 'mounting /dev/block/sda1' },
  { ok: true, text: 'starting pack verifier' },
  { ok: true, text: 'ed25519 signature accepted' },
  { ok: true, text: 'catalogue synced' },
  { ok: null, text: 'starting mindberzerk admin' },
];

export default function AdminSignInPage() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lines, setLines] = useState(0);

  // One line every 260ms, then stop. `prefers-reduced-motion` skips straight to
  // the finished state rather than being ignored: the whole point of the
  // sequence is atmosphere, and atmosphere is the first thing to drop for
  // someone who asked for less of it.
  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setLines(BOOT.length);
      return;
    }
    const timer = setInterval(() => {
      setLines((n) => {
        if (n >= BOOT.length) {
          clearInterval(timer);
          return n;
        }
        return n + 1;
      });
    }, 260);
    return () => clearInterval(timer);
  }, []);

  // ── FINISH A REDIRECT THE MOMENT THIS PAGE LOADS ───────────────────────
  //
  // With a popup, `signIn` did the whole exchange and returned a result. A
  // redirect has no such moment: the user leaves, signs in at Google, and comes
  // back as a FRESH LOAD carrying a pending credential that only
  // `getRedirectResult` can collect. Without this effect they would sign in
  // successfully and land straight back on this screen with no error and
  // nothing in the log, which is indistinguishable from the button not working.
  //
  // `busy` is set for the whole check so the button cannot be pressed into a
  // second redirect while the first is being collected. The `idle` case clears
  // it silently, because a first visit with no redirect in flight is not an
  // error and must not flash one.
  useEffect(() => {
    let live = true;
    setBusy(true);
    completeSignIn()
      .then((outcome) => {
        if (!live) return;
        if (outcome.state === 'ok') {
          // The console, not `/`: `/` is the public site now, and the proxy
          // lets a session-holding browser stay there, so landing on it after
          // sign-in would leave an admin looking at the marketing page.
          router.replace(outcome.returnTo ?? '/dashboard');
          router.refresh();
          // Deliberately still busy. The route is changing, and clearing it
          // here would repaint an enabled button for the frame before it goes.
          return;
        }
        if (outcome.state === 'error') setError(outcome.error);
        setBusy(false);
      })
      .catch(() => {
        if (!live) return;
        setError('Sign-in failed. Try again.');
        setBusy(false);
      });
    return () => {
      live = false;
    };
  }, [router]);

  async function onSignIn() {
    setBusy(true);
    setError(null);
    try {
      // Where the gate wanted them, so signing in does not always dump someone
      // on the dashboard when they followed a link to a distro. `?next=` is
      // read rather than `document.referrer`, which is empty on a redirect and
      // wrong on a bookmark.
      const next = new URLSearchParams(window.location.search).get('next');
      // Relative paths only. An absolute URL here would be an open redirect
      // wearing a query parameter, and the one thing this page must not do is
      // send a signed-in admin somewhere else entirely.
      const safe = next && next.startsWith('/') && !next.startsWith('//')
          ? next
          : undefined;
      await signIn(safe);
      // Not reached: the document unloads. Nothing after this line runs, which
      // is why there is no success branch here any more.
    } catch {
      setError('Sign-in could not start. Try again.');
      setBusy(false);
    }
  }

  return (
    <main className="grid min-h-[100dvh] lg:grid-cols-[1.15fr_1fr]">
      {/* ── the hero, drawn ─────────────────────────────────────────────────
          Hidden below lg rather than stacked. On a phone it would push the
          button below the fold, and the button is the only reason anyone opens
          this page. */}
      <section className="relative hidden overflow-hidden bg-surface-0 lg:block">
        {/* A desktop gradient in the launcher's own Ubuntu aubergine, with the
            accent bleeding in from the corner. Same two-stop treatment the
            distro previews use, at wall size. */}
        <div
          className="absolute inset-0"
          style={{
            background:
              'radial-gradient(120% 90% at 12% 8%, #3d1f2c 0%, #1a0f16 45%, #0c0e11 100%)',
          }}
        />
        <div
          className="absolute inset-0 opacity-40"
          style={{
            background:
              'radial-gradient(60% 45% at 88% 92%, rgba(233,84,32,0.28) 0%, transparent 70%)',
          }}
        />

        {/* The dock, left, exactly where a GNOME shell puts it. */}
        <div className="absolute top-1/2 left-8 flex -translate-y-1/2 flex-col gap-3 rounded-2xl bg-black/25 p-3 backdrop-blur-sm">
          {['#e95420', '#ffffff2e', '#e95420', '#ffffff2e', '#ffffff2e'].map((c, i) => (
            <span
              key={i}
              className="block size-8 rounded-lg"
              style={{ background: c }}
            />
          ))}
        </div>

        <div className="relative flex h-full flex-col justify-between p-10 xl:p-14">
          <div>
            <div className="flex items-center gap-2.5">
              <span className="grid size-7 place-items-center rounded-lg bg-accent font-mono text-data font-bold text-accent-ink">
                M
              </span>
              <span className="font-mono text-micro tracking-wider text-ink-2">
                MINDBERZERK STUDIO
              </span>
            </div>
            <h1 className="mt-8 max-w-md text-3xl leading-tight font-semibold tracking-tight text-ink xl:text-4xl">
              Your phone,
              <span className="text-accent"> running a real desktop.</span>
            </h1>
            <p className="mt-3 max-w-sm text-data leading-relaxed text-ink-2">
              The publishing console for every Mindberzerk app. Signed packs, one
              catalogue, no accounts anywhere near a device.
            </p>
          </div>

          {/* The boot log, bottom left, where a real one is. */}
          <div className="max-w-md rounded-card border border-line-soft bg-black/40 p-4 font-mono text-micro leading-relaxed backdrop-blur-sm">
            {BOOT.slice(0, lines).map((l, i) => (
              <div key={i} className="text-ink-2">
                {l.ok === true && <span className="text-ok">[ OK ] </span>}
                {l.ok === null && <span className="text-ink-3">[ .. ] </span>}
                {l.text}
              </div>
            ))}
            {lines >= BOOT.length && (
              <div className="mt-2 text-accent">
                admin@mindberzerk:~${' '}
                <span className="inline-block w-1.5 animate-pulse bg-ink text-transparent">
                  .
                </span>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* ── the sign-in ─────────────────────────────────────────────────── */}
      <section className="flex items-center justify-center bg-surface-1 p-6 sm:p-10">
        <div className="w-full max-w-sm">
          {/* The mark repeats here because below lg the hero is gone entirely
              and this column is the whole page. */}
          <div className="flex items-center gap-2.5 lg:hidden">
            <span className="grid size-7 place-items-center rounded-lg bg-accent font-mono text-data font-bold text-accent-ink">
              M
            </span>
            <span className="font-mono text-micro tracking-wider text-ink-2">
              MINDBERZERK STUDIO
            </span>
          </div>

          <h2 className="mt-8 text-xl font-semibold tracking-tight text-ink lg:mt-0">
            Sign in
          </h2>
          <p className="mt-1 text-data leading-relaxed text-ink-3">
            admin.mindberzerk.com
          </p>

          <button
            onClick={onSignIn}
            disabled={busy}
            className="mt-6 flex w-full items-center justify-center gap-2.5 rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-50"
          >
            {/* Google's mark, inline, because a login button that says only
                "continue" is one people hesitate over. No network request and
                nothing to keep in sync. */}
            <svg viewBox="0 0 24 24" className="size-4" aria-hidden="true">
              <path
                fill="currentColor"
                d="M21.35 11.1h-9.17v2.98h5.27c-.23 1.37-1.6 4.02-5.27 4.02-3.17 0-5.76-2.62-5.76-5.85s2.59-5.85 5.76-5.85c1.8 0 3.01.77 3.7 1.43l2.52-2.43C16.78 3.9 14.66 3 12.18 3 7.14 3 3.06 7.08 3.06 12.12s4.08 9.12 9.12 9.12c5.27 0 8.76-3.7 8.76-8.92 0-.6-.06-1.05-.14-1.5z"
              />
            </svg>
            {busy ? 'Signing in' : 'Continue with Google'}
          </button>

          {error && (
            <p className="mt-3 rounded-card border border-bad/40 bg-bad-dim px-3 py-2 text-data leading-relaxed text-bad">
              {error}
            </p>
          )}

          <div className="mt-8 border-t border-line-soft pt-4">
            <p className="font-mono text-micro leading-relaxed text-ink-3">
              mindberzerk.com
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
