import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// A next step offered by a sheet.
///
/// WHEN THERE IS ONE, IT SITS DIRECTLY UNDER THE TITLE.
///
/// A sheet that explains why a screen is empty, names a fix, and then does not
/// offer it is a dead end. The reasons drop to supporting text beneath the
/// action, because someone who opened that sheet wants the step more than the
/// explanation.
class GSheetAction {
  const GSheetAction({required this.label, required this.onTap, this.detail});

  final String label;

  /// One line on what it does and what it costs. Keeps the button honest about
  /// a scan that takes minutes.
  final String? detail;

  /// Runs after the sheet closes, so the page underneath is already visible by
  /// the time the work starts and its progress is not hidden behind a panel.
  final VoidCallback onTap;
}

/// Detail, one tap away.
///
/// The pattern this app uses instead of putting explanations at the top of a
/// page. Everything in here is essential to understand and unhelpful to read
/// first: a wall of caveats before someone knows what they are looking at reads
/// as an apology rather than as honesty.
///
/// A sheet is not where things go to be hidden. Nothing moved into one is
/// shortened or softened; it is the same words, reachable from an info icon,
/// after the person has seen what the page is for.
Future<void> showGSheet({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  GSheetAction? action,
  String? footnote,
}) {
  final GTokens t = context.g;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.panel,
    // The bottom nav lives below this page's navigator. Without the root one
    // the nav stays at full brightness beside a dimmed page, which reads as a
    // panel that failed to cover the screen rather than a layer above it.
    useRootNavigator: true,
    barrierColor: const Color(0x99000000),
    // Scroll controlled, so a long explanation is scrollable rather than
    // clipped. Several of these run past half the screen on a small phone.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            GSpace.md,
            GSpace.gutter,
            GSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: GRadius.all(2),
                  ),
                ),
              ),
              const SizedBox(height: GSpace.lg),
              Text(title, style: GType.title.copyWith(color: t.text)),
              if (action != null) ...<Widget>[
                const SizedBox(height: GSpace.md),
                _Action(
                  action: action,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onTap();
                  },
                ),
              ],
              if (footnote != null) ...<Widget>[
                const SizedBox(height: GSpace.lg),
                Text(
                  footnote,
                  style: GType.micro.copyWith(color: t.dim, letterSpacing: 1.3),
                ),
              ],
              const SizedBox(height: GSpace.md),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.action, required this.onTap});

  final GSheetAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: GRadius.all(GRadius.tile),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(GSpace.md),
          decoration: BoxDecoration(
            borderRadius: GRadius.all(GRadius.tile),
            border: Border.all(color: t.accent.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                action.label,
                style: GType.body.copyWith(color: t.accentText),
              ),
              if (action.detail != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  action.detail!,
                  style: GType.bodySmall.copyWith(color: t.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One point inside a sheet.
///
/// NO MARK BY DEFAULT, and that is the whole fix.
///
/// This used to default to a dash tinted with the warning colour, so a sheet
/// stating three plain facts drew three orange dashes, and the one point that
/// set its own icon made the column read as two vocabularies stacked on each
/// other. A statement is not a warning.
///
/// [icon] survives for the rare point that genuinely carries a mark, but a group
/// uses one icon family or none, never a mixture.
class GSheetPoint extends StatelessWidget {
  const GSheetPoint({required this.text, super.key, this.icon, this.tone});

  final String text;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, size: 16, color: tone ?? t.dim),
            ),
            const SizedBox(width: GSpace.sm + 2),
          ],
          Expanded(
            child: Text(text, style: GType.bodySmall.copyWith(color: t.muted)),
          ),
        ],
      ),
    );
  }
}

/// A heading inside a sheet.
class GSheetHeading extends StatelessWidget {
  const GSheetHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(top: GSpace.md, bottom: GSpace.sm),
      child: Text(text, style: GType.heading.copyWith(color: t.text)),
    );
  }
}
