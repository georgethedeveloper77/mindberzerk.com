'use client';

import * as React from 'react';

import { repairEntitlementsAction } from '@/app/apps/[app]/commerce/actions';
import type { EntitlementRepair } from '@/lib/g-launcher/repair-entitlements';

/**
 * Repair grants, from the page that already names the fault.
 *
 * ─── WHY THERE ARE TWO BUTTONS AND NOT A CHECKBOX ───────────────────────────
 *
 * Repair is additive: it can only add a grant, so the worst case of pressing it
 * by mistake is that nothing happens. Deleting an orphan takes access away from
 * anyone who bought under the old product id, and cannot be undone from here.
 *
 * A checkbox beside one button makes those the same gesture with a modifier,
 * which is how the destructive one gets pressed by someone who meant the safe
 * one. Two buttons, and the second only appears once a repair has actually
 * found orphans to name.
 *
 * ─── AND IT REPORTS EVERY LINE ──────────────────────────────────────────────
 *
 * Not a count. "3 entitlements repaired" is a number nobody can check;
 * `distro_kali: added kali-2024-line` is a sentence you can compare against the
 * index. This whole class of bug went unnoticed for weeks because the pipeline
 * was quiet about what it changed.
 */
export function RepairGrants({ app }: { app: string }) {
  const [busy, setBusy] = React.useState(false);
  const [out, setOut] = React.useState<EntitlementRepair | null>(null);

  async function run(deleteOrphans: boolean) {
    setBusy(true);
    try {
      setOut(await repairEntitlementsAction(app, deleteOrphans));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-3 rounded-xl border border-site-line bg-site-plan p-4">
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={busy}
          onClick={() => run(false)}
          className="rounded-lg bg-site-ink px-3 py-1.5 font-mono text-[12px] font-semibold text-site-plan disabled:opacity-50"
        >
          {busy ? 'Working' : 'Repair grants'}
        </button>
        <span className="text-[11.5px] text-site-ink-3">
          Adds the icon pack each paid distro owns. Never removes a grant, so it
          is safe to run twice.
        </span>
      </div>

      {out && !out.ok ? (
        <p className="mt-3 font-mono text-[11.5px] text-site-ink">
          {out.error}
        </p>
      ) : null}

      {out?.ok ? (
        <div className="mt-3 space-y-1">
          {out.changes.length === 0 ? (
            <p className="font-mono text-[11.5px] text-site-ink-3">
              Nothing to add. Every entitlement already grants what its distro
              owns.
            </p>
          ) : (
            out.changes.map((c) => (
              <p key={c} className="font-mono text-[11.5px] text-site-ink">
                {c}
              </p>
            ))
          )}

          {out.orphans.length > 0 ? (
            <div className="mt-3 border-t border-site-line pt-3">
              <p className="text-[11.5px] text-site-ink-3">
                {out.orphans.join(', ')} {out.orphans.length === 1 ? 'is' : 'are'}{' '}
                granted by no product any pack carries. Removing{' '}
                {out.orphans.length === 1 ? 'it' : 'them'} takes access away from
                anyone who bought under{' '}
                {out.orphans.length === 1 ? 'that id' : 'those ids'} before it was
                replaced.
              </p>
              <button
                type="button"
                disabled={busy}
                onClick={() => run(true)}
                className="mt-2 rounded-lg border border-site-line px-3 py-1.5 font-mono text-[12px] text-site-ink disabled:opacity-50"
              >
                Remove {out.orphans.length === 1 ? 'it' : 'them'} anyway
              </button>
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
