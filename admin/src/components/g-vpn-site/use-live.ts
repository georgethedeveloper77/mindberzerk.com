'use client';

import { useEffect, useSyncExternalStore } from 'react';
import { LIVE_POLL_MS, LIVE_ROUTE, type LiveSnapshot } from './live-types';

/**
 * One shared live snapshot for every component on the page (both maps, the
 * stats and the feed), refreshed by a single poller while the tab is visible.
 * The server-rendered snapshot seeds it, so the first paint is already real
 * data and nothing flickers on hydration.
 */

let current: LiveSnapshot | null = null;
const listeners = new Set<() => void>();
let timer: ReturnType<typeof setInterval> | null = null;

function emit(next: LiveSnapshot) {
  current = next;
  listeners.forEach((l) => l());
}

async function refresh() {
  if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return;
  try {
    const res = await fetch(LIVE_ROUTE, { cache: 'no-store' });
    if (!res.ok) return;
    const next = (await res.json()) as LiveSnapshot;
    // A failed source on refresh keeps the last good value rather than
    // emptying a map the visitor is looking at.
    emit({
      free: next.free ?? current?.free ?? null,
      gservers: next.gservers.length > 0 ? next.gservers : (current?.gservers ?? []),
      at: next.at,
    });
  } catch {
    // Offline: keep showing the last snapshot.
  }
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  if (!timer) timer = setInterval(refresh, LIVE_POLL_MS);
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0 && timer) {
      clearInterval(timer);
      timer = null;
    }
  };
}

export function useLive(initial: LiveSnapshot): LiveSnapshot {
  useEffect(() => {
    // Seed once from the server render, so a refresh that loses one source
    // still has the server's value to fall back on.
    if (current === null) current = initial;
    const onVisible = () => {
      if (document.visibilityState === 'visible') void refresh();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [initial]);
  return useSyncExternalStore(
    subscribe,
    () => current ?? initial,
    () => initial,
  );
}

/** "Japan" from "JP", falling back to the code. */
export function countryName(code: string): string {
  try {
    return new Intl.DisplayNames(['en'], { type: 'region' }).of(code) ?? code;
  } catch {
    return code;
  }
}
