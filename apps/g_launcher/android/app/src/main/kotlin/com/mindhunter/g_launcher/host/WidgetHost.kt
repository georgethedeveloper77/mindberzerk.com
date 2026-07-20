package com.mindhunter.g_launcher.host

/**
 * PHASE 4 (late) / PHASE 6.
 *
 * AppWidgetHost - lets G Launcher embed real Android widgets on the desktop.
 * Needed for: the conky-style system tile, G Recovery status tiles (storage,
 * last backup, network), and later the news feed.
 *
 * Embedding a native AppWidgetHostView inside Flutter means a PlatformView.
 * Those are not free - measure scroll performance on a budget device before
 * committing to widgets on the main workspace.
 */
