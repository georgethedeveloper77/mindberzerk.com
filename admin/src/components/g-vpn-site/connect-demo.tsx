'use client';

import { useEffect, useRef, useState } from 'react';
import { COPY, WHOAMI_URL } from './copy';
import { Icon } from './icons';
import styles from './connect-demo.module.css';

type Phase = 'off' | 'connecting' | 'on';

/** What the internet sees for this visitor, from the gvpn-whoami Worker. */
interface Seen {
  ip: string;
  location: string | null;
}

/** Status colours per phase, mirroring the app's Home button. */
const TONE: Record<Phase, { text: string; soft: string; border: string; knob: string; wave: string }> = {
  off: {
    text: 'text-gv-bad',
    soft: 'bg-gv-bad-soft',
    border: 'border-gv-bad',
    knob: 'bg-gv-knob text-gv-bad',
    wave: styles.fast,
  },
  connecting: {
    text: 'text-gv-warn',
    soft: 'bg-gv-warn-soft',
    border: 'border-gv-warn',
    knob: 'bg-gv-knob text-gv-warn',
    wave: styles.mid,
  },
  on: {
    text: 'text-gv-good',
    soft: 'bg-gv-good-soft',
    border: 'border-gv-good',
    knob: 'bg-gv-good text-gv-on-ink',
    wave: styles.slow,
  },
};

const CONNECT_MS = 1400;
const WHOAMI_TIMEOUT_MS = 5000;

/** "Nairobi, Kenya" from Cloudflare's city plus ISO country code. */
function describeLocation(city: unknown, country: unknown): string | null {
  const code = typeof country === 'string' && /^[A-Z]{2}$/.test(country) ? country : null;
  let name: string | null = code;
  if (code) {
    try {
      name = new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code;
    } catch {
      // Older engines without DisplayNames keep the bare code.
    }
  }
  const place = typeof city === 'string' && city.trim() ? city.trim() : null;
  if (place && name) return `${place}, ${name}`;
  return place ?? name;
}

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
    <div className="min-w-0 rounded-[18px] bg-gv-surface-2 px-4 py-3.5">
      <div className="text-xs font-bold uppercase tracking-[0.08em] text-gv-muted">{label}</div>
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
 * The hero's interactive connect button. Off shows what sites see for this
 * visitor right now; connecting and on show a free server's view, which is
 * the whole pitch in one tap.
 */
export function ConnectDemo() {
  const [phase, setPhase] = useState<Phase>('off');
  const [seen, setSeen] = useState<Seen | null>(null);
  const [lookupFailed, setLookupFailed] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    // Set on unmount, so an abort from cleanup is not reported as a failure;
    // an abort from the timeout is.
    let disposed = false;
    const timeout = setTimeout(() => controller.abort(), WHOAMI_TIMEOUT_MS);

    fetch(WHOAMI_URL, { signal: controller.signal, cache: 'no-store' })
      .then((res) => (res.ok ? res.json() : Promise.reject(new Error(`whoami ${res.status}`))))
      .then((body: Record<string, unknown>) => {
        if (typeof body.ip !== 'string' || !body.ip) throw new Error('whoami: no ip');
        if (disposed) return;
        setSeen({ ip: body.ip, location: describeLocation(body.city, body.country) });
      })
      .catch(() => {
        // Blocked by an extension, offline, or CORS not deployed yet: the
        // readouts are dropped rather than filled with a stand-in.
        if (!disposed) setLookupFailed(true);
      })
      .finally(() => clearTimeout(timeout));

    return () => {
      disposed = true;
      clearTimeout(timeout);
      controller.abort();
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

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

  // Off: the visitor's own address. Connecting or on: the free server's.
  const protectedView = phase !== 'off';
  const showReadouts = protectedView || !lookupFailed;
  const ip = protectedView ? COPY.demo.serverIp : (seen?.ip ?? null);
  const location = protectedView ? COPY.demo.serverLocation : (seen?.location ?? null);
  // While loading both tiles hold their place; a lookup with no geo drops one.
  const showLocation = protectedView || !seen || location !== null;

  return (
    <div className="relative flex min-w-0 flex-[1_1_440px] flex-col items-center gap-[22px] overflow-hidden rounded-[28px] border border-gv-line bg-gv-surface px-6 py-9 shadow-gv-card">
      <div className="flex w-full items-center justify-center gap-2">
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

      <div className="flex flex-col gap-1.5 text-center" aria-live="polite">
        <div className={`text-[26px] font-extrabold ${tone.text}`}>{label}</div>
        <div className="text-sm text-gv-muted">{hint}</div>
      </div>

      {showReadouts && (
        <div className={`grid w-full gap-2.5 ${showLocation ? 'grid-cols-2' : 'grid-cols-1'}`}>
          <Readout label={COPY.demo.ipLabel} value={ip} mono />
          {showLocation && <Readout label={COPY.demo.locationLabel} value={location} />}
        </div>
      )}
    </div>
  );
}
