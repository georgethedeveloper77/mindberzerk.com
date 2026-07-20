# Architecture — the decisions, and why

Short document. If a decision isn't load-bearing, it isn't here.

---

## 1. Flutter is the UI. Kotlin is the engine.

The single most important call in this project.

- A multi-GB overnight backup **cannot** depend on a live Flutter engine. It runs
  in **WorkManager, in Kotlin**. Flutter configures it and watches progress.
- Scanning 50,000 photos, hashing them, transcoding video: native jobs. Kotlin
  does the work and streams results into Dart.
- The launcher's app list and icon rendering live in Kotlin, cached as bitmaps
  on disk. Flutter draws the desktop.

Get this backwards and both apps crawl on the budget hardware most of our users
actually own. Flutter is the UI, navigation, state and business-logic layer.
It is not the engine.

---

## 2. Four shells, many themes.

Ubuntu and Fedora are both GNOME: **same shell, different `ThemeSpec`.**

    gnome   -> Ubuntu, Fedora
    plasma  -> KDE
    tiling  -> Arch/Hyprland, i3
    tui     -> Terminal, Kali

A theme is *data*: palette + shell + dock side + icon treatment + wallpaper.
That is what makes "ship a new distro over the CDN with no app update" true
rather than aspirational.

If you write a shell per distro, you have built a maintenance trap. If you find
yourself writing `if (theme.id == 'fedora')` inside a widget — stop. Something
belongs in the spec that isn't in it yet.

---

## 3. You do not draw every icon.

Two layers get you 100% coverage for ~50 drawings per theme:

1. **Generator** — every app's adaptive icon has separate foreground/background
   layers, and Android 13+ apps ship a monochrome layer too. `IconRenderer`
   re-masks, re-shapes and re-tints them. Every app on the phone gets themed,
   including ones you've never heard of.
2. **Hero set** — hand-craft only the 40–60 icons that *define* the distro
   (Files/Nautilus, Terminal, Settings, Software) plus the common third-party
   apps people actually have. These override the generator, and ship in an
   icon-pack over the CDN.

---

## 4. Signed content, or don't ship it.

Themes drive fonts, colours, layout and icons. Content that drives UI is
code-adjacent. Every CDN manifest is signed with ed25519 at publish time and
verified at load time against a public key baked into the app.

Skip this and whoever controls the CDN controls the app.

---

## 5. Opinionated defaults, full escape hatches.

The default look is the **authentic** desktop — Ubuntu means a real GNOME top
bar and a *left* dock, not a generic bottom row. That authenticity is the entire
product; it's the thing Nova and One UI will never do.

But every layout choice is overridable in Settings: dock Left/Bottom/Off, grid
rows × columns, icon size, drawer style. Overrides are stored **per theme**, so
trying KDE doesn't wipe how you'd set up Ubuntu.

---

## 6. The launcher must always render.

A corrupt theme, a failed signature, a missing pack — fall back to bundled Ubuntu,
silently. A user with a broken home screen has a bricked phone. There is no
error state that justifies a black rectangle.

---

## 7. No melos yet. No iOS launcher, ever.

**Melos** earns its keep when app #2 exists. Until then, shared code lives in
`lib/core/` and `lib/design/` inside the launcher, kept import-clean so the lift
is an afternoon.

**iOS** does not permit replacing the home screen. There is no launcher category
on the App Store because launchers cannot exist there. G Launcher is
Android-only, permanently. (G Recovery's iOS version is a genuinely different,
thinner app — photo cleanup, backup-to-your-server, vault. No undelete. Phase 7.)
