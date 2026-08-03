/// The row and group vocabulary every settings page is built from.
///
/// Extracted from `settings_screen.dart`. These were private, which is why the
/// names changed: `SettingsGroup`, `SettingsRow`, `SettingsToggleRow` and the
/// small value widgets around them. See that file's header for why the split
/// happened and why `part of` was refused.
///
/// [SettingsSkin] is the load-bearing one. Every surface here resolves from the
/// chrome rather than from a constant, and forks on [ChromeFamily], so the same
/// row reads as Adwaita under Ubuntu and Breeze under Plasma without any caller
/// naming a colour.
library;

import 'package:flutter/material.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/components/components.dart';
import '../../engine/theme_spec.dart' show ChromeFamily;

class SettingsFraming {
  const SettingsFraming({
    required this.cardRadius,
    required this.cardInset,
    required this.headerUpper,
  });

  /// Corner radius of the group card (and the search / banner cards).
  final double cardRadius;

  /// Horizontal margin around cards.
  final double cardInset;

  /// Upper-case the section label with tracking (Breeze category headers).
  final bool headerUpper;

  static SettingsFraming forFamily(ChromeFamily f) => switch (f) {
        ChromeFamily.adwaita => const SettingsFraming(
            cardRadius: 16, cardInset: 16, headerUpper: false),
        ChromeFamily.breeze => const SettingsFraming(
            cardRadius: 6, cardInset: 12, headerUpper: true),
        ChromeFamily.aqua => const SettingsFraming(
            cardRadius: 12, cardInset: 16, headerUpper: false),
        ChromeFamily.generic => const SettingsFraming(
            cardRadius: 12, cardInset: 16, headerUpper: false),
      };
}

/// This screen's resolved skin: the colours it uses (mapped 1:1 from the derived
/// chrome) plus the family framing. Replaces the old fixed `_Ou` palette. Field
/// names are kept short and familiar so the widget bodies read the same; the
/// values now come from the active theme.
class SettingsSkin {
  const SettingsSkin({
    required this.bg,
    required this.card,
    required this.card2,
    required this.tx,
    required this.mut,
    required this.acc,
    required this.onAcc,
    required this.line,
    required this.warn,
    required this.framing,
  });

  final Color bg; // page background
  final Color card; // group / sheet surface
  final Color card2; // recessed chips (segment track, icon circle, step button)
  final Color tx; // primary text
  final Color mut; // muted text / icons
  final Color acc; // distro accent
  final Color onAcc; // ink on the accent (active segment text)
  final Color line; // hairline dividers
  final Color warn; // the vertical-swipe warning tint
  final SettingsFraming framing;

  factory SettingsSkin.fromData(ChromeData d) {
    final c = d.colors;
    return SettingsSkin(
      bg: c.bg,
      card: c.surface,
      card2: c.surfaceAlt,
      tx: c.text,
      mut: c.textMuted,
      acc: c.accent,
      onAcc: c.onAccent,
      line: c.line,
      warn: c.warn,
      framing: SettingsFraming.forFamily(d.family),
    );
  }

  /// Read the nearest chrome. Under a [ThemedScaffold] this is the live theme;
  /// outside one it is the bootstrap floor (never a crash).
  static SettingsSkin of(BuildContext context) =>
      SettingsSkin.fromData(ChromeScope.of(context));
}

// ─────────────────────────────────────────────────────────────────────────────
// Structure
// ─────────────────────────────────────────────────────────────────────────────

// `_Title` LIVED HERE and is gone. It was a 28px, w700, left-aligned page
// heading rendered as the first item of the list: the iOS large-title pattern,
// and the loudest of the three things making this screen read as a phone app
// wearing Ubuntu's orange. The landing page now passes a title to
// ThemedScaffold and gets the same flat centred header bar every other chrome
// screen already had.

