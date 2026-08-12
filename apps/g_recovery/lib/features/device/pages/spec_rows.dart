import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

/// A list of label and value rows, with the absent ones removed.
///
/// Every hardware page is mostly this. Sharing it means a null is dropped the
/// same way on all of them, rather than one page showing a dash, another an
/// empty string, and a third the word "Unknown".
class SpecRows extends StatelessWidget {
  const SpecRows({required this.rows, super.key});

  /// Null values are not rendered.
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final List<(String, String)> present = <(String, String)>[
      for (final (String label, String? value) in rows)
        if (value != null && value.isNotEmpty) (label, value),
    ];
    if (present.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        for (int i = 0; i < present.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 1),
            decoration: BoxDecoration(
              border: i == present.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    present[i].$1,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                ),
                const SizedBox(width: GSpace.md),
                Flexible(
                  child: Text(
                    present[i].$2,
                    textAlign: TextAlign.right,
                    style: GType.monoSmall.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
