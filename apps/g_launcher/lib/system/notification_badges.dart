import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/effective_theme.dart';
import '../engine/theme_spec.dart' show ShellKind;

/// Notification badges: how many live notifications each app has.
///
/// ─── WHY A METHOD CHANNEL AND NOT PIGEON ────────────────────────────────────
///
/// Everything else native goes through Pigeon. This does not, and the reason is
/// written at length in `NotificationBadges.kt`: a badge feature wants a "dot
/// or count or none" enum, Pigeon numbers enums positionally, and a third enum
/// in `launcher_api.dart` renumbers every class in a codec that a shipped APK
/// already agrees on. `pack_api.dart` is a separate schema for exactly this
/// reason. A plain channel needs no schema and cannot shift anything.
///
/// ─── THE KEY IS PACKAGE PLUS USER, NOT PACKAGE ──────────────────────────────
///
/// A work-profile app is a separate [AppEntry] with the SAME package name, so
/// counts keyed on package alone would put the work chat's unread number on the
/// personal one. Native keys on `packageName#userSerial` and [badgeFor] below
/// composes the same string from the entry.
const _channel = MethodChannel('g_launcher/notifications');

/// Live counts, keyed `packageName#userSerial`.
///
/// Empty until the user grants notification access, and empty again the moment
/// they revoke it: the service publishes an empty map on disconnect rather than
/// leaving the last numbers on screen, because every one of them is by then a
/// claim it cannot support.
final badgeCountsProvider =
    NotifierProvider<BadgeCounts, Map<String, int>>(BadgeCounts.new);

class BadgeCounts extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'badges') return null;
      final raw = call.arguments;
      if (raw is! Map) return null;
      state = {
        for (final e in raw.entries)
          if (e.key is String && e.value is int) e.key as String: e.value as int,
      };
      return null;
    });

    // Ask once on start. The listener service is constructed by the SYSTEM and
    // may have connected long before this provider existed, in which case there
    // is no future push to wait for: the counts are already sitting in the
    // bridge's cache and nothing would arrive until the next notification, which
    // on a quiet phone could be an hour of blank icons.
    //
    // Post-frame is not needed. This is an async call whose result lands in a
    // later microtask, so it cannot write to the provider during build.
    _refresh();

    ref.onDispose(() => _channel.setMethodCallHandler(null));

    return const {};
  }

  Future<void> _refresh() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('refresh');
      if (raw == null) return;
      state = {
        for (final e in raw.entries)
          if (e.key is String && e.value is int) e.key as String: e.value as int,
      };
    } on PlatformException {
      // Never granted, or the channel is not up on this build. An absent badge
      // is the correct rendering of "we do not know", and it is not worth a log
      // line on every cold start.
    } on MissingPluginException {
      // The Dart half shipped ahead of the native half. Same answer.
    }
  }

  /// Pull the current state again. Call after returning from the system's
  /// notification-access screen, where a grant produces no event we can see.
  Future<void> refresh() => _refresh();
}

/// Whether the user has granted notification access.
///
/// Deliberately NOT cached in prefs. It is revocable from Android's own
/// settings at any moment and we are never told, so a stored flag would go
/// stale silently and the launcher would show a settings row claiming badges
/// are on while none were being drawn. Asked fresh; invalidate to re-ask.
final notificationAccessProvider = FutureProvider<bool>((ref) async {
  try {
    return await _channel.invokeMethod<bool>('isEnabled') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
});

/// Open Android's notification-access screen.
///
/// A full page with a confirmation dialog, because there is no runtime-prompt
/// form of this permission. The caller should invalidate
/// [notificationAccessProvider] and call [BadgeCounts.refresh] when the user
/// comes back, since nothing tells us a grant happened.
Future<void> openNotificationAccessSettings() async {
  try {
    await _channel.invokeMethod<void>('openSettings');
  } on PlatformException {
    // Handled natively with a fallback to the top-level settings screen; if
    // even that failed there is nothing useful to say here.
  } on MissingPluginException {
    // Nothing to open.
  }
}

/// How a badge is drawn.
enum BadgeStyle {
  /// No badge at all.
  none,

  /// A plain dot. No number.
  dot,

  /// A number, capped for display.
  count,
}

/// The badge style for the active distro, with the user's override on top.
///
/// ─── WHY THE DEFAULT COMES FROM THE SHELL ───────────────────────────────────
///
/// A count and a dot are not two skins of one idea, they are what two different
/// desktops actually do, and this launcher's whole argument is that it imitates
/// them rather than averaging them.
///
/// GNOME shows a dot. Its own dash-to-dock draws an unread indicator without a
/// number, and Adwaita has no numeric badge anywhere; a count on an Ubuntu
/// desktop is a thing from a different operating system. Plasma counts, because
/// KDE's task manager badge is a number and always has been. A tiling WM has no
/// icons to badge and a terminal has no icons at all, so both are none rather
/// than an invented answer.
///
/// Derived from [ShellKind] rather than from a new `theme.json` field, and that
/// is a deliberate first cut. The shell IS the per-distro fact here: Ubuntu and
/// Fedora share a desktop and should share a badge, which shell-derivation gives
/// for free and a per-theme field would let a pack author get wrong. If a distro
/// ever genuinely disagrees with its own shell, that is the moment to add the
/// field, and this getter is the one place it would land.
BadgeStyle badgeStyleFor(EffectiveTheme theme) {
  final override = theme.prefs.badgeStyle;

  return switch (override) {
    'off' => BadgeStyle.none,
    'dot' => BadgeStyle.dot,
    'count' => BadgeStyle.count,
    // 'auto', null, or a value written by a newer build. Falling through to the
    // distro's own answer rather than to a fixed one means an unknown string
    // degrades to sensible rather than to wrong.
    _ => switch (theme.shell) {
        ShellKind.gnome => BadgeStyle.dot,
        ShellKind.aqua => BadgeStyle.count,
        ShellKind.plasma => BadgeStyle.count,
        ShellKind.tiling => BadgeStyle.none,
        ShellKind.tui => BadgeStyle.none,
      },
  };
}

/// The count for one app, or 0.
int badgeFor(Map<String, int> counts, String packageName, int userSerial) =>
    counts['$packageName#$userSerial'] ?? 0;
