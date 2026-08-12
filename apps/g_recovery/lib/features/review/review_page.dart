import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../bridge/recovery_bridge.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_stat.dart';
import '../../ui/g_thumbnail.dart';
import '../recovery/state/recovery_providers.dart';
import 'state/review_providers.dart';
import 'widgets/review_card.dart';

/// Swipe to triage. Left bins, right keeps, up skips.
///
/// Nothing happens on the device until Apply. Swiping is fast and mistakes are
/// certain, so every decision stays reversible until one explicit confirmation.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ReviewPage(),
  );

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  bool _committing = false;

  late final AnimationController _fling = AnimationController(
    vsync: this,
    duration: GMotion.fast,
  );

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  /// A quarter of the screen width, or a fast flick.
  ///
  /// Distance alone makes a decisive flick feel unresponsive; velocity alone
  /// fires on an accidental brush during a scroll. Either one qualifies.
  static const double _distanceThreshold = 0.25;
  static const double _velocityThreshold = 700;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _drag += details.delta);
  }

  Future<void> _onPanEnd(DragEndDetails details, double width) async {
    final double dx = _drag.dx;
    final double velocity = details.velocity.pixelsPerSecond.dx;
    final bool passed =
        dx.abs() > width * _distanceThreshold ||
        velocity.abs() > _velocityThreshold;

    if (!passed) {
      setState(() => _drag = Offset.zero);
      return;
    }

    final ReviewVerdict verdict = dx > 0
        ? ReviewVerdict.keep
        : ReviewVerdict.bin;
    await _flingOut(dx.isNegative ? -1 : 1, width);
    ref.read(reviewProvider.notifier).decide(verdict);
    if (mounted) setState(() => _drag = Offset.zero);
  }

  Future<void> _flingOut(int direction, double width) async {
    final Offset from = _drag;
    final Offset to = Offset(direction * width * 1.6, from.dy + 40);
    _fling.reset();
    void listener() {
      setState(() => _drag = Offset.lerp(from, to, _fling.value) ?? to);
    }

    _fling.addListener(listener);
    await _fling.forward();
    _fling.removeListener(listener);
  }

  Future<void> _button(ReviewVerdict verdict, double width) async {
    await _flingOut(verdict == ReviewVerdict.bin ? -1 : 1, width);
    ref.read(reviewProvider.notifier).decide(verdict);
    if (mounted) setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final ReviewSession? session = ref.watch(reviewProvider);
    final RecoveryBridge bridge = ref.watch(recoveryBridgeProvider);
    final double width = MediaQuery.sizeOf(context).width;

    if (session == null) {
      return Scaffold(backgroundColor: t.ink, body: const SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
          child: Column(
            children: <Widget>[
              _Header(session: session),
              Expanded(
                child: session.isDone
                    ? _Finished(
                        session: session,
                        busy: _committing,
                        onApply: () => _commit(session),
                      )
                    : _Deck(
                        session: session,
                        bridge: bridge,
                        drag: _drag,
                        width: width,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: (DragEndDetails d) => _onPanEnd(d, width),
                        onOpen: () => _openViewer(session.current!, bridge),
                      ),
              ),
              if (!session.isDone) ...<Widget>[
                const SizedBox(height: GSpace.lg),
                _Actions(
                  onBin: () => _button(ReviewVerdict.bin, width),
                  onKeep: () => _button(ReviewVerdict.keep, width),
                  onUndo: session.index == 0
                      ? null
                      : ref.read(reviewProvider.notifier).undo,
                ),
              ],
              const SizedBox(height: GSpace.lg),
              _Tally(session: session),
              const SizedBox(height: GSpace.md),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewer(RecoverableItem item, RecoveryBridge bridge) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: context.g.scrim,
        pageBuilder:
            (BuildContext context, Animation<double> a, Animation<double> b) =>
                _Viewer(item: item, bridge: bridge),
      ),
    );
  }

  Future<void> _commit(ReviewSession session) async {
    setState(() => _committing = true);
    final ReviewOutcome outcome = await ref
        .read(reviewProvider.notifier)
        .commit();
    if (!mounted) return;
    setState(() => _committing = false);
    Navigator.of(context).pop();
    GMessenger.show(
      context,
      outcome.firstProblem == null
          ? GMessage.success(
              '${outcome.restored} restored, ${outcome.deleted} deleted',
            )
          : GMessage.warning(
              '${outcome.restored} restored. ${outcome.firstProblem!.detail}',
            ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.session});

  final ReviewSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSpace.md),
      child: Row(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(reviewProvider.notifier).end();
              Navigator.of(context).pop();
            },
            child: Icon(Icons.close_rounded, color: t.muted, size: 20),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${GFormat.count(session.index)} of '
                  '${GFormat.count(session.queue.length)}',
                  style: GType.monoNumber.copyWith(color: t.text),
                ),
                const SizedBox(height: 5),
                GBar(
                  fraction: session.queue.isEmpty
                      ? null
                      : session.index / session.queue.length,
                  colour: t.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.session,
    required this.bridge,
    required this.drag,
    required this.width,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onOpen,
  });

  final ReviewSession session;
  final RecoveryBridge bridge;
  final Offset drag;
  final double width;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final RecoverableItem? current = session.current;
    if (current == null) return const SizedBox.shrink();

    final double progress = (drag.dx / (width * 0.25)).clamp(-1.0, 1.0);
    final RecoverableItem? next = session.next;

    return Stack(
      children: <Widget>[
        // The card behind, scaled up as the top card leaves. Preloading its
        // thumbnail here is why the next photo is already decoded by the time
        // it becomes the top card.
        if (next != null)
          Transform.scale(
            scale: 0.94 + (0.06 * progress.abs()),
            child: Opacity(
              opacity: 0.45 + (0.55 * progress.abs()),
              child: ReviewCard(item: next, bridge: bridge),
            ),
          ),
        GestureDetector(
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Stack(
            children: <Widget>[
              ReviewCard(
                item: current,
                bridge: bridge,
                offset: drag,
                // Rotate around the drag distance, capped. Uncapped, a long
                // drag spins the card past vertical and the photo becomes
                // unreadable at exactly the moment the user is deciding.
                tilt: (drag.dx / width) * 0.28,
                onOpen: onOpen,
              ),
              if (progress < 0)
                ReviewStamp(
                  label: 'BIN',
                  colour: t.danger,
                  opacity: -progress,
                  alignLeft: true,
                ),
              if (progress > 0)
                ReviewStamp(
                  label: 'KEEP',
                  colour: t.success,
                  opacity: progress,
                  alignLeft: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onBin,
    required this.onKeep,
    required this.onUndo,
  });

  final VoidCallback onBin;
  final VoidCallback onKeep;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _Circle(
          icon: Icons.close_rounded,
          tone: t.danger,
          size: 58,
          onTap: onBin,
        ),
        const SizedBox(width: GSpace.lg),
        _Circle(
          icon: Icons.undo_rounded,
          tone: onUndo == null ? t.dim : t.muted,
          size: 46,
          onTap: onUndo,
        ),
        const SizedBox(width: GSpace.lg),
        _Circle(
          icon: Icons.check_rounded,
          tone: t.success,
          size: 58,
          onTap: onKeep,
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.icon,
    required this.tone,
    required this.size,
    this.onTap,
  });

  final IconData icon;
  final Color tone;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tone.withValues(alpha: 0.13),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: tone, size: size * 0.36),
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.session});

  final ReviewSession session;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        GStat(
          label: 'In the bin',
          value: GFormat.bytes(session.binnedBytes),
          tone: t.danger,
        ),
        GStat(
          label: 'Kept',
          value: GFormat.count(session.kept.length),
          tone: t.success,
          align: CrossAxisAlignment.center,
        ),
        GStat(
          label: 'Reviewed',
          value: GFormat.count(session.reviewed),
          align: CrossAxisAlignment.end,
        ),
      ],
    );
  }
}

