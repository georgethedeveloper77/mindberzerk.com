'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';

import type { OrphanGroup } from '@/lib/core/orphans';

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
 * Restyled onto the `site-` tokens with the launcher screens. The console
 * tokens it carried are dark-only, so inside the soft panel on CDN objects the
 * rows read as dark text on a light card and the confirm sentence was the
 * quietest thing in a destructive control.
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
      <div className="divide-y divide-site-line">
        {groups.map((g) => (
          <div key={g.dir} className="flex flex-wrap items-center gap-3 py-3">
            <div className="min-w-0 flex-1">
              <div className="truncate font-mono text-[12px] text-site-ink">{g.dir}</div>
              <div className="mt-0.5 text-[11px] leading-relaxed text-site-ink-3">
                {/* EVERY kind named, none reached by falling through. The
                    third arm used to be the default, which described `loose`
                    correctly by luck; a fourth kind added to OrphanGroup would
                    have silently inherited that sentence. */}
                {g.kind === 'stale'
                  ? `old version of ${g.packId}, still live at a newer one`
                  : g.kind === 'unpublished'
                    ? 'not in the catalogue; nothing new can discover it'
                    : g.kind === 'loose'
                      ? 'outside the pack layout, so no version owns it'
                      : 'unrecognised kind; nothing is deleted without the confirm below'}
                {` · ${g.keys.length} object${g.keys.length === 1 ? '' : 's'} · ${mb(g.sizeBytes)}`}
              </div>
            </div>
            {confirming === g.dir ? (
              <div className="flex items-center gap-3">
                <span className="max-w-[46ch] rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11px] leading-relaxed text-site-plan">
                  Deletes {g.keys.length} object{g.keys.length === 1 ? '' : 's'} for good. A
                  device mid-download of this exact version would fail its install.
                </span>
                <button
                  disabled={busy}
                  onClick={() => void sweep([g.dir])}
                  className="shrink-0 text-[11.5px] font-bold text-site-plan transition hover:brightness-110 disabled:opacity-50"
                >
                  {busy ? 'Deleting' : 'Confirm'}
                </button>
                <button
                  disabled={busy}
                  onClick={() => setConfirming(null)}
                  className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-ink"
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
                className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan"
              >
                Delete
              </button>
            )}
          </div>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3 border-t border-site-line pt-3">
        {confirming === '*' ? (
          <>
            <span className="max-w-[52ch] rounded-lg bg-site-plan-soft px-2.5 py-2 text-[11px] leading-relaxed text-site-plan">
              Deletes every group above, {groups.reduce((n, g) => n + g.keys.length, 0)} objects.
              The catalogue and every live pack are untouched.
            </span>
            <button
              disabled={busy}
              onClick={() => void sweep(groups.map((g) => g.dir))}
              className="shrink-0 text-[11.5px] font-bold text-site-plan transition hover:brightness-110 disabled:opacity-50"
            >
              {busy ? 'Deleting' : 'Confirm sweep all'}
            </button>
            <button
              disabled={busy}
              onClick={() => setConfirming(null)}
              className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-ink"
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
            className="shrink-0 text-[11.5px] font-semibold text-site-ink-3 transition hover:text-site-plan"
          >
            Sweep all orphans
          </button>
        )}
        {note && (
          <span className="rounded-lg bg-site-ok-soft px-2.5 py-1.5 text-[11.5px] text-site-ok">{note}</span>
        )}
        {error && (
          <span className="rounded-lg bg-site-plan-soft px-2.5 py-1.5 text-[11.5px] text-site-plan">{error}</span>
        )}
      </div>
    </div>
  );
}