/// A group label above a rounded card whose rows are divided by a hairline.
/// Empty groups render nothing — which is also how search hides a whole section.
/// The card is a [Material] so the rows' ink splashes have a surface to land on.
/// Radius, inset and header case fork on the theme's [ChromeFamily].
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.label,
    required this.rows,
    this.scope,
    this.query = '',
    // KEPT AND SILENCED, not deleted. The doc on the field below argues at
    // length for holding the slot open, and it is right: the header is where a
    // group-local action belongs if one ever returns, and removing the
    // parameter takes the header layout with it. What the analyser is
    // reporting is true and not a defect, so it is answered rather than obeyed.
    // ignore: unused_element_parameter
    this.onReset,
  });

  final String label;
  final List<FilterRow> rows;

  /// Who this group's settings belong to: "This distro" or "All distros".
  ///
  /// ─── THE SPLIT WAS INVISIBLE UNTIL THIS EXISTED ───────────────────────────
  ///
  /// Some of these settings live in the theme's own file and some in the global
  /// bucket, and the difference is not guessable from the row. Someone who sets
  /// circular icons on Ubuntu and finds them on Plasma has learned something
  /// true; someone who sets a bottom dock and finds it gone has learned
  /// something equally true and drawn the opposite conclusion. Saying it once
  /// per group is the cheapest place to say it, because after the regroup the
  /// groups are almost entirely scope-coherent.
  ///
  /// ALMOST. A row that disagrees with its group carries its own marker in the
  /// value slot instead, which is why this is a group hint and not a promise;
  /// `drawerCols` is the live example. Null renders nothing, which is right for
  /// a group where the question does not arise.
  final String? scope;

  /// Restore this group's settings, or null for no affordance.
  ///
  /// ─── CURRENTLY ALWAYS NULL, AND KEPT ON PURPOSE ─────────────────────────
  ///
  /// Six groups passed this until `RestoreScreen` arrived. Two surfaces for
  /// one feature is worse than either alone, especially with DIFFERENT section
  /// boundaries: this screen groups the bar with the icons, that one groups it
  /// with the desktop, and a user who reset "Icons and bar" here and "Icons"
  /// there would get two different results from the same word. The dedicated
  /// page won because it can say "settings only, nothing you made is removed"
  /// once, at the top, where it is read.
  ///
  /// The parameter stays because the header slot is the right home if a group
  /// ever wants a local action, and because deleting it would take the layout
  /// with it for no gain. It renders nothing while null.
  final VoidCallback? onReset;

  /// Already trimmed; may be empty (no search active).
  final String query;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    final f = s.framing;
    final q = query.toLowerCase();
    // A matching group label reveals the whole section; otherwise filter row by
    // row. So "gestures" surfaces every gesture, and "wrap" surfaces one row.
    final labelHit = q.isEmpty || label.toLowerCase().contains(q);
    final visible = <Widget>[
      for (final r in rows)
        if (labelHit || r.matches(q)) r.child,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    final divided = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) {
        divided.add(Divider(height: 1, thickness: 1, color: s.line));
      }
      divided.add(visible[i]);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(f.cardInset, 0, f.cardInset, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: f.headerUpper ? label.toUpperCase() : label,
                      children: [
                        if (scope != null)
                          TextSpan(
                            // Lighter and unbolded against the label, never on
                            // its own line: it is a qualifier on the heading,
                            // and a second line would make every group look
                            // like it had a subtitle.
                            text: f.headerUpper
                                ? '  ${scope!.toUpperCase()}'
                                : '  $scope',
                            style: TextStyle(
                              color: s.mut.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    style: TextStyle(
                      color: s.mut,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: f.headerUpper ? 0.6 : 0,
                    ),
                  ),
                ),
                if (onReset != null)
                  GestureDetector(
                    onTap: onReset,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      // Padding rather than a bare Text: the tap target has to
                      // be reachable with a thumb, and the glyph is small.
                      padding: const EdgeInsets.fromLTRB(10, 2, 2, 4),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: ChromeScope.of(context).colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(f.cardRadius),
            child: Material(
              color: s.card,
              child: Column(children: divided),
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row plus the words that should surface it in search. [terms] must
/// be lowercase; [matches] receives an already-lowercased query.
class FilterRow {
  const FilterRow(this.terms, this.child);

  final List<String> terms;
  final Widget child;

  bool matches(String q) => q.isEmpty || terms.any((t) => t.contains(q));
}

/// The search field. Filters the settings live; the clear button appears only
/// once there's something to clear.

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.subtitleTint,
    this.accent = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleTint;

  /// Tint the icon circle with the distro accent (was the `tint:` colour). A
  /// bool, not a Color, because the accent is resolved from the chrome inside
  /// [IconCircle] — the row is built above the scope in the page build.
  final bool accent;

  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // ── ICONS ON THE LANDING PAGE, NONE INSIDE A SECTION ──────
            //
            // GNOME puts icons in the settings SIDEBAR and almost never on the
            // rows within a page. An accent circle on every row is an iOS and
            // One UI convention, and together with the large title it was the
            // main reason this chrome read as a phone app wearing Ubuntu's
            // orange rather than as a desktop settings app.
            //
            // A scope rather than a parameter, deliberately: the rows were
            // sliced verbatim out of the old build method and all 30 of them
            // pass `icon:`. Threading a flag through every one would have meant
            // editing all 30, which is exactly the retyping this refactor kept
            // avoiding. `_SectionPage` sets it false for its whole subtree and
            // nothing else has to know.
            if (RowIcons.of(context)) ...[
              IconCircle(icon: icon, accent: accent),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: s.tx,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleTint ?? s.mut,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A row with a trailing toggle; the whole row flips it.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.accent = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// DIMMED AND INERT, NOT ABSENT.
  ///
  /// A setting that only applies in some other mode ("Group A to Z" needs the
  /// list layout) is shown greyed with the reason in its own subtitle rather
  /// than hidden. Hiding it means someone who has read about the feature
  /// concludes it does not exist in this build; greying it teaches the rule at
  /// a glance and says where to go for it.
  ///
  /// Both the row tap AND the switch have to go inert. Killing only one leaves
  /// a control that half-works, which is worse than either.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    final row = SettingsRow(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      onTap: enabled ? () => onChanged(!value) : null,
      // WidgetStateProperty, not the activeColor churn — the stable Material-3
      // surface. Track fills with the distro accent when on.
      trailing: Switch(
        value: value,
        // Null disables it. Material greys the thumb and track itself, so the
        // colours below still apply in the enabled case only.
        onChanged: enabled ? onChanged : null,
        thumbColor: WidgetStatePropertyAll(s.onAcc),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? s.acc : s.card2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );

    // One Opacity over the whole row, so the label, the subtitle, the icon
    // circle and the switch all fade together. Dimming only the switch would
    // read as a rendering glitch rather than as a disabled setting.
    return enabled ? row : Opacity(opacity: 0.45, child: row);
  }
}

class IconCircle extends StatelessWidget {
  const IconCircle({super.key, required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent ? s.acc.withValues(alpha: 0.16) : s.card2,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: accent ? s.acc : s.mut),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trailing controls
// ─────────────────────────────────────────────────────────────────────────────

class ValueLabel extends StatelessWidget {
  const ValueLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: s.mut, fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: s.mut),
      ],
    );
  }
}

class Chevron extends StatelessWidget {
  const Chevron({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Icon(Icons.chevron_right, size: 18, color: s.mut);
  }
}

/// The `System` pill + external-link glyph for rows that leave the app.
class SysBadge extends StatelessWidget {
  const SysBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: s.acc.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            'System',
            style: TextStyle(
              color: s.acc,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.open_in_new, size: 15, color: s.mut),
      ],
    );
  }
}

