/**
 * The PUBLIC loading state.
 *
 * The root skeleton is admin-shaped: a header bar and four stat blocks on the
 * console's dark surfaces. Inherited here it means a visitor sees a dark
 * dashboard skeleton for a moment and then a light marketing page, which reads
 * as a broken load rather than a slow one.
 *
 * This is the landing's own shape instead: an eyebrow, a headline, two store
 * badges and the featured card beside them. It carries `data-surface="soft"`
 * for the same reason the error boundary does, since the group's layout is not
 * mounted while this renders.
 *
 * The proportions matter more than the detail. A skeleton that matches what
 * arrives makes the page appear to settle; one that does not makes it appear to
 * be replaced.
 */
export default function PublicLoading() {
  return (
    <div
      data-surface="soft"
      aria-hidden
      className="min-h-[100dvh] animate-pulse bg-site-page font-site-sans"
    >
      <div className="mx-auto flex h-[72px] max-w-[1180px] items-center gap-9 px-7">
        <span className="size-[30px] rounded-[9px] bg-site-sunk" />
        <span className="h-3.5 w-28 rounded bg-site-sunk" />
        <span className="flex-1" />
        <span className="h-9 w-32 rounded-full bg-site-sunk" />
      </div>

      <div className="mx-auto grid max-w-[1180px] items-center gap-14 px-7 pb-20 pt-16 lg:grid-cols-[1fr_0.98fr]">
        <div>
          <span className="block h-7 w-64 rounded-full bg-site-sunk" />
          <span className="mt-5 block h-11 w-full rounded-lg bg-site-sunk" />
          <span className="mt-2.5 block h-11 w-4/5 rounded-lg bg-site-sunk" />
          <span className="mt-6 block h-4 w-3/4 rounded bg-site-sunk" />
          <span className="mt-2 block h-4 w-2/3 rounded bg-site-sunk" />
          <div className="mt-8 flex gap-3.5">
            <span className="h-[46px] w-[160px] rounded-[14px] bg-site-sunk" />
            <span className="h-[46px] w-[160px] rounded-[14px] bg-site-sunk" />
          </div>
        </div>

        <div className="rounded-[30px] border border-site-line bg-site-card p-7 shadow-site-soft">
          <div className="grid min-h-[356px] items-center gap-6 min-[621px]:grid-cols-[1fr_176px]">
            <div>
              <span className="block h-5 w-20 rounded-full bg-site-sunk" />
              <span className="mt-3.5 block h-6 w-40 rounded bg-site-sunk" />
              <span className="mt-3 block h-3.5 w-full rounded bg-site-sunk" />
              <span className="mt-2 block h-3.5 w-4/5 rounded bg-site-sunk" />
              <span className="mt-4 block h-8 w-28 rounded-full bg-site-sunk" />
            </div>
            <span className="h-[342px] w-[176px] rounded-[28px] bg-site-sunk" />
          </div>
        </div>
      </div>
    </div>
  );
}
