import { NotAuthorised, requireAdmin } from '@/lib/core/auth';

/**
 * PHASE C-polish - one place for the auth gate.
 *
 * Every page and route repeated the same try/requireAdmin/catch NotAuthorised
 * block, thirteen times, each free to drift. This centralises the PAGE variant:
 * it awaits the check, renders a plain not-authorised screen on NotAuthorised,
 * and rethrows anything else so a real failure still reaches the error boundary
 * rather than being swallowed as "not authorised".
 *
 * Routes keep their own inline block, because a route must answer 401 JSON, not
 * render HTML - a shared helper that returned different types for the two cases
 * would be worse than the duplication.
 *
 * Usage at the top of a server page:
 *
 *   const gate = await adminGate();
 *   if (gate) return gate;            // the not-authorised screen
 *   // ...authorised, carry on
 */
export async function adminGate(): Promise<React.ReactElement | null> {
  try {
    await requireAdmin();
    return null;
  } catch (e) {
    if (e instanceof NotAuthorised) return <NotAuthorisedScreen />;
    // A credential misconfiguration or a network failure is NOT an auth denial.
    // Rethrow so error.tsx shows it, instead of telling an admin they lack
    // access when the real problem is the service account.
    throw e;
  }
}

/**
 * The not-authorised screen.
 *
 * ON THE SOFT REGISTER, and it carries `data-surface="soft"` itself, because it
 * REPLACES the page rather than rendering inside `StudioShell`: without the
 * marker it would inherit the console's dark canvas from globals.css and render
 * light text on light card over a black page.
 *
 * It states what worked as well as what did not. "Not authorised" alone reads
 * as a sign-in failure, and the whole point is that sign-in succeeded, so the
 * next action is an allowlist edit rather than another attempt at logging in.
 */
function NotAuthorisedScreen() {
  return (
    <main
      data-surface="soft"
      className="flex min-h-[100dvh] items-center justify-center bg-site-page p-6 font-site-sans"
    >
      <div className="w-full max-w-md rounded-[18px] border border-site-line bg-site-card p-6 shadow-site-soft">
        <span className="grid size-10 place-items-center rounded-xl bg-site-plan-soft text-site-plan">
          <svg width="19" height="19" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
            <rect x="3" y="7" width="10" height="6.5" rx="1.6" />
            <path d="M5.5 7V5a2.5 2.5 0 015 0" />
          </svg>
        </span>
        <h1 className="mt-3.5 font-site-display text-[19px] font-bold tracking-tight text-site-ink">
          Not authorised.
        </h1>
        <p className="mt-2 text-[13px] leading-relaxed text-site-ink-2">
          Your Google sign-in worked. Your Firebase UID is not on the allowlist, so this is not
          something signing in again will fix.
        </p>
        <p className="mt-2.5 text-[12.5px] leading-relaxed text-site-ink-3">
          Add the UID to the{' '}
          <code className="rounded bg-site-sunk px-1.5 py-0.5 font-mono text-[11.5px] text-site-ink-2">
            admin-uids
          </code>{' '}
          secret and redeploy.
        </p>
      </div>
    </main>
  );
}
