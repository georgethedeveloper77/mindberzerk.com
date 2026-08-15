'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

import {
  planRenameAction,
  runRenameAction,
} from '@/app/apps/[app]/icons/rename/actions';
import type { RenameOutcome, RenamePlan } from '@/lib/g-launcher/pack-rename';

/**
 * CHECK, READ, THEN RUN. The Run button does not exist until a check has come
 * back clean, because the operation publishes to a CDN every installed launcher
 * reads and the interesting facts (is the old pack published, does a distro
 * still name it, is a bundle granting it) are only knowable from the bucket.
 */
export function RenamePack({
  app,
  initialFrom = '',
  initialTo = '',
}: {
  app: string;
  initialFrom?: string;
  initialTo?: string;
}) {
  const router = useRouter();
  const [from, setFrom] = useState(initialFrom);
  const [to, setTo] = useState(initialTo);
  const [plan, setPlan] = useState<RenamePlan | null>(null);
  const [outcome, setOutcome] = useState<RenameOutcome | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);

  const field =
    'mt-1 w-full rounded-lg border border-site-line bg-site-sunk px-3 py-2 font-mono text-[13px]';
  const label = 'block text-[11.5px] text-site-ink-3';
  const card = 'rounded-[14px] border border-site-line bg-site-sunk p-4';
  const bad =
    'rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan';
  const info =
    'rounded-[14px] bg-site-info-soft px-4 py-3 text-[13px] leading-relaxed text-site-info';

  function reset() {
    setPlan(null);
    setOutcome(null);
    setError(null);
    setConfirm(false);
  }

  async function check() {
    setBusy(true);
    reset();
    try {
      const res = await planRenameAction(app, from, to);
      if (res.ok) setPlan(res.plan);
      else setError(res.error);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function run() {
    setBusy(true);
    setError(null);
    try {
      const res = await runRenameAction(app, from, to);
      if (res.ok) {
        setOutcome(res.outcome);
        setPlan(null);
        router.refresh();
      } else {
        setError(res.error);
      }
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
      setConfirm(false);
    }
  }

  const blocked = !!plan && plan.refusals.length > 0;

  return (
    <div className="space-y-4">
      <div className={card}>
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className={label}>Current pack id</label>
            <input
              value={from}
              onChange={(e) => {
                setFrom(e.target.value);
                reset();
              }}
              placeholder="ubuntu-24-04-icons"
              autoCapitalize="none"
              spellCheck={false}
              className={field}
            />
          </div>
          <div>
            <label className={label}>New pack id</label>
            <input
              value={to}
              onChange={(e) => {
                setTo(e.target.value);
                reset();
              }}
              placeholder="papirus-icon-theme"
              autoCapitalize="none"
              spellCheck={false}
              className={field}
            />
          </div>
        </div>
        <p className="mt-3 text-[11.5px] leading-relaxed text-site-ink-3">
          The art moves, the id does not. A rename creates a new pack at version 1 and leaves the
          old one published, because a device holding the old catalogue may still be resolving it.
          Pulling the old pack is a separate act on the icons list, once the repointed distro has
          had time to reach phones.
        </p>
        <div className="mt-4 flex gap-2">
          <button
            onClick={check}
            disabled={busy || !from.trim() || !to.trim()}
            className="rounded-lg border border-site-line bg-site-sunk px-4 py-2 text-[13px] font-medium text-site-ink-2 disabled:opacity-40"
          >
            {busy && !confirm ? 'Checking' : 'Check'}
          </button>
        </div>
      </div>

      {error && <p className={bad}>{error}</p>}

      {plan && (
        <div className={card}>
          <p className="text-[13px] text-site-ink-2">
            <span className="font-mono">{plan.from}</span> to{' '}
            <span className="font-mono">{plan.to}</span>
          </p>

          <dl className="mt-3 space-y-2 text-[12.5px]">
            <Row k="Art">
              {plan.source
                ? `${plan.iconCount} icons, read from the ${plan.source}`
                : 'not read, because the check refused'}
            </Row>
            <Row k="Old pack">
              {plan.publishedFrom
                ? `published at v${plan.publishedFrom.version}, staying published`
                : 'never published, draft only'}
            </Row>
            <Row k="New pack">{`published at v${plan.newVersion}`}</Row>
            <Row k="Shelf">
              {plan.shelfFrom === plan.shelfTo
                ? plan.shelfTo
                  ? `stays under ${plan.shelfTo}`
                  : 'stays standalone'
                : `moves from ${plan.shelfFrom ?? 'standalone'} to ${plan.shelfTo ?? 'standalone'}`}
            </Row>
            <Row k="Distros repointed">
              {plan.themeRefs.length
                ? plan.themeRefs.map((t) => `${t.title} (${t.field})`).join(', ')
                : 'none'}
            </Row>
          </dl>

          {plan.refusals.length > 0 && (
            <ul className="mt-4 space-y-2">
              {plan.refusals.map((r) => (
                <li key={r} className={bad}>
                  {r}
                </li>
              ))}
            </ul>
          )}

          {plan.warnings.length > 0 && (
            <ul className="mt-4 space-y-2">
              {plan.warnings.map((w) => (
                <li key={w} className={info}>
                  {w}
                </li>
              ))}
            </ul>
          )}

          {!blocked && (
            <div className="mt-4 flex items-center gap-3">
              {confirm ? (
                <>
                  <button
                    onClick={run}
                    disabled={busy}
                    className="rounded-lg bg-site-plan-soft px-4 py-2 text-[13px] font-medium text-site-plan disabled:opacity-40"
                  >
                    {busy ? 'Running' : `Yes, publish ${plan.to}`}
                  </button>
                  <button
                    onClick={() => setConfirm(false)}
                    disabled={busy}
                    className="text-[13px] text-site-ink-3"
                  >
                    Cancel
                  </button>
                </>
              ) : (
                <button
                  onClick={() => setConfirm(true)}
                  className="rounded-lg border border-site-line bg-site-sunk px-4 py-2 text-[13px] font-medium text-site-ink-2"
                >
                  Run the migration
                </button>
              )}
            </div>
          )}
        </div>
      )}

      {outcome && (
        <div className={card}>
          <p className="text-[13px] font-medium text-site-ink-2">
            {outcome.ok ? 'Migration finished.' : 'Migration stopped part way.'}
          </p>
          <ol className="mt-3 space-y-3">
            {outcome.steps.map((s, i) => (
              <li key={`${s.label}-${i}`} className="text-[12.5px] leading-relaxed">
                <span className={s.ok ? 'text-site-ink-2' : 'text-site-plan'}>
                  {s.ok ? 'Done' : 'Failed'} · {s.label}
                </span>
                <span className="block text-site-ink-3">{s.detail}</span>
              </li>
            ))}
          </ol>
        </div>
      )}
    </div>
  );
}

function Row({ k, children }: { k: string; children: React.ReactNode }) {
  return (
    <div className="flex gap-3">
      <dt className="w-36 shrink-0 text-site-ink-3">{k}</dt>
      <dd className="text-site-ink-2">{children}</dd>
    </div>
  );
}
