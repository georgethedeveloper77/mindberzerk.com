import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// A single number with a label beneath it.
///
/// A null value renders nothing at all. The rule across this app: absent data
/// is an absent row, never a placeholder like "--" or "0", because a fabricated
/// zero in a recovery app reads as "nothing can be recovered".
class GStat extends StatelessWidget {
  const GStat({
    required this.label,
    required this.value,
    super.key,
    this.unit,
    this.tone,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String? value;
  final String? unit;
  final Color? tone;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (value == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RichText(
          text: TextSpan(
            text: value,
            style: GType.monoNumber.copyWith(
              color: tone ?? t.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            children: <InlineSpan>[
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: GType.monoSmall.copyWith(color: t.dim),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: GType.micro.copyWith(color: t.dim, fontSize: 10)),
      ],
    );
  }
}

/// The uppercase section label used above every group of cards.
class GOverline extends StatelessWidget {
  const GOverline(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: GType.overline.copyWith(color: t.dim),
          ),
        ),
        // Null-aware element. Equivalent to `if (trailing != null) trailing!`
        // without the bang, so a later refactor cannot leave the bang behind
        // after the null check is moved.
        ?trailing,
      ],
    );
  }
}
