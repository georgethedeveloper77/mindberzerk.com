import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_skin.dart';

export 'message_skin.dart' show MessageTone;

/// The branded scaffold message. The ONLY transient-message surface in any
/// Mindhunter app. There are no SnackBars — `scripts/no_snackbars.sh` fails the
/// build if one comes back.
///
/// Why an Overlay and not ScaffoldMessenger:
///  1. `gesture_layer.dart` fires from places with no Scaffold above them.
///  2. The shells are transparent; a Material SnackBar drags Material's own
///     surfaces onto a Linux desktop.
///  3. The overlay outlives route pushes, so a message survives navigation.
///
/// ─── The lifecycle bug this version fixes ───────────────────────────────────
///
/// v1 cached its OverlayEntry forever:
///
///     _entry ??= OverlayEntry(...);
///     if (!_entry!.mounted) overlay.insert(_entry!);
///
/// An OverlayEntry belongs to the Overlay it was inserted into — for life.
/// When that tree is disposed (every widget test; in production an engine
/// restart or a root rebuild), the entry is a corpse: not mounted, but still
/// owned by a defunct OverlayState. The next showMessage() then tries to insert
/// the corpse into the NEW overlay and Flutter throws "already present in a
/// different Overlay".
///
/// The fix: track WHICH overlay we're attached to. A different overlay means
/// the old tree is gone — abandon the old entry (with `remove()` if it's still
/// mounted), drop any queued messages (toasts from a dead tree have no business
/// appearing in a new one), and build fresh.
/// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

extension BrandedMessengerX on BuildContext {
  /// Shows a branded message. Safe from anywhere under the MaterialApp,
  /// Scaffold or not. Messages queue; they never stack.
  void showMessage(
    String text, {
    MessageTone tone = MessageTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    assert(
      actionLabel == null || onAction != null,
      'An actionLabel with no onAction is a button that does nothing.',
    );
    _messenger.enqueue(
      this,
      BrandedMessage(
        text: text,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      ),
    );
  }

  /// Dismisses the current message and drops the queue. Call from the
  /// HOME-press handler — a stale toast on a fresh desktop looks like a bug.
  void clearMessages() => _messenger.clear();
}

/// Tears the messenger down completely: timer cancelled, queue dropped, entry
/// removed. Tests call this in tearDown so no timer outlives the test tree;
/// production never needs it (enqueue heals stale state by itself).
@visibleForTesting
void debugResetBrandedMessenger() => _messenger.detach();

@immutable
class BrandedMessage {
  const BrandedMessage({
    required this.text,
    this.tone = MessageTone.neutral,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(milliseconds: 2800),
  });

  final String text;
  final MessageTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
}

// ─────────────────────────────────────────────────────────────────────────────
// Machinery
// ─────────────────────────────────────────────────────────────────────────────

final _Messenger _messenger = _Messenger();

class _Messenger {
  final Queue<BrandedMessage> _queue = Queue<BrandedMessage>();

  /// The overlay widget listens to this. null = nothing showing / animate out.
  final ValueNotifier<BrandedMessage?> current =
      ValueNotifier<BrandedMessage?>(null);

  OverlayEntry? _entry;
  OverlayState? _overlay;
  Timer? _timer;

  void enqueue(BuildContext context, BrandedMessage message) {
    // rootOverlay: true, so the toast sits above any nested Navigator (drawer,
    // palette, sheets).
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    assert(overlay != null, 'showMessage() called outside the MaterialApp.');
    if (overlay == null) return;

    // Attached to a stale tree? Tear it down before touching the new one. An
    // OverlayEntry belongs to its Overlay for life, so a tree change makes the
    // old entry unusable, and any queued toasts belonged to a screen that is
    // already gone.
    if (_overlay != null && !identical(overlay, _overlay)) {
      detach();
    }

    // Ensure a LIVE entry in the current overlay. Never re-insert the cached
    // entry: OverlayEntry.mounted can read false while a disposed overlay still
    // owns it, and re-inserting that corpse is the "already present in the
    // target Overlay" crash. A freshly built entry cannot be already-present,
    // so when there is no live entry, discard the old one and build a new one.
    if (_entry == null || !_entry!.mounted) {
      _discardEntry();
      final entry =
          OverlayEntry(builder: (_) => _MessageOverlay(messenger: this));
      _entry = entry;
      _overlay = overlay;
      overlay.insert(entry);
    }

    _queue.add(message);
    if (current.value == null) _advance();
  }

