import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/hidden_apps.dart';
import '../../data/prefs/hidden_folder.dart';
import '../../data/prefs/hidden_lock.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/search/search_text.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/app_icon.dart';

/// Open Hide apps, behind the hidden apps lock when it is on.
///
/// The ONE way in. Settings and the search page's overflow both call this, so
/// there is no route to the page that skips the fingerprint.
Future<void> openHideApps(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
) async {
  final ok = await confirmHiddenAccessFromWidget(
    ref,
    title: context.t('hidden.confirmManage'),
  );
  if (!ok || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => HideAppsScreen(theme: theme)),
  );
}

/// Hide apps, One UI style: every app in one grid, tap to hide or unhide.
///
/// Hidden apps sit on top with filled checks, everyone else below with empty
/// rings, and each tap saves at once. The set is launcher-wide (GlobalPrefs
/// schema 3), so what is hidden here is hidden on every distro.
///
/// The lock and find-by-name switches live in a sheet behind the tune button
/// rather than under the grid: a list page's settings get their own surface,
/// and below a 130-app grid they would be unreachable.
class HideAppsScreen extends ConsumerStatefulWidget {
  const HideAppsScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<HideAppsScreen> createState() => _HideAppsScreenState();
}

class _HideAppsScreenState extends ConsumerState<HideAppsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live theme, so each tap moves the app between sections under the finger.
    final async = ref.watch(effectiveThemeProvider);
    final theme = async.hasValue ? async.requireValue : widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final hiddenKeys = theme.prefs.hiddenApps;

    // RAW list: shellApps has the hidden ones filtered out, and they are
    // exactly what this page has to show.
    final all = [
      ...ref.watch(appListProvider).asData?.value ?? const <AppEntry>[],
    ]..sort(
        (a, b) => SearchText.fold(a.label).compareTo(SearchText.fold(b.label)));

    final shown = _query.isEmpty
        ? all
        : [
            for (final a in all)
              if (SearchText.contains(a.label, _query)) a,
          ];
    final hidden = [
      for (final a in shown)
        if (hiddenKeys.contains(a.componentKey)) a,
    ];
    final visible = [
      for (final a in shown)
        if (!hiddenKeys.contains(a.componentKey)) a,
    ];

    void toggle(AppEntry a) {
      HapticFeedback.selectionClick();
      notifier.edit(
        (p) => hiddenKeys.contains(a.componentKey)
            ? HiddenApps.unhide(p, a.componentKey)
            : HiddenApps.hide(p, a.componentKey),
      );
    }

    // ChromeScope is provided BY ThemedScaffold, so anything that reads it
    // has to be built below it: hence the two Builders.
    return ThemedScaffold(
      title: context.t('hidden.title'),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.tune, color: ChromeScope.of(ctx).colors.textMuted),
            tooltip: ctx.t('hidden.options'),
            onPressed: () => _options(ctx, theme),
          ),
        ),
      ],
      body: Builder(
        builder: (context) {
          final d = ChromeScope.of(context);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _searchField(d)),
              if (hidden.isNotEmpty) ...[
                _header(
                  d,
                  context.t('hidden.sectionHidden'),
                  trailing: '${hiddenKeys.length}',
                ),
                _grid(hidden, hiddenKeys, toggle),
              ],
              _header(d, context.t('hidden.sectionAll')),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Text(
                      _query.isEmpty
                          ? context.t('hidden.everythingHidden')
                          : context
                              .t('search.nothingMatches', {'query': _query}),
                      style: d.text.caption,
                    ),
                  ),
                )
              else
                _grid(visible, hiddenKeys, toggle),
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomInset + 16),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(ChromeData d) {
    final c = d.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: c.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: d.text.body,
                decoration: InputDecoration(
                  hintText: context.t('drawer.search'),
                  hintStyle: d.text.body.copyWith(color: c.textFaint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: c.textMuted),
                tooltip: context.t('hidden.clearSearch'),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(ChromeData d, String title, {String? trailing}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(child: Text(title, style: d.text.title)),
            if (trailing != null) Text(trailing, style: d.text.caption),
          ],
        ),
      ),
    );
  }

  /// Lazily built, the drawer's perf rule: a phone has 130+ apps.
  Widget _grid(
    List<AppEntry> apps,
    Set<String> hiddenKeys,
    void Function(AppEntry) onToggle,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.70,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
        ),
        itemCount: apps.length,
        itemBuilder: (context, i) {
          final a = apps[i];
          return _HideCell(
            entry: a,
            iconSize: widget.theme.iconSizeDp,
            hidden: hiddenKeys.contains(a.componentKey),
            onTap: () => onToggle(a),
          );
        },
      ),
    );
  }

  void _options(BuildContext context, EffectiveTheme theme) {
    final host = context;
    ThemedSheet.show<void>(
      context,
      title: context.t('hidden.options'),
      builder: (sheet) => Consumer(
        builder: (ctx, r, _) {
          final live = r.watch(effectiveThemeProvider);
          final t = live.hasValue ? live.requireValue : theme;
          final notifier = r.read(prefsProvider(t.spec.id).notifier);
          final locked = r.watch(hiddenLockProvider).asData?.value ?? false;
          final availability =
              r.watch(userAuthAvailabilityProvider).asData?.value;
          final canLock = availability == UserAuthStatus.ready;
          final folder = r.watch(hiddenFolderProvider).asData?.value ??
              const HiddenFolderSettings();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedListRow(
                icon: Icons.fingerprint,
                title: ctx.t('hidden.lock'),
                subtitle: canLock || locked
                    ? ctx.t('hidden.lockSub')
                    : ctx.t('hidden.lockUnavailable'),
                trailing: ThemedToggle(
                  value: locked,
                  // Off is always allowed (this page is already behind the
                  // lock). On needs a phone that can answer the prompt.
                  onChanged:
                      locked || canLock ? (v) => _setLock(host, r, v) : null,
                ),
              ),
              ThemedListRow(
                icon: Icons.manage_search,
                title: ctx.t('settings.findHiddenAppsBy'),
                subtitle: ctx.t('hidden.findSub'),
                trailing: ThemedToggle(
                  value: HiddenApps.searchable(t.prefs),
                  onChanged: (v) => notifier.edit(
                    (p) => p.copyWith(hiddenAppsSearchable: v),
                  ),
                ),
              ),
              ThemedListRow(
                icon: Icons.folder_special_outlined,
                title: ctx.t('hidden.folder'),
                // Without the lock the folder opens for anyone, so say so
                // rather than let it look like protection.
                subtitle: locked
                    ? ctx.t('hidden.folderSub')
                    : ctx.t('hidden.folderSubNoLock'),
                trailing: ThemedToggle(
                  value: folder.enabled,
                  onChanged: (v) =>
                      r.read(hiddenFolderProvider.notifier).setEnabled(v),
                ),
              ),
              if (folder.enabled)
                ThemedListRow(
                  icon: Icons.drive_file_rename_outline,
                  title: ctx.t('hidden.folderRename'),
                  subtitle: folder.name ?? ctx.t('hidden.folderName'),
                  onTap: () => _renameFolder(ctx, r, folder),
                ),
              if (t.prefs.hiddenApps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: ThemedButton(
                    label: ctx.t('settings.unhideAll'),
                    kind: ThemedButtonKind.text,
                    expand: true,
                    onPressed: () {
                      Navigator.pop(sheet);
                      notifier.edit(HiddenApps.unhideAll);
                    },
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  /// Rename the Hidden folder tile. An empty name goes back to the default.
  Future<void> _renameFolder(
    BuildContext context,
    WidgetRef r,
    HiddenFolderSettings folder,
  ) async {
    final controller = TextEditingController(text: folder.name ?? '');
    final d = ChromeScope.of(context);
    final name = await ThemedDialog.show<String>(
      context,
      title: context.t('hidden.folderRename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: HiddenFolderSettings.maxNameLength,
        style: d.text.body,
        cursorColor: d.colors.accent,
        decoration: InputDecoration(
          hintText: context.t('hidden.folderName'),
          hintStyle: d.text.body.copyWith(color: d.colors.textFaint),
          counterStyle: d.text.caption,
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actionsBuilder: (dialog) => [
        ThemedButton(
          label: dialog.t('common.cancel'),
          kind: ThemedButtonKind.text,
          onPressed: () => Navigator.of(dialog).pop(),
        ),
        ThemedButton(
          label: dialog.t('common.save'),
          onPressed: () => Navigator.of(dialog).pop(controller.text),
        ),
      ],
    );
    controller.dispose();
    if (name == null) return;
    await r.read(hiddenFolderProvider.notifier).setName(name);
  }

  /// Turning the lock ON proves the prompt works first, so nobody switches on
  /// a lock their phone then refuses to open.
  Future<void> _setLock(BuildContext host, WidgetRef r, bool on) async {
    final lock = r.read(hiddenLockProvider.notifier);
    if (!on) {
      await lock.set(false);
      return;
    }
    String status;
    try {
      status = await r
          .read(launcherHostApiProvider)
          .confirmUser(host.t('hidden.confirmEnable'), null);
    } catch (_) {
      status = UserAuthStatus.unsupported;
    }
    if (status == UserAuthStatus.ok) {
      await lock.set(true);
      if (host.mounted) host.showMessage(host.t('hidden.lockOn'));
    } else if (status == UserAuthStatus.lockout && host.mounted) {
      host.showMessage(host.t('hidden.lockout'));
    }
  }
}

/// One app: icon, two-line label, and the check ring in the corner.
class _HideCell extends StatelessWidget {
  const _HideCell({
    required this.entry,
    required this.iconSize,
    required this.hidden,
    required this.onTap,
  });

  final AppEntry entry;
  final double iconSize;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Semantics(
      checked: hidden,
      button: true,
      label: entry.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(entry: entry, size: iconSize),
                Positioned(
                  top: -4,
                  right: -4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hidden ? c.accent : c.bg.withValues(alpha: 0.7),
                      border: Border.all(
                        color: hidden ? c.accent : c.textMuted,
                        width: 1.5,
                      ),
                    ),
                    child: hidden
                        ? Icon(Icons.check, size: 13, color: c.onAccent)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
