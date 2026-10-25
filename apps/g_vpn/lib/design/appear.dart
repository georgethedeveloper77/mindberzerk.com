import 'package:flutter/material.dart';

/// Eases a list item in, rising slightly while it fades in. [index] staggers
/// items so a list arrives top to bottom; the delay is capped so long lists
/// never feel slow. Plays once, when the item first appears.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 45);
  static const _maxDelay = Duration(milliseconds: 360);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = _step * widget.index;
    Future.delayed(delay > _maxDelay ? _maxDelay : delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the system's reduce-motion setting.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(_t),
        child: widget.child,
      ),
    );
  }
}
