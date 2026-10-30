'use client';

import * as React from 'react';

/**
 * EXPORT: every distro as a zip of `<id>.theme.json`, or all of them as one
 * JSON array on the clipboard. Both are the canonical files publish signs, and
 * both import straight back.
 */
export function ExportDistros({ app }: { app: string }) {
  const [open, setOpen] = React.useState(false);
  const [note, setNote] = React.useState<string | null>(null);
  const base = `/apps/${app}/distros/export`;
  const ref = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [open]);

  const copyAll = async () => {
    setNote(null);
    try {
      const res = await fetch(`${base}?format=json`, { cache: 'no-store' });
      if (!res.ok) throw new Error(`export failed (${res.status})`);
      await navigator.clipboard.writeText(await res.text());
      setNote('copied');
    } catch (e) {
      setNote((e as Error).message || 'copy failed');
    }
    setTimeout(() => setNote(null), 1800);
  };

  const item =
    'block w-full rounded-lg px-3 py-2 text-left text-[13px] text-site-ink hover:bg-site-sunk';

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="inline-flex items-center gap-1.5 rounded-[10px] border border-site-line bg-site-card px-3.5 py-2 text-[13px] font-semibold text-site-ink transition hover:bg-site-sunk"
      >
        {note ?? 'Export'}
      </button>
      {open && (
        <div
          role="menu"
          className="absolute right-0 z-40 mt-1.5 w-[220px] rounded-[12px] border border-site-line bg-site-card p-1.5 shadow-site-soft"
        >
          <a role="menuitem" href={`${base}?format=zip`} className={item} onClick={() => setOpen(false)}>
            Download all (.zip)
          </a>
          <button
            type="button"
            role="menuitem"
            className={item}
            onClick={() => {
              setOpen(false);
              void copyAll();
            }}
          >
            Copy all as JSON
          </button>
        </div>
      )}
    </div>
  );
}
