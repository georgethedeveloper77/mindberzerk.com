# Wiring the map into the Commerce page

Four files changed, one added. The page edit is described rather than patched:
`page.tsx` is 463 lines carrying a filter model, a detail pane and three empty
states, and rewriting it blind would take out working behaviour to gain a
drawing.

## What changed underneath

`skus.ts` gains a `feature` kind, exempt from the prefix check because there is
no `feature_` prefix and `terminal_pro` can never gain one: a Play product ID is
permanent.

`product-ids.ts` gains `ManualProduct.kind` and `kindOf`. Absent means read the
prefix, which is right for every product that follows the scheme. It is stored
only when it says something the prefix does not, so a kind that merely repeats
the prefix is never written twice.

`commerce.ts` seeds rows from all THREE sources rather than only the signed
index, records which in `SkuRow.sources`, and derives `SkuRow.state`. `orphans`
still exists and is now derived from the rows, so the two cannot disagree.

The "unlocks nothing" warning now fires only for `unlinked`. It used to fire for
`terminal_pro` too, forever, on a product working exactly as intended.

## The page edit

Two spots.

**1. Build the pack column.** The map needs every pack, free ones included,
because a free pack is the other half of the inventory rather than an absence.
`commerceReport` does not return packs today, so either add `packs` to the
report from the `live.packs` it already reads, or read the index again in the
page. The first is better: one read, one source.

    const packs = report.packs.map((p) => ({
      packId: p.packId,
      title: p.title || p.packId,
      free: !p.sku,
    }));

**2. Render it above the existing list.**

    <CommerceMap app={app} rows={report.rows} packs={packs} selected={sel ?? null} />

The severity-sorted list below it stays. It answers a different question: the map
shows what connects to what, the list shows what is wrong. That is not the two
lists problem this change fixes, because those were the same question answered
twice from different sources.

## What to delete once it renders

The Product IDs panel, whose contents are now the left column. Keep its add bar,
with a kind selector added, since `addManualProduct` takes a kind now.

The "In Play" panel, which is the `untracked` state.

The header tally. `0 products, 0 paid packs, 2 free` counts three different
populations. `9 products, 7 sell packs, 1 sells a feature, 1 not linked` is one
population and adds up.

## The known limit

Above roughly a dozen packs the curves will cross badly. The fix when that
happens is collapsing by distro or isolating on hover, not thinning the lines.
It is worth waiting for real density before choosing.
