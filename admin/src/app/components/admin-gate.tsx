import { NotAuthorised, requireAdmin } from '@/lib/auth';

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

function NotAuthorisedScreen() {
  return (
    <main className="flex min-h-[100dvh] items-center justify-center p-6">
      <div className="max-w-sm text-data leading-relaxed text-ink-2">
        <p className="text-ink">Not authorised.</p>
        <p className="mt-2">
          Your Google sign-in worked; your Firebase UID is not on the allowlist.
          Add it to the <code className="font-mono text-micro">admin-uids</code>{' '}
          secret and redeploy.
        </p>
      </div>
    </main>
  );
}