/// A row's value as a PICTURE, with the text kept alongside it.
///
/// The chip is a real [DevicePreview] at 26x40 — the same renderer as the hero
/// previews and the setup backdrop, so a row can never disagree with the screen
/// it opens. Drawn from the live prefs, so it redraws the moment the setting
/// changes rather than the next time you visit.
///
/// The label stays. A picture at this size tells you the SHAPE of a setting
/// ("dock on the left", "a wide grid") and cannot tell you "5 x 4" — dropping
/// the number to make room for the graphic would trade precision for prettiness.
class ChipValue extends StatelessWidget {
  const ChipValue({
    super.key,
    required this.preview,
    this.label,
    this.chevron = false,
  });

  final Widget preview;
  final String? label;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(color: s.mut, fontSize: 12.5),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(width: 26, height: 40, child: preview),
        if (chevron) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: s.mut),
        ],
      ],
    );
  }
}

/// A pill track with one active segment (accent fill, ink text).
class Seg extends StatelessWidget {
  const Seg({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.card2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: e.key == value
                    ? BoxDecoration(
                        color: s.acc,
                        borderRadius: BorderRadius.circular(7),
                      )
                    : null,
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        e.key == value ? FontWeight.w600 : FontWeight.w400,
                    color: e.key == value ? s.onAcc : s.mut,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gesture row (carries the vertical-swipe warning)
// ─────────────────────────────────────────────────────────────────────────────

class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: s.tx, fontSize: 15),
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.tx,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    final enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: s.card2,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? s.tx : s.mut.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class ValueChevron extends StatelessWidget {
  const ValueChevron({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text != null) ...[
          Text(text!, style: TextStyle(color: s.mut, fontSize: 13)),
          const SizedBox(width: 8),
        ],
        Icon(Icons.chevron_right, size: 20, color: s.mut),
      ],
    );
  }
}

