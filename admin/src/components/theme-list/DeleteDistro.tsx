'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';

import { deleteDistroAction } from '@/app/apps/[app]/distros/actions';
import type { AppId } from '@/lib/core/registry';

/**
 * Delete, as a two-step inline confirm rather than a dialog.
 *
 * The first click swaps the link for a sentence saying exactly what this
 * delete will do to THIS card, because the answer differs: a draft-only distro
 * loses a draft, a published one comes out of the store, and a paid one leaves
 * its product behind in Play with every buyer keeping it. A generic "are you
 * sure" would hide the only information worth confirming.
 *
 * [iconPacks] is the icon packs actually in the live index for this distro,
 * because those are what the delete will pull. Granted-but-unshipped packs are
 * not listed here: there is nothing in the index to pull for them.
 *
 * On success the router refreshes and the row disappears with the server
 * render; there is no local list to reconcile. Errors render inline under the
 * button, worded by the server.
 *
 * Restyled onto the `site-` tokens with the rest of the launcher screens. The
 * console tokens it carried are dark-only and rendered as bright red on a light
 * card.
 */
export function DeleteDistro({
  app,
  id,
  published,
  sku,
  iconPacks,
}: {
  app: AppId;
  id: string;
  published: boolean;
  sku: string | null;
  iconPacks: string[];
}) {
  const router = useRouter();
  const [confirming, setConfirming] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  async function run() {
    setBusy(true);
    setError(null);
    try {
      const res = await deleteDistroAction(app, id);
      if (res.ok) {
        // The card is gone from the next server render; nothing local to update.
        router.refresh();
        return;
      }
      setError(res.error);
    } catch (e) {
      setError((e as Error).message);
    }
    setBusy(false);
    setConfirming(false);
  }

  if (!confirming) {
    return (
      <div className="min-w-0">
        <button
          type="button"
          onClick={() => {
            setError(null);
            setConfirming(true);
          }}
          className="text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan"
        >
          Delete
        </button>
        {error && (
          <p className="mt-1.5 rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11px] leading-relaxed text-site-plan">
            {error}
          </p>
        )}
      </div>
    );
  }

  const what = published
    ? `Unpublishes ${[id, ...iconPacks].join(' and ')} and removes the draft. ` +
      'Files stay on the CDN, and devices that installed it keep it.'
    : 'Removes the draft. Nothing is published under this id.';
  const play =
    published && sku
      ? ` Anyone who bought ${sku} keeps the purchase, and the ID stays reserved in Play.`
      : '';

  return (
    <div className="min-w-0 flex-1 basis-full">
      <p className="rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11.5px] leading-relaxed text-site-plan">
        {what}
        {play}
      </p>
      <div className="mt-1 flex items-center gap-3">
        <button
          type="button"
          disabled={busy}
          onClick={run}
          className="text-[11.5px] font-bold text-site-plan transition hover:brightness-110 disabled:opacity-50"
        >
          {busy ? 'Deleting' : 'Confirm delete'}
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={() => setConfirming(false)}
          className="text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-ink"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
