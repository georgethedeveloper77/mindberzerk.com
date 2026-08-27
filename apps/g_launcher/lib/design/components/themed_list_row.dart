import 'package:flutter/material.dart';

import '../tokens/radii.dart';
import '../tokens/spacing.dart';
import 'chrome_theme.dart';

/// The workhorse of the chrome layer: one row in a settings list. Icon, title,
/// optional subtitle, optional trailing control, optional tap.
///
/// It reads [ChromeScope] and nothing else, so the same row is a GNOME setting
/// under Ubuntu and a Breeze setting under KDE with no per-call change — the
/// colours and type come from the derived chrome. Step 3 rebuilds
/// `settings_screen.dart` out of these.
class ThemedListRow extends StatelessWidget {
  const ThemedListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.enabled = true,
  });

  final String title;

  /// A second line. Null renders a single-line row — never a placeholder
  /// string, per the house rule that absent data is an absent line, not "--".
  final String? subtitle;

  final IconData? icon;

  /// Any control: a [ThemedToggle], a chevron, a value label. Kept generic so
  /// the row doesn't grow a variant per trailing type.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Destructive rows (delete a theme, reset). Tints the icon + title with the
  /// semantic danger colour so the weight of the action reads at a glance.
  final bool danger;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // ─── A MENU ROW MAY BE TEXT ONLY ────────────────────────────────────
    //
    // GNOME menus and macOS menus carry no icons; Breeze and Xfce menus do.
    // [ChromeMenu.rowIcons] is the family's answer and it is applied HERE
    // rather than by passing a null icon at each call site, because rows in a
    // menu are built in six places and three of them are callers handing in
    // their own list.
    //
    // Gated on [ChromeData.inMenu], which only [AnchoredMenu] sets. A settings
    // list is not a menu: an Adwaita settings page genuinely does carry icons,
    // and stripping them would be the right convention applied to the wrong
    // surface.
    final showIcon = icon != null && (!d.inMenu || d.menu.rowIcons);

    final titleColor = !enabled
        ? c.textFaint
        : danger
            ? c.danger
            : c.text;
    final iconColor = !enabled
        ? c.textFaint
        : danger
            ? c.danger
            : c.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: c.accent.withValues(alpha: 0.10),
        highlightColor: c.surfaceAlt.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.lg,
            vertical: GSpace.md,
          ),
          child: Row(
            children: [
              if (showIcon) ...[
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: GSpace.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: d.text.body.copyWith(color: titleColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: d.text.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: GSpace.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section heading above a group of [ThemedListRow]s. Small caps-y label in
/// the chrome's faint ink — the same rhythm your existing `_Head` gives, but
/// themed.
class ThemedSectionHeader extends StatelessWidget {
  const ThemedSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GSpace.lg,
        GSpace.xl,
        GSpace.lg,
        GSpace.sm,
      ),
      // SENTENCE CASE, not upper.
      //
      // `label` still carries the small size and the letter spacing, and both
      // suit an uppercase caption, which is why this shouted for so long. But
      // neither GNOME nor KDE uppercases a section heading: that is an iOS and
      // One UI convention, and it was one of the two things making this chrome
      // read as a phone app wearing Ubuntu's orange. The other was the icon
      // circle on every row.
      //
      // Muted rather than faint, because a heading that is quieter than the
      // rows beneath it stops grouping them.
      child: Text(
        text,
        style: d.text.label.copyWith(
          color: d.colors.textMuted,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// A grouped card wrapping rows, Adwaita-style (rounded, inset, hairline
/// between rows). KDE/Breeze can later opt for a flatter framing via
/// chromeFamily; the rows inside don't change.
class ThemedListCard extends StatelessWidget {
  const ThemedListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final divided = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        divided.add(Divider(height: 0.5, thickness: 0.5, color: c.line, indent: GSpace.lg, endIndent: GSpace.lg));
      }
      divided.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GSpace.lg, vertical: GSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: GRadius.mdAll,
        border: Border.all(color: c.line, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: divided),
    );
  }
}
