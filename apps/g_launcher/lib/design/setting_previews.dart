/// The live pictures in Settings: what a setting will look like, drawn from the
/// setting itself.
///
/// ─── IN design/, NOT features/settings/ ─────────────────────────────────────
///
/// Next to [DevicePreview], which it wraps, and which the setup wizard already
/// uses. A preview is a design primitive rather than a settings screen: the
/// same picture belongs in setup, in the folders screen, and in the wallpaper
/// screen, and none of those should import a settings file to get it.
///
/// Everything here paints from the palette, so switching distro repaints every
/// preview in the app with no wiring at all.
library;

import 'package:flutter/material.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../engine/effective_theme.dart';
import '../engine/theme_spec.dart' show ThemePalette;
import 'components/components.dart';
import 'device_preview.dart';

/// A page-level preview: one picture at the top of a settings section, showing
/// what the settings below it do.
///
/// ─── ONE PER PAGE, NOT ONE PER GROUP ────────────────────────────────────────
///
/// Both were on the table. Per group is more directly connected to the control
/// you are touching, and it is what [PanelPreview] already does, correctly:
/// blur, tint and corner radius are impossible to describe in a subtitle and
/// obvious the instant you see them, and the surface they change only appears
/// when you have stopped looking at this screen. That case earns its own
/// picture inside its own group.
///
/// It does not generalise. A page with a picture over every group is a page
/// that is mostly pictures, and the reader loses the thread of the list. So the
/// default is one at the top, answering "what am I about to change" for the
/// whole section, and a group keeps its own only when the thing it changes is
/// invisible from here.
///
/// ─── AND IT IS HIDDEN WHILE SEARCHING ───────────────────────────────────────
///
/// A preview is not a search result. Sitting above a filtered list it would
/// look like one, and it would be the only thing on screen that did not match
/// what was typed. [query] does that here rather than at each call site, so a
/// section cannot forget.
class SettingPreview extends StatelessWidget {
  const SettingPreview({
    super.key,
    required this.child,
    required this.caption,
    this.query = '',
  });

  final Widget child;

  /// One quiet line naming what is being shown. Not a title: the section
  /// already has one, and a heading over a picture that repeats the page name
  /// is a heading that earns nothing.
  final String caption;

  /// Already trimmed. Non-empty means a search is active and this renders
  /// nothing.
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) return const SizedBox.shrink();
    final c = ChromeScope.of(context).colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        children: [
          child,
          const SizedBox(height: 8),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A single framed phone at a readable size, centred.
///
/// [DevicePreview] fills whatever it is given, and a full-width phone on a
/// settings page is a phone drawn nearly life size. The pair in
/// [LayoutPreview] is constrained by being two across; a lone one needs saying.
class SinglePreview extends StatelessWidget {
  const SinglePreview({super.key, required this.child, this.width = 132});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) =>
      Center(child: SizedBox(width: width, child: child));
}

/// One option in a [PreviewChoice]: the picture, the word, and the value.
class PreviewOption<T> {
  const PreviewOption({
    required this.value,
    required this.label,
    required this.child,
  });

  final T value;
  final String label;

  /// The picture. Drawn at whatever width the row divides into, so it should be
  /// something that scales rather than something with a fixed size inside it.
  final Widget child;
}

