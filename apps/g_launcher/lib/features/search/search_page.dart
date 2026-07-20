import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/recent_searches.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/usage/usage_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/app_icon.dart';

/// The drawer search page — the One UI layout, dressed in the active theme.
///
/// Four blocks before you type (suggested apps, settings topics,
/// Downloads/Screenshots, recent searches) and a bottom search bar; typing
/// replaces the blocks with live app results. It reads the same providers the
/// rest of the launcher does, so nothing here is a second source of truth:
///  - suggested apps  → [recentAppsProvider] (most-recently launched), resolved
///    to entries against [appListProvider]; falls back to frecency, then to the
///    A-to-Z head, so the block is never an empty card
///  - results         → [visibleAppsProvider] (the existing prefix/substring rank)
///  - recent searches → [recentSearchesProvider] (global, most-recent-first)
///  - settings topics → [LauncherHostApi.openAndroidSettings]
///
/// Chrome, not Material: every colour and font comes from [ChromeScope] via
/// [ThemedScaffold], so on Ubuntu it reads aubergine and on KDE it reads Breeze,
/// the same rule as Settings and Wallpaper. The One UI screenshot is the
/// reference for the LAYOUT, not for a fixed neutral palette.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The bar is the point of the page — open straight into it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String v) => setState(() => _query = v);

  void _searchFor(String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _focus.requestFocus();
    _setQuery(term);
  }

  /// Launch an app. When it came from a typed result, [recordTerm] is the query
  /// that found it, so it lands in recent searches; suggested-app taps pass none.
  void _launch(AppEntry e, {String? recordTerm}) {
    final term = recordTerm?.trim() ?? '';
    if (term.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).record(term);
    }
    ref.read(appListProvider.notifier).launch(e);
    ref.read(usageProvider.notifier).record(e.componentKey);
  }

  /// Enter records the term and opens the top hit, matching the drawer's
  /// enter-launches-top-match contract.
  void _submit() {
    final q = _query.trim();
    if (q.isEmpty) return;
    final results = ref.read(visibleAppsProvider(q));
    ref.read(recentSearchesProvider.notifier).record(q);
    if (results.isNotEmpty) {
      ref.read(appListProvider.notifier).launch(results.first);
      ref.read(usageProvider.notifier).record(results.first.componentKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      // No app bar: the One UI search screen is content plus a bottom bar. Back
      // is the system gesture, same as the shells' overlays.
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final d = ChromeScope.of(context);
            return Column(
              children: [
                Expanded(
                  child: _query.isEmpty
                      ? _landing(context, d)
                      : _results(context, d),
                ),
                _searchBar(context, d),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Before typing: the four blocks ──────────────────────────────────────────
  Widget _landing(BuildContext context, ChromeData d) {
    final c = d.colors;
    final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
    final byKey = {for (final a in apps) a.componentKey: a};

    // RECENT, not frequent. "Suggested apps" on a search screen should answer
    // "what were you just doing?" — you opened a bank app two minutes ago and
    // want it again now, even though it will never out-rank WhatsApp on
    // frequency. The dock is the surface that wants frecency (it must hold
    // still); this one wants recency.
    final recentKeys = ref.watch(recentAppsProvider);
    final suggested = <AppEntry>[
      for (final k in recentKeys)
        if (byKey[k] != null) byKey[k]!,
    ].take(8).toList();

    // Nothing launched yet (fresh install, or usage cleared). Fall back to
    // frecency, then to the alphabetical head, so the block fills in as soon as
    // there is anything real to show and never renders as an empty card.
    var suggestedFilled = suggested;
    if (suggestedFilled.isEmpty) {
      suggestedFilled = <AppEntry>[
        for (final k in ref.watch(frequentAppsProvider))
          if (byKey[k] != null) byKey[k]!,
      ].take(8).toList();
    }
    if (suggestedFilled.isEmpty) {
      suggestedFilled = apps.take(8).toList();
    }

    final recent =
        ref.watch(recentSearchesProvider).asData?.value ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      children: [
        _Block(
          d: d,
          title: 'Suggested apps',
          child: _SuggestedGrid(
            apps: suggestedFilled,
            iconSize: widget.theme.iconSizeDp,
            onTap: (e) => _launch(e),
          ),
        ),
        _Block(
          d: d,
          title: 'Settings topics',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in _settingsTopics)
                _Chip(
                  d: d,
                  icon: t.icon,
                  label: t.label,
                  onTap: () => ref
                      .read(launcherHostApiProvider)
                      .openAndroidSettings(t.action),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _Tile(
                  d: d,
                  icon: Icons.folder_outlined,
                  label: 'Downloads',
                  // No view-intent seam on the host API yet; opening the real
                  // folder needs a Pigeon method (see the handoff note). Honest
                  // placeholder until it lands, same rule as the widgets menu.
                  onTap: () => context.showMessage('Files browsing is coming soon'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  d: d,
                  icon: Icons.image_outlined,
                  label: 'Screenshots',
                  onTap: () => context.showMessage('Files browsing is coming soon'),
                ),
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty)
          _Block(
            d: d,
            title: 'Recent searches',
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: c.textMuted),
              tooltip: 'Clear recent searches',
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final term in recent)
                  _RecentChip(
                    d: d,
                    term: term,
                    onTap: () => _searchFor(term),
                    onRemove: () => ref
                        .read(recentSearchesProvider.notifier)
                        .remove(term),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── While typing: live app results ──────────────────────────────────────────
  Widget _results(BuildContext context, ChromeData d) {
    final results = ref.watch(visibleAppsProvider(_query));
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No apps match "$_query"',
          style: d.text.body.copyWith(color: d.colors.textMuted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final e = results[i];
        return _AppCell(
          entry: e,
          iconSize: widget.theme.iconSizeDp,
          labelColor: d.colors.text,
          onTap: () => _launch(e, recordTerm: _query),
        );
      },
    );
  }

  // ── Bottom search bar ───────────────────────────────────────────────────────
  Widget _searchBar(BuildContext context, ChromeData d) {
    final c = d.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _setQuery,
                onSubmitted: (_) => _submit(),
                style: d.text.body,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: d.text.body.copyWith(color: c.textFaint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            // Speech capture needs a plugin we haven't added; honest placeholder
            // for now rather than a dead button.
            _BarIcon(
              icon: Icons.mic_none_outlined,
              color: c.textMuted,
              tooltip: 'Voice search',
              onTap: () => context.showMessage('Voice search is coming soon'),
            ),
            _BarIcon(
              icon: Icons.more_vert,
              color: c.textMuted,
              tooltip: 'More',
              onTap: () => _overflow(context),
            ),
          ],
        ),
      ),
    );
  }

  void _overflow(BuildContext context) {
    final host = context;
    ThemedSheet.show<void>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemedListRow(
            icon: Icons.delete_outline,
            title: 'Clear recent searches',
            onTap: () {
              Navigator.pop(sheet);
              ref.read(recentSearchesProvider.notifier).clear();
              if (host.mounted) host.showMessage('Recent searches cleared');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Settings topics ───────────────────────────────────────────────────────────
//
// A FIXED, universal set on purpose. Samsung's own topics (Eye comfort,
// Performance, Loss prevention...) are Samsung-only and would dead-end on the
// Infinix / Tecno / Xiaomi devices this launcher targets. These are AOSP actions
// that resolve on virtually any Android. Edit the list freely; each entry is
// just (icon, label, intent action).
class _Topic {
  const _Topic(this.icon, this.label, this.action);
  final IconData icon;
  final String label;
  final String action;
}

const _settingsTopics = <_Topic>[
  _Topic(Icons.brightness_6_outlined, 'Display', 'android.settings.DISPLAY_SETTINGS'),
  _Topic(Icons.shield_outlined, 'Security', 'android.settings.SECURITY_SETTINGS'),
  _Topic(Icons.battery_charging_full_outlined, 'Battery',
      'android.intent.action.POWER_USAGE_SUMMARY'),
  _Topic(Icons.wifi, 'Connections', 'android.settings.WIRELESS_SETTINGS'),
  _Topic(Icons.apps_outlined, 'Apps', 'android.settings.APPLICATION_SETTINGS'),
  _Topic(Icons.sd_storage_outlined, 'Storage',
      'android.settings.INTERNAL_STORAGE_SETTINGS'),
];

// ── Small themed pieces ───────────────────────────────────────────────────────

/// A titled block with an optional trailing action (the recent-searches trash).
class _Block extends StatelessWidget {
  const _Block({
    required this.d,
    required this.title,
    required this.child,
    this.trailing,
  });

  final ChromeData d;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: d.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: d.text.title)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SuggestedGrid extends StatelessWidget {
  const _SuggestedGrid({
    required this.apps,
    required this.iconSize,
    required this.onTap,
  });

  final List<AppEntry> apps;
  final double iconSize;
  final void Function(AppEntry) onTap;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 14,
      ),
      itemCount: apps.length,
      itemBuilder: (context, i) => _AppCell(
        entry: apps[i],
        iconSize: iconSize,
        labelColor: ChromeScope.of(context).colors.text,
        onTap: () => onTap(apps[i]),
      ),
    );
  }
}

class _AppCell extends StatelessWidget {
  const _AppCell({
    required this.entry,
    required this.iconSize,
    required this.labelColor,
    required this.onTap,
  });

  final AppEntry entry;
  final double iconSize;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: iconSize),
          const SizedBox(height: 6),
          Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.d,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ChromeData d;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c.textMuted),
            const SizedBox(width: 8),
            Text(label, style: d.text.body),
          ],
        ),
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.d,
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  final ChromeData d;
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Text(term, style: d.text.body),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 12, 10),
              child: Icon(Icons.close, size: 16, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.d,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ChromeData d;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c.textMuted),
            const SizedBox(width: 12),
            Text(label, style: d.text.title),
          ],
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
