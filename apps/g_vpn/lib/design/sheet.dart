import 'package:flutter/material.dart';

import '../i18n/strings.g.dart';
import 'meridian.dart';

/// One section of an explanation sheet: a short heading and a sentence or
/// two. [icon] is optional: give one only when it says something the
/// heading does not (a check for "Free", a bolt for "Pro").
class SheetSection {
  const SheetSection(this.icon, this.title, this.body, {this.tone});

  /// Text-only section.
  const SheetSection.text(this.title, this.body)
      : icon = null,
        tone = null;

  final IconData? icon;
  final String title;
  final String body;
  final Color? tone;
}

/// The one bottom-sheet style used across the app.
///
/// A header with the screen's own mark and colour, the title and one lead
/// line; then each section as a soft card, its heading in that colour; and
/// one button in the same colour.
Future<void> showInfoSheet(
  BuildContext context, {
  IconData? icon,
  Color? color,
  required String title,
  String? subtitle,
  required List<SheetSection> sections,
  String? linkLabel,
  VoidCallback? onLink,
  String? button,

  /// Runs when the button is pressed, before the sheet closes; dragging the
  /// sheet away does not run it.
  VoidCallback? onButton,
}) {
  final m = context.mer;
  final tone = color ?? m.brand;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .82),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)),
                        child: Icon(icon ?? Icons.info_outline_rounded, size: 24, color: tone),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(title,
                            style: TextStyle(fontSize: 21, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text)),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(subtitle, style: TextStyle(fontSize: 15, height: 1.5, color: m.text)),
                  ],
                  const SizedBox(height: 14),
                  for (final (i, s) in sections.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _Section(section: s, tone: tone),
                  ],
                  if (linkLabel != null && onLink != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onLink,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(linkLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tone)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  onButton?.call();
                  Navigator.pop(c);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tone,
                  foregroundColor: m.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(button ?? t.common.gotIt, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.tone});

  final SheetSection section;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final accent = section.tone ?? tone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(color: m.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.icon != null) ...[
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(section.icon, size: 20, color: accent)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (section.title.isNotEmpty) ...[
                  Text(section.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
                  const SizedBox(height: 3),
                ],
                Text(section.body, style: TextStyle(fontSize: 14.5, height: 1.5, color: m.text.withValues(alpha: .82))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The app bar's "i", drawn like every other app bar icon: the text colour,
/// the standard size, nothing around it.
class InfoIcon extends StatelessWidget {
  const InfoIcon({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: t.common.about,
        icon: Icon(Icons.info_outline_rounded, size: 22, color: context.mer.text),
        onPressed: onPressed,
      );
}

/// App-bar "i" that opens a sectioned sheet.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, this.subtitle, required this.sections});

  final String title;
  final String? subtitle;
  final List<SheetSection> sections;

  @override
  Widget build(BuildContext context) =>
      InfoIcon(onPressed: () => showInfoSheet(context, title: title, subtitle: subtitle, sections: sections));
}
