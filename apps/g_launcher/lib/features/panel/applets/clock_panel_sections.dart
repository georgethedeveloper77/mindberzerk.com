/// What the clock opens, above the month: the playing media, G VPN, and
/// notifications counted by app.
///
/// ─── COUNTS, NEVER CONTENT ──────────────────────────────────────────────────
///
/// The notification listener behind badges promises it counts by package and
/// reads nothing else, and the badges screen says so to the person granting
/// it. This panel keeps that promise: an icon, a name, a number. Reading or
/// replying is Android's own shade, one tap away at the bottom, because a
/// launcher can neither dismiss nor reply to a notification anyway.
///
/// ─── ONE WIDGET, TWO HOSTS ──────────────────────────────────────────────────
///
/// The panel shells open it from the clock's calendar popover (ChromeScope),
/// and GNOME and Aqua from Quick Settings (raw palette). [ClockPanelStyle]
/// carries the four colours so neither host has to learn the other's system.
/// Every section hides itself when it has nothing true to say: no player, no
/// G VPN, no notifications.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_family/g_family.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../data/usage/usage_repository.dart';
import '../../../design/branded_message.dart';
import '../../../engine/effective_theme.dart';
import '../../../platform/launcher_api.g.dart';
import '../../../system/gvpn_status.dart';
import '../../../system/notification_badges.dart';
import '../../drawer/app_icon.dart';

class ClockPanelStyle {
  const ClockPanelStyle({
    required this.text,
    required this.muted,
    required this.accent,
    required this.surface,
    this.fontFamily,
  });

  final Color text;
  final Color muted;
  final Color accent;

  /// The fill each section card sits on.
  final Color surface;
  final String? fontFamily;
}

/// The session worth showing: the one playing, else the most recent.
/// Read when the panel opens and after each button, never polled.
final clockPanelMediaProvider =
    FutureProvider.autoDispose<NowPlaying?>((ref) async {
  try {
    final all = await ref.read(launcherHostApiProvider).activeSessions();
    if (all.isEmpty) return null;
    for (final s in all) {
      if (s.playing) return s;
    }
    return all.first;
  } catch (_) {
    return null;
  }
});

class ClockPanelSections extends ConsumerWidget {
  const ClockPanelSections({
    super.key,
    required this.style,
    required this.onLeave,
  });

  final ClockPanelStyle style;

  /// Close the host (popover or Quick Settings) before leaving the launcher,
  /// so it is not still open when the person comes back.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Media(style: style),
        _Vpn(style: style, onLeave: onLeave),
        _Counts(style: style, onLeave: onLeave),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.style, required this.child});

  final ClockPanelStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

TextStyle _body(ClockPanelStyle s) =>
    TextStyle(fontFamily: s.fontFamily, fontSize: 14, color: s.text);

TextStyle _sub(ClockPanelStyle s) =>
    TextStyle(fontFamily: s.fontFamily, fontSize: 12, color: s.muted);

class _Media extends ConsumerWidget {
  const _Media({required this.style});

  final ClockPanelStyle style;

  Future<void> _send(WidgetRef ref, NowPlaying s, String command) async {
    await ref
        .read(launcherHostApiProvider)
        .sendMediaCommand(s.packageName, command);
    // Pressing a button is the one moment the state certainly changed.
    ref.invalidate(clockPanelMediaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(clockPanelMediaProvider).asData?.value;
    if (s == null) return const SizedBox.shrink();

    Widget button(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          icon: Icon(icon, color: onTap == null ? style.muted : style.text),
          tooltip: tip,
          onPressed: onTap,
        );

    return _Card(
      style: style,
      child: Row(
        children: [
          Icon(Icons.music_note, color: style.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(style)),
                if (s.artist.isNotEmpty)
                  Text(s.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sub(style)),
              ],
            ),
          ),
          button(
            Icons.skip_previous,
            context.t('panel.mediaPrevious'),
            s.canSkipPrevious ? () => _send(ref, s, 'previous') : null,
          ),
          button(
            s.playing ? Icons.pause : Icons.play_arrow,
            s.playing
                ? context.t('panel.mediaPause')
                : context.t('panel.mediaPlay'),
            () => _send(ref, s, s.playing ? 'pause' : 'play'),
          ),
          button(
            Icons.skip_next,
            context.t('panel.mediaNext'),
            s.canSkipNext ? () => _send(ref, s, 'next') : null,
          ),
        ],
      ),
    );
  }
}

