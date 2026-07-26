'use client';

/**
 * PHASE C-polish - the error boundary every page falls back to.
 *
 * A page's R2 or Remote Config read can throw: a missing credential, a network
 * blip, a service account without a role. Before this, that crashed to Next's
 * default error page - a stack trace on a white background, which on a phone
 * standing somewhere is useless. This catches it, names the likely cause, and
 * offers retry, because most of these are transient.
 *
 * It must be a client component (error boundaries are), and it deliberately does
 * NOT show the raw stack: the message is enough to act on, and the digest is
 * there for correlating with logs without dumping internals on screen.
 */
export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="flex min-h-[100dvh] items-center justify-center p-6">
      <div className="max-w-md">
        <p className="text-data font-medium text-ink">Something failed to load.</p>
        <p className="mt-2 text-data leading-relaxed text-ink-2">
          This is usually the CDN bucket or a Google credential, not the data
          itself. The service account may be missing a role, or the read timed
          out. Retry first; if it persists, check the App Hosting logs.
        </p>
        {error.digest && (
          <p className="mt-2 font-mono text-micro text-ink-3">ref {error.digest}</p>
        )}
        <button
          onClick={reset}
          className="mt-4 rounded-lg bg-accent px-3 py-2 text-data font-medium text-accent-ink transition hover:brightness-110"
        >
          Retry
        </button>
      </div>
    </main>
  );
}
