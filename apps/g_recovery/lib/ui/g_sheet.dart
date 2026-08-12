import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

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
}) {
  final GTokens t = context.g;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.panel,
    // Scroll controlled, so a long explanation is scrollable rather than
    // clipped. Several of these run past half the screen on a small phone.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
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
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: GRadius.all(2),
                  ),
                ),
              ),
              const SizedBox(height: GSpace.lg),
              Text(title, style: GType.title.copyWith(color: t.text)),
              const SizedBox(height: GSpace.md),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

/// One point inside a sheet, with a mark against it.
///
/// [tone] carries the meaning. Warning for a limit, success for something that
/// works, muted for a plain statement.
class GSheetPoint extends StatelessWidget {
  const GSheetPoint({
    required this.text,
    super.key,
    this.icon = Icons.remove_rounded,
    this.tone,
  });

  final String text;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Color mark = tone ?? t.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 16, color: mark),
          ),
          const SizedBox(width: GSpace.sm + 2),
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
