'use client';

/**
 * Form controls for the G VPN admin screens, in the panel's own tokens:
 * a real switch for on/off, a segmented choice for one-of-a-few, a stepper
 * for small numbers, a labelled setting row, and a save bar that appears
 * only when there is something to save.
 */

export function Switch({
  checked,
  onChange,
  label,
  disabled,
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
  /** Read by screen readers; the row shows the visible label. */
  label: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full border transition-colors duration-200 disabled:opacity-40 ${
        checked ? 'border-site-accent bg-site-accent' : 'border-site-line bg-site-sunk'
      }`}
    >
      <span
        aria-hidden
        className={`inline-block size-[18px] rounded-full bg-white shadow-[0_1px_3px_rgba(0,0,0,0.3)] transition-transform duration-200 ${
          checked ? 'translate-x-[22px]' : 'translate-x-[2px]'
        }`}
      />
    </button>
  );
}

export function Segmented<T extends string>({
  value,
  options,
  onChange,
  label,
}: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (next: T) => void;
  label: string;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex rounded-[10px] border border-site-line bg-site-sunk p-0.5">
      {options.map((o) => {
        const on = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={on}
            onClick={() => onChange(o.value)}
            className={`rounded-[8px] px-3 py-1 text-[12px] font-semibold transition-colors ${
              on ? 'bg-site-card text-site-ink shadow-site-soft' : 'text-site-ink-3 hover:text-site-ink'
            }`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

export function Stepper({
  value,
  min,
  max,
  step = 1,
  onChange,
  label,
  suffix,
}: {
  value: number;
  min: number;
  max: number;
  step?: number;
  onChange: (next: number) => void;
  label: string;
  suffix?: string;
}) {
  const set = (n: number) => onChange(Math.min(max, Math.max(min, n)));
  const btn =
    'grid size-7 place-items-center rounded-[8px] text-[15px] font-bold text-site-ink-3 transition hover:bg-site-card hover:text-site-ink disabled:opacity-30';
  return (
    <div className="inline-flex items-center gap-1 rounded-[10px] border border-site-line bg-site-sunk p-0.5">
      <button type="button" aria-label={`Less ${label}`} className={btn} disabled={value <= min} onClick={() => set(value - step)}>
        −
      </button>
      <input
        type="number"
        aria-label={label}
        value={value}
        min={min}
        max={max}
        onChange={(e) => set(Number(e.target.value) || min)}
        className="w-12 bg-transparent text-center font-mono text-[13px] font-semibold text-site-ink outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none"
      />
      {suffix && <span className="pr-1 text-[11.5px] text-site-ink-3">{suffix}</span>}
      <button type="button" aria-label={`More ${label}`} className={btn} disabled={value >= max} onClick={() => set(value + step)}>
        +
      </button>
    </div>
  );
}

/** One setting: what it is and what it does on the left, the control on the right. */
export function SettingRow({ title, hint, children }: { title: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-site-line py-3 last:border-b-0">
      <div className="min-w-0">
        <div className="text-[13px] font-semibold text-site-ink">{title}</div>
        {hint && <div className="mt-0.5 text-[11.5px] leading-relaxed text-site-ink-3">{hint}</div>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

/**
 * Floats at the bottom of the screen while there are unsaved changes, or
 * briefly after a save to say how it went.
 */
export function SaveBar({
  dirty,
  busy,
  note,
  onSave,
  onDiscard,
  saveLabel = 'Save and publish',
}: {
  dirty: boolean;
  busy: boolean;
  note: { ok: boolean; message: string } | null;
  onSave: () => void;
  onDiscard: () => void;
  saveLabel?: string;
}) {
  const shown = dirty || busy || note !== null;
  return (
    <div
      aria-live="polite"
      className={`sticky bottom-4 z-20 transition-all duration-200 ${shown ? 'translate-y-0 opacity-100' : 'pointer-events-none translate-y-3 opacity-0'}`}
    >
      <div className="ml-auto flex w-fit items-center gap-3 rounded-[14px] border border-site-line bg-site-card px-4 py-2.5 shadow-[0_12px_30px_rgba(0,0,0,0.35)]">
        <span className={`text-[12.5px] font-semibold ${note ? (note.ok ? 'text-site-ok' : 'text-site-bad') : 'text-site-ink'}`}>
          {note ? note.message : 'Unsaved changes'}
        </span>
        {dirty && !busy && (
          <button type="button" onClick={onDiscard} className="rounded-lg px-2.5 py-1.5 text-[12px] font-semibold text-site-ink-3 hover:text-site-ink">
            Discard
          </button>
        )}
        {dirty && (
          <button
            type="button"
            disabled={busy}
            onClick={onSave}
            className="rounded-lg border border-site-accent bg-site-accent px-3.5 py-1.5 text-[12px] font-semibold text-white transition hover:bg-site-accent-deep disabled:opacity-50"
          >
            {busy ? 'Saving' : saveLabel}
          </button>
        )}
      </div>
    </div>
  );
}
