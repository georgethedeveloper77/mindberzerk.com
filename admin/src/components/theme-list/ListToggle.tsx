'use client';

import * as React from 'react';
import { setPackListed } from '@/app/apps/[app]/themes/actions';

export function ListToggle({
  app,
  packId,
  initial,
  disabled,
}: {
  app: string;
  packId: string;
  initial: boolean;
  disabled?: boolean;
}) {
  const [on, setOn] = React.useState(initial);
  const [busy, setBusy] = React.useState(false);

  async function toggle() {
    if (disabled || busy) return;
    const next = !on;
    setOn(next); // optimistic
    setBusy(true);
    const res = await setPackListed(app, packId, next);
    setBusy(false);
    if (!res.ok) setOn(!next); // revert
  }

  const label = disabled ? 'Bundled - always available' : on ? 'Listed' : 'Hidden';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={`Listing: ${label}`}
      title={label}
      onClick={toggle}
      disabled={disabled || busy}
      className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border transition disabled:opacity-40 ${
        on ? 'border-accent bg-accent' : 'border-line bg-surface-3'
      }`}
    >
      <span
        className={`inline-block size-3.5 rounded-full transition ${
          on ? 'translate-x-4 bg-accent-ink' : 'translate-x-0.5 bg-ink-3'
        }`}
      />
    </button>
  );
}
