'use client';

import { useEffect, useState } from 'react';

/**
 * Light and dark. The rules, in order:
 *
 * 1. No stored choice: the system preference wins, via the media query in
 *    globals.css, and this button shows whichever mode that resolved to.
 * 2. A press stores an explicit choice in localStorage and sets
 *    data-theme on <html>, which outranks the media query.
 *
 * The inline script in layout.tsx replays the stored choice before first
 * paint, so a dark-mode visitor never sees a white flash.
 */

const KEY = 'mb-theme';
type Mode = 'light' | 'dark';

function effectiveMode(): Mode {
  const set = document.documentElement.dataset.theme;
  if (set === 'light' || set === 'dark') return set;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function ThemeToggle() {
  // Null until mounted: the server cannot know the mode, so it renders a
  // neutral button and the icon appears on hydration.
  const [mode, setMode] = useState<Mode | null>(null);

  useEffect(() => {
    setMode(effectiveMode());
  }, []);

  function toggle() {
    const next: Mode = (mode ?? effectiveMode()) === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(KEY, next);
    } catch {
      // Private mode without storage still gets the visual switch.
    }
    setMode(next);
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={mode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
      className="grid size-10 place-items-center rounded-full border-[1.5px] border-site-line bg-site-card text-site-ink-3 transition hover:text-site-ink"
    >
      {mode === 'dark' ? (
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden>
          <circle cx="8" cy="8" r="3.4" />
          <path d="M8 1.2v1.6M8 13.2v1.6M1.2 8h1.6M13.2 8h1.6M3.2 3.2l1.1 1.1M11.7 11.7l1.1 1.1M12.8 3.2l-1.1 1.1M4.3 11.7l-1.1 1.1" />
        </svg>
      ) : mode === 'light' ? (
        <svg width="15" height="15" viewBox="0 0 15 15" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M13 9.2A5.6 5.6 0 116.2 2.1a4.6 4.6 0 006.8 7.1z" />
        </svg>
      ) : (
        <span className="size-4" aria-hidden />
      )}
    </button>
  );
}
