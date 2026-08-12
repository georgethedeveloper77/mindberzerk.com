import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The search bar that sits at the top of home.
///
/// Search is a first class element, not a menu item, because the most common
/// thing a user knows about a lost file is its name. Phase 4 wires this to the
/// unified index; here it is a shell with the correct geometry.
///
/// Stateful only because of the typewriter. When [hints] is empty it behaves
/// exactly as the plain field it replaces.
class GSearchField extends StatefulWidget {
  const GSearchField({
    required this.hint,
    super.key,
    this.value,
    this.onTap,
    this.onClear,
    this.leading = '>',
    this.active = false,
    this.hints = const <String>[],
    this.animateHints = false,
  });

  final String hint;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  /// The operator prompt. Storage uses a terminal style caret, home uses a
  /// magnifier glyph supplied by the caller.
  final String leading;

  final bool active;

  /// Example queries typed out one after another while the field is empty. The
  /// static [hint] is the fallback and the reduce motion answer.
  final List<String> hints;

  /// Off switch owned by the caller. The shell is an IndexedStack, so this
  /// widget stays mounted while the user is on another tab and a timer left
  /// running here would tick forever behind Storage.
  final bool animateHints;

  @override
  State<GSearchField> createState() => _GSearchFieldState();
}

class _GSearchFieldState extends State<GSearchField> {
  // Deleting at typing speed feels stuck, so the two rates differ.
  static const Duration _typeStep = Duration(milliseconds: 55);
  static const Duration _eraseStep = Duration(milliseconds: 28);
  static const Duration _holdFull = Duration(milliseconds: 1400);
  static const Duration _holdEmpty = Duration(milliseconds: 320);
  static const Duration _blinkStep = Duration(milliseconds: 530);

  Timer? _typeTimer;
  Timer? _blinkTimer;

  int _line = 0;
  int _chars = 0;
  bool _erasing = false;
  bool _caretOn = true;

  @override
  void didUpdateWidget(GSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  bool get _hasValue => widget.value != null && widget.value!.isNotEmpty;

  /// Typing under the user while they are looking at their own text is the one
  /// way this feature becomes a bug, so anything that means "the field is in
  /// use" stops it.
  bool get _shouldRun {
    if (!widget.animateHints) return false;
    if (widget.hints.isEmpty) return false;
    if (widget.active || _hasValue) return false;
    return !MediaQuery.disableAnimationsOf(context);
  }

  void _sync() {
    if (_shouldRun) {
      if (_typeTimer == null) _start();
      return;
    }
    if (_typeTimer != null || _blinkTimer != null) {
      _stop();
      if (mounted) setState(() => _chars = 0);
    }
  }

  void _start() {
    _blinkTimer = Timer.periodic(_blinkStep, (Timer _) {
      if (mounted) setState(() => _caretOn = !_caretOn);
    });
    _typeTimer = Timer(_holdEmpty, _step);
  }

  void _stop() {
    _typeTimer?.cancel();
    _typeTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void _step() {
    if (!mounted || !_shouldRun) return;
    final String word = widget.hints[_line % widget.hints.length];
    Duration next;

    if (!_erasing) {
      _chars++;
      if (_chars >= word.length) {
        _chars = word.length;
        _erasing = true;
        next = _holdFull;
      } else {
        next = _typeStep;
      }
    } else {
      _chars--;
      if (_chars <= 0) {
        _chars = 0;
        _erasing = false;
        _line = (_line + 1) % widget.hints.length;
        next = _holdEmpty;
      } else {
        next = _eraseStep;
      }
    }

    setState(() {});
    _typeTimer = Timer(next, _step);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.button + 2);
    final bool typing = _typeTimer != null && !_hasValue;
    final String shown = typing
        ? widget.hints[_line % widget.hints.length].substring(0, _chars)
        : widget.hint;

    return Material(
      color: t.panel,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: widget.active ? t.accent : t.line),
          ),
          child: Row(
            children: <Widget>[
              Text(
                widget.leading,
                style: GType.monoNumber.copyWith(
                  color: widget.active ? t.accentText : t.dim,
                ),
              ),
              const SizedBox(width: GSpace.md - 2),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        _hasValue ? widget.value! : shown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.body.copyWith(
                          color: _hasValue ? t.text : t.dim,
                        ),
                      ),
                    ),
                    if (typing)
                      Container(
                        width: 1.5,
                        height: GType.body.fontSize,
                        margin: const EdgeInsets.only(left: 2),
                        color: _caretOn ? t.accentText : t.panel,
                      ),
                  ],
                ),
              ),
              if (_hasValue && widget.onClear != null)
                GestureDetector(
                  onTap: widget.onClear,
                  child: Icon(Icons.close_rounded, size: 17, color: t.dim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
