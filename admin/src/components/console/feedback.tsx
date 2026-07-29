'use client';

import * as React from 'react';
import { C } from '../theme-builder/console';

/**
 * The shared feedback layer for the whole panel: toasts, skeletons, and a button
 * that all agree on ink, focus, and motion. Dependency-free on purpose (no Sonner,
 * no react-hot-toast), because the panel already ships its own console palette and
 * a second toast library would drag its own theme in to fight it. Accessible by
 * construction: toasts announce over aria-live, errors are assertive, everything
 * is keyboard-dismissable, and motion yields to prefers-reduced-motion.
 */

// ── one-shot keyframes + focus ring ──────────────────────────────────────────

/** Mount once, high in the tree (layout.tsx). Included by ToastProvider too, so
 *  toasts and skeletons animate even before a page mounts its own. */
export function KitStyle() {
  return (
    <style
      dangerouslySetInnerHTML={{
        __html: `
@keyframes tbk-in { from { opacity:0; transform:translateY(10px) scale(.98) } to { opacity:1; transform:none } }
@keyframes tbk-shimmer { 0% { background-position:100% 0 } 100% { background-position:-100% 0 } }
.tbk-focus:focus-visible { outline:none; box-shadow:0 0 0 2px ${C.bg}, 0 0 0 4px ${C.amber}; }
@media (prefers-reduced-motion: reduce){ .tbk-anim { animation:none !important } }
`,
      }}
    />
  );
}

// ── toasts ───────────────────────────────────────────────────────────────────

type ToastKind = 'success' | 'error' | 'info';
interface ToastItem {
  id: number;
  kind: ToastKind;
  msg: string;
}
interface ToastApi {
  success: (msg: string) => void;
  error: (msg: string) => void;
  info: (msg: string) => void;
  dismiss: (id: number) => void;
}

const ToastCtx = React.createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const ctx = React.useContext(ToastCtx);
  if (!ctx) throw new Error('useToast must be used inside <ToastProvider>');
  return ctx;
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = React.useState<ToastItem[]>([]);
  const idRef = React.useRef(0);
  const timers = React.useRef<Map<number, ReturnType<typeof setTimeout>>>(new Map());

  const dismiss = React.useCallback((id: number) => {
    setItems((x) => x.filter((t) => t.id !== id));
    const h = timers.current.get(id);
    if (h) {
      clearTimeout(h);
      timers.current.delete(id);
    }
  }, []);

  const push = React.useCallback(
    (kind: ToastKind, msg: string) => {
      const id = ++idRef.current;
      setItems((x) => [...x, { id, kind, msg }]);
      timers.current.set(id, setTimeout(() => dismiss(id), 3600));
    },
    [dismiss],
  );

  React.useEffect(() => {
    const t = timers.current;
    return () => t.forEach((h) => clearTimeout(h));
  }, []);

  const api = React.useMemo<ToastApi>(
    () => ({
      success: (m) => push('success', m),
      error: (m) => push('error', m),
      info: (m) => push('info', m),
      dismiss,
    }),
    [push, dismiss],
  );

  return (
    <ToastCtx.Provider value={api}>
      {children}
      <KitStyle />
      <div
        style={{ position: 'fixed', right: 20, bottom: 20, zIndex: 9999, display: 'flex', flexDirection: 'column', gap: 8, maxWidth: 400, pointerEvents: 'none' }}
      >
        {items.map((t) => (
          <ToastView key={t.id} item={t} onDismiss={() => dismiss(t.id)} />
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

function ToastView({ item, onDismiss }: { item: ToastItem; onDismiss: () => void }) {
  const color = item.kind === 'success' ? C.green : item.kind === 'error' ? C.red : C.amber;
  return (
    <div
      role={item.kind === 'error' ? 'alert' : 'status'}
      aria-live={item.kind === 'error' ? 'assertive' : 'polite'}
      className="tbk-anim tbk-focus"
      tabIndex={0}
      onClick={onDismiss}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'Escape') onDismiss();
      }}
      style={{
        pointerEvents: 'auto',
        cursor: 'pointer',
        fontFamily: C.mono,
        fontSize: 13,
        color,
        background: C.raised,
        border: `1px solid ${color}`,
        borderLeftWidth: 3,
        borderRadius: 8,
        padding: '10px 14px',
        boxShadow: '0 12px 30px -12px rgba(0,0,0,0.7)',
        animation: 'tbk-in .18s ease',
      }}
    >
      {item.msg}
    </div>
  );
}

// ── skeletons ────────────────────────────────────────────────────────────────

export function Skeleton({
  width = '100%',
  height = 14,
  radius = 6,
  style,
}: {
  width?: number | string;
  height?: number | string;
  radius?: number;
  style?: React.CSSProperties;
}) {
  return (
    <span
      aria-hidden
      className="tbk-anim"
      style={{
        display: 'block',
        width,
        height,
        borderRadius: radius,
        background: `linear-gradient(90deg, ${C.chip} 25%, rgba(200,216,200,0.14) 50%, ${C.chip} 75%)`,
        backgroundSize: '200% 100%',
        animation: 'tbk-shimmer 1.3s linear infinite',
        ...style,
      }}
    />
  );
}

export function SkeletonText({ lines = 3 }: { lines?: number }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton key={i} width={i === lines - 1 ? '58%' : '100%'} />
      ))}
    </div>
  );
}

/** A card placeholder for a loading table row or tile. */
export function SkeletonCard({ height = 64 }: { height?: number }) {
  return (
    <div style={{ border: `1px solid ${C.lineSoft}`, borderRadius: 10, background: C.surface, padding: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
      <Skeleton width={height - 28} height={height - 28} radius={8} />
      <div style={{ flex: 1 }}>
        <SkeletonText lines={2} />
      </div>
    </div>
  );
}

// ── button ───────────────────────────────────────────────────────────────────

type ButtonVariant = 'primary' | 'ghost' | 'danger';

export function Button({
  children,
  onClick,
  variant = 'primary',
  disabled,
  busy,
  type = 'button',
  title,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  variant?: ButtonVariant;
  disabled?: boolean;
  busy?: boolean;
  type?: 'button' | 'submit';
  title?: string;
}) {
  const base: React.CSSProperties = {
    fontFamily: C.mono,
    fontSize: 12.5,
    borderRadius: 7,
    padding: '8px 16px',
    cursor: disabled || busy ? 'not-allowed' : 'pointer',
    // Busy dims too. The label used to be REPLACED by an ellipsis while
    // working, which loses the one piece of information the button carries at
    // the moment you most want it — you tapped Publish, and now it says nothing
    // about what is publishing. The button is already `disabled` while busy, so
    // dimming is the whole signal and the word stays put.
    opacity: disabled || busy ? 0.5 : 1,
    transition: 'background .12s, border-color .12s, opacity .12s',
  };
  const skin: Record<ButtonVariant, React.CSSProperties> = {
    primary: { fontWeight: 700, color: C.onAccent, background: C.amber, border: 'none' },
    ghost: { color: C.ink, background: C.chip, border: `1px solid ${C.line}` },
    danger: { color: C.red, background: 'transparent', border: `1px solid ${C.red}` },
  };
  return (
    <button
      type={type}
      className="tbk-focus"
      onClick={onClick}
      disabled={disabled || busy}
      title={title}
      style={{ ...base, ...skin[variant] }}
    >
      {children}
    </button>
  );
}
