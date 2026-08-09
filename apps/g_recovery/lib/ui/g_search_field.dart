import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The search bar that sits at the top of home.
///
/// Search is a first class element, not a menu item, because the most common
/// thing a user knows about a lost file is its name. Phase 4 wires this to the
/// unified index; here it is a shell with the correct geometry.
class GSearchField extends StatelessWidget {
  const GSearchField({
    required this.hint,
    super.key,
    this.value,
    this.onTap,
    this.onClear,
    this.leading = '>',
    this.active = false,
  });

  final String hint;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  /// The operator prompt. Storage uses a terminal style caret, home uses a
  /// magnifier glyph supplied by the caller.
  final String leading;

  final bool active;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool hasValue = value != null && value!.isNotEmpty;
    final BorderRadius radius = GRadius.all(GRadius.button + 2);

    return Material(
      color: t.panel,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: active ? t.accent : t.line),
          ),
          child: Row(
            children: <Widget>[
              Text(
                leading,
                style: GType.monoNumber.copyWith(
                  color: active ? t.accentText : t.dim,
                ),
              ),
              const SizedBox(width: GSpace.md - 2),
              Expanded(
                child: Text(
                  hasValue ? value! : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.body.copyWith(
                    color: hasValue ? t.text : t.dim,
                  ),
                ),
              ),
              if (hasValue && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded, size: 17, color: t.dim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
