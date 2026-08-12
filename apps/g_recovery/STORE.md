# G RECOVERY / STORE COPY

Everything that goes into Play Console, written to be pasted. Nothing here is a
draft to be reworded later: the permission declarations are judged on whether the
stated use matches what the app does, so the wording IS the commitment.

---

## In-app product

**Product ID:** `pro_unlock`

Deliberately one product. The launcher sells many because a distro is a distinct
thing a person chooses; here there is nothing to choose between. Two SKUs would
mean two upgrade paths, two states to test, and a question at the till.

**Type:** Managed product, one time purchase. Not a subscription.

A subscription cannot be defended when the marginal cost of the thing being sold
is zero. Compression runs entirely on the phone: no server, no bandwidth, no
per-user cost whether someone compresses one file or four thousand. Charging
monthly for that invites exactly the comparison it would lose.

**Name (55 char limit):**

    G Recovery Pro

**Description (200 char limit):**

    Compress, archive and export in batches instead of one file at a time.
    Every recovery and scanning feature stays free. One payment, no
    subscription, no ads, no account.

### Pricing

Two tiers, matching the launcher's split.

| Region | Price |
|---|---|
| Default | $4.99 |
| KE, NG, IN, PK, and comparable markets | $2.49 |

### What it unlocks

Pro sells LABOUR, not capability. Every feature works free on one item at a time,
chosen by hand. Pro does the whole selection unattended.

- Batch compression, a whole selection in one run
- Batch archive to a home server, once that exists
- Scheduled backups
- PDF export of a storage or device report

### What is free, permanently

If a person cannot get a deleted photo back without paying, every honesty claim
this product makes collapses. So:

- All recovery, every source, unlimited
- All scanning, including the whole-phone background scan
- The complete storage breakdown, duplicates, similar photos, large files
- The entire Device tab, including the live monitors a competitor charges for
- The message archive
- Compression of one file at a time

### What will never be sold

- Ads, in any form
- A subscription
- First-party cloud storage
- Anything that makes the free app worse in order to sell the paid one

---

## Photo and video permissions declaration

Both under the 250 character limit. Both end on "never uploaded", which is true,
is the first thing a reviewer wonders about a media-reading app, and costs nine
characters.

### READ_MEDIA_IMAGES

    G Recovery lists photos in the system trash and in app trash folders so
    users can restore them, shows thumbnails so a file is recognisable before
    restoring, and reports how much space images use so storage can be freed.
    Images are never uploaded.

### READ_MEDIA_VIDEO

    G Recovery lists videos in the system trash and in app trash folders so
    users can restore them, plays a video so it can be identified before
    restoring, and reports how much space video uses so users can free storage.
    Videos are never uploaded.

---

## Still open, and each one blocks a release

- **K1.** The live listing declares "Contains ads" for an app that has none and
  never will. This is a wrong statement on a public listing and takes minutes to
  correct.
- **K2.** The icon is a stock trash can shared with about nine competitors.
- **K3.** Store screenshots show `0 Files`.
- **K6.** Upload keystore location and the live versionCode have never been
  written down anywhere.
- MANAGE_EXTERNAL_STORAGE needs its own declaration, separate from the two
  above, and it is the one most likely to draw questions. The answer is the same
  as the permission text: app trash folders belong to other apps, and no narrower
  permission reaches them.
