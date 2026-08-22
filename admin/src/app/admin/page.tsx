'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { signIn, signInWithPassword } from '@/lib/core/firebase-client';
import { REGISTRY, type AppMeta } from '@/lib/core/registry';

/**
 * The only page reachable without a session, at `/admin`.
 *
 * A CLIENT COMPONENT, and it has to be: Firebase's popup sign-in needs a
 * browser. It holds nothing sensitive. The NEXT_PUBLIC_ config identifies the
 * project and authorises nothing, and the ID token it produces is posted once
 * to /api/auth/session and never stored.
 *
 * ─── PASSWORD FIRST, GOOGLE SECOND ──────────────────────────────────────────
 *
 * The order is the point, and it is the opposite of what it was.
 *
 * A password form sat here before and could not work, because the account had
 * no password credential linked. It does now, on the SAME UID, so both paths
 * end at the same record and the allowlist is unchanged.
 *
 * The password field takes the top slot because it is the path that cannot be
 * broken from a console. Google depends on an OAuth client, an authDomain, a
 * reverse proxy and redirect URIs whose changes Google warns may take hours to
 * propagate, and while any of that is wrong the panel is shut. The password is
 * one HTTPS call. On a panel with one operator, the credential that still
 * works during a misconfiguration is the one that belongs first.
 *
 * Google stays because it is the better credential when it works, with nothing
 * to store or remember, and it is already wired.
 *
 * ─── AND NO EXPLANATION OF THE AUTH MODEL ───────────────────────────────────
 *
 * This page used to end with a paragraph saying access is a fixed list of UIDs
 * and that a successful Google sign-in could still be refused. In production
 * the audience is anyone who reaches the URL, and every sentence of it is
 * reconnaissance: it confirms the panel is live, names the auth model, and
 * tells a stranger that signing in with any account probes whether that account
 * is on the list. The person who is allowed in already knew.
 *
 * The refusal still explains itself, and only to someone who got through
 * Google: `signIn` returns "That account is not authorised for this panel" on a
 * 403. By then the visitor has proved something about themselves, so it is an
 * answer rather than a notice.
 */

/**
 * ─── THE HERO ROTATES THROUGH THE STUDIO, NOT ONE APP ───────────────────────
 *
 * The slides come from [REGISTRY], so a third app appears here the day it is
 * added and nobody has to remember this file exists.
 *
 * ─── THE HEADLINES ARE LOCAL, AND DELIBERATELY NOT IN THE REGISTRY ──────────
 *
 * `AppMeta.blurb` is the one-line description the public site renders, written
 * to be informative. A hero line is a different job: it is short, it lands, and
 * it is allowed to be a fragment. Putting it in `AppMeta` would mean every app
 * carries a field that only this screen reads, and a registry entry that is
 * half marketing copy is one people stop editing honestly.
 *
 * So the copy lives here and `blurb` is the fallback, which means an app added
 * to the registry with no entry below still renders correctly. Slightly worse
 * copy is the right failure; a blank hero is not.
 */
const HERO: Record<string, { lead: string; accent: string }> = {
  'g-launcher': { lead: 'Your phone,', accent: 'running a real desktop.' },
  'g-recovery': { lead: 'Your data,', accent: 'on a server you own.' },
  'g-music': { lead: 'Your music,', accent: 'with nobody listening in.' },
  'g-news': { lead: 'Your feed,', accent: 'without the algorithm.' },
  'g-editor': { lead: 'Your photos,', accent: 'edited on the device.' },
};

/**
 * Four at most, in registry order.
 *
 * A rotation nobody watches to the end is a rotation whose later slides do not
 * exist, and this page is open for about six seconds. Four at five seconds each
 * is already longer than anyone stays.
 */
