import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g_family/g_family.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../desklet_frame.dart';

/// G VPN on the desktop: whether this phone is protected, and one tap to
/// change that. Reads and controls G VPN through g_family, which only
/// Mindberzerk-signed apps may use.
///
/// Like the clock, it has no look of its own. The terminal prints it as
/// `gvpn status` rows through [DeskletFrame]; the other surfaces get a status
/// line drawn in the theme's own font and palette. NO COLOUR CONSTANTS: the
/// distro's accent marks "protected", and the shield's mark (check, pause
/// bars, arrows, exclamation) carries the state, so it reads in any palette
/// and without colour at all.
///
/// Tap does the obvious thing for the state; long press opens G VPN.
class VpnDesklet extends StatefulWidget {
  const VpnDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  State<VpnDesklet> createState() => _VpnDeskletState();
}

class _VpnDeskletState extends State<VpnDesklet> {
  // Drawn from the first frame, never blank: "G VPN, tap to open" until G VPN
  // answers, and it stays that if the bridge cannot be reached (the picker's
  // preview included).
  GVpnStatus _status = const GVpnStatus(GVpnState.unavailable);
  StreamSubscription<GVpnStatus>? _sub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    GVpn.status().then((s) {
      if (mounted) setState(() => _status = s);
    }).catchError((Object _) {
      // No g_family on this build, or G VPN too old: keep "open G VPN".
    });
    _sub = GVpn.watch().listen(
      (s) {
        if (mounted) setState(() => _status = s);
      },
      onError: (Object _) {},
    );
    // A pause counts down; nothing else here changes without an event.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _status.state == GVpnState.paused) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _primary() {
    switch (_status.state) {
      case GVpnState.on || GVpnState.reconnecting:
        GVpn.disconnect();
      case GVpnState.off || GVpnState.paused:
        // Resuming a pause is a connect to the same server.
        GVpn.connect();
      case GVpnState.connecting ||
            GVpnState.notInstalled ||
            GVpnState.unavailable:
        // Opens G VPN, or its Play page when it is not installed.
        GVpn.open(referrer: 'g_launcher');
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _VpnView.of(context, _status);

    return Semantics(
      button: true,
      label: '${view.title}. ${view.detail}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _primary,
        onLongPress: () => GVpn.open(referrer: 'g_launcher'),
        child: DeskletFrame(
          theme: widget.theme,
          skin: widget.skin,
          body: widget.skin.surface == DeskletSurface.terminal
              ? _terminalBody(view)
              : DeskletBody(
                  custom: _StatusLine(
                      theme: widget.theme,
                      skin: widget.skin,
                      view: view,
                      onAction: _primary)),
        ),
      ),
    );
  }

  /// On the shell the desklet IS a command's output, so it uses the frame's
  /// own rows. The words are command output and stay English, like `df -h`.
  DeskletBody _terminalBody(_VpnView v) => DeskletBody(
        command: 'gvpn status',
        rows: [
          DeskletRow('state',
              value: v.shellState, accent: v.mark == _Mark.check),
          if (v.server != null) DeskletRow('server', value: v.server),
          if (v.fraction != null)
            DeskletRow('resumes', value: v.shellDetail, fraction: v.fraction),
        ],
        custom: _ShellAction(
            theme: widget.theme, label: v.shellAction, onTap: _primary),
      );
}

enum _Mark { check, pause, sync, warn, none }

/// Everything one state shows, worked out once.
class _VpnView {
  const _VpnView({
    required this.title,
    required this.detail,
    required this.mark,
    required this.action,
    required this.shellState,
    required this.shellAction,
    this.server,
    this.fraction,
    this.shellDetail,
  });

  final String title;
  final String detail;
  final _Mark mark;
  final String? action;
  final String shellState;
  final String shellAction;
  final String? server;

  /// Share of a pause still to run, for the frame's progress row.
  final double? fraction;
  final String? shellDetail;

