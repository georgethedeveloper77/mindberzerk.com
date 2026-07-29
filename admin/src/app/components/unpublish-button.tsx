'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

/**
 * PHASE C6 - pulling a pack, with the confirmation inline.
 *
 * Two taps rather than a modal. A dialog on a phone covers the thing you are
 * about to act on, which is exactly the context you want while deciding, and
 * `position: fixed` overlays are the part of a mobile layout most likely to end
 * up under the home indicator.
 *
 * The button says what happens after, not what it does now: the files stay in
 * the bucket, so this is genuinely a delisting rather than a delete, and
 * somebody reading it at speed should not think the objects are gone.
 */
export function UnpublishButton({ app, packId }: { app: string; packId: string }) {
  const router = useRouter();
  const [armed, setArmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function pull() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch('/api/publish/unpublish', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app, packId }),
      });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error ?? 'Could not pull the pack');
        setArmed(false);
      } else {
        router.replace(`/apps/${app}/packs`);
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  if (error) {
    return (
      <div className="text-right">
        <p className="max-w-xs text-micro leading-relaxed text-bad">{error}</p>
        <button
          onClick={() => setError(null)}
          className="mt-1 text-micro text-ink-3 hover:text-ink-2"
        >
          Dismiss
        </button>
      </div>
    );
  }

  if (!armed) {
    return (
      <button
        onClick={() => setArmed(true)}
        className="inline-flex items-center rounded-lg border border-line bg-surface-2 px-2.5 py-1.5 text-data text-ink-2 transition hover:border-bad/40 hover:text-bad"
      >
        Pull from store
      </button>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <span className="text-micro text-ink-3">Files stay. Republish higher to undo.</span>
      <button
        onClick={() => setArmed(false)}
        className="rounded-lg border border-line px-2.5 py-1.5 text-data text-ink-2"
      >
        Cancel
      </button>
      <button
        onClick={pull}
        disabled={busy}
        className="rounded-lg border border-bad bg-bad px-2.5 py-1.5 text-data font-medium text-surface-0 transition hover:brightness-110 disabled:opacity-50"
      >
        {busy ? 'Signing' : 'Pull'}
      </button>
    </div>
  );
}
