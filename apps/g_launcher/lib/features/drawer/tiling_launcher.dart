import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/anchored_menu.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../palette/fuzzy.dart';
import '../palette/palette_controller.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'drawer_state.dart';

/// The tiling WM's launcher — rofi / wofi, phone-shaped.
///
/// A tiling desktop has no dock and no icon grid: you hit a keybind, a small
/// centred box appears, you type two letters, you press enter. That box is the
/// entire app-launching surface, which is why this looks nothing like the GNOME
/// grid or the Kickoff menu even though all three read the same
/// [drawerItemsProvider].
///
/// **Ranking is the terminal's, not the drawer's.** Typing runs through
/// [paletteResultsProvider] — the same `fuzzy.dart` DP that backs the TUI shell's
/// command line, with its 18 tests and its match-index highlighting. A tiling
/// launcher and a terminal prompt want identical behaviour ("two letters, top
/// hit, enter"), so they share one matcher rather than growing a second,
/// slightly-different one.
///
/// With an EMPTY query it falls back to the full drawer list, so folders and the
/// launcher-owned entries stay reachable here too — the fuzzy matcher ranks
/// installed apps, and a folder is not one. Typing narrows to apps, exactly as
/// rofi's drun mode does.
class TilingLauncher extends ConsumerStatefulWidget {
  const TilingLauncher({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<TilingLauncher> createState() => _TilingLauncherState();
}

class _TilingLauncherState extends ConsumerState<TilingLauncher> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The prompt IS the surface. A launcher you have to tap to focus wastes the
    // keystroke that opened it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    // Leave no query behind: reopening should start empty, not mid-search.
    Future.microtask(
      () => ref.read(paletteQueryProvider.notifier).state = '',
    );
    super.dispose();
  }

