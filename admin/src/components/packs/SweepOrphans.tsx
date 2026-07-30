'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';

import type { OrphanGroup } from '@/lib/orphans';

/**
 * The sweep UI: every group visible, nothing deleted without its own confirm.
 *
 * A group is one pack version directory, labelled by what it is: an old
 * version of a pack still live (routine), or a pack the index no longer names
 * at all (might be one you meant to keep, so its id is shown plainly). The
 * confirm sentence carries the one operational caution: a device that read
 * the index moments before an unpublish may still be downloading, so sweeping
 * immediately after unpublishing can fail that one install.
 *
 * The server recomputes orphans at delete time, so this component's job is
 * presentation and consent, not safety. `skippedDirs` in the response is that
 * recomputation speaking: a dir that stopped being orphaned since the page
 * rendered is reported, not deleted.
 */
export function SweepOrphans({ app, groups }: { app: string; groups: OrphanGroup[] }) {
  const router = useRouter();
  const [confirming, setConfirming] = React.useState<string | null>(null);
  const [busy, setBusy] = React.useState(false);
  const [note, setNote] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  async function sweep(dirs: string[]) {
    setBusy(true);
    setError(null);
    setNote(null);
    try {
      const res = await fetch('/api/publish/sweep', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app, dirs }),
      });
      const data = (await res.json()) as {
        error?: string;
        deleted?: number;
        freedBytes?: number;
        skippedDirs?: string[];
      };
      if (!res.ok) {
        setError(data.error ?? `Sweep failed (${res.status}).`);
      } else {
        const skipped = data.skippedDirs?.length
          ? ` Skipped ${data.skippedDirs.join(', ')}: no longer orphaned.`
          : '';
        setNote(`Deleted ${data.deleted} object${data.deleted === 1 ? '' : 's'}.${skipped}`);
        router.refresh();
      }
    } catch (e) {
      setError((e as Error).message);
    }
    setBusy(false);
    setConfirming(null);
  }

  const mb = (n: number) => `${(n / (1024 * 1024)).toFixed(2)} MB`;

  return (
    <div>
      <div className="divide-y divide-line-soft">
        {groups.map((g) => (
          <div key={g.dir} className="flex flex-wrap items-center gap-3 px-3 py-2.5 sm:px-4">
            <div className="min-w-0 flex-1">
              <div className="truncate font-mono text-data text-ink">{g.dir}</div>
              <div className="text-micro text-ink-3">
                {g.kind === 'stale'
                  ? `old version of ${g.packId}, still live at a newer one`
                  : g.kind === 'unpublished'
                    ? 'not in the catalogue; nothing new can discover it'
                    : 'stray object outside the pack layout'}
                {` · ${g.keys.length} object${g.keys.length === 1 ? '' : 's'} · ${mb(g.sizeBytes)}`}
              </div>
            </div>
            {confirming === g.dir ? (
              <div className="flex items-center gap-3">
                <span className="text-micro text-ink-2">
                  Deletes {g.keys.length} object{g.keys.length === 1 ? '' : 's'} for good. A
                  device mid-download of this exact version would fail its install.
                </span>
                <button
                  disabled={busy}
                  onClick={() => void sweep([g.dir])}
                  className="text-micro font-medium text-bad transition hover:brightness-110 disabled:opacity-50"
                >
                  {busy ? 'Deleting' : 'Confirm'}
                </button>
                <button
                  disabled={busy}
                  onClick={() => setConfirming(null)}
                  className="text-micro text-ink-3 transition hover:text-ink"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <button
                onClick={() => {
                  setError(null);
                  setConfirming(g.dir);
                }}
                className="text-micro text-ink-3 transition hover:text-bad"
              >
                Delete
              </button>
            )}
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3 border-t border-line-soft px-3 py-2.5 sm:px-4">
        {confirming === '*' ? (
          <>
            <span className="text-micro text-ink-2">
              Deletes every group above, {groups.reduce((n, g) => n + g.keys.length, 0)} objects.
              The catalogue and every live pack are untouched.
            </span>
            <button
              disabled={busy}
              onClick={() => void sweep(groups.map((g) => g.dir))}
              className="text-micro font-medium text-bad transition hover:brightness-110 disabled:opacity-50"
            >
              {busy ? 'Deleting' : 'Confirm sweep all'}
            </button>
            <button
              disabled={busy}
              onClick={() => setConfirming(null)}
              className="text-micro text-ink-3 transition hover:text-ink"
            >
              Cancel
            </button>
          </>
        ) : (
          <button
            onClick={() => {
              setError(null);
              setConfirming('*');
            }}
            className="text-micro text-ink-3 transition hover:text-bad"
          >
            Sweep all orphans
          </button>
        )}
        {note && <span className="text-micro text-ok">{note}</span>}
        {error && <span className="text-micro text-bad">{error}</span>}
      </div>
    </div>
  );
}
