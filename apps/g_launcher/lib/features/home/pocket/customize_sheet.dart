/// Customize: the iOS 26 Home Screen's look picker, for a theme with looks.
///
/// Hold the empty home and choose how every icon is drawn: Default, Dark,
/// Clear or Tinted, and for Clear, light or dark glass. Each look is a full
/// icon style the theme authored (`ThemeSpec.iconLooks`), so choosing one is a
/// single pref write and the icon cache re-keys from the style itself.
///
/// Tinted takes the theme's accent, and the accent picker already lives in
/// quick settings, so this sheet does not grow a second one.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../design/liquid_glass.dart';
import '../../../engine/effective_theme.dart';

Future<void> showCustomizeSheet(
  BuildContext context,
  EffectiveTheme theme,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    barrierDismissible: true,
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (routeContext, _, __) => Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _CustomizeSheet(themeId: theme.spec.id),
      ),
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet({required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, so the sheet shows the look it just applied rather than the
    // one it was opened with.
    final theme = ref.watch(effectiveThemeProvider).asData?.value;
    if (theme == null) return const SizedBox.shrink();

    final looks = theme.spec.iconLooks;
    final current =
        theme.prefs.iconLook ?? (looks.isEmpty ? null : looks.first.id);
    final ink = theme.palette.onDark;
    final notifier = ref.read(prefsProvider(themeId).notifier);

    Widget chip(String id, String label) {
      final on = id == current;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            notifier.edit((p) => p.copyWith(iconLook: id));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: on ? theme.palette.accent : ink.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13 * theme.textScale,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                color: on ? Colors.white : ink,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LiquidGlass(
          radius: BorderRadius.circular(28),
          dark: theme.glassDark,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('home.customize'),
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 16 * theme.textScale,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              // Two rows of at most four, so five or six looks still fit a
              // 360dp phone with whole words in every chip.
              for (var start = 0; start < looks.length; start += 4) ...[
                if (start > 0) const SizedBox(height: 6),
                Row(
                  children: [
                    for (final l in looks.skip(start).take(4))
                      chip(l.id, l.name),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
