/// Quick Settings: the things this launcher actually owns, under your thumb.
///
/// ─── WHY THIS IS NOT A COPY OF ANDROID'S TRAY ───────────────────────────────
///
/// The obvious build is six pill toggles: Wi-Fi, Bluetooth, torch, dark mode,
/// rotate, night light. Most of them cannot be built, and shipping them anyway
/// would be a panel where half the controls accept a tap and change nothing.
///
///   * `WifiManager.setWifiEnabled` has been refused to third-party apps since
///     Android 10. A launcher can OPEN the Wi-Fi panel; it cannot flip it.
///   * Night light has no public API at all.
///   * Rotate and brightness both need `WRITE_SETTINGS`, a special-access grant
///     the user has to go and find, and a toggle that silently does nothing
///     until they do is worse than no toggle.
///   * System dark mode is not ours either. We can move the LAUNCHER's
///     brightness, which is a different thing wearing the same word.
///
/// So this panel carries what the launcher genuinely owns, and that turns out
/// to be the interesting half: light and dark, the accent, and the way to
/// Appearance. Android's own tray cannot offer any of those, so this stops
/// being a worse copy of the system panel and becomes the only place these live
/// without going three taps into Settings.
///
/// Torch and volume are honestly buildable and are NOT here yet, because both
/// need a new Pigeon call and the codec's field ordering is load-bearing. They
/// are the first thing to add, not a thing this panel is missing on principle.
///
/// ─── AND WHY IT RISES FROM THE PANEL ────────────────────────────────────────
///
/// Android's shade comes down from the notch, which on a 800dp screen is the
/// part of the glass a thumb reaches worst. This one comes up off the tray
/// cluster it was opened from, so the controls land in the same arc as the
/// finger that asked for them. It is the one place this launcher can beat the
/// system panel on ergonomics rather than on features.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/layout_preset.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart';
import '../panel/applets/clock_panel_sections.dart';
import '../panel/modules/panel_readouts.dart';
import '../panel/panel_edit.dart';
import '../panel/panel_modules.dart' show panelIsNarrow;
import 'workspaces/workspace_controller.dart';

/// Is the Quick Settings panel open?
final quickSettingsProvider =
    NotifierProvider<QuickSettingsOpen, bool>(QuickSettingsOpen.new);

class QuickSettingsOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void open() {
    if (!state) state = true;
  }

  void close() {
    if (state) state = false;
  }

  void toggle() => state ? close() : open();
}

/// The panel. Mounted above the shell, drawing nothing while closed.
class QuickSettingsPanel extends ConsumerWidget {
  const QuickSettingsPanel({super.key, required this.theme});

  final EffectiveTheme theme;

  /// Clear of the panel it rises from, and of the gesture pill under that.
  static const _gap = 12.0;

