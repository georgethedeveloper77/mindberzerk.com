package com.mindhunter.g_launcher.host

/**
 * PHASE D9 — DEFERRED, NOT CANCELLED. Nothing here is implemented.
 *
 * Third-party Android widgets (`AppWidgetHost`) on the G Launcher desktop.
 *
 * ─── WHY THIS IS STILL A STUB AFTER PHASE D ─────────────────────────────────
 *
 * Phase D built DESKLETS instead: our own tiles, rendered in Flutter, placed on
 * the same grid, skinned per distro. That covers the clock, the conky, network,
 * storage, battery, fastfetch, notes and search, and it is what makes this
 * launcher look like a Linux desktop rather than a launcher with widgets on it.
 *
 * Three reasons this came second, and they should be re-read before it comes
 * first:
 *
 *  1. IT IS NOT THE DIFFERENTIATOR. Every launcher hosts widgets. None of them
 *     boots with a fake GRUB log into a waybar. Time spent here is time not
 *     spent on the thing nobody else has.
 *
 *  2. IT COSTS A PLATFORMVIEW ON THE ONE SCREEN THAT MUST FEEL INSTANT.
 *     `AppWidgetHostView` is a real Android `View`; Flutter draws into its own
 *     surface and cannot composite one except through a PlatformView. That
 *     means hybrid composition on the home screen, on the budget devices this
 *     app targets. Measure it on a Tecno before committing, not after.
 *
 *  3. IT WILL NOT PARALLAX. The desktop is a vertical PageView with a parallax
 *     tint; a PlatformView slides as a flat rectangle through it and cannot be
 *     tinted, scaled or clipped the way a Dart-drawn desklet can. On a canvas
 *     whose whole job is to feel like a moving desktop, one rectangle that
 *     refuses to move with it is visible immediately.
 *
 * Eventually table stakes all the same — people want their bank, their music
 * and their calendar widgets — so this is a "when", not an "if". Do it once the
 * desklet placement grid has proven itself in the wild.
 *
 * ─── THE TRAP, WRITTEN DOWN NOW WHILE IT IS FRESH ───────────────────────────
 *
 * **Every `allocateAppWidgetId()` that is not matched by a `deleteAppWidgetId()`
 * leaks a permanent host id.** They accumulate in the system's own bookkeeping,
 * not ours, and on several OEM skins they SURVIVE AN APP DATA CLEAR — so the
 * usual "clear data and try again" does not undo it, and a user who has been
 * adding and removing widgets for a month is carrying every id they ever made.
 *
 * There are THREE paths that allocate, and all three must delete:
 *
 *   a. the user removes a placed widget          -> delete
 *   b. the user cancels the BIND permission dialog -> delete
 *   c. the user cancels the provider's CONFIGURE activity -> delete
 *
 * (b) and (c) are the ones that get missed, because they are the paths where
 * nothing appeared on screen, so there is nothing visible to clean up. Allocate
 * as late as possible and wrap every early return.
 *
 * ─── THE SHAPE, WHEN IT IS TIME ─────────────────────────────────────────────
 *
 *  1. `AppWidgetHost` subclass, created ONCE in the Activity (not the
 *     Application: it is tied to a window). `startListening()` in `onStart`,
 *     `stopListening()` in `onStop`. Listening while backgrounded is a battery
 *     cost for updates nobody can see.
 *
 *  2. `allocateAppWidgetId()` -> `ACTION_APPWIDGET_BIND`. A launcher holding
 *     the HOME role can be granted `BIND_APPWIDGET`, but it still needs the
 *     user grant path via `bindAppWidgetIdIfAllowed()`, falling back to the
 *     system dialog. -> `ACTION_APPWIDGET_CONFIGURE` if the provider declares
 *     one.
 *
 *  3. A `PlatformViewFactory` returning the `AppWidgetHostView`.
 *
 *  4. One hardcoded slot on the GNOME desktop rendering one bound widget.
 *     Get a clock widget on screen and measure the scroll. THEN the grid, then
 *     the picker, then persistence.
 *
 * Persistence is nearly free when it arrives: the `Desklet` record already
 * carries a free-form `config` map, so a hosted widget is a desklet kind whose
 * config holds its `appWidgetId`. It gets placement, resize, removal and the
 * per-workspace grid without any new storage — which is the other reason
 * desklets went first.
 *
 * ─── WHAT THIS FILE IS NOT ──────────────────────────────────────────────────
 *
 * Not the route for ECOSYSTEM tiles (D8: G Recovery status, the news feed).
 * Those are our own apps, so they are desklet kinds with a different data
 * source — a signature-permission ContentProvider — and need no widget host at
 * all. They would only need one if the requirement changed to "our tiles must
 * also work on OTHER launchers", which is a different product decision and not
 * this one.
 */