  void _submit() {
    // launchTopMatch owns the "is there a hit?" decision, same as the terminal.
    if (launchTopMatch(ref, widget.theme)) {
      _controller.clear();
      ref.read(paletteQueryProvider.notifier).state = '';
    }
    // No toast on an empty match list. Someone mid-typo does not need to be
    // told they are mid-typo.
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final query = ref.watch(paletteQueryProvider);
    final results = ref.watch(paletteResultsProvider(theme));
    final items = ref.watch(drawerItemsProvider(theme));

    final palette = theme.palette;
    final mono = theme.typography.mono ?? 'UbuntuMono';

    return Stack(
      children: [
        // Tap outside to dismiss, the way rofi does. The box is a floating
        // window over the desktop, not a full-screen page, so the area around it
        // has to be live.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(activitiesOpenProvider.notifier).state = false,
            child: ColoredBox(
              // A scrim, not an opaque fill: a tiling WM dims what is behind the
              // launcher rather than hiding it.
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
              child: Container(
                decoration: BoxDecoration(
                  // The rofi box itself. The black scrim above is deliberately
                  // NOT scaled: it is the dimming of the desktop behind, not a
                  // surface of ours, and fading it with this setting would make
                  // a translucent launcher unreadable over a bright wallpaper.
                  color: palette.bar.withValues(alpha: 0.98 * theme.drawerOpacity),
                  // Tiling WMs draw a hard accent border round the focused
                  // window. That border is the whole aesthetic; do not round it
                  // away.
                  border: Border.all(color: palette.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Prompt(
                      theme: theme,
                      controller: _controller,
                      focus: _focus,
                      mono: mono,
                      onChanged: (v) =>
                          ref.read(paletteQueryProvider.notifier).state = v,
                      onSubmit: _submit,
                    ),
                    Container(
                      height: 1,
                      color: palette.onDark.withValues(alpha: 0.12),
                    ),
                    Flexible(
                      child: query.isEmpty
                          ? _AllList(theme: theme, items: items, mono: mono)
                          : _Results(
                              theme: theme,
                              results: results,
                              mono: mono,
                            ),
                    ),
                    _Hint(
                      theme: theme,
                      mono: mono,
                      count:
                          query.isEmpty ? items.length : results.length,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `❯ ` plus the input. Mono, because a tiling WM's launcher is a terminal's
/// cousin and the theme already carries the font.
class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.theme,
    required this.controller,
    required this.focus,
    required this.mono,
    required this.onChanged,
    required this.onSubmit,
  });

  final EffectiveTheme theme;
  final TextEditingController controller;
  final FocusNode focus;
  final String mono;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Text(
            '❯',
            style: TextStyle(
              fontFamily: mono,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              // A launcher that autocapitalises fights every package name.
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.go,
              cursorColor: palette.accent,
              cursorWidth: 8,
              cursorRadius: Radius.zero,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 15,
                color: palette.onDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'run',
                hintStyle: TextStyle(
                  fontFamily: mono,
                  fontSize: 15,
                  color: palette.onDark.withValues(alpha: 0.35),
                ),
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fuzzy hits. Top match takes the accent wash and the `↵`, so enter is
/// obviously bound to what you are looking at.
class _Results extends ConsumerWidget {
  const _Results({
    required this.theme,
    required this.results,
    required this.mono,
  });

  final EffectiveTheme theme;
  final List<Ranked<AppEntry>> results;
  final String mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Text(
          'no matches',
          style: TextStyle(
            fontFamily: mono,
            fontSize: 12.5,
            color: theme.palette.onDark.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    // Ten is plenty. If the right app isn't in the top ten, the answer is
    // another keystroke, not more scrolling.
    final shown = results.take(10).toList();

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final ranked = shown[i];
        final entry = ranked.item;
        final isTop = i == 0;

        return _Line(
          theme: theme,
          mono: mono,
          isTop: isTop,
          icon: AppIcon(entry: entry, size: theme.iconSizeDp * 0.5),
          label: _Highlighted(
            theme: theme,
            mono: mono,
            text: entry.label,
            indices: ranked.match.indices,
          ),
          onTap: () {
            launchDrawerApp(ref, entry);
            ref.read(paletteQueryProvider.notifier).state = '';
          },
          onLongPress: () => showDrawerAppMenu(context, ref, theme, entry,
                anchor: AnchoredMenu.anchorOf(context)),
        );
      },
    );
  }
}

/// The empty-query view: everything, in drawer order. Folders and the
/// launcher-owned entries live here — the fuzzy matcher ranks installed apps,
/// so this is the one view that can show the rest.
class _AllList extends ConsumerWidget {
  const _AllList({
    required this.theme,
    required this.items,
    required this.mono,
  });

  final EffectiveTheme theme;
  final List<DrawerItem> items;
  final String mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = theme.iconSizeDp * 0.5;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];

        return _Line(
          theme: theme,
          mono: mono,
          isTop: false,
          icon: SizedBox(
            width: size,
            height: size,
            child: switch (item) {
              AppDrawerItem(:final entry) => AppIcon(entry: entry, size: size),
              FolderDrawerItem() => Icon(
                  Icons.folder_outlined,
                  size: size * 0.9,
                  color: theme.palette.accent,
                ),
              LauncherSettingsItem() =>
                LauncherBrandIcon(theme: theme, size: size),
              DeviceSettingsItem() => Icon(
                  Icons.settings,
                  size: size * 0.85,
                  color: theme.palette.onDark,
                ),
            },
          ),
          label: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: mono,
              fontSize: 13,
              color: theme.palette.onDark,
            ),
          ),
          onTap: () => activateDrawerItem(context, ref, theme, item),
          onLongPress: switch (item) {
            AppDrawerItem(:final entry) => () =>
                showDrawerAppMenu(context, ref, theme, entry,
                anchor: AnchoredMenu.anchorOf(context)),
            final FolderDrawerItem f => () =>
                drawerFolderSettings(context, ref, theme, f,
                anchor: AnchoredMenu.anchorOf(context)),
            LauncherSettingsItem() || DeviceSettingsItem() => null,
          },
        );
      },
    );
  }
}

/// One row of the list, shared by both views so they cannot drift apart.
class _Line extends StatelessWidget {
  const _Line({
    required this.theme,
    required this.mono,
    required this.isTop,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final EffectiveTheme theme;
  final String mono;
  final bool isTop;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isTop
              ? palette.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 10),
            Expanded(child: label),
            if (isTop)
              Text(
                '↵',
                style: TextStyle(
                  fontFamily: mono,
                  fontSize: 14,
                  color: palette.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the matched characters in the accent, bold.
///
/// This is the payoff for `FuzzyMatch.indices`, and it doubles as the feature's
/// own debug view: if the highlight looks wrong, the RANKING is wrong, and you
/// can see it without a print statement.
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.theme,
    required this.mono,
    required this.text,
    required this.indices,
  });

  final EffectiveTheme theme;
  final String mono;
  final String text;
  final List<int> indices;

  @override
  Widget build(BuildContext context) {
    final hit = indices.toSet();
    final palette = theme.palette;

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < text.length; i++)
            TextSpan(
              text: text[i],
              style: hit.contains(i)
                  ? TextStyle(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    )
                  : TextStyle(color: palette.onDark),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: mono, fontSize: 13),
    );
  }
}

/// waybar-style footer: a count and the key hints, in the bar's own idiom.
class _Hint extends StatelessWidget {
  const _Hint({
    required this.theme,
    required this.mono,
    required this.count,
  });

  final EffectiveTheme theme;
  final String mono;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark.withValues(alpha: 0.45);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.palette.onDark.withValues(alpha: 0.12)),
        ),
      ),
      child: Text(
        '$count · ↵ runs the top match',
        style: TextStyle(fontFamily: mono, fontSize: 11, color: ink),
      ),
    );
  }
}
