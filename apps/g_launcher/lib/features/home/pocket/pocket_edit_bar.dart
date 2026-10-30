import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/liquid_glass.dart';
import '../../../engine/effective_theme.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_picker.dart';
import '../../settings/settings_screen.dart';
import '../../settings/wallpaper_screen.dart';
import '../workspaces/workspace_controller.dart';
import 'customize_sheet.dart';

/// A phone home's edit mode chrome: Edit at the top left, Done at the top
/// right, both on glass, over a home that is NOT dimmed.
///
/// ─── WHY NOT THE DESKTOP MENU ───────────────────────────────────────────────
///
/// The desktop menu is a bottom bar over a 38% black scrim, which is right
/// for a desktop and reads as the screen clouding over on a glass phone home.
/// A phone enters edit mode on the hold itself: the icons jiggle and these two
/// buttons are everything else. Edit opens the few things the bar used to:
/// Add Widget, Customize, Wallpaper, Settings.
class PocketEditBar extends ConsumerWidget {
  const PocketEditBar({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.viewPaddingOf(context).top;
    return Stack(
      children: [
        Positioned(
          top: top,
          left: 14,
          child: Builder(
            builder: (pill) => _GlassPill(
              theme: theme,
              label: context.t('home.edit'),
              onTap: () => _showEditMenu(pill, ref),
            ),
          ),
        ),
        Positioned(
          top: top,
          right: 14,
          child: _GlassPill(
            theme: theme,
            label: context.t('common.done'),
            onTap: () => ref.read(deskletEditProvider.notifier).exit(),
          ),
        ),
      ],
    );
  }

  /// The glass list under the Edit pill. No scrim: the home stays bright, and
  /// a tap anywhere outside closes it.
  Future<void> _showEditMenu(BuildContext pill, WidgetRef ref) {
    final navigator = Navigator.of(pill);
    final box = pill.findRenderObject() as RenderBox?;
    final below = box == null
        ? const Offset(14, 100)
        : box.localToGlobal(Offset(0, box.size.height + 8));

    void open(Widget screen) {
      ref.read(deskletEditProvider.notifier).exit();
      navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return showGeneralDialog<void>(
      context: pill,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: pill.t('common.back'),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (menu, _, __) {
        void close() => Navigator.pop(menu);
        final rows = <(String, IconData, VoidCallback)>[
          (
            menu.t('desklets.addWidget'),
            Icons.add,
            () {
              close();
              showDeskletPicker(
                pill,
                ref,
                theme,
                page: ref.read(activeWorkspaceProvider),
              );
            },
          ),
          if (theme.spec.iconLooks.isNotEmpty)
            (
              menu.t('home.customize'),
              Icons.auto_awesome_outlined,
              () {
                close();
                ref.read(deskletEditProvider.notifier).exit();
                showCustomizeSheet(pill, theme);
              },
            ),
          (
            menu.t('settings.wallpaper'),
            Icons.image_outlined,
            () {
              close();
              open(WallpaperScreen(theme: theme));
            },
          ),
          (
            menu.t('settings.settings'),
            Icons.settings_outlined,
            () {
              close();
              open(SettingsScreen(theme: theme));
            },
          ),
        ];
        return Stack(
          children: [
            Positioned(
              left: below.dx,
              top: below.dy,
              width: 220,
              child: _GlassPanel(
                theme: theme,
                children: [
                  for (final (label, icon, onTap) in rows)
                    _MenuRow(
                      theme: theme,
                      label: label,
                      icon: icon,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap();
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          alignment: Alignment.topLeft,
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // 7dp of invisible margin above and below: a 48dp touch target
        // around a 34dp pill.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34, minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LiquidGlass.fill(dark: theme.glassDark),
                border: Border.all(color: LiquidGlass.edge),
                borderRadius: radius,
              ),
              foregroundDecoration: LiquidGlass.rim(radius),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.spec.palette.onDark,
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.theme, required this.children});

  final EffectiveTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LiquidGlass.fill(dark: theme.glassDark),
              border: Border.all(color: LiquidGlass.edge),
              borderRadius: radius,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.theme,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.spec.palette.onDark;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    fontSize: 15,
                    color: onDark,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: onDark),
            ],
          ),
        ),
      ),
    );
  }
}
