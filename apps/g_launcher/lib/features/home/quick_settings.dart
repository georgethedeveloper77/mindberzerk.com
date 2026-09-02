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

import '../../data/prefs/prefs_repository.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart';

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
          Positioned(
            left: 8,
            right: 8,
            bottom: panelHeight + _gap + MediaQuery.paddingOf(context).bottom,
            child: _Sheet(theme: theme),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final accents = theme.spec.accents;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.bar.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.onDark.withValues(alpha: 0.16)),
      ),
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
          _Mode(theme: theme),
          // ─── ONLY WHEN THE DISTRO SHIPS A SET ───────────────────────────
          //
          // Same rule the Appearance row follows: an empty `accents` means this
          // distro has one accent, and a one-swatch picker is a control whose
          // only use is to reselect what is already selected.
          if (accents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Accents(theme: theme, accents: accents),
          ],
        ],
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  }
}
