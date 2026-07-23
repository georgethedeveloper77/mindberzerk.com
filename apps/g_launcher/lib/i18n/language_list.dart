import 'package:flutter/widgets.dart';

import 'app_locale.dart';

/// The list of native language names, styled after Ubuntu's "Choose your
/// language" screen: a plain scroll of names with the active one drawn in the
/// accent colour.
///
/// Presentational on purpose: every colour and the base text style are passed
/// in, so the same widget drops into the full-bleed setup step and the (later)
/// settings page without this file ever importing your theme system. The
/// caller reads EffectiveTheme and hands the palette values down.
class LanguageList extends StatelessWidget {
  const LanguageList({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.textColor,
    required this.accentColor,
    this.baseStyle,
    this.mutedColor,
    this.showSystemOption = false,
    this.systemLabel = 'System default',
    this.rowPadding = const EdgeInsets.symmetric(vertical: 14),
    this.shrinkWrap = false,
  });

  /// The active choice, or null when "System default" is active.
  final AppLocale? selected;

  /// Called with the tapped language, or null for the system-default row.
  final ValueChanged<AppLocale?> onSelect;

  final Color textColor;
  final Color accentColor;

  /// Font family / size come from here (pass theme.typography.body or similar).
  /// Colour and weight are overridden per row below.
  final TextStyle? baseStyle;

  /// Optional dimmed colour for the system row's helper text.
  final Color? mutedColor;

  /// When true, prepends a "System default" row (useful on the settings page,
  /// usually off during first-run setup where a concrete choice is expected).
  final bool showSystemOption;
  final String systemLabel;

  final EdgeInsets rowPadding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final langs = localesForDisplay();
    final rows = <Widget>[
      if (showSystemOption)
        _Row(
          label: systemLabel,
          active: selected == null,
          textColor: textColor,
          accentColor: accentColor,
          baseStyle: baseStyle,
          padding: rowPadding,
          onTap: () => onSelect(null),
        ),
      for (final l in langs)
        _Row(
          label: l.nativeName,
          active: selected == l,
          textColor: textColor,
          accentColor: accentColor,
          baseStyle: baseStyle,
          padding: rowPadding,
          onTap: () => onSelect(l),
        ),
    ];

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: rows,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.active,
    required this.textColor,
    required this.accentColor,
    required this.baseStyle,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color textColor;
  final Color accentColor;
  final TextStyle? baseStyle;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = (baseStyle ?? const TextStyle()).copyWith(
      color: active ? accentColor : textColor,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    );
    // GestureDetector, not InkWell: shell overlays and setup have no Material
    // ancestor, so InkWell would throw "No Material widget found".
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Text(label, style: style),
      ),
    );
  }
}
