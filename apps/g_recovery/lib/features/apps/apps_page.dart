import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/apps_api.g.dart';
import '../../bridge/apps_bridge.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_enter.dart';
import '../../ui/g_sheet.dart';

/// WHAT EACH APP IS TAKING.
///
/// ─── IT DOES NOT CLEAR ANYTHING, AND SAYS SO ─────────────────────────────────
///
/// No app on Play can clear another app's cache; the API has been system only
/// since Android 6. Anything advertising it is driving the screen through an
/// accessibility service or inventing a number.
///
/// So this screen shows the real figure and opens the one place the button
/// works. That is less satisfying than a Clean All button and it is the only
/// version that is true.
class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const AppsPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AppsState? state = ref.watch(appsStateProvider).value;
    final AppSort sort = ref.watch(appSortProvider);
    final List<AppEntry> apps = ref.watch(sortedAppsProvider);

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: 'Apps',
                subtitle: state == null || !state.usageAccess
                    ? null
                    : '${GFormat.count(state.count)} apps  ·  '
                          '${GFormat.bytes(state.totalBytes)}',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  GIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _explain(context),
                  ),
                ],
              ),
            ),

            if (state != null && !state.usageAccess)
              Expanded(
                child: _NeedsAccess(
                  onGrant: () async {
                    await ref.read(appsBridgeProvider).requestUsageAccess();
                    ref.invalidate(appsStateProvider);
                    ref.invalidate(appsProvider);
                  },
                ),
              )
            else if (apps.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Reading app sizes',
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ),
              )
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Fact(
                        value: GFormat.bytes(state!.cacheBytes),
                        label: 'cache, rebuildable',
                        tone: t.audio,
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        value: GFormat.bytes(
                          state.totalBytes - state.cacheBytes,
                        ),
                        label: 'apps and their data',
                        tone: t.text,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md - 2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SortPill(current: sort),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    GSpace.gutter,
                    0,
                    GSpace.gutter,
                    GSpace.xl,
                  ),
                  itemCount: apps.length,
                  itemBuilder: (BuildContext context, int index) => GEnter(
                    index: index,
                    child: _Row(
                      entry: apps[index],
                      onTap: () async {
                        await ref
                            .read(appsBridgeProvider)
                            .openAppSettings(apps[index].packageName);
                        ref.invalidate(appsStateProvider);
                        ref.invalidate(appsProvider);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _explain(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: 'Clearing app caches',
      children: <Widget>[
        Text(
          'Android has not let one app clear another app\u0027s cache since '
          '2015. Anything claiming to do it is either driving your screen '
          'through an accessibility service, or reporting a number it made up.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('What this screen does'),
        GSheetPoint(
          icon: Icons.open_in_new_rounded,
          tone: t.docs,
          text:
              'Shows the real size and opens that app\u0027s own storage '
              'screen, where Clear cache is one tap and actually works.',
        ),
        const GSheetHeading('Cache and data are different'),
        GSheetPoint(
          icon: Icons.refresh_rounded,
          tone: t.docs,
          text:
              'Cache is rebuildable. Clearing it costs nothing but a slower '
              'next launch.',
        ),
        GSheetPoint(
          text:
              'Data is the app\u0027s actual content: your accounts, '
              'messages and downloads. Clearing it signs you out and deletes '
              'what was there.',
        ),
      ],
    );
  }
}

class _NeedsAccess extends StatelessWidget {
  const _NeedsAccess({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.query_stats_rounded, size: 42, color: t.dim),
            const SizedBox(height: GSpace.lg),
            Text(
              'Android keeps app sizes behind a switch',
              textAlign: TextAlign.center,
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              // Names what is really being granted. "Usage access" sounds like
              // browsing history, and a person who thinks that is what they are
              // handing over should be told otherwise.
              'Usage access lets this app read how much space each app takes. '
              'It reads sizes, not what you do in them.',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.lg),
            GButton(
              label: 'Open the setting',
              icon: Icons.open_in_new_rounded,
              expand: false,
              onPressed: onGrant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortPill extends ConsumerWidget {
  const _SortPill({required this.current});

  final AppSort current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    return Material(
      color: t.panelAlt,
      borderRadius: GRadius.all(GRadius.chip),
      child: InkWell(
        borderRadius: GRadius.all(GRadius.chip),
        onTap: () => showGSheet(
          context: context,
          title: 'Sort',
          children: <Widget>[
            for (final AppSort mode in AppSort.values)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: GRadius.all(GRadius.tile),
                  onTap: () {
                    ref.read(appSortProvider.notifier).select(mode);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GSpace.md - 2,
                      horizontal: GSpace.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            mode.label,
                            style: GType.body.copyWith(
                              color: mode == current ? t.text : t.muted,
                            ),
                          ),
                        ),
                        if (mode == current)
                          Icon(Icons.check_rounded, size: 18, color: t.accent),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.md - 2,
            vertical: GSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.swap_vert_rounded, size: 16, color: t.dim),
              const SizedBox(width: GSpace.xs + 1),
              Text(current.label, style: GType.micro.copyWith(color: t.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.onTap});

  final AppEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int total = entry.appBytes + entry.dataBytes + entry.cacheBytes;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.body.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Text(
                  GFormat.bytes(total),
                  style: GType.monoNumber.copyWith(color: t.text, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: GSpace.sm),
            // The split, as a bar. Three numbers in a row is a table; a bar
            // shows at a glance whether an app is big because of its content or
            // because of a cache that can be thrown away.
            ClipRRect(
              borderRadius: GRadius.all(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: <Widget>[
                    if (entry.appBytes > 0)
                      Expanded(
                        flex: entry.appBytes,
                        child: ColoredBox(color: t.dim),
                      ),
                    if (entry.dataBytes > 0)
                      Expanded(
                        flex: entry.dataBytes,
                        child: ColoredBox(color: t.photo),
                      ),
                    if (entry.cacheBytes > 0)
                      Expanded(
                        flex: entry.cacheBytes,
                        child: ColoredBox(color: t.audio),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: GSpace.sm),
            Text(
              _line(entry),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.micro.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }

  /// Only the parts that are worth reading. An app with no cache does not need
  /// to be told it has no cache.
  static String _line(AppEntry entry) {
    final List<String> parts = <String>[
      'app ${GFormat.bytes(entry.appBytes)}',
      if (entry.dataBytes > 0) 'data ${GFormat.bytes(entry.dataBytes)}',
      if (entry.cacheBytes > 0) 'cache ${GFormat.bytes(entry.cacheBytes)}',
      if (entry.lastUsedMillis == null)
        'never opened'
      else
        _ago(entry.lastUsedMillis!),
    ];
    return parts.join('  ·  ');
  }

  static String _ago(int millis) {
    final int days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(millis))
        .inDays;
    if (days <= 0) return 'used today';
    if (days == 1) return 'used yesterday';
    if (days < 30) return 'used $days days ago';
    if (days < 365) return 'used ${(days / 30).round()} months ago';
    return 'unused for over a year';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label, required this.tone});

  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GType.monoNumber.copyWith(color: tone, fontSize: 19),
        ),
        Text(label, style: GType.micro.copyWith(color: t.muted)),
      ],
    );
  }
}
