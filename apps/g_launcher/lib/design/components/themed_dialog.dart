import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'chrome_theme.dart';
import 'themed_button.dart';

/// A themed dialog. Same route-boundary rule as [ThemedSheet]: the chrome is
/// captured before `showDialog` and re-provided inside, so the dialog matches
/// the screen behind it.
///
/// Two ways to call it: [confirm] for the common title + message + two-button
/// case, or [show] for arbitrary content.
class ThemedDialog {
  const ThemedDialog._();

  /// Arbitrary dialog content.
  ///
  /// Pass EITHER [actions] (built by the caller) OR [actionsBuilder], which
  /// receives the dialog's own [BuildContext] — use it so `Navigator.of(...)`
  /// targets THIS dialog's route, not a nested navigator the caller might sit
  /// under. [confirm] relies on this.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? content,
    List<Widget> actions = const [],
    List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
  }) {
    final data = ChromeScope.of(context);
    final c = data.colors;

    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final resolvedActions = actionsBuilder?.call(ctx) ?? actions;
        return ChromeScope(
          data: data,
          child: Dialog(
            backgroundColor: c.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: GRadius.lgAll),
            child: Padding(
              padding: const EdgeInsets.all(GSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: data.text.title),
                  if (content != null) ...[
                    const SizedBox(height: GSpace.md),
                    DefaultTextStyle(style: data.text.body, child: content),
                  ],
                  if (resolvedActions.isNotEmpty) ...[
                    const SizedBox(height: GSpace.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < resolvedActions.length; i++) ...[
                          if (i > 0) const SizedBox(width: GSpace.sm),
                          resolvedActions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The common case: title, message, cancel + confirm. Resolves to true if
  /// confirmed, false/null otherwise. [danger] paints confirm as destructive.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
  }) {
    return show<bool>(
      context,
      title: title,
      content: Text(message),
      // Built against the DIALOG context so pops hit this route.
      actionsBuilder: (dialogCtx) => [
        ThemedButton(
          label: cancelLabel,
          kind: ThemedButtonKind.text,
          onPressed: () => Navigator.of(dialogCtx).pop(false),
        ),
        ThemedButton(
          label: confirmLabel,
          kind: danger ? ThemedButtonKind.danger : ThemedButtonKind.primary,
          onPressed: () => Navigator.of(dialogCtx).pop(true),
        ),
      ],
    );
  }
}