  static _VpnView of(BuildContext context, GVpnStatus s) {
    final server = s.label;
    String withServer(String key) =>
        server == null ? context.t(key) : '$server · ${context.t(key)}';
    switch (s.state) {
      case GVpnState.on:
        return _VpnView(
          title: context.t('gvpn.protected'),
          detail: server ?? context.t('gvpn.protectedDetail'),
          mark: _Mark.check,
          action: context.t('gvpn.disconnect'),
          shellState: 'protected',
          shellAction: 'disconnect',
          server: server,
        );
      case GVpnState.reconnecting:
        return _VpnView(
          title: context.t('gvpn.reconnecting'),
          detail: withServer('gvpn.networkChanged'),
          mark: _Mark.sync,
          action: null,
          shellState: 'reconnecting',
          shellAction: 'open gvpn',
          server: server,
        );
      case GVpnState.connecting:
        return _VpnView(
          title: context.t('gvpn.connecting'),
          detail: server ?? '',
          mark: _Mark.sync,
          action: null,
          shellState: 'connecting',
          shellAction: 'open gvpn',
          server: server,
        );
      case GVpnState.paused:
        final until = s.pausedUntil;
        final left = until == null
            ? 0
            : until.difference(DateTime.now()).inMinutes.clamp(0, 9999) + 1;
        return _VpnView(
          title: context.t('gvpn.paused'),
          detail: withServer('gvpn.resumesIn').replaceAll('{0}', '$left'),
          mark: _Mark.pause,
          action: context.t('gvpn.resume'),
          shellState: 'paused',
          shellAction: 'resume',
          server: server,
          // Pauses are 15 or 60 minutes; the bar shows what is left of the
          // longer one when unsure, and never runs backwards.
          fraction: until == null
              ? null
              : (left / (left > 15 ? 60 : 15)).clamp(0.0, 1.0),
          shellDetail: '$left min',
        );
      case GVpnState.off:
        return _VpnView(
          title: context.t('gvpn.off'),
          detail: context.t('gvpn.offDetail'),
          mark: _Mark.warn,
          action: context.t('gvpn.connect'),
          shellState: 'off',
          shellAction: 'connect',
        );
      case GVpnState.notInstalled:
        return _VpnView(
          title: context.t('gvpn.getTitle'),
          detail: context.t('gvpn.getDetail'),
          mark: _Mark.none,
          action: context.t('gvpn.get'),
          shellState: 'not installed',
          shellAction: 'get gvpn',
        );
      case GVpnState.unavailable:
        return _VpnView(
          title: 'G VPN',
          detail: context.t('gvpn.unavailableDetail'),
          mark: _Mark.none,
          action: context.t('gvpn.open'),
          shellState: 'unavailable',
          shellAction: 'open gvpn',
        );
    }
  }
}

/// Shield, state and detail, in the theme's font and palette; plus the one
/// action on surfaces that have room for a button (card and panel). On bare,
/// the whole desklet is the button.
class _StatusLine extends StatelessWidget {
  const _StatusLine(
      {required this.theme,
      required this.skin,
      required this.view,
      required this.onAction});

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final _VpnView view;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final mono = skin.font == DeskletFont.mono;
    final family = mono ? theme.typography.mono : theme.typography.display;
    final bare = skin.surface == DeskletSurface.bare;
    final shadows = bare
        ? [
            Shadow(
                color: p.bgBottom.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]
        : null;
    final markColour = view.mark == _Mark.check ? p.accent : p.onDark;
    final titleSize = skin.num_('vpnTitleSize', bare ? 20 : 15);
    final detailSize = skin.num_('rowSize', bare ? 14 : 12.5);

    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size.square(bare ? 40 : 30),
          painter: _ShieldPainter(
              colour: markColour,
              mark: view.mark,
              filled: view.mark == _Mark.check,
              shadow: bare),
        ),
        SizedBox(width: bare ? 14 : 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mono ? view.title.toLowerCase() : view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: view.mark == _Mark.check ? p.accent : p.onDark,
                  shadows: shadows,
                ),
              ),
              if (view.detail.isNotEmpty)
                Text(
                  view.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: detailSize,
                    height: 1.35,
                    color: p.onDark.withValues(alpha: 0.85),
                    shadows: shadows,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final action = view.action;
    if (bare || action == null) return line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        if (view.fraction != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: view.fraction,
              minHeight: 3,
              backgroundColor: p.onDark.withValues(alpha: 0.14),
              color: p.accent,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _ActionChip(theme: theme, skin: skin, label: action, onTap: onAction),
      ],
    );
  }
}

