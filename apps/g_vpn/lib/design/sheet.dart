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
/// Built to read like a short article, not a form: a plain title, sections
/// separated by space rather than boxes, body text at a comfortable measure
/// and line height, and one quiet button.
Future<void> showInfoSheet(
  BuildContext context, {
  IconData? icon,
  required String title,
  String? subtitle,
  required List<SheetSection> sections,
  String? linkLabel,
  VoidCallback? onLink,
  String? button,
}) {
  final m = context.mer;
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 15, height: 1.4, color: m.muted)),
                  ],
                  const SizedBox(height: 18),
                  for (final (i, s) in sections.indexed) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _Section(section: s),
                  ],
                  if (linkLabel != null && onLink != null) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: onLink,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(linkLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.brand)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              height: 50,
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(c),
                style: FilledButton.styleFrom(
                  backgroundColor: m.surface2,
                  foregroundColor: m.text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(button ?? t.common.gotIt, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final SheetSection section;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title.isNotEmpty) ...[
          Text(section.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: m.text)),
          const SizedBox(height: 4),
        ],
        // About 60 characters a line at this size: easy to read.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(section.body, style: TextStyle(fontSize: 15, height: 1.55, color: m.muted)),
        ),
      ],
    );
    if (section.icon == null) return text;
    final tone = section.tone ?? m.brand;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(section.icon, size: 20, color: tone),
        ),
        const SizedBox(width: 12),
        Expanded(child: text),
      ],
    );
  }
}

/// App-bar "i" that opens a sectioned sheet.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, this.subtitle, required this.sections});

  final String title;
  final String? subtitle;
  final List<SheetSection> sections;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: t.common.about,
        icon: const Icon(Icons.info_outline_rounded),
        onPressed: () => showInfoSheet(context, title: title, subtitle: subtitle, sections: sections),
      );
}
