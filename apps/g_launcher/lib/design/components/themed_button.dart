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
    //
    // ─── AND THE LABEL SHRINKS RATHER THAN SPILLS ─────────────────────────
    //
    // Min-width also means the label claims its intrinsic width and overflows
    // whenever the PARENT constrains it: two buttons in Expanded, three across
    // a 360dp row. That is a property of every constrained call site, not of
    // one screen, so it is fixed here rather than by shortening copy until it
    // happens to fit at one text scale on one device.
    //
    // FittedBox and NOT TextOverflow.ellipsis. A truncated button label is the
    // worst of both: it still does not tell you what the button does, and it
    // puts a cut word on screen. Scaling down keeps the whole word readable,
    // and the amount of scaling is tiny in practice because the overflow is a
    // few pixels rather than a few words.
    //
    // scaleDown, so a short label never grows: a two-word button in a wide
    // slot keeps body size rather than ballooning to fill it.
    //
    // The LayoutBuilder is what keeps the unbounded case safe. Flexible is a
    // flex child, and a flex child under unbounded width is exactly the
    // RenderFlex exception the paragraph above avoids, so it is only used when
    // there is a width to flex inside.
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final text = Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: d.text.body.copyWith(color: fg, fontWeight: FontWeight.w600),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: GSpace.sm),
            ],
            if (constraints.hasBoundedWidth)
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text))
            else
              text,
          ],
        );
      },
    );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return c.surfaceAlt.withValues(alpha: 0.5);
        }
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
