'use client';

import { COPY } from './copy';
import type { LiveSnapshot } from './live-types';
import { useLive } from './use-live';
import styles from './landing.module.css';

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex items-baseline gap-2.5">
      <b className="text-[26px] font-bold tracking-[-0.02em] tabular-nums text-gv-text">{value}</b>
      <span className="text-[11px] font-bold uppercase tracking-[0.2em] text-gv-muted">{label}</span>
    </div>
  );
}

/**
 * The hero's live numbers, refreshed with the shared live store. The live
 * group is left out when the free list cannot be read, so a visitor never
 * sees a stand-in number.
 */
export function LiveStats({ initial }: { initial: LiveSnapshot }) {
  const free = useLive(initial).free;
  const s = COPY.stats;
  return (
    <div className="pointer-events-none relative mt-16 flex flex-wrap justify-between gap-6 pb-5">
      {free ? (
        <div className="flex flex-wrap items-baseline gap-x-9 gap-y-4">
          <span className="inline-flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.2em] text-gv-good">
            <i className={styles.live} aria-hidden />
            {s.live}
          </span>
          <Stat value={free.servers.toLocaleString('en-US')} label={s.servers} />
          <Stat value={String(free.countries.length)} label={s.countries} />
        </div>
      ) : (
        <span />
      )}
      <div className="flex flex-wrap items-baseline gap-x-9 gap-y-4">
        <Stat value={String(COPY.tools.items.length)} label={s.tools} />
        <Stat value={String(s.languageCount)} label={s.languages} />
      </div>
    </div>
  );
}