  void _advance() {
    _timer?.cancel();
    if (_queue.isEmpty) {
      current.value = null;
      return;
    }
    final next = _queue.removeFirst();
    current.value = next;
    _timer = Timer(next.duration, dismiss);
  }

  /// Begins the exit animation. The overlay calls [onExited] when it finishes.
  void dismiss() {
    _timer?.cancel();
    current.value = null;
  }

  void clear() {
    _queue.clear();
    dismiss();
  }

  /// Full teardown: cancel, drop the queue, remove the entry if it is still
  /// mounted somewhere, forget the overlay. Used when the tree changes and by
  /// [debugResetBrandedMessenger].
  void detach() {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    current.value = null;
    _overlay = null;
    _discardEntry();
  }

  /// Best-effort removal of the current entry, tolerant of a half-disposed
  /// overlay. Always leaves [_entry] null, so the next enqueue builds fresh.
  void _discardEntry() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      try {
        entry.remove();
      } catch (_) {
        // The owning overlay is mid-teardown; it will dispose the entry itself.
      }
    }
  }

  void onExited() {
    if (_queue.isNotEmpty) _advance();
  }
}

class _MessageOverlay extends StatefulWidget {
  const _MessageOverlay({required this.messenger});

  final _Messenger messenger;

  @override
  State<_MessageOverlay> createState() => _MessageOverlayState();
}

class _MessageOverlayState extends State<_MessageOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 150),
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  BrandedMessage? _shown;

  @override
  void initState() {
    super.initState();
    widget.messenger.current.addListener(_onChanged);
    _onChanged();
  }

  void _onChanged() {
    if (!mounted) return;
    final next = widget.messenger.current.value;

    if (next != null) {
      setState(() => _shown = next);
      _ctrl.forward();
      return;
    }

    if (_shown == null) return;

    _ctrl.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() => _shown = null);
      // Only now is the slot free — otherwise the next message pops in on top
      // of the outgoing one mid-fade.
      widget.messenger.onExited();
    });
  }

  @override
  void dispose() {
    widget.messenger.current.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _shown;
    if (message == null) return const SizedBox.shrink();

    // Sits above the nav bar / gesture pill, not under it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 24,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(_curve),
          child: Consumer(
            builder: (context, ref, _) {
              final skin = ref.watch(messageSkinProvider);
              return _MessageCard(message: message, skin: skin);
            },
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.skin});

  final BrandedMessage message;
  final MessageSkin skin;

  @override
  Widget build(BuildContext context) {
    final accent = skin.accentFor(message.tone);

    return Semantics(
      liveRegion: true,
      label: message.text,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          // Tap anywhere to dismiss. Swipe down too — a toast you cannot get
          // rid of is worse than no toast.
          onTap: _messenger.dismiss,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 200) _messenger.dismiss();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: skin.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _LogoChip(accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: skin.foreground,
                      fontFamily: skin.uiFamily,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
                if (message.actionLabel != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _messenger.dismiss();
                      message.onAction?.call();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: accent,
                    ),
                    child: Text(
                      message.actionLabel!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: skin.uiFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo. The whole reason this component exists — every transient message
/// in a Mindhunter app carries the mark.
class _LogoChip extends StatelessWidget {
  const _LogoChip({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/brand/mindhunter_mark.png',
        width: 16,
        height: 16,
        filterQuality: FilterQuality.medium,
        // A missing asset must not take the toast down with it — a toast is
        // often what's reporting the error in the first place.
        errorBuilder: (_, __, ___) => Icon(Icons.bolt, size: 15, color: accent),
      ),
    );
  }
}
