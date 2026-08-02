import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/recent_searches.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../data/usage/usage_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../../design/components/anchored_menu.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/drawer_items.dart';

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

  /// Hold a result for the same menu the drawer gives: pin, app info, hide,
  /// uninstall.
  ///
  /// ─── SEARCH WAS THE ONE APP SURFACE WITH NO HOLD ────────────────────────
  ///
  /// The drawer grid, the Kickoff list, the tiling prompt, the dock and a
  /// folder's contents all answer a long press with a menu. Search did not, so
  /// the one place you go when you already know which app you want was the one
  /// place you could not act on it: finding an app in order to pin or uninstall
  /// it meant finding it, closing search, and finding it again in the drawer.
  ///
  /// [showDrawerAppMenu] rather than a menu of its own, for the reason its own
  /// conversion note gives: two implementations of "pin this app" drift, and
  /// the pin here refusing differently from the pin in the drawer is the kind
  /// of bug nobody reports because it looks like the dock being full.
  void _hold(BuildContext cellContext, AppEntry e) {
    showDrawerAppMenu(
      context,
      ref,
      widget.theme,
      e,
      // The CELL's rectangle, not this page's: `context` here is the search
      // page, whose box is the whole screen, and anchoring to that would centre
      // the menu regardless of which result was held. The cell's own context is
      // passed in for exactly this.
      anchor: AnchoredMenu.anchorOf(cellContext),
    );
  }

  /// Hand the intent to Android, and say so when nothing can take it.
  ///
  /// The refusal matters. `openIntent` resolves before it fires and returns
  /// false rather than throwing, so a phone with no gallery gets a sentence
  /// instead of a tap that does nothing, which is indistinguishable from the
  /// launcher being broken.
  Future<void> _openIntent(
    String action, {
    String? uri,
    String? type,
    required String missing,
  }) async {
    final ok = await ref
        .read(launcherHostApiProvider)
        .openIntent(action, uri, type);
    if (!ok && mounted) context.showMessage(missing);
  }

  /// Enter records the term and opens the top hit, matching the drawer's
  /// enter-launches-top-match contract.
  void _submit() {
    final q = _query.trim();
    if (q.isEmpty) return;
    final results =
        ref.read(visibleAppsProvider((query: q, theme: widget.theme)));
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
    // ─── shellApps, NOT appList ────────────────────────────────────────
    //
    // `appListProvider` is the RAW list and includes hidden apps.
    // `shellAppsProvider` is the same list with this theme's hidden set
    // removed, which is what every other surface reads.
    //
    // Resolving suggestions against the raw list meant an app you had
    // deliberately hidden reappeared under "Suggested apps" the moment you
    // opened search, having launched it once before hiding it. That is exactly
    // the failure `HiddenApps.forSearch` was written to prevent on the RESULTS
    // list, and this block has no query to admit anything against: nobody typed
    // its whole name, so it has no business being here at all.
    //
    // It also fixes the alphabetical fallback below, which was showing the
    // first eight apps including hidden ones on a fresh install.
    final apps = ref.watch(shellAppsProvider(widget.theme));
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
            onHold: _hold,
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
                  // ── THE SEAM LANDED, SO THESE OPEN THE REAL THING ──────
                  //
                  // Both tiles said "Files browsing is coming soon" because
                  // the host API had no way to fire a view intent. It has one
                  // now, and the answer is still NOT to browse files ourselves:
                  // the phone already has a downloads viewer and a gallery, and
                  // reimplementing either is how a launcher rots, which is the
                  // same argument openAndroidSettings makes about settings.
                  //
                  // Downloads is action-only, so no uri and no type.
                  onTap: () => _openIntent(
                    'android.intent.action.VIEW_DOWNLOADS',
                    missing: 'No downloads app on this phone',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  d: d,
                  icon: Icons.image_outlined,
                  label: 'Screenshots',
                  // ACTION_VIEW at the external images collection, which is
                  // what every gallery registers for. There is no screenshots
                  // intent: the folder is a MediaStore bucket, not a
                  // destination, so this opens the gallery and the user is one
                  // album from the shots. Honest, and it works on the OEM
                  // galleries a Tecno actually ships.
                  onTap: () => _openIntent(
                    'android.intent.action.VIEW',
                    uri: 'content://media/external/images/media',
                    type: 'image/*',
                    missing: 'No gallery app on this phone',
                  ),
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
    final results =
        ref.watch(visibleAppsProvider((query: _query, theme: widget.theme)));

    // The launcher's OWN entries, which [visibleAppsProvider] cannot return
    // because it ranks AppEntry and a launcher entry is not one.
    //
    // This was the third surface with the same blind spot, after the rofi
    // launcher and the terminal: searching "settings" here found Android's
    // Settings app and never G Launcher's. Worse for the theme picker, which
    // nobody knows to look for under "G Launcher Settings" — hence the aliases
    // in drawer_items, shared so the three surfaces cannot drift.
    final launcherHits = launcherItemsMatching(_query);

    if (results.isEmpty && launcherHits.isEmpty) {
      return Center(
        child: Text(
          'Nothing matches "$_query"',
          style: d.text.body.copyWith(color: d.colors.textMuted),
        ),
      );
    }

    // TWO TITLED CARDS, matching the landing page's _Block treatment: an
    // "Apps" card holding the result grid, then a "Launcher" card for the
    // launcher-owned hits. Apps come FIRST because they are what the person is
    // overwhelmingly searching for; the launcher's own entries are the
    // secondary answer and read that way sitting below.
    //
    // Still a SEPARATE section rather than cells mixed into the app grid, and
    // that is deliberate on two counts. The grid is typed to AppEntry all the
    // way down (_AppCell, onTap, the usage recording), so mixing would mean
    // threading a sealed type through the whole page for two rows. And a
    // launcher entry is not an app: giving it its own card says so, the same
    // way the drawer pins these above the app list rather than sorting them in.
    //
    // A CustomScrollView rather than a ListView of _Blocks, because a _Block
    // would shrink-wrap the grid and build EVERY matching cell at once. One
    // typed letter can match dozens of apps, and the drawer's own perf rule
    // (lazy build only, never decode off a full list) applies just as hard
    // here. DecoratedSliver paints the card behind a grid that stays lazy.
    return CustomScrollView(
      slivers: [
        if (results.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: d.colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Apps', style: d.text.title),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: _appResultsSliver(context, d, results),
                  ),
                ],
              ),
            ),
          ),
        if (launcherHits.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: d.colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text('Launcher', style: d.text.title),
                  ),
                  for (final item in launcherHits)
                    _LauncherHit(
                      item: item,
                      theme: widget.theme,
                      onTap: () {
                        // Reuses the drawer's own router, so this page cannot
                        // drift from what tapping the same entry does in the
                        // drawer.
                        ref
                            .read(recentSearchesProvider.notifier)
                            .record(_query);
                        activateDrawerItem(context, ref, widget.theme, item);
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The result grid as a SLIVER, so it can sit inside the Apps card and stay
  /// lazily built. Same delegate numbers the old full-screen _appGrid used.
  /// That method is deleted rather than kept for the no-hits case: the card is
  /// drawn whenever there are results, so a second unstyled render path would
  /// only exist to drift from this one.
  Widget _appResultsSliver(
    BuildContext context,
    ChromeData d,
    List<AppEntry> results,
  ) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // 0.70, not 0.78: the cell has to be taller now that the label takes
        // two lines, and this is the same ratio the drawer uses for two-line
        // labels rather than a second guess at it.
        childAspectRatio: 0.70,
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
          onHold: (cell) => _hold(cell, e),
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
    this.onHold,
  });

  final List<AppEntry> apps;
  final double iconSize;
  final void Function(AppEntry) onTap;

  /// Threaded through rather than built here: the grid has no ref and no theme,
  /// and giving it either would make a dumb layout widget a consumer.
  final void Function(BuildContext cellContext, AppEntry entry)? onHold;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // See the results grid: two-line labels need the taller cell.
        childAspectRatio: 0.70,
        crossAxisSpacing: 8,
        mainAxisSpacing: 14,
      ),
      itemCount: apps.length,
      itemBuilder: (context, i) => _AppCell(
        entry: apps[i],
        iconSize: iconSize,
        labelColor: ChromeScope.of(context).colors.text,
        onTap: () => onTap(apps[i]),
        onHold: onHold == null ? null : (cell) => onHold!(cell, apps[i]),
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
    this.onHold,
  });

  final AppEntry entry;
  final double iconSize;
  final Color labelColor;
  final VoidCallback onTap;

  /// Receives THIS cell's context, so the menu can anchor to the cell rather
  /// than to the page. Null leaves the cell tap-only.
  final void Function(BuildContext cellContext)? onHold;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Null when no handler was given, so no recognizer is registered at all
      // and nothing competes for the pointer. See the gesture layer for why an
      // inert callback is not the same as an absent one.
      onLongPress: onHold == null ? null : () => onHold!(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: iconSize),
          const SizedBox(height: 6),
          Text(
            entry.label,
            // TWO LINES, so the whole app name reads.
            //
            // At one line this truncated names the drawer shows in full, which
            // is the worst place for it: search is where you have typed part of
            // a name and are checking you found the right thing, and
            // "AKI VIC Verificati" is precisely the case where the tail is the
            // informative part.
            //
            // TextOverflow.ellipsis stays as the last resort, per the house
            // rule: no ellipsis in authored COPY, but runtime truncation is
            // what stops a pathological name from clipping mid-glyph. Two lines
            // at four columns holds around 26 characters, so it is a fallback
            // rather than a normal outcome.
            maxLines: 2,
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

/// One launcher-owned entry in the search results.
///
/// A ROW, not a grid cell. The app results are a four-across grid of icons;
/// these are two entries at most and would look stranded in one. A row also
/// carries a subtitle, which is where the answer to "why is this here" goes
/// when someone searched for "theme" and got something called Settings.
class _LauncherHit extends StatelessWidget {
  const _LauncherHit({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final DrawerItem item;
  final EffectiveTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // Sealed, so adding a launcher entry later stops this compiling until it is
    // handled here too. Apps and folders never reach this widget.
    final (icon, subtitle) = switch (item) {
      LauncherSettingsItem() => (
          // The theme's own brand mark, matching the drawer tile so the same
          // entry looks like itself wherever it turns up.
          LauncherBrandIcon(theme: theme, size: 30),
          'Themes, layout, gestures, icons',
        ),
      DeviceSettingsItem() => (
          Icon(Icons.settings, size: 26, color: c.textMuted),
          'Opens Android settings',
        ),
      AppDrawerItem() || FolderDrawerItem() => (
          const SizedBox.shrink(),
          '',
        ),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 34, height: 34, child: Center(child: icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: d.text.body.copyWith(color: c.text)),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: d.text.body.copyWith(
                        color: c.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
