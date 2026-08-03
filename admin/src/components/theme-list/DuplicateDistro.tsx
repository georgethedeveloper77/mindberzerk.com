'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';

import { duplicateDistroAction } from '@/app/apps/[app]/distros/actions';

/**
 * Duplicate a distro into a new draft.
 *
 * The id is asked for UP FRONT rather than generated, because it is permanent
 * from the moment the copy is saved: it becomes the pack id, the bucket
 * directory and the device's install path, and the workspace will not let it
 * be edited afterwards for exactly that reason. A generated `kali-2024-copy`
 * would be a permanent identifier chosen by a default.
 *
 * The seeded value is a suggestion and nothing more. The server refuses an id
 * that already exists as a draft or a published pack, so a collision costs a
 * message rather than an overwrite.
 */
export function DuplicateDistro({ app, fromId }: { app: string; fromId: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [id, setId] = useState(`${fromId}-copy`);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="text-[12.5px] font-semibold text-site-ink-2 hover:text-site-ink hover:underline"
      >
        Duplicate
      </button>
    );
  }

  return (
    <div className="w-full rounded-[10px] border border-site-line bg-site-sunk px-3 py-2.5">
      <label className="block text-[11.5px] text-site-ink-3">New distro id</label>
      <input
        value={id}
        autoFocus
        autoCapitalize="none"
        spellCheck={false}
        onChange={(e) => setId(e.target.value)}
        className="mt-1 w-full rounded-lg border border-site-line bg-site-card px-2.5 py-1.5 font-mono text-[12.5px]"
      />
      <p className="mt-1.5 text-[11px] leading-relaxed text-site-ink-3">
        Copies the theme and its art into a new draft. Nothing is published, and the copy carries
        no product ID: a Play product belongs to one pack only.
      </p>

      <div className="mt-2.5 flex items-center gap-3">
        <button
          type="button"
          disabled={pending || !id.trim()}
          onClick={() => {
            setError(null);
            start(async () => {
              const res = await duplicateDistroAction(app, fromId, id);
              if (!res.ok) {
                setError(res.error);
                return;
              }
              setOpen(false);
              router.push(`/apps/${app}/distros/builder?id=${res.id}`);
            });
          }}
          className="rounded-lg bg-site-accent px-3 py-1.5 text-[12.5px] font-semibold text-white disabled:opacity-60"
        >
          {pending ? 'Copying' : 'Create copy'}
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => setOpen(false)}
          className="text-[12.5px] text-site-ink-3 hover:text-site-ink"
        >
          Cancel
        </button>
      </div>

      {error && (
        <p className="mt-2 rounded-[8px] bg-site-plan-soft px-2.5 py-1.5 text-[11.5px] leading-relaxed text-site-plan">
          {error}
        </p>
      )}
    </div>
  );
}