class _Vpn extends ConsumerWidget {
  const _Vpn({required this.style, required this.onLeave});

  final ClockPanelStyle style;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(gvpnStatusProvider).asData?.value;
    // Nothing for a phone without G VPN, or before it answers: this panel is
    // not where G VPN advertises itself.
    if (status == null ||
        status.state == GVpnState.notInstalled ||
        status.state == GVpnState.unavailable) {
      return const SizedBox.shrink();
    }

    final busy = status.state == GVpnState.connecting ||
        status.state == GVpnState.reconnecting;
    final title = status.protected && status.label != null
        ? 'G VPN · ${status.label}'
        : 'G VPN';
    final sub = switch (status.state) {
      GVpnState.on => context.t('panel.vpnOn'),
      GVpnState.connecting ||
      GVpnState.reconnecting =>
        context.t('panel.vpnConnecting'),
      GVpnState.paused => context.t('panel.vpnPaused'),
      _ => context.t('panel.vpnOff'),
    };

    return _Card(
      style: style,
      child: InkWell(
        onTap: () {
          onLeave();
          GVpn.open(referrer: 'g_launcher_panel');
        },
        child: Row(
          children: [
            Icon(
              Icons.vpn_key,
              color: status.protected ? style.accent : style.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: _body(style)),
                  Text(sub, style: _sub(style)),
                ],
              ),
            ),
            Switch(
              value: status.protected,
              activeThumbColor: style.accent,
              onChanged:
                  busy ? null : (on) => on ? GVpn.connect() : GVpn.disconnect(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counts extends ConsumerWidget {
  const _Counts({required this.style, required this.onLeave});

  final ClockPanelStyle style;
  final VoidCallback onLeave;

  static const _max = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(notificationAccessProvider).asData?.value;
    if (access == null) return const SizedBox.shrink();

    if (!access) {
      return _Card(
        style: style,
        child: InkWell(
          onTap: () {
            onLeave();
            openNotificationAccessSettings();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.notifications_none, color: style.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.t('panel.countsOff'), style: _sub(style)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final counts = ref.watch(badgeCountsProvider);
    final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
    final themeAsync = ref.watch(effectiveThemeProvider);
    final hidden = themeAsync.hasValue
        ? themeAsync.requireValue.prefs.hiddenApps
        : const <String>{};

    // One row per app, hidden apps never: a count beside a hidden app's name
    // would reveal exactly what hiding it was meant to keep off the screen.
    final rows = <(AppEntry, int)>[
      for (final a in apps)
        if (!hidden.contains(a.componentKey))
          if (badgeFor(counts, a.packageName, a.userSerial) case final n
              when n > 0)
            (a, n),
    ];
    // An app with several launcher activities appears once.
    final seen = <String>{};
    rows.retainWhere((r) => seen.add('${r.$1.packageName}#${r.$1.userSerial}'));
    rows.sort((x, y) => y.$2.compareTo(x.$2));

    Future<void> openShade() async {
      final ok = await ref
          .read(launcherHostApiProvider)
          .performGlobalAction('notifications');
      if (ok) {
        onLeave();
      } else if (context.mounted) {
        context.showMessage(context.t('panel.swipeForShade'));
      }
    }

    return _Card(
      style: style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              context.t('panel.notifications'),
              style: _body(style).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child:
                  Text(context.t('panel.noNotifications'), style: _sub(style)),
            ),
          for (final (app, n) in rows.take(_max))
            InkWell(
              onTap: () {
                onLeave();
                ref.read(appListProvider.notifier).launch(app);
                ref.read(usageProvider.notifier).record(app.componentKey);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    AppIcon(entry: app, size: 24, showBadge: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(style)),
                    ),
                    Text('$n', style: _sub(style)),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: openShade,
              child: Text(
                context.t('panel.openShade'),
                style: _sub(style).copyWith(color: style.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
