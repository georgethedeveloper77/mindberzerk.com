import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'chrome_theme.dart';

/// What a [ThemedButton] is for, which decides its colour, not its size.
enum ThemedButtonKind {
  /// Filled accent — the one affirmative action on a screen.
  primary,

  /// Outlined, neutral — secondary actions that shouldn't compete.
  secondary,

  /// Text-only accent — low-emphasis inline actions.
  text,

  /// Filled danger — destructive confirmations (delete, reset).
  danger,
}

/// A button coloured entirely from the chrome. Every state (disabled, pressed)
/// is set explicitly so nothing falls through to the host `ThemeData`.
class ThemedButton extends StatelessWidget {
  const ThemedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ThemedButtonKind.primary,
    this.expand = false,
  });

  final String label;

  /// Null renders the disabled look.
  final VoidCallback? onPressed;

  final IconData? icon;
  final ThemedButtonKind kind;

  /// Stretch to fill the cross axis (full-width sheet/dialog actions).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // Resolve the four colours that distinguish the variants; everything else
    // (shape, padding, type) is shared.
    late final Color fg;
    late final Color? bg;
    late final Color? border;
    switch (kind) {
      case ThemedButtonKind.primary:
        fg = c.onAccent;
        bg = c.accent;
        border = null;
      case ThemedButtonKind.danger:
        fg = c.onAccent;
        bg = c.danger;
        border = null;
      case ThemedButtonKind.secondary:
        fg = c.text;
        bg = c.surfaceAlt;
        border = c.lineStrong;
      case ThemedButtonKind.text:
        fg = c.accent;
        bg = Colors.transparent;
        border = null;
    }

    // The Row is always min-width; full-width comes from wrapping the button in
    // a stretched box below. A max-width Row inside an unbounded parent (a
    // dialog action row) would throw.
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: GSpace.sm),
        ],
        Text(label, style: d.text.body.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ],
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return c.surfaceAlt.withValues(alpha: 0.5);
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return c.textFaint;
        return fg;
      }),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.10)),
      side: border == null
          ? null
          : WidgetStatePropertyAll(BorderSide(color: border, width: 0.5)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: GRadius.smAll),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: GSpace.lg, vertical: GSpace.md),
      ),
      elevation: const WidgetStatePropertyAll(0.0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
    );

    final button = TextButton(onPressed: onPressed, style: style, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