/// The one action, as the surface draws a control: a rounded pill on card,
/// a flat mono label on panel.
class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.theme,
      required this.skin,
      required this.label,
      required this.onTap});

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final panel = skin.surface == DeskletSurface.panel;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: panel ? null : p.accent,
            border: panel ? Border.all(color: p.accent) : null,
            borderRadius: BorderRadius.circular(
                panel ? 0 : skin.num_('radius', 10) * 0.7),
          ),
          child: Text(
            panel ? label.toLowerCase() : label,
            style: TextStyle(
              fontFamily:
                  panel ? theme.typography.mono : theme.typography.display,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: panel ? p.accent : p.bgBottom,
            ),
          ),
        ),
      ),
    );
  }
}

/// `[ connect ]` under the shell output.
class _ShellAction extends StatelessWidget {
  const _ShellAction(
      {required this.theme, required this.label, required this.onTap});

  final EffectiveTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(
                '[ $label ]',
                style: TextStyle(
                    fontFamily: theme.typography.mono,
                    fontSize: 13,
                    color: theme.palette.accent),
              ),
            ),
          ),
        ),
      );
}

/// A shield with its state's mark. Drawn rather than an icon font, so every
/// distro gets the same silhouette in its own colour.
class _ShieldPainter extends CustomPainter {
  _ShieldPainter(
      {required this.colour,
      required this.mark,
      required this.filled,
      required this.shadow});

  final Color colour;
  final _Mark mark;
  final bool filled;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final shield = Path()
      ..moveTo(12 * s, 2.5 * s)
      ..lineTo(19.5 * s, 5.5 * s)
      ..lineTo(19.5 * s, 11.5 * s)
      ..cubicTo(19.5 * s, 16.2 * s, 16.3 * s, 20.1 * s, 12 * s, 21.5 * s)
      ..cubicTo(7.7 * s, 20.1 * s, 4.5 * s, 16.2 * s, 4.5 * s, 11.5 * s)
      ..lineTo(4.5 * s, 5.5 * s)
      ..close();
    if (shadow) {
      canvas.drawShadow(shield, colour.withValues(alpha: 0.5), 3, false);
    }

    // Filled (protected): the mark is cut out of the shield, so it shows the
    // wallpaper or card through it. Outlined (every other state): the mark is
    // drawn in the same colour as the outline.
    final ink = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (filled) {
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawPath(shield, Paint()..color = colour);
      ink.blendMode = BlendMode.clear;
    } else {
      canvas.drawPath(
        shield,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    }
    switch (mark) {
      case _Mark.check:
        canvas.drawPath(
          Path()
            ..moveTo(8.5 * s, 12.2 * s)
            ..lineTo(10.9 * s, 14.6 * s)
            ..lineTo(15.5 * s, 9.8 * s),
          ink,
        );
      case _Mark.pause:
        canvas.drawLine(Offset(10 * s, 9 * s), Offset(10 * s, 15 * s), ink);
        canvas.drawLine(Offset(14 * s, 9 * s), Offset(14 * s, 15 * s), ink);
      case _Mark.warn:
        canvas.drawLine(Offset(12 * s, 8 * s), Offset(12 * s, 13 * s), ink);
        canvas.drawCircle(
            Offset(12 * s, 16.2 * s), 1.1 * s, Paint()..color = colour);
      case _Mark.sync:
        final r =
            Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 3.6 * s);
        canvas.drawArc(r, 3.4, 2.4, false, ink);
        canvas.drawArc(r, 0.26, 2.4, false, ink);
      case _Mark.none:
        break;
    }
    if (filled) canvas.restore();
  }

  @override
  bool shouldRepaint(_ShieldPainter old) =>
      old.colour != colour ||
      old.mark != mark ||
      old.filled != filled ||
      old.shadow != shadow;
}
