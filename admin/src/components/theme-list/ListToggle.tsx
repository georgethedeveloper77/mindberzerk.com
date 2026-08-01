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

  const label = disabled ? 'Bundled, always available' : on ? 'Listed' : 'Hidden';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={`Listing: ${label}`}
      title={label}
      onClick={toggle}
      disabled={disabled || busy}
      // SOFT REGISTER. The console tokens this used to carry (`bg-surface-3`,
      // `bg-accent-ink`) are dark-only, so on the redesigned screens the track
      // rendered as a dark slab on a light card. `site-` tokens carry a value
      // for both modes.
      className={`relative inline-flex h-[22px] w-10 shrink-0 items-center rounded-full border transition disabled:opacity-40 ${
        on ? 'border-site-ok bg-site-ok' : 'border-site-line bg-site-sunk'
      }`}
    >
      <span
        className={`inline-block size-4 rounded-full transition ${
          on ? 'translate-x-[19px] bg-white' : 'translate-x-[3px] bg-site-ink-3'
        }`}
      />
    </button>
  );
}