  /// The side panel's widest, so a tablet gets a panel and not half a screen.
  static const _sideWidth = 360.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(quickSettingsProvider)) return const SizedBox.shrink();

    final palette = theme.palette;
    final panelHeight = theme.panelHeight ?? 56;

    return Material(
      // theme-exempt: the sheet paints the palette itself a layer down.
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(quickSettingsProvider.notifier).close(),
              child: ColoredBox(
                // Light, so the desktop stays visible. A heavy scrim would
                // hide the very thing the accent swatches are being judged
                // against.
                color: palette.bgBottom.withValues(alpha: 0.45),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // ─── DEEPIN'S CONTROL CENTER SHAPE ─────────────────────────────
          //
          // `quickSettings: "side"` opens the same sheet as a tall panel
          // against the right edge, sliding in from it, the way Deepin's
          // Control Center does. Every other distro keeps the bottom sheet.
          if (theme.quickSettingsSide)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              right: 0,
              width: (MediaQuery.sizeOf(context).width * 0.86)
                  .clamp(0.0, _sideWidth),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => FractionalTranslation(
                  translation: Offset(t, 0),
                  child: child,
                ),
                child: _Sheet(theme: theme, side: true),
              ),
            )
          else
            Positioned(
              left: 8,
              right: 8,
              bottom:
                  panelHeight + _gap + MediaQuery.paddingOf(context).bottom,
              child: _Sheet(theme: theme),
            ),
        ],
      ),
    );
  }
}

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.theme, this.side = false});

  final EffectiveTheme theme;

  /// Drawn as the right-edge panel: square on the screen's side, full height.
  final bool side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final accents = theme.spec.accents;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.bar.withValues(alpha: 0.98),
        borderRadius: side
            ? const BorderRadius.horizontal(left: Radius.circular(20))
            : BorderRadius.circular(20),
        border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
      ),
      // Scrolls past 70% of the screen: with a player, G VPN and a few apps'
      // counts the sheet can outgrow a 800dp phone above its panel.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: side
              ? double.infinity
              : MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.onDark.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ─── WHAT AN UPRIGHT PANEL LEFT OUT ────────────────────────
              //
              // On a phone held upright the panel drops its readouts (see
              // `panelItemsShown`), so they open the sheet instead. Only the
              // ones this distro put on its panel: nothing appears here that
              // the desktop did not already offer.
              if (panelIsNarrow(context)) ...[
                _Workspaces(theme: theme),
                _Readouts(theme: theme),
              ],
              // ─── THE DESKTOP, FIRST ─────────────────────────────────────
              //
              // Xfce, GNOME, KDE on Kali; Zorin's layouts on Zorin. The same
              // switch Appearance offers, one tap from the panel instead of
              // three screens deep, and above light and dark because it is the
              // bigger change.
              if (theme.spec.layouts.length > 1) ...[
                _Layouts(theme: theme),
                const SizedBox(height: 12),
              ],
              _Mode(theme: theme),
              const SizedBox(height: 12),
              _StatusIcons(theme: theme),
              // ─── ONLY WHEN THE DISTRO SHIPS A SET ───────────────────────────
              //
              // Same rule the Appearance row follows: an empty `accents` means this
              // distro has one accent, and a one-swatch picker is a control whose
              // only use is to reselect what is already selected.
              if (accents.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Accents(theme: theme, accents: accents),
              ],
              // ─── NOW PLAYING, G VPN, NOTIFICATIONS ──────────────────────────
              //
              // GNOME and Aqua have no clock on a top bar (Android's own is right
              // above it), so this panel is where those distros get what the
              // panel shells' clock opens. Same widget, same rules.
              const SizedBox(height: 12),
              ClockPanelSections(
                style: ClockPanelStyle(
                  text: palette.onDark,
                  muted: palette.onDark.withValues(alpha: 0.6),
                  accent: palette.accent,
                  surface: palette.onDark.withValues(alpha: 0.07),
                  fontFamily: theme.typography.display,
                ),
                onLeave: () => ref.read(quickSettingsProvider.notifier).close(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The distro's desktop layouts, as one segmented row.
///
/// Same look as [_Mode] beneath it, and the same write Appearance makes: see
/// [applyLayoutPreset] for why a switch clears the overrides the preset owns.
/// Up to three share the row evenly, which fits "KDE Plasma" at 360dp; a
/// distro with more scrolls the row rather than squeezing the names.
class _Layouts extends ConsumerWidget {
  const _Layouts({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final layouts = theme.spec.layouts;
    // Stored id, else the distro's default card, else the first: the same
    // answer Appearance rings, so the two never disagree about what is on.
    final current = theme.prefs.layoutPreset ??
        layouts.firstWhere((l) => l.isDefault, orElse: () => layouts.first).id;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    Widget seg(ThemeLayoutPreset l) {
      final on = l.id == current;
      return Semantics(
        button: true,
        selected: on,
        label: l.name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  notifier.edit((p) => applyLayoutPreset(p, l.id));
                },
          child: Container(
            height: 40,
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? palette.accent : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.name,
              maxLines: 1,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13 * theme.textScale,
                color: on
                    ? palette.bgBottom
                    : palette.onDark.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      );
    }

    final row = layouts.length <= 3
        ? Row(children: [for (final l in layouts) Expanded(child: seg(l))])
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final l in layouts) seg(l)]),
          );

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.onDark.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: row,
    );
  }
}