/// A row of pictures where the picture IS the control.
///
/// ─── WHY THIS REPLACES A VALUE PLUS A SHEET ─────────────────────────────────
///
/// A row reading "Dock position   Left" with a chevron makes you open a sheet,
/// pick a word, close it, and look at the desktop to find out what the word
/// meant. Every step of that except the last is overhead, and the last one
/// happens on a different screen. The picture collapses it: you can see the
/// three answers at once and the tap that selects is the same tap that showed
/// you.
///
/// It is the pattern Android's own Display and Navigation bar screens use, and
/// they did not invent it either: a settings panel showing you the layouts
/// rather than naming them is how every desktop has done this for twenty years.
/// It suits this launcher better than most, because the thing being chosen is
/// almost always spatial.
///
/// ─── WHAT IT IS NOT FOR ─────────────────────────────────────────────────────
///
/// Numbers and continuous values. A column count is a stepper, an opacity is a
/// slider, and three tiles showing 4, 5 and 6 columns would be a worse stepper
/// with a lower ceiling. This is for a small closed set of shapes.
///
/// The radio under each label is not decoration. The accent border alone
/// carries the selection on a page whose accent is also the distro's accent and
/// therefore appears on half the other rows, and a border is the one selection
/// affordance that disappears entirely for anyone who cannot separate those two
/// colours.
class PreviewChoice<T> extends StatelessWidget {
  const PreviewChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onSelect,
    this.title,
    this.subtitle,
    this.enabled = true,
    this.following = false,
    this.onFollow,
  });

  /// The setting's name, above the pictures. Optional, because a chooser that
  /// is the only thing in its group already has the group heading and a second
  /// line would say it twice.
  final String? title;
  final String? subtitle;

  final List<PreviewOption<T>> options;
  final T value;
  final ValueChanged<T> onSelect;

  /// True when no preference is stored and [value] is the DISTRO's answer.
  ///
  /// ─── A CHOOSER WITH NO WAY BACK IS A TRAP ───────────────────────────────
  ///
  /// Dock position had four tiles and every one of them wrote a pref, so the
  /// first tap pinned the dock on EVERY distro forever. Mint authors
  /// `dock: "off"` and showed one anyway; so would Arch, EndeavourOS, Pop and
  /// Zorin, and nothing on the screen said why or offered a way out.
  ///
  /// `OpacityRow` has carried this pair since it shipped and the same two
  /// arguments do the same job here: a chip that says the value is inherited,
  /// and a tap that clears the pref and hands the row back to the theme.
  final bool following;

  /// Clears the pref. Null hides the chip, for a setting with no distro answer
  /// to fall back to.
  final VoidCallback? onFollow;

  /// False dims the tiles and stops them answering a tap.
  ///
  /// ─── THE SAME RULE SettingsToggleRow ALREADY STATES ───────────────────────
  ///
  /// Dimmed and inert, never absent. A choice that only applies under some
  /// other mode is shown greyed with the reason in [subtitle], because hiding
  /// it makes someone who has read about the feature conclude this build does
  /// not have it.
  ///
  /// The SELECTED tile keeps its accent ring while dimmed, deliberately. The
  /// row still has an answer, it is just not one you can change from here, and
  /// a disabled control that also loses its value looks broken rather than
  /// locked.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    // 0.4 is the alpha `SettingsToggleRow` dims its title by (settings_rows,
    // `enabled ? s.tx : s.mut.withValues(alpha: 0.4)`), so a greyed picture row
    // and a greyed switch row sit at the same weight in one list.
    final row = Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              // Opaque, so the gap under the label is part of the target.
              // The picture is the affordance but the whole column is the
              // tap, which is what makes this usable with a thumb.
              behavior: HitTestBehavior.opaque,
              // Null, not an ignored call. A GestureDetector with no callback
              // registers no recognizer at all, so a disabled row does not
              // quietly swallow a tap that the scroll underneath it could have
              // used.
              onTap: enabled ? () => onSelect(options[i].value) : null,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: options[i].value == value ? c.accent : c.line,
                        width: options[i].value == value ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: AspectRatio(
                          aspectRatio: 10 / 15,
                          child: options[i].child,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    options[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: options[i].value == value ? c.accent : c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    options[i].value == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: options[i].value == value ? c.accent : c.textFaint,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
      ),
    );

    if (title == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: TextStyle(color: c.text, fontSize: 14.5),
                ),
              ),
              // ── THE WAY BACK ──────────────────────────────────────────
              //
              // Beside the title rather than a fifth tile: it is not another
              // value, it is the absence of one, and putting it in the row of
              // pictures would make "no preference" look like a shape you can
              // choose. `OpacityRow` puts its chip in the same place.
              //
              // Drawn only when a pref IS set, so a row that is already
              // following says nothing. A chip that is present and inert on
              // most visits is a control people stop reading.
              if (onFollow != null && !following)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? onFollow : null,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      context.t('settings.follow'),
                      style: TextStyle(color: c.accent, fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(color: c.textMuted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 12),
          row,
        ],
      ),
    );
  }
}

/// Two pictures in one tile, split down the middle.
///
/// Exists for "Match the system", which is not a third appearance but the other
/// two taking turns. A tile showing one of them would be a lie half the time,
/// and a tile showing neither would be the only blank one in the row.
class SplitTile extends StatelessWidget {
  const SplitTile({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: FractionallySizedBox(widthFactor: 2, child: left),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 0.5,
                child: FractionallySizedBox(widthFactor: 2, child: right),
              ),
            ),
          ),
        ],
      );
}

