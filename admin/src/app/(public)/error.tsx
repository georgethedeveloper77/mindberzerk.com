'use client';

/**
 * The PUBLIC error boundary, for mindberzerk.com.
 *
 * ## Why the root one is wrong here
 *
 * `app/error.tsx` is written for an admin: it names the CDN bucket, a service
 * account role and the App Hosting logs, because those are the three things
 * that are usually at fault and the person reading it can act on all of them.
 *
 * A visitor can act on none of them, and telling a stranger which credential
 * failed is both useless to them and more than they should be told. A route
 * group can have its own boundary, so this one catches everything under
 * `(public)` before the root ever sees it.
 *
 * ## It carries the surface marker itself
 *
 * When this renders, the group's layout is gone too, so nothing else sets
 * `data-surface="soft"` and the canvas would fall back to the console's dark
 * `html`. That would put a light card on a black page for someone who has never
 * seen the console and never will.
 *
 * ## The digest stays
 *
 * Not as a diagnostic, as a reference. It is the one string that lets someone
 * writing in say WHICH failure they hit, and it reveals nothing on its own.
 */
export default function PublicError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div
      data-surface="soft"
      className="flex min-h-[100dvh] items-center justify-center bg-site-page p-6 font-site-sans"
    >
      <div className="w-full max-w-md rounded-[18px] border border-site-line bg-site-card p-6 shadow-site-soft">
        <span className="grid size-10 place-items-center rounded-xl bg-site-plan-soft text-site-plan">
          <svg width="19" height="19" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
            <path d="M8 2.5l6 11H2l6-11z" />
            <path d="M8 6.6v3M8 11.7v.01" />
          </svg>
        </span>

        <h1 className="mt-3.5 font-site-display text-[19px] font-bold tracking-tight text-site-ink">
          This page did not load.
        </h1>
        <p className="mt-2 text-[13px] leading-relaxed text-site-ink-2">
          Something on our side went wrong, not on yours. It is usually
          temporary, so trying again is worth a moment.
        </p>

        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button
            onClick={reset}
            className="rounded-full bg-site-accent px-5 py-2.5 text-[14px] font-semibold text-white transition hover:bg-site-accent-deep"
          >
            Try again
          </button>
          <a
            href="https://play.google.com/store/apps/dev?id=8965127905950081681"
            className="text-[13px] font-semibold text-site-ink-3 transition hover:text-site-ink"
          >
            Our apps on Google Play
          </a>
        </div>

        {error.digest && (
          <p className="mt-4 border-t border-site-line pt-3 font-mono text-[11px] text-site-ink-3">
            If you write to us, quote {error.digest}
          </p>
        )}
      </div>
    </div>
  );
}
