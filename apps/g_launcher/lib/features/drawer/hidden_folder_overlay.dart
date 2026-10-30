import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/hidden_apps.dart';
import '../../data/prefs/hidden_lock.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/search/search_text.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../settings/hide_apps_screen.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';

/// Open the Hidden folder, behind the hidden apps lock when it is on.
///
/// One successful prompt opens a [hiddenSessionProvider] session, so the app
/// launches and the Manage button inside do not ask a second time. The
/// overlay ends the session when it closes.
Future<void> openHiddenFolder(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  HiddenFolderItem item,
) async {
  final title = context.t('hidden.confirmOpen', {'name': item.label});
  if (!await confirmHiddenAccessFromWidget(ref, title: title)) return;
  if (!context.mounted) return;

  ref.read(hiddenSessionProvider.notifier).open();
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      // Non-opaque, like an ordinary drawer folder: it opens ON the drawer.
      opaque: false,
      barrierColor: null,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) =>
          _HiddenFolderOverlay(theme: theme, title: item.label),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// The unlocked folder: the hidden apps, launchable, with Unhide and
/// Uninstall on a long press.
///
/// Deliberately smaller than the ordinary folder overlay. No rename, no
/// drag in or out and no pin to the dock: a hidden app on the dock would be
/// un-hidden in all but name, and the set itself is edited on Hide apps.
class _HiddenFolderOverlay extends ConsumerStatefulWidget {
  const _HiddenFolderOverlay({required this.theme, required this.title});

  final EffectiveTheme theme;
  final String title;

  @override
  ConsumerState<_HiddenFolderOverlay> createState() =>
      _HiddenFolderOverlayState();
}

class _HiddenFolderOverlayState extends ConsumerState<_HiddenFolderOverlay> {
  late final HiddenSessionNotifier _session;
  late final AppLifecycleListener _lifecycle;

  /// Guards the pop: the lifecycle callback and the empty-folder check can
  /// both fire, and a second pop would take the drawer's route down too.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(hiddenSessionProvider.notifier);
    // Hidden covers Home, the recents screen, screen off and launching an
    // app from here. Each leaves the folder locked for whoever looks next.
    _lifecycle = AppLifecycleListener(onHide: _lock);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // After the frame, since provider state must not change mid-teardown.
    Future.microtask(_session.close);
    super.dispose();
  }

  /// Close this folder and anything opened from it (Hide apps via Manage).
  void _lock() {
    if (_closing || !mounted) return;
    _closing = true;
    _session.close();
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route != null) nav.popUntil((r) => r == route);
    nav.pop();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final hidden = ref.watch(globalPrefsProvider).asData?.value.hiddenApps ??
        const <String>{};
    final apps = [
      for (final a
          in ref.watch(appListProvider).asData?.value ?? const <AppEntry>[])
        if (hidden.contains(a.componentKey)) a,
    ]..sort(
        (a, b) => SearchText.fold(a.label).compareTo(SearchText.fold(b.label)),
      );

    // Everything unhidden from inside: nothing left to guard, so close.
    if (apps.isEmpty && ref.watch(appListProvider).hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }

    final chrome = ChromeData.fromPalette(
      theme.palette,
      typography: theme.typography,
      textScale: theme.textScale,
      family: theme.chromeFamily,
      opacity: theme.drawerOpacity,
    );
    final c = chrome.colors;

    return ChromeScope(
      data: chrome,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Tap off the panel to close, like any folder.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: ColoredBox(
                    color: theme.palette.bgBottom.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassPanel(
                    borderRadius: BorderRadius.circular(chrome.panelRadius + 6),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(context, chrome),
                          const SizedBox(height: 8),
                          Flexible(child: _grid(context, chrome, apps)),
                          const SizedBox(height: 12),
                          Text(
                            context.t('hidden.relocks'),
                            textAlign: TextAlign.center,
                            style: chrome.text.caption
                                .copyWith(color: c.textFaint),
                          ),
                        ],
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

  Widget _header(BuildContext context, ChromeData chrome) {
    final c = chrome.colors;
    return Row(
      children: [
        Icon(Icons.lock_open_outlined, size: 18, color: c.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: chrome.text.title,
          ),
        ),
        TextButton(
          onPressed: () => openHideApps(context, ref, widget.theme),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('hidden.manage'),
                style: chrome.text.body.copyWith(color: c.accent),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.accent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, ChromeData chrome, List<AppEntry> apps) {
    final theme = widget.theme;
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(right: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.74,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
      ),
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final entry = apps[i];
        return Builder(
          builder: (cell) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => launchDrawerApp(
              ref,
              entry,
              iconBounds: AnchoredMenu.anchorOf(cell),
            ),
            onLongPress: () => _menu(cell, chrome, entry),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(entry: entry, size: theme.iconSizeDp),
                const SizedBox(height: 6),
                Text(
                  entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      chrome.text.caption.copyWith(color: chrome.colors.text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _menu(BuildContext cell, ChromeData chrome, AppEntry entry) {
    HapticFeedback.mediumImpact();
    final apps = ref.read(appListProvider.notifier);
    final prefs = ref.read(prefsProvider(widget.theme.spec.id).notifier);
    final host = context;

    return AnchoredMenu.show(
      context: cell,
      chrome: chrome,
      anchor: AnchoredMenu.anchorOf(cell),
      width: 236,
      title: entry.label,
      leading: AppIcon(entry: entry, size: 30),
      onInfo: () => apps.openInfo(entry),
      showActionLabels: widget.theme.menuActionLabels,
      actions: [
        MenuAction(
          icon: Icons.visibility_outlined,
          label: host.t('settings.unhide'),
          onTap: () {
            prefs.edit((p) => HiddenApps.unhide(p, entry.componentKey));
            if (host.mounted) {
              host.showMessage(
                host.t('hidden.unhidden', {'name': entry.label}),
              );
            }
          },
        ),
        MenuAction(
          icon: Icons.delete_outline,
          label: host.t('drawer.uninstall'),
          danger: true,
          onTap: () async {
            final status = await apps.uninstall(entry);
            if (UninstallStatus.succeeded(status) || !host.mounted) return;
            host.showMessage(host.t(uninstallRefusalKey(status)));
          },
        ),
      ],
      rows: (_) => const [],
    );
  }
}
