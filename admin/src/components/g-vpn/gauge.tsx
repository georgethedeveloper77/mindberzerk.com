/**
 * A ring gauge: a share of something (CPU, memory, disk) as an arc, with the
 * number in the middle. Green under 60%, amber to 85%, red above.
 */
export function Gauge({ label, pct, detail }: { label: string; pct: number; detail?: string }) {
  const p = Math.max(0, Math.min(100, pct));
  const r = 30;
  const c = 2 * Math.PI * r;
  const colour = p >= 85 ? 'var(--color-site-bad)' : p >= 60 ? 'var(--color-site-plan)' : 'var(--color-site-ok)';
  return (
    <figure className="flex flex-col items-center gap-1.5">
      <svg width="84" height="84" viewBox="0 0 84 84" role="img" aria-label={`${label} ${Math.round(p)} percent`}>
        <circle cx="42" cy="42" r={r} fill="none" stroke="var(--color-site-line)" strokeWidth="8" />
        <circle
          cx="42"
          cy="42"
          r={r}
          fill="none"
          stroke={colour}
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={`${(p / 100) * c} ${c}`}
          transform="rotate(-90 42 42)"
        />
        <text x="42" y="47" textAnchor="middle" className="fill-site-ink font-mono text-[15px] font-semibold">
          {Math.round(p)}%
        </text>
      </svg>
      <figcaption className="text-center">
        <div className="text-[12px] font-semibold text-site-ink">{label}</div>
        {detail && <div className="font-mono text-[11px] text-site-ink-3">{detail}</div>}
      </figcaption>
    </figure>
  );
}

/** A small status dot; pulses while online. */
export function StatusDot({ online }: { online: boolean }) {
  return (
    <span className="relative inline-flex size-2.5" aria-hidden>
      {online && <span className="absolute inline-flex size-full animate-ping rounded-full bg-site-ok opacity-60" />}
      <span className={`relative inline-flex size-2.5 rounded-full ${online ? 'bg-site-ok' : 'bg-site-bad'}`} />
    </span>
  );
}
