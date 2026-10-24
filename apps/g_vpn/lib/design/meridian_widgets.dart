import 'package:flutter/material.dart';

import 'meridian.dart';

/// A Meridian card. A MATERIAL, not a decorated box, so list tiles, switches
/// and ink ripples inside it paint correctly (the old Rules screen tripped
/// Flutter's "ListTile ink may be invisible" assertion for exactly this).
class MerCard extends StatelessWidget {
  const MerCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: color ?? m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        side: BorderSide(color: m.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Card heading with an optional action on the right.
class MerCardTitle extends StatelessWidget {
  const MerCardTitle(this.title, {super.key, this.trailing, this.caption});

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: TextStyle(fontSize: 12, color: m.muted, height: 1.4)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A label and a value on one line; long values wrap, never truncate.
class MerRow extends StatelessWidget {
  const MerRow(this.label, this.value, {super.key, this.color, this.mono = false});

  final String label;
  final String value;
  final Color? color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 118, child: Text(label, style: TextStyle(fontSize: 13, color: m.muted))),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? m.monoStyle(size: 13, color: color ?? m.text)
                  : TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? m.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small text action used in card corners.
class MerAction extends StatelessWidget {
  const MerAction(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: context.mer.brand,
          minimumSize: const Size(48, 40),
          textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      );
}