/// The confirmation. The only place anything is applied.
class _Finished extends StatelessWidget {
  const _Finished({
    required this.session,
    required this.busy,
    required this.onApply,
  });

  final ReviewSession session;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int bin = session.binned.length;
    final int keep = session.kept.length;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Session done', style: GType.display.copyWith(color: t.text)),
            const SizedBox(height: GSpace.md),
            Text(
              // Stated plainly, because it is the reason the screen is safe to
              // use quickly. Until this button, the device is untouched.
              'Nothing has been changed on your device yet.',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.lg),
            GCard(
              child: Column(
                children: <Widget>[
                  _Line(
                    label: 'Restore',
                    value: GFormat.count(keep),
                    tone: t.success,
                  ),
                  const GCardDivider(),
                  _Line(
                    label: 'Delete permanently',
                    value: GFormat.count(bin),
                    tone: t.danger,
                  ),
                  const GCardDivider(),
                  _Line(
                    label: 'Space freed',
                    value: GFormat.bytes(session.binnedBytes),
                    tone: t.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSpace.lg),
            GButton(
              label: busy ? 'Applying' : 'Apply',
              onPressed: busy || (bin == 0 && keep == 0) ? null : onApply,
            ),
            const SizedBox(height: GSpace.md),
            Text(
              'Deleted items cannot be brought back after this.',
              textAlign: TextAlign.center,
              style: GType.micro.copyWith(color: t.dim),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: GType.bodySmall.copyWith(color: t.muted)),
        ),
        Text(
          value,
          style: GType.monoNumber.copyWith(color: tone, fontSize: 15),
        ),
      ],
    );
  }
}

/// Full screen pinch and pan, on its own route so no gesture competes with the
/// deck.
class _Viewer extends StatelessWidget {
  const _Viewer({required this.item, required this.bridge});

  final RecoverableItem item;
  final RecoveryBridge bridge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: math.max(2, 6),
          child: GThumbnail(
            itemId: item.itemId,
            bridge: bridge,
            kind: item.kind,
            maxPixels: 2048,
            fit: BoxFit.contain,
            radius: 0,
          ),
        ),
      ),
    );
  }
}