/// Whether a [SettingsRow] draws its leading icon circle.
///
/// True everywhere by default, so the landing page and the flat search results
/// keep their icons with no wrapper. [_SectionPage] sets it false, which is the
/// GNOME split: icons in the sidebar, none on the rows inside a page.
class RowIcons extends InheritedWidget {
  const RowIcons({super.key, required this.show, required super.child});

  final bool show;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RowIcons>()?.show ?? true;

  @override
  bool updateShouldNotify(RowIcons oldWidget) => oldWidget.show != show;
}

/// The surface opacity slider.
///
/// Its own widget because a `SettingsRow` is an icon, two lines of text and a trailing
/// slot, and a slider is none of those. Built from chrome tokens the same way
/// `_SuggestionRow` in folders_screen is, which is the established way this app
/// makes a row that the primitive does not cover.
class OpacityRow extends StatelessWidget {
  const OpacityRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.sub,
    this.subWhenInert = false,
    this.following = false,
    this.onFollow,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Null for the main slider, which keeps its translated strings. The three
  /// section rows pass their own; those join the i18n backlog with the rest of
  /// this round's copy rather than minting keys ahead of the sweep.
  final String? label;
  final String? sub;

  /// Marks a row whose subtitle names a case where it does nothing on the
  /// shell currently on screen. Drawn quieter, and never hidden: a row that
  /// vanishes per distro is worse than one that says why it is idle.
  final bool subWhenInert;

  /// True while this section has no value of its own and is tracking the main
  /// slider. The Follow action only appears once it has stopped.
  final bool following;

  /// Clears the section's own value so it tracks the main slider again.
  /// Without it a section could be split out and never rejoined, which is the
  /// state that makes a settings screen feel like a one-way door.
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.opacity, size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label ?? context.t('settings.surfaceOpacity'),
                    style: d.text.body),
              ),
              if (!following && onFollow != null)
                GestureDetector(
                  onTap: onFollow,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(context.t('settings.follow'),
                        style: d.text.caption.copyWith(color: c.accent)),
                  ),
                ),
              Text('${(value * 100).round()}%',
                  style: d.text.value.copyWith(color: c.textMuted)),
            ],
          ),
          ThemedSlider(
            value: value,
            // 0.6 to 1.0, and the floor is the point. Below it a settings page
            // stops being readable over an arbitrary photograph, and
            // EffectiveTheme.surfaceOpacity clamps to the same bounds so a
            // value from anywhere else cannot get past it either.
            min: 0.6,
            max: 1.0,
            divisions: 8,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child: Text(
              sub ?? context.t('settings.surfaceOpacitySub'),
              style: d.text.caption.copyWith(
                color: subWhenInert ? c.textFaint : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