/// How the drawer moves, as a picture.
///
/// Its own painter rather than a [DevicePreview] mode: the difference between a
/// list, a pager and a cube is MOTION, and none of the three is distinguishable
/// from a still grid of tiles. So each tile shows the artefact that gives the
/// style away instead: a list that runs off the bottom edge, a page with dots
/// under it, two faces meeting at an angle.
class ScrollStyleTile extends StatelessWidget {
  const ScrollStyleTile({
    super.key,
    required this.style,
    required this.palette,
  });

  /// 'vertical' | 'pages' | 'cube'.
  final String style;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final ink = palette.onDark;
    Widget tile() => DecoratedBox(
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(2),
          ),
        );
    Widget grid(int rows) => Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: 3),
                        Expanded(child: tile()),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bgTop, palette.bgBottom],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: switch (style) {
          // Runs past the bottom edge, which is the whole of what a list does
          // that a page does not.
          'vertical' => ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: 200,
                child: SizedBox(height: 120, child: grid(6)),
              ),
            ),
          'cube' => Row(
              children: [
                Expanded(
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.004)
                      ..rotateY(0.5),
                    child: grid(3),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.004)
                      ..rotateY(-0.5),
                    child: grid(3),
                  ),
                ),
              ],
            ),
          _ => Column(
              children: [
                Expanded(child: grid(3)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var d = 0; d < 3; d++) ...[
                      if (d > 0) const SizedBox(width: 4),
                      SizedBox(
                        width: 4,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d == 0
                                ? palette.accent
                                : ink.withValues(alpha: 0.34),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
        },
      ),
    );
  }
}

class LayoutPreview extends StatelessWidget {
  const LayoutPreview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.desktop,
              dock: theme.dock,
              gridButton: theme.prefs.dockGridButton ?? 'end',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.drawer,
              cols: theme.drawerCols,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chrome resolver
// ─────────────────────────────────────────────────────────────────────────────

/// The framing that forks on [ChromeFamily] — the STRUCTURE of a group card, as
/// opposed to its colours. Adwaita is libadwaita's boxed-list look (rounded,
/// inset, plain header); Breeze is flatter and squarer with an upper-case
/// category header, like KDE System Settings; generic/aqua sit in between. This
/// is where the family split becomes visible on the settings page.

/// A live panel, drawn with the settings currently being dragged.
class PanelPreview extends StatelessWidget {
  const PanelPreview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The stand-in wallpaper. Diagonal so the blur has edges running
              // through the panel rather than a flat field, which is the only
              // way a blur is visible at all.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.palette.bgTop,
                      theme.palette.accent,
                      theme.palette.bgBottom,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),

              // A REAL scope carrying the live values, so this panel resolves
              // exactly what a sheet will. Built here rather than inherited
              // because the settings screen's own chrome is the page's, and
              // the page is not what is being previewed.
              Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                child: ChromeScope(
                  data: ChromeData.fromPalette(
                    theme.palette,
                    typography: theme.typography,
                    textScale: theme.textScale,
                    family: theme.chromeFamily,
                    opacity: theme.panelOpacity,
                    panelBlur: theme.panelBlur,
                    panelTint: theme.panelTint,
                    panelRadius: theme.panelRadius,
                  ),
                  child: Builder(
                    builder: (inner) {
                      final p = ChromeScope.of(inner);
                      return GlassPanel(
                        // Top corners only, the shape a real sheet takes.
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(p.panelRadius),
                        ),
                        border: Border(
                          top: BorderSide(color: p.colors.lineStrong),
                        ),
                        child: SizedBox(
                          height: 86,
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 8),
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: p.colors.lineStrong,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Text(
                                    inner.t('settings.panels.previewTitle'),
                                    style: p.text.title,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Text(
                                    inner.t('settings.panels.previewSub'),
                                    style: p.text.caption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled slider for one panel setting.
///
/// Shaped like [OpacityRow] on purpose, since they sit in the same group and
/// two slider layouts a row apart is the sort of inconsistency nobody names and
/// everybody feels. It carries no Follow action because these three have no
/// parent slider to follow: the panel OPACITY does, and it uses the existing
/// row for exactly that reason.
class PanelSlider extends StatelessWidget {
  const PanelSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String sub;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

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
              Icon(icon, size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: d.text.body)),
              Text(
                format(value),
                style: d.text.value.copyWith(color: c.textMuted),
              ),
            ],
          ),
          ThemedSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child:
                Text(sub, style: d.text.caption.copyWith(color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}
