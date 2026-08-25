'use client';

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  useTransition,
  type ReactNode,
} from 'react';
import { useRouter } from 'next/navigation';

/**
 * MULTI-SELECT OVER A SERVER-RENDERED LIST.
 *
 * Both list screens render their rows on the server, which is why they can show
 * a wallpaper swatch, a live version and a listing flag without a single fetch
 * in the browser. Selection is the one thing that has to be client state, so it
 * arrives as three small islands around that markup rather than as a rewrite of
 * it: a provider wrapping the section, a checkbox inside each row, and a bar
 * above it. The rows stay server components and keep every fact they had.
 *
 * ─── WHY A CONTEXT AND NOT PROPS ────────────────────────────────────────────
 *
 * The checkbox and the bar are siblings separated by a server-rendered subtree,
 * so there is no prop path between them. A provider is the only thing that
 * crosses that boundary, and it works because a client provider may take server
 * children: they are already-rendered elements passed through, not re-rendered
 * by the client.
 */

interface BulkCtx {
  selected: Set<string>;
  toggle: (id: string) => void;
  clear: () => void;
}

const Ctx = createContext<BulkCtx | null>(null);

export function BulkProvider({ children }: { children: ReactNode }) {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const toggle = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const clear = useCallback(() => setSelected(new Set()), []);

  const value = useMemo(() => ({ selected, toggle, clear }), [selected, toggle, clear]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

function useBulk(): BulkCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('BulkProvider is missing above this component');
  return ctx;
}

/**
 * One row's checkbox.
 *
 * It sits INSIDE the row's `<Link>`, so both events have to be stopped: the
 * click would otherwise navigate to the inspector while also ticking the box,
 * which is two intentions from one press and neither of them clearly.
 */
export function RowCheck({ id, disabled, why }: { id: string; disabled?: boolean; why?: string }) {
  const { selected, toggle } = useBulk();

  if (disabled) {
    return (
      <span
        aria-hidden
        title={why}
        className="grid size-[18px] shrink-0 place-items-center rounded-[5px] border border-dashed border-site-line text-[9px] text-site-ink-3"
      >
        {'\u00b7'}
      </span>
    );
  }

  return (
    <span
      role="checkbox"
      aria-checked={selected.has(id)}
      tabIndex={0}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggle(id);
      }}
      onKeyDown={(e) => {
        if (e.key !== ' ' && e.key !== 'Enter') return;
        e.preventDefault();
        e.stopPropagation();
        toggle(id);
      }}
      className={`grid size-[18px] shrink-0 cursor-pointer place-items-center rounded-[5px] border transition ${
        selected.has(id)
          ? 'border-site-accent bg-site-accent text-white'
          : 'border-site-line bg-site-card hover:border-site-ink-3'
      }`}
    >
      {selected.has(id) ? (
        <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 8.5l3.2 3.2L13 5" />
        </svg>
      ) : null}
    </span>
  );
}

export interface BulkOutcome {
  id: string;
  ok: boolean;
  detail: string;
}

/**
 * The bar above the list: count, the action, and then the RESULT PER ITEM.
 *
 * ─── EVERY ITEM REPORTS, AND THAT IS THE WHOLE DESIGN ───────────────────────
 *
 * The tempting shape is one button and one toast. It is also the shape that
 * loses work: these operations refuse individually and for good reasons (a
 * bundled id, a pack a distro still names, an index that would be left empty),
 * so a run of nine where two refuse is the NORMAL case, not the error case.
 * Collapsing that into "done" hides two refusals, and collapsing it into
 * "failed" hides seven successes. So the caller returns one line per id and
 * this renders all of them until the next selection.
 *
 * Items are processed SEQUENTIALLY by the action, not in parallel: each one
 * re-signs the index, and concurrent writers would race the catalogue.
 */
