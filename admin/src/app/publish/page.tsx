import { NotAuthorised, requireAdmin } from '@/lib/auth';
import { readLiveIndex } from '@/lib/catalogue';
import { Shell } from '../components/shell';
import { PublishForm } from '../components/publish-form';

export const dynamic = 'force-dynamic';

/**
 * Publishing on its own route rather than bolted under the pack list.
 *
 * On a phone the list and the form cannot share a screen without one of them
 * being a scroll-past, and the form is a task you enter deliberately. It also
 * means the pack list stays a fast read-only view you can open to check
 * something without a 12-field form loading underneath it.
 */
export default async function PublishPage() {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return (
        <main className="flex min-h-[100dvh] items-center justify-center p-6 text-sm text-neutral-400">
          Not authorised.
        </main>
      );
    }
    throw e;
  }

  const app = 'g-launcher' as const;
  const live = await readLiveIndex(app);

  return (
    <Shell subtitle={`cdn.mindberzerk.com / ${app}`}>
      <h1 className="text-lg font-semibold tracking-tight">Publish a pack</h1>
      <PublishForm app={app} packs={live.packs} />
    </Shell>
  );
}
