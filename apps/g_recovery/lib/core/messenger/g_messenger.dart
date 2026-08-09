import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_logo_mark.dart';
import '../logging.dart';
import 'g_message.dart';

/// The one and only transient message surface in this app.
///
/// SnackBar is banned everywhere (tool/no_snackbars.sh enforces it). Reasons it
/// had to go: it cannot carry the brand mark, its Material 3 geometry fights the
/// custom nav bar, and its queueing behaviour drops messages silently when two
/// arrive close together. This shows one at a time, replaces rather than drops,
/// and always clears the bottom nav.
class GMessenger {
  const GMessenger._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(BuildContext context, GMessage message) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      GLog.w('no overlay in scope, message dropped', scope: 'messenger');
      return;
    }

    dismiss();

    final double bottomInset = GMessengerInsets.of(context) +
        MediaQuery.viewPaddingOf(context).bottom +
        GSpace.md;

    final GlobalKey<_GMessageCardState> cardKey =
        GlobalKey<_GMessageCardState>();

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext ctx) => Positioned(
        left: GSpace.gutter,
        right: GSpace.gutter,
        bottom: bottomInset,
        child: _GMessageCard(key: cardKey, message: message),
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(message.duration, () {
      cardKey.currentState?.hide().whenComplete(dismiss);
    });
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

/// Supplies the bottom offset a message must clear. GShell installs this so a
/// message never sits under the nav bar. Absent means a full screen route, so
/// the message can sit at the very bottom.
class GMessengerInsets extends InheritedWidget {
  const GMessengerInsets({
    required this.bottom,
    required super.child,
    super.key,
  });

  final double bottom;

  /// getInheritedWidgetOfExactType, not dependOn: this is read from a tap
  /// callback, and registering a dependency from outside build would rebuild
  /// whatever element happened to be passed in.
  static double of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GMessengerInsets>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(GMessengerInsets oldWidget) =>
      oldWidget.bottom != bottom;
}

class _GMessageCard extends StatefulWidget {
  const _GMessageCard({required this.message, super.key});

  final GMessage message;

  @override
  State<_GMessageCard> createState() => _GMessageCardState();
}

class _GMessageCardState extends State<_GMessageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GMotion.normal,
    reverseDuration: GMotion.fast,
  );

  // Built once, not per build. Since Flutter 3.24 a CurvedAnimation owns
  // listeners that must be disposed, so creating one inside build() leaks on
  // every repaint.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: GMotion.enter,
    reverseCurve: GMotion.exit,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> hide() async {
    if (!mounted) return;
    await _controller.reverse();
  }

  Color _toneColour(GTokens t) {
    switch (widget.message.tone) {
      case GMessageTone.neutral:
        return t.accent;
      case GMessageTone.success:
        return t.success;
      case GMessageTone.warning:
        return t.warning;
      case GMessageTone.danger:
        return t.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Color tone = _toneColour(t);

    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(_curve),
        child: Dismissible(
          key: const ValueKey<String>('g-message'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => GMessenger.dismiss(),
          // Shell overlays have no Scaffold, so InkWell would throw
          // "No Material widget found". Material is not optional here.
          child: Material(
            color: t.panelAlt,
            elevation: 0,
            borderRadius: GRadius.all(GRadius.card),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GSpace.md,
                vertical: GSpace.md,
              ),
              decoration: BoxDecoration(
                borderRadius: GRadius.all(GRadius.card),
                border: Border.all(color: t.lineStrong),
              ),
              child: Row(
                children: <Widget>[
                  GLogoMark(size: 28, background: tone),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      widget.message.text,
                      style: GType.bodySmall.copyWith(color: t.text),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.message.actionLabel != null) ...<Widget>[
                    const SizedBox(width: GSpace.sm),
                    GestureDetector(
                      onTap: () {
                        widget.message.onAction?.call();
                        GMessenger.dismiss();
                      },
                      child: Text(
                        widget.message.actionLabel!,
                        style: GType.label.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