export function BulkBar({
  noun,
  verb,
  app,
  action,
  runVerb,
  runEach,
}: {
  /** Singular noun for the count, e.g. "icon pack". */
  noun: string;
  /** The destructive word on the button, e.g. "Delete". */
  verb: string;
  app: string;
  /**
   * THE SERVER ACTION ITSELF, not a closure over it.
   *
   * A server component may only hand a client component values it can
   * serialise, and an arrow function written at the call site is not one:
   * `run={async (ids) => bulkDeleteDistrosAction(appId, ids)}` fails at render
   * with "Functions cannot be passed directly to Client Components". A
   * `'use server'` export IS passable, because what crosses the boundary is a
   * reference the runtime can call rather than the function body. So the bound
   * argument moves to its own prop and this stays a plain reference.
   */
  action: (app: string, ids: string[]) => Promise<BulkOutcome[]>;

  /**
   * AN OPTIONAL SECOND VERB, RUN ONE AT A TIME FROM THE CLIENT.
   *
   * ─── WHY NOT JUST ANOTHER BATCH ACTION ──────────────────────────────────
   *
   * Delete returns in about a second, so `action` waiting for the whole list
   * and reporting at the end is fine. Republish signs a pack and re-signs the
   * index per distro; fourteen of those is a minute or more of a page that
   * looks hung, and a failure at the second one stays invisible until the
   * fourteenth finishes.
   *
   * So this prop is a SINGLE-item action the loop below awaits in order. Same
   * sequential guarantee `action` has, for the same reason (concurrent writers
   * would race the index), but each row lands as it happens.
   *
   * ─── AND IT STOPS ON THE FIRST FAILURE ──────────────────────────────────
   *
   * Not because stopping undoes anything: by then the earlier items are
   * already live. It stops so the remaining ones are not published on top of a
   * state you have not looked at yet, and so the decision to continue is one
   * you make rather than one the loop makes for you.
   *
   * NO ARMING. Arming exists to catch an accidental irreversible click, and a
   * republish is neither. A confirm here would only train the reflex that
   * makes the delete confirm useless.
   */
  /** Imperative, e.g. "Republish". Omit along with `runEach` to hide the verb. */
  runVerb?: string;

  /**
   * FLAT, NOT NESTED IN AN OBJECT WITH `runVerb`.
   *
   * Same reason `app` is its own prop rather than a closure: what may cross the
   * server/client boundary is a `'use server'` reference, and the note above
   * records what happens when something less careful is tried. An action
   * reference inside an object literal is very probably fine, and this file has
   * already paid once for "very probably fine".
   */
  runEach?: (app: string, id: string) => Promise<BulkOutcome>;
}) {
  const router = useRouter();
  const { selected, clear } = useBulk();
  const [armed, setArmed] = useState(false);
  const [results, setResults] = useState<BulkOutcome[] | null>(null);
  const [pending, start] = useTransition();

  // ── per-item run state ────────────────────────────────────────────────────
  //
  // `done` accumulates outcomes as they land and doubles as the cursor: the
  // next id to process is always `queue[done.length]`. One source of truth, so
  // "skip and continue" is just a resume from that index with the failed one
  // already recorded.
  const [queue, setQueue] = useState<string[] | null>(null);
  const [done, setDone] = useState<BulkOutcome[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [halted, setHalted] = useState(false);

  const ids = [...selected];
  if (ids.length === 0 && !results && !queue) return null;

  /** Walks the queue from `from`, stopping at the first failure. */
  async function walk(list: string[], from: number, acc: BulkOutcome[]) {
    for (let i = from; i < list.length; i++) {
      const id = list[i];
      setBusy(id);
      let out: BulkOutcome;
      try {
        out = await runEach!(app, id);
      } catch (e) {
        // A thrown action is a failed row, never a dead loop. The server
        // action already returns its refusals; this catches the transport.
        out = { id, ok: false, detail: (e as Error).message || 'the request failed' };
      }
      acc = [...acc, out];
      setDone(acc);
      if (!out.ok) {
        setBusy(null);
        setHalted(true);
        return;
      }
    }
    setBusy(null);
    setHalted(false);
    setQueue(null);
    setResults(acc);
    clear();
    router.refresh();
  }

  return (
    <div className="rounded-[14px] border border-site-line bg-site-card px-4 py-3 shadow-site-soft">
      {ids.length > 0 && (
        <div className="flex flex-wrap items-center gap-3">
          <span className="text-[13px] font-semibold text-site-ink">
            {ids.length} {noun}
            {ids.length === 1 ? '' : 's'} selected
          </span>

          {!armed ? (
            <button
              type="button"
              onClick={() => setArmed(true)}
              className="text-[12.5px] font-semibold text-site-plan hover:underline"
            >
              {verb}
            </button>
          ) : (
            <>
              <button
                type="button"
                disabled={pending}
                onClick={() => {
                  setResults(null);
                  start(async () => {
                    const out = await action(app, ids);
                    setResults(out);
                    setArmed(false);
                    clear();
                    router.refresh();
                  });
                }}
                className="rounded-lg bg-site-plan px-3 py-1.5 text-[12.5px] font-semibold text-white disabled:opacity-60"
              >
                {pending ? `${verb}ing` : `${verb} ${ids.length}`}
              </button>
              <button
                type="button"
                disabled={pending}
                onClick={() => setArmed(false)}
                className="text-[12.5px] text-site-ink-3 hover:text-site-ink"
              >
                Cancel
              </button>
            </>
          )}

          {runVerb && runEach && !armed ? (
            <button
              type="button"
              disabled={pending || !!queue}
              onClick={() => {
                setResults(null);
                setDone([]);
                setHalted(false);
                setQueue(ids);
                void walk(ids, 0, []);
              }}
              className="rounded-lg border border-site-line px-3 py-1.5 text-[12.5px] font-semibold text-site-ink disabled:opacity-60"
            >
              {runVerb} {ids.length}
            </button>
          ) : null}

          <button
            type="button"
            onClick={clear}
            className="ml-auto text-[12.5px] text-site-ink-3 hover:text-site-ink"
          >
            Clear
          </button>
        </div>
      )}

      {queue ? (
        <div className="mt-3 border-t border-site-line pt-3">
          <div className="flex flex-wrap items-center gap-3">
            <span className="text-[12.5px] text-site-ink-2">
              {halted
                ? `${done.filter((d) => d.ok).length} done, stopped at a failure`
                : `${done.length} of ${queue.length}`}
            </span>
            {halted ? (
              <>
                <button
                  type="button"
                  onClick={() => {
                    setHalted(false);
                    void walk(queue, done.length, done);
                  }}
                  className="rounded-lg bg-site-plan px-3 py-1.5 text-[12.5px] font-semibold text-white"
                >
                  Skip and continue
                </button>
                <button
                  type="button"
                  onClick={() => {
                    // Keeps what already landed as the result list. The run is
                    // abandoned, not undone; pretending otherwise by clearing
                    // would hide which distros are already live at a new
                    // version.
                    setResults(done);
                    setQueue(null);
                    setHalted(false);
                    clear();
                    router.refresh();
                  }}
                  className="text-[12.5px] text-site-ink-3 hover:text-site-ink"
                >
                  Stop here
                </button>
              </>
            ) : null}
          </div>

          <div className="mt-1 h-[4px] overflow-hidden rounded-full bg-site-bg">
            <div
              className="h-full bg-site-plan transition-all"
              style={{ width: `${(done.length / queue.length) * 100}%` }}
            />
          </div>

          <ul className="mt-2 space-y-1">
            {done.map((r) => (
              <li key={r.id} className="flex gap-2 text-[11.5px] leading-relaxed">
                <span className={`font-mono ${r.ok ? 'text-site-ok' : 'text-site-plan'}`}>
                  {r.ok ? 'done' : 'fail'}
                </span>
                <span className="font-mono text-site-ink-2">{r.id}</span>
                <span className="text-site-ink-3">{r.detail}</span>
              </li>
            ))}
            {busy ? (
              <li className="flex gap-2 text-[11.5px] leading-relaxed">
                <span className="font-mono text-site-ink-3">busy</span>
                <span className="font-mono text-site-ink-2">{busy}</span>
                <span className="text-site-ink-3">signing the pack, writing the index</span>
              </li>
            ) : null}
          </ul>
        </div>
      ) : null}

      {results && (
        <ul className="mt-2 space-y-1 border-t border-site-line pt-2">
          {results.map((r) => (
            <li key={r.id} className="flex gap-2 text-[11.5px] leading-relaxed">
              <span className={`font-mono ${r.ok ? 'text-site-ok' : 'text-site-plan'}`}>
                {r.ok ? 'done' : 'kept'}
              </span>
              <span className="font-mono text-site-ink-2">{r.id}</span>
              <span className="text-site-ink-3">{r.detail}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
