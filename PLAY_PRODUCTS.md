# Play Console in-app products — transcription sheet

All are **one-time products** (Play calls them "managed products" or "in-app
products"), never subscriptions. Create under Monetise → Products → In-app
products → Create product.

Product IDs **cannot be reused after deletion**, so get them right the first
time. These match `backend/content/products.json` exactly; if you change one,
change it in both places, because a sku that differs silently never matches what
Play reports as owned, and on-device that looks identical to the user not having
bought it.

## Set the USD price, then fix the local prices by hand

Play converts a US anchor by straight FX with no adjustment for purchasing
power. Your audience is Infinix, Tecno and Redmi owners, so the auto-generated
Kenyan, Nigerian and Indonesian prices will land far above what anyone there
pays for an app. After creating each product, open its price table and set those
markets manually.

Starting points, worth checking against what comparable launchers charge in each
store:

| Market | Single ($1.49) | Family ($3.99) | Complete ($11.99) |
|---|---|---|---|
| Kenya | ~KES 150 | ~KES 400 | ~KES 1,200 |
| India | ~₹59 | ~₹149 | ~₹449 |
| Nigeria, Indonesia, Pakistan, Egypt, Brazil, Philippines, Vietnam | same treatment | same treatment | same treatment |

Keep the complete collection near full price everywhere. The people who buy it
are not the price-sensitive segment, so discounting it costs revenue without
gaining volume.

## Singles — $1.49

| Product ID | Name | Description |
|---|---|---|
| `distro_pack_kali` | Kali | The Kali desktop: dragon wallpapers, the dark blue Kali palette, its own boot log and icon set. One-time purchase, yours forever. |
| `distro_pack_arch` | Arch + Hyprland | Arch with a Hyprland tiling shell: waybar, gaps, a verbose mkinitcpio boot log, and the Arch blue throughout. One-time purchase. |
| `distro_pack_garuda` | Garuda Dr460nized | The showpiece. Garuda's dragon palette, blur, and heavy visual treatment across every surface. One-time purchase. |
| `distro_pack_elementary` | elementary OS | Pantheon: a clean top bar and a centred magnifying dock, in elementary's soft grey palette. One-time purchase. |
| `distro_pack_mint` | Linux Mint | Cinnamon: a bottom panel, the Mint green palette, and its own wallpapers and boot log. One-time purchase. |
| `distro_pack_popos` | Pop!_OS | Pop!_OS with COSMIC: tiling by default, the Pop teal and orange, and System76's boot sequence. One-time purchase. |
| `distro_pack_debian` | Debian | Debian: the swirl, the deep red palette, and a plain honest desktop. One-time purchase. |

## Families — $3.99

| Product ID | Name | Description |
|---|---|---|
| `bundle_tiling` | Tiling collection | Every tiling desktop: Arch with Hyprland, Garuda Dr460nized, and any tiling distro added later. Cheaper than two on their own. |
| `bundle_classic` | Classic desktops | Linux Mint, elementary OS, Debian and Pop!_OS. Four traditional desktops, cheaper than three bought separately. |

## Complete — $11.99

| Product ID | Name | Description |
|---|---|---|
| `distro_pack_all` | Every distro, forever | All distro packs, including every one released in future. No subscription, no renewals. Buy once and the collection keeps growing. |

Every name is under Play's 55-character limit and every description is under
200, checked.

## What is deliberately NOT here

**Fedora and KDE Plasma have no product.** Both already ship bundled and free in
what is live. Making a shipped free theme paid is the one pricing move that
generates one-star reviews rather than revenue, and it is not recoverable. They
stay free permanently. Sell new distros instead.

**Ubuntu, Terminal and Aqua have no product**, by the same decision as before:
the free tier has to be complete enough to be worth talking about, and those
three are the ones that get screenshotted.

**There is no Pro feature unlock.** Icon shapes, gestures, grid settings,
folders, drawer styles and verbose boot stay free forever. A launcher that
paywalls the corner-radius slider reads as nickel-and-diming. If you later want
one for the boot-log editor and scheduled distro switching, add `pro_unlock` at
$2.99 — but only once those features exist, and never by removing something that
already shipped free.

**No subscription.** A launcher theme subscription churns hard and the audience
punishes it in reviews.

## The wiring, so nothing drifts

```
backend/content/products.json          <- source of truth, prices + grants
        │
        ├─> Play Console               (you transcribe, once)
        │
        └─> backend/content/g-launcher/index.json
                entitlements[]         (generated from the multi-grant products)
```

The index's `entitlements` block was generated from `products.json`, so bundle
membership is identical in both. Only the multi-grant products appear there;
singles are carried on their pack's own `sku` field instead.

`grants` names pack ids that mostly do not exist yet, and that is fine on
purpose. `CdnIndex` deliberately allows a bundle to name an unshipped pack, so
you can announce a collection before its contents are live and the grant simply
matches nothing until the pack appears.

## Order of operations, given the two-day key wait

Nothing here is blocked by the AAB.

1. Create the ten products in Play Console now. Prices and descriptions are
   editable later; the IDs are not.
2. Upload the index and the brand pack to R2. Both are CDN-side and need no
   release.
3. When the AAB window opens, ship the build with `PackKeys` populated.

The one thing that must not slip: **`PackKeys.ACCEPTED_HEX` has to hold the
public half of the key you sign packs with.** If the app ships with the
placeholder zeros, every pack is refused with `UnknownKey` and the only fix is
another release.
