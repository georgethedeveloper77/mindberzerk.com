/**
 * The dashboard's own layout, for one reason: the canvas.
 *
 * `globals.css` paints `body` with `surface-0` and pins `color-scheme: dark` on
 * `<html>`, which is correct for the console and wrong for this screen. A
 * wrapper div alone cannot fix it, because overscroll, the scrollbar and the
 * area below short content are painted by `<html>` itself.
 *
 * So this marks the subtree instead, and `globals.css` carries the rule that
 * follows it. No inline script, nothing written onto `<html>` before
 * hydration, and the canvas is correct on a client navigation as well as on a
 * cold load. The stored light or dark preference is replayed once in the root
 * layout, which is the only place `beforeInteractive` is allowed.
 */
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <div data-surface="soft">{children}</div>;
}
