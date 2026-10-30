'use client';

import { useEffect, useRef, useState } from 'react';
import { COPY } from './copy';
import { Icon } from './icons';
import { describeLocation, useWhoami } from './use-whoami';
import styles from './connect-demo.module.css';

type Phase = 'off' | 'connecting' | 'on';

/** Status colours per phase, mirroring the app's Home button. */
const TONE: Record<Phase, { text: string; soft: string; border: string; knob: string; wave: string; halo: string }> = {
  off: {
    text: 'text-gv-bad',
    soft: 'bg-gv-bad-soft',
    border: 'border-gv-bad',
    knob: 'bg-gv-knob text-gv-bad',
    wave: styles.fast,
    halo: 'from-gv-bad-soft',
  },
  connecting: {
    text: 'text-gv-warn',
    soft: 'bg-gv-warn-soft',
    border: 'border-gv-warn',
    knob: 'bg-gv-knob text-gv-warn',
    wave: styles.mid,
    halo: 'from-gv-warn-soft',
  },
  on: {
    text: 'text-gv-good',
    soft: 'bg-gv-good-soft',
    border: 'border-gv-good',
    knob: 'bg-gv-good text-gv-on-ink',
    wave: styles.slow,
    halo: 'from-gv-good-soft',
  },
};

const CONNECT_MS = 1400;

function Waves({ phase, mirrored = false }: { phase: Phase; mirrored?: boolean }) {
  const d = 'M0 40 Q 9.4 14 18.75 40 T 37.5 40 T 56.25 40 T 75 40 T 93.75 40 T 112.5 40 T 131.25 40 T 150 40';
  const echo = 'M0 40 Q 9.4 28 18.75 40 T 37.5 40 T 56.25 40 T 75 40 T 93.75 40 T 112.5 40 T 131.25 40 T 150 40';
  return (
    <svg
      viewBox="0 0 150 80"
      fill="none"
      aria-hidden
      className={`h-auto w-[70px] shrink sm:w-[150px] ${styles.wave} ${TONE[phase].wave} ${TONE[phase].text} ${mirrored ? styles.mirror : ''}`}
    >
      <path d={d} stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
      <path d={echo} stroke="currentColor" strokeOpacity="0.45" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function Readout({ label, value, mono = false }: { label: string; value: string | null; mono?: boolean }) {
  return (
    <div className="min-w-0 rounded-2xl bg-gv-surface-2 px-4 py-3.5">
      <div className="text-[11px] font-bold uppercase tracking-[0.12em] text-gv-muted">{label}</div>
      {value ? (
        <div className={`mt-1 truncate text-[17px] ${mono ? 'font-mono' : 'font-semibold'}`} title={value}>
          {value}
        </div>
      ) : (
        <div className="mt-2 h-4 w-3/4 animate-pulse rounded bg-gv-line" aria-hidden />
      )}
    </div>
  );
}

/**
 * The tap-to-connect demo. Off shows what sites see for this visitor right
 * now; connecting and on show a free server's view, which is the pitch in one
 * tap. A failed lookup drops the visitor's readouts instead of faking them.
 */
export function ConnectDemo() {
  const me = useWhoami();
  const [phase, setPhase] = useState<Phase>('off');
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );

  function toggle() {
    if (timer.current) clearTimeout(timer.current);
    if (phase === 'off') {
      setPhase('connecting');
      timer.current = setTimeout(() => setPhase('on'), CONNECT_MS);
    } else {
      setPhase('off');
    }
  }

  const tone = TONE[phase];
  const label = phase === 'on' ? COPY.demo.on : phase === 'connecting' ? COPY.demo.connecting : COPY.demo.off;
  const hint = phase === 'off' ? COPY.demo.tapOn : COPY.demo.tapOff;

  const protectedView = phase !== 'off';
  const myLocation = me ? describeLocation(me) : null;
  const ip = protectedView ? COPY.demo.serverIp : (me?.ip ?? null);
  const location = protectedView ? COPY.demo.serverLocation : myLocation;
  // Loading: both tiles hold their place. Failed: the visitor's tiles go.
  const showReadouts = protectedView || me !== null;
  const showLocation = protectedView || me === undefined || myLocation !== null;

  return (
    <div className="relative flex min-w-0 flex-col items-center gap-[22px] overflow-hidden rounded-[28px] border border-gv-line bg-gv-surface px-6 py-9 shadow-gv-card">
      <div
        className={`pointer-events-none absolute inset-x-0 top-0 h-2/3 bg-radial-[ellipse_at_50%_0%] ${tone.halo} to-transparent to-70% transition-colors duration-500`}
        aria-hidden
      />
      <div className="relative flex w-full items-center justify-center gap-2">
        <Waves phase={phase} />
        <div className="relative size-[168px] flex-none">
          <span className={`absolute inset-0 rounded-full ${tone.soft} ${styles.pulse}`} aria-hidden />
          <button
            type="button"
            onClick={toggle}
            aria-label={hint}
            aria-pressed={phase !== 'off'}
            className={`absolute inset-[14px] grid place-items-center rounded-full border-[6px] shadow-gv-card transition-all duration-300 ${tone.border} ${tone.knob}`}
          >
            <Icon name="power" size={48} strokeWidth={2.2} />
          </button>
        </div>
        <Waves phase={phase} mirrored />
      </div>

      <div className="relative flex flex-col gap-1.5 text-center" aria-live="polite">
        <div className={`text-[26px] font-extrabold ${tone.text}`}>{label}</div>
        <div className="text-sm text-gv-muted">{hint}</div>
      </div>

      {showReadouts && (
        <div className={`relative grid w-full gap-2.5 ${showLocation ? 'grid-cols-2' : 'grid-cols-1'}`}>
          <Readout label={COPY.demo.ipLabel} value={ip} mono />
          {showLocation && <Readout label={COPY.demo.locationLabel} value={location} />}
        </div>
      )}
    </div>
  );
}
