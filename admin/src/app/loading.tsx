/**
 * PHASE C-polish - the loading state every page inherits.
 *
 * Pages block on an R2 read (the index, a manifest, the site doc) and R2 is not
 * instant, so without this the screen is blank until the read returns. This is a
 * single skeleton at the route level: a header bar and four stat-sized blocks,
 * pulsing, so a slow bucket looks like a load and not a hang. It is intentionally
 * generic - one skeleton for the whole app rather than a bespoke one per page,
 * because the shell is identical and the content area is what varies.
 */
export default function Loading() {
  return (
    <div className="animate-pulse p-4 sm:p-6" aria-hidden>
      <div className="mb-4 h-5 w-40 rounded bg-surface-2" />
      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-20 rounded-card border border-line-soft bg-surface-1" />
        ))}
      </div>
      <div className="mt-3 h-64 rounded-card border border-line-soft bg-surface-1 sm:mt-4" />
    </div>
  );
}
