import 'package:flutter/material.dart';

import '../../../../../../../../i18n/strings.g.dart';
import 'meridian.dart';
import 'sheet.dart';

/// The one list language every screen uses: section titles, grouped rows,
/// and an info button whose sheet holds the explanations, so screens stay
/// free of paragraphs.

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.mer.text)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Rows in one rounded card, separated by hairlines.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        side: BorderSide(color: m.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: m.line),
            c,
          ],
        ],
      ),
    );
  }
}

class ListItem extends StatelessWidget {
  const ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.mono = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  /// Subtitle in the mono face (addresses, numbers).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? m.brandSoft : null,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.text)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: mono ? m.monoStyle(size: 12, color: m.muted) : TextStyle(fontSize: 12, color: m.muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// A small coloured label (FAST, RISKY, WPA2...).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .3, color: color)),
      );
}

/// App-bar "i": the screen's explanation, in a sheet, only when asked.
class InfoAction extends StatelessWidget {
  const InfoAction({super.key, required this.title, required this.body});

  final String title;
  final String body;

  /// Paragraphs become text sections. A paragraph opening "Heading: rest"
  /// takes that heading; the first paragraph without one becomes the
  /// sheet's subtitle, so nothing repeats the title.
  static Future<void> show(BuildContext context, String title, String body) {
    final sections = <SheetSection>[];
    String? lead;
    for (final para in body.split(RegExp(r'\n\s*\n'))) {
      final text = para.trim();
      if (text.isEmpty) continue;
      final colon = text.indexOf(': ');
      final hasHead = colon > 0 && colon < 28 && !text.substring(0, colon).contains('.');
      if (hasHead) {
        sections.add(SheetSection.text(text.substring(0, colon), text.substring(colon + 2)));
      } else if (lead == null && sections.isEmpty) {
        lead = text;
      } else {
        sections.add(SheetSection.text('', text));
      }
    }
    return showInfoSheet(context, title: title, subtitle: lead, sections: sections);
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: t.common.about,
        icon: const Icon(Icons.info_outline_rounded),
        onPressed: () => show(context, title, body),
      );
}