/// The panel's workspace switcher, when an upright phone left it off the bar.
///
/// One numbered button per workspace, the current one filled. Tapping one
/// goes there and closes the sheet, since the point was to see that desktop.
class _Workspaces extends ConsumerWidget {
  const _Workspaces({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (theme.panels.isEmpty) return const SizedBox.shrink();
    final authored =
        currentPanelItems(theme).any((i) => i.kind == PanelModule.pager);
    final count = ref.watch(workspaceCountProvider);
    if (!authored || count < 2) return const SizedBox.shrink();
    final active = ref.watch(activeWorkspaceProvider);
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.onDark.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == active,
                  label: context.t('home.workspaceN', {'n': '${i + 1}'}),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(activeWorkspaceProvider.notifier).goTo(i);
                      ref.read(quickSettingsProvider.notifier).close();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == active ? palette.accent : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: theme.typography.mono,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: i == active
                              ? palette.bgBottom
                              : palette.onDark.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The panel's readouts, when an upright phone left them off the bar.
class _Readouts extends StatelessWidget {
  const _Readouts({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    if (theme.panels.isEmpty) return const SizedBox.shrink();
    final show = [
      for (final i in currentPanelItems(theme))
        if (isStatModule(i.kind)) i.kind,
    ];
    if (show.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.palette.onDark.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: PanelReadouts(
          palette: theme.palette,
          fontFamily: theme.typography.display,
          stacked: false,
          show: show,
        ),
      ),
    );
  }
}

/// Who owns the status row: Android's bar, or this distro's panel.
///
/// The same pref the Desktop settings row writes, here because most people
/// will never find that row, and this sheet is where they already are when the
/// panel's clock or battery is the question. With no panel on screen it is the
/// plain status bar switch, as in settings.
class _StatusIcons extends ConsumerWidget {
  const _StatusIcons({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    // A dock with its own tray owns the status row the same way a panel
    // does (Deepin), so it gets the same switch, worded for the dock.
    final hasPanel = theme.panels.isNotEmpty || theme.dockTray;
    final value = hasPanel ? !theme.statusBar : theme.statusBar;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    void set(bool v) {
      HapticFeedback.selectionClick();
      notifier.edit((p) => p.copyWith(statusBar: hasPanel ? !v : v));
    }

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => set(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: palette.onDark.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                hasPanel ? Icons.signal_wifi_4_bar : Icons.smartphone_outlined,
                size: 20,
                color: palette.onDark.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t(!hasPanel
                          ? 'settings.statusBar'
                          : theme.panels.isEmpty
                              ? 'settings.dockStatusIcons'
                              : 'settings.panelStatusIcons'),
                      style: TextStyle(
                        fontFamily: theme.typography.display,
                        fontSize: 14 * theme.textScale,
                        color: palette.onDark,
                      ),
                    ),
                    if (hasPanel)
                      Text(
                        context.t('settings.panelStatusIconsSub'),
                        style: TextStyle(
                          fontFamily: theme.typography.display,
                          fontSize: 12 * theme.textScale,
                          color: palette.onDark.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: set,
                activeTrackColor: palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light, dark, auto.
///
/// Disabled whole on a distro with no `paletteLight`, rather than accepting the
/// tap and doing nothing. `appearance_section` makes this argument at length:
/// an explanation under a control that still works is worse than no
/// explanation, because the control is the thing people believe.
class _Mode extends ConsumerWidget {
  const _Mode({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final hasLight = theme.spec.paletteLight != null;
    final mode = theme.prefs.themeMode ?? 'system';
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    Widget seg(String value, String label) {
      final on = value == mode;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasLight
              ? () {
                  HapticFeedback.selectionClick();
                  notifier.edit((p) => p.copyWith(themeMode: value));
                }
              : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? palette.accent : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13 * theme.textScale,
                color: on
                    ? palette.bgBottom
                    : palette.onDark.withValues(alpha: hasLight ? 0.8 : 0.3),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.onDark.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          seg('light', 'Light'),
          seg('dark', 'Dark'),
          seg('system', 'Auto'),
        ],
      ),
    );
  }
}

/// The distro's accents, as a row of swatches.
///
/// Tapping the selected one clears back to the distro's own, the same contract
/// the Appearance row has. Two controls writing the same pref must not disagree
/// about what a second tap means.
class _Accents extends ConsumerWidget {
  const _Accents({required this.theme, required this.accents});

  final EffectiveTheme theme;
  final List<ThemeAccent> accents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final chosen = theme.prefs.accentId;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    // ─── A GRID, NOT ONE ROW ───────────────────────────────────────────
    //
    // A Row of 44dp swatches fits six across a 360dp phone. Mint ships ten
    // and overflowed by 106dp. As many fit per row as the sheet allows, with
    // the gap stretched so every row lines up on the same columns, and the
    // rest wrap beneath instead of spreading across a half-empty last row.
    return LayoutBuilder(builder: (context, box) {
      const swatch = 44.0;
      const minGap = 8.0;
      final perRow =
          ((box.maxWidth + minGap) / (swatch + minGap)).floor().clamp(1, 99);
      final gap =
          perRow > 1 ? (box.maxWidth - perRow * swatch) / (perRow - 1) : minGap;
      return Wrap(
        spacing: gap,
        runSpacing: minGap,
        children: [
          for (final a in accents)
            Semantics(
              button: true,
              selected: a.id == chosen,
              label: a.name,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.edit(
                    (p) => a.id == chosen
                        ? p.clearing(accentId: true)
                        : p.copyWith(accentId: a.id),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: a.id == chosen
                          ? palette.onDark
                          : palette.onDark.withValues(alpha: 0.18),
                      width: a.id == chosen ? 2.5 : 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
