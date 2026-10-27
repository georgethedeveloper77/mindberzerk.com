import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g_family/g_family.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/i18n/g_strings.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';

/// G VPN on G Recovery's home: whether this phone is protected, with the one
/// action that fits. Reads and controls G VPN through g_family, which only
/// Mindberzerk-signed apps may use.
///
/// Where G VPN is not installed it offers it once, quietly; "Not now" hides
/// the offer for 30 days. The section [header] is passed in by the home page
/// and shown only when the card is.
class VpnCard extends StatefulWidget {
  const VpnCard({super.key, required this.header});

  final Widget header;

  @override
  State<VpnCard> createState() => _VpnCardState();
}

class _VpnCardState extends State<VpnCard> {
  static const _dismissKey = 'gvpn.card.dismissedUntil';
  static const _quiet = Duration(days: 30);

  GVpnStatus? _status;
  bool _dismissed = false;
  StreamSubscription<GVpnStatus>? _sub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final until = prefs.getInt(_dismissKey) ?? 0;
      if (mounted) setState(() => _dismissed = DateTime.now().millisecondsSinceEpoch < until);
    });
    GVpn.status().then((s) {
      if (mounted) setState(() => _status = s);
    }).catchError((Object _) {});
    _sub = GVpn.watch().listen(
      (s) {
        if (mounted) setState(() => _status = s);
      },
      onError: (Object _) {},
    );
    // A pause counts down; nothing else changes without an event.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _status?.state == GVpnState.paused) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _notNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissKey, DateTime.now().add(_quiet).millisecondsSinceEpoch);
    if (mounted) setState(() => _dismissed = true);
  }

  void _open() => GVpn.open(referrer: 'g_recovery');

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const SizedBox.shrink();
    if (s.state == GVpnState.notInstalled && _dismissed) return const SizedBox.shrink();

    final t = context.g;
    final server = s.label;
    final minutesLeft = s.pausedUntil == null
        ? 0
        : s.pausedUntil!.difference(DateTime.now()).inMinutes.clamp(0, 9999) + 1;

    final (Color tint, IconData icon, String title, String detail, Widget actions) = switch (s.state) {
      GVpnState.on || GVpnState.reconnecting => (
          t.success,
          Icons.gpp_good_rounded,
          s.state == GVpnState.on ? context.s('Protected') : context.s('Reconnecting'),
          server ?? context.s('Your connection is encrypted'),
          _row(GButton(label: context.s('Disconnect'), kind: GButtonKind.danger, onPressed: GVpn.disconnect)),
        ),
      GVpnState.connecting => (
          t.warning,
          Icons.sync_rounded,
          context.s('Connecting'),
          server ?? '',
          _row(GButton(label: context.s('Open G VPN'), kind: GButtonKind.ghost, onPressed: _open), withOpen: false),
        ),
      GVpnState.paused => (
          t.warning,
          Icons.pause_circle_outline_rounded,
          context.s('Paused'),
          [?server, context.s1('resumes in {} min', minutesLeft)].join(' · '),
          _row(GButton(label: context.s('Resume now'), onPressed: GVpn.connect)),
        ),
      GVpnState.off => (
          t.warning,
          Icons.gpp_maybe_rounded,
          context.s('Not protected'),
          context.s('Uploading recovered files on public Wi-Fi? Turn on G VPN first.'),
          _row(GButton(label: context.s('Connect'), onPressed: GVpn.connect)),
        ),
      GVpnState.unavailable => (
          t.accent,
          Icons.shield_outlined,
          'G VPN',
          context.s('Open G VPN to see whether this phone is protected.'),
          _row(GButton(label: context.s('Open G VPN'), onPressed: _open), withOpen: false),
        ),
      GVpnState.notInstalled => (
          t.accent,
          Icons.shield_outlined,
          context.s('Protect public Wi-Fi'),
          context.s('G VPN is free, from the makers of G Recovery.'),
          Row(
            children: <Widget>[
              Expanded(child: GButton(label: context.s('Get G VPN'), onPressed: _open)),
              const SizedBox(width: GSpace.sm),
              Expanded(child: GButton(label: context.s('Not now'), kind: GButtonKind.ghost, onPressed: _notNow)),
            ],
          ),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        widget.header,
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          tint: tint,
          onLongPress: s.state == GVpnState.notInstalled ? null : _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.16),
                      borderRadius: GRadius.all(GRadius.glyph),
                    ),
                    child: Icon(icon, size: 22, color: tint),
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: GType.heading.copyWith(color: t.text)),
                        if (detail.isNotEmpty)
                          Text(detail, style: GType.bodySmall.copyWith(color: t.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GSpace.md),
              actions,
            ],
          ),
        ),
      ],
    );
  }

  /// The state's action, with a small "open G VPN" beside it.
  Widget _row(Widget primary, {bool withOpen = true}) => Row(
        children: <Widget>[
          Expanded(child: primary),
          if (withOpen) ...<Widget>[
            const SizedBox(width: GSpace.sm),
            GButton(
              label: context.s('Open'),
              icon: Icons.open_in_new_rounded,
              kind: GButtonKind.ghost,
              expand: false,
              onPressed: _open,
            ),
          ],
        ],
      );
}
