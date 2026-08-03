'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';

import { deleteIconPackAction } from '@/app/apps/[app]/icons/actions';

/**
 * Delete one icon pack, with the consequences said BEFORE the press.
 *
 * TWO-STEP ON PURPOSE, matching the distro delete. The first press swaps the
 * word for a sentence and a confirm, because everything this does that a user
 * would want to undo is on the far side of a network call: the index is
 * re-signed, and a device that syncs a minute later stops offering the pack.
 *
 * What it does NOT do is equally worth saying, and the panel says it rather
 * than leaving someone to discover it: the bucket objects stay (an in-flight
 * download must finish), Play keeps the product forever because product ids
 * are never released, and everyone who already bought or installed the pack
 * keeps what they have. Deleting is about the STORE, not about reaching into
 * phones.
 */
export function DeleteIconPack({
  app,
  packId,
  published,
  usedBy,
}: {
  app: string;
  packId: string;
  published: boolean;
  /** Themes naming this pack, from the page's reverse lookup. */
  usedBy: string[];
}) {
  const router = useRouter();
  const [armed, setArmed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  // The server re-derives this from the drafts and refuses on its own; showing
  // it here means the button never looks available for something that cannot
  // happen, and the reason is visible before the click rather than after it.
  const blocked = usedBy.length > 0;

  function run() {
    setError(null);
    start(async () => {
      const res = await deleteIconPackAction(app, packId);
      if (!res.ok) {
        setError(res.error);
        setArmed(false);
        return;
      }
      router.refresh();
    });
  }

  if (blocked) {
    return (
      <p className="mt-3 rounded-[10px] bg-site-plan-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-plan">
        {usedBy.join(', ')} still names this pack, so it cannot be deleted. Point that distro at
        another pack first.
      </p>
    );
  }

  return (
    <div className="mt-3">
      {!armed ? (
        <button
          type="button"
          onClick={() => setArmed(true)}
          className="text-[12.5px] font-semibold text-site-plan hover:underline"
        >
          Delete
        </button>
      ) : (
        <div className="rounded-[10px] border border-site-line bg-site-sunk px-3 py-2.5">
          <p className="text-[11.5px] leading-relaxed text-site-ink-2">
            {published
              ? 'This comes out of the signed catalogue, so no device will offer it again. Files stay in the bucket for downloads already running, anyone who has it keeps it, and Play keeps the product and every purchase.'
              : 'This draft and its uploaded art are removed. Nothing is live, so no device is affected.'}
          </p>
          <div className="mt-2.5 flex items-center gap-3">
            <button
              type="button"
              disabled={pending}
              onClick={run}
              className="rounded-lg bg-site-plan px-3 py-1.5 text-[12.5px] font-semibold text-white disabled:opacity-60"
            >
              {pending ? 'Deleting' : 'Delete for good'}
            </button>
            <button
              type="button"
              disabled={pending}
              onClick={() => setArmed(false)}
              className="text-[12.5px] text-site-ink-3 hover:text-site-ink"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {error && (
        <p className="mt-2 rounded-[10px] bg-site-plan-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-plan">
          {error}
        </p>
      )}
    </div>
  );
}