const SLIDES: AppMeta[] = REGISTRY.slice(0, 4);

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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [lines, setLines] = useState(0);
  const [slide, setSlide] = useState(0);

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

  // ── THE ROTATION ────────────────────────────────────────────────────────
  //
  // Five seconds, which is long enough to read a four word headline and short
  // enough that a second app is seen before the button is pressed.
  //
  // `prefers-reduced-motion` STOPS AT THE FIRST SLIDE rather than cycling
  // faster or without a transition. The whole feature is motion; someone who
  // asked for less of it wants none.
  //
  // Also skipped for a single-app registry, where a "rotation" of one is a
  // timer that repaints the same thing forever.
  useEffect(() => {
    if (SLIDES.length < 2) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const timer = setInterval(
      () => setSlide((n) => (n + 1) % SLIDES.length),
      5000,
    );
    return () => clearInterval(timer);
  }, []);

  const app = SLIDES[slide] ?? REGISTRY[0];
  const hero = HERO[app.id];

  /**
   * Both providers end here, because from this point they are identical: a
   * session cookie exists or it does not, and the reason it exists has no
   * bearing on where the browser goes next.
   */
  async function run(attempt: () => Promise<{ ok: boolean; error?: string }>) {
    setBusy(true);
    setError(null);
    const result = await attempt();
    if (result.ok) {
      // The console, not `/`: `/` is the public site now, and the proxy lets a
      // session-holding browser stay there, so landing on it after sign-in
      // would leave an admin looking at the marketing page.
      router.replace('/dashboard');
      router.refresh();
      return;
    }
    setError(result.error ?? 'Sign-in failed.');
    setBusy(false);
    // The PASSWORD is cleared and the EMAIL is not. A failed attempt means the
    // password was wrong or the account has none, and either way the stored
    // string is worth nothing. The email is almost certainly right and
    // retyping it is pure friction.
    setPassword('');
  }

  return (
    <main className="grid min-h-[100dvh] lg:grid-cols-[1.15fr_1fr]">
      {/* ── the hero, drawn ─────────────────────────────────────────────────
          Hidden below lg rather than stacked. On a phone it would push the
          button below the fold, and the button is the only reason anyone opens
          this page. */}
      <section className="relative hidden overflow-hidden bg-surface-0 lg:block">
        {/* ── EVERY COLOUR HERE IS THE APP'S OWN TINT ───────────────────────
            `color-mix` rather than five hand-picked shades per app: the
            registry carries one colour and a hero that needed a palette per
            entry would be a hero nobody adds an app to.

            `transition-[background]` on the wrapper is what makes the swap read
            as one desktop changing rather than two screens cutting. */}
        <div
          className="absolute inset-0 transition-[background] duration-700"
          style={{
            background: `radial-gradient(120% 90% at 12% 8%, color-mix(in srgb, ${app.tint} 34%, #120b10) 0%, color-mix(in srgb, ${app.tint} 12%, #0e0a0d) 45%, #0c0e11 100%)`,
          }}
        />
        <div
          className="absolute inset-0 opacity-40 transition-[background] duration-700"
          style={{
            background: `radial-gradient(60% 45% at 88% 92%, color-mix(in srgb, ${app.tint} 40%, transparent) 0%, transparent 70%)`,
          }}
        />

        {/* The dock, left, exactly where a GNOME shell puts it. Two lit tiles
            in the app's tint and three dark ones, which is the shape a dock has
            at a glance without pretending to be any particular one. */}
        <div className="absolute top-1/2 left-8 flex -translate-y-1/2 flex-col gap-3 rounded-2xl bg-black/25 p-3 backdrop-blur-sm">
          {[true, false, true, false, false].map((lit, i) => (
            <span
              key={i}
              className="block size-8 rounded-lg transition-colors duration-700"
              style={{ background: lit ? app.tint : '#ffffff2e' }}
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
            {/* ── THE FADE, AND WHY THE KEYFRAME IS LOCAL ──────────────────
                Keyed by app id so React REPLACES this node rather than
                mutating it. Without the key the text swaps instantly inside an
                element that is already fully opaque, and there is nothing for
                an animation to animate.

                The keyframe is declared here rather than in globals.css
                because exactly one element uses it, and a rule in the global
                sheet that nothing else references is a rule nobody dares
                delete later. */}
            <style>{'@keyframes heroIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}'}</style>
            <div key={app.id} className="motion-safe:animate-[heroIn_500ms_ease-out]">
              <h1 className="mt-8 max-w-md text-3xl leading-tight font-semibold tracking-tight text-ink xl:text-4xl">
                {hero ? (
                  <>
                    {hero.lead}
                    <span style={{ color: app.tint }}> {hero.accent}</span>
                  </>
                ) : (
                  // No hero copy for this app yet. The NAME is the headline,
                  // which is never wrong, and the blurb below carries the rest.
                  <span style={{ color: app.tint }}>{app.name}</span>
                )}
              </h1>
              <p className="mt-3 max-w-sm text-data leading-relaxed text-ink-2">
                {app.blurb}
              </p>
            </div>

            {/* ── WHICH OF HOW MANY ─────────────────────────────────────────
                Without this the hero looks like it changed its mind rather
                than like a set. Not tappable: this is a sign-in page, and a
                control that does nothing but change decoration is a control
                that steals a tap from the only button that matters. */}
            {SLIDES.length > 1 && (
              <div className="mt-6 flex items-center gap-1.5" aria-hidden>
                {SLIDES.map((s, i) => (
                  <span
                    key={s.id}
                    className="block h-1 rounded-full transition-all duration-500"
                    style={{
                      width: i === slide ? 18 : 6,
                      background: i === slide ? app.tint : '#ffffff2e',
                    }}
                  />
                ))}
              </div>
            )}
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

          {/* ── the password path ──────────────────────────────────────────
              NOT AN HTML `form`. A real form submits on Enter through a
              navigation this page never wants, and the handler is async, so
              the whole thing would be `preventDefault` plus a manual call.
              Enter is wired directly on the password field instead, which is
              the only key behaviour a form was providing. */}
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={busy}
            placeholder="Email"
            autoComplete="username"
            className="mt-6 w-full rounded-lg border border-line-soft bg-surface-0 px-4 py-3 text-data text-ink outline-none transition placeholder:text-ink-3 focus:border-accent disabled:opacity-50"
          />
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !busy) {
                void run(() => signInWithPassword(email, password));
              }
            }}
            disabled={busy}
            placeholder="Password"
            autoComplete="current-password"
            className="mt-2 w-full rounded-lg border border-line-soft bg-surface-0 px-4 py-3 text-data text-ink outline-none transition placeholder:text-ink-3 focus:border-accent disabled:opacity-50"
          />
          {/* Disabled on empty fields rather than validated on submit. An
              attempt with nothing typed can only fail, and refusing to make it
              is clearer than reporting it. */}
          <button
            onClick={() => run(() => signInWithPassword(email, password))}
            disabled={busy || !email || !password}
            className="mt-3 w-full rounded-lg bg-accent px-4 py-3 text-data font-medium text-accent-ink transition hover:brightness-110 disabled:opacity-50"
          >
            {busy ? 'Signing in' : 'Sign in'}
          </button>

          {/* ── the Google path ────────────────────────────────────────────
              The OUTLINE treatment, one step down. It is the better credential
              when it works, and the one that stops working for reasons no
              amount of retrying fixes, so it does not get the emphasis. */}
          <button
            onClick={() => run(signIn)}
            disabled={busy}
            className="mt-3 flex w-full items-center justify-center gap-2.5 rounded-lg border border-line-soft px-4 py-3 text-data font-medium text-ink transition hover:bg-surface-0 disabled:opacity-50"
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
            Continue with Google
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
