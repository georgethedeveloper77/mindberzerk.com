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
 *
 * Restyled onto the `site-` tokens with the launcher screens. The console
 * tokens it carried are dark-only, so on a light card the armed state rendered
 * as a dark slab and the confirm as a shout.
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
        <p className="max-w-xs rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11.5px] leading-relaxed text-site-plan">
          {error}
        </p>
        <button
          onClick={() => setError(null)}
          className="mt-1 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-ink"
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
        className="inline-flex items-center rounded-lg border border-site-line bg-site-card px-3 py-1.5 text-xs font-semibold text-site-ink transition hover:border-site-plan/45 hover:text-site-plan"
      >
        Pull from store
      </button>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <span className="text-[11.5px] text-site-ink-3">Files stay. Republish higher to undo.</span>
      <button
        onClick={() => setArmed(false)}
        className="rounded-lg border border-site-line px-3 py-1.5 text-xs font-semibold text-site-ink-2"
      >
        Cancel
      </button>
      <button
        onClick={pull}
        disabled={busy}
        className="rounded-lg bg-site-plan px-3 py-1.5 text-xs font-bold text-site-card transition hover:brightness-110 disabled:opacity-50"
      >
        {busy ? 'Signing' : 'Pull'}
      </button>
    </div>
  );
}
