import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/tokens.dart';

/// How a list of files is laid out.
///
/// Three, not two. The grid and list toggle answered "can I recognise it by
/// looking" and nothing else, and every screen that showed files had its own
/// copy of the same boolean.
enum GViewMode {
  /// Squares. For recognising a photo without reading anything.
  grid,

  /// A row with a thumbnail, a name and one line of facts.
  list,

  /// The same row with the folder, the date and the type spelled out.
  ///
  /// The mode a person switches to when the name is not enough, which happens
  /// the moment a phone has forty files called IMG_20240416.
  details,
}

/// One choice, shared by every file list in the app.
///
/// App wide rather than per page on purpose. Someone who prefers a list prefers
/// it everywhere, and making them set it again on each screen is the kind of
/// thing that reads as the app not paying attention.
///
/// NOT PERSISTED YET. That needs a key in GPrefsKeys, and adding one blind is
/// how a prefs file ends up with two spellings of the same setting. The choice
/// survives navigation and dies with the process.
class GViewModeController extends Notifier<GViewMode> {
  @override
  GViewMode build() => GViewMode.grid;

  void select(GViewMode mode) {
    if (mode == state) return;
    state = mode;
  }
}

final NotifierProvider<GViewModeController, GViewMode> gViewModeProvider =
    NotifierProvider<GViewModeController, GViewMode>(GViewModeController.new);

/// Three icons in a well.
///
/// A segmented control rather than the single cycling button this replaces. A
/// button that rotates through three states hides two of them and tells nobody
/// which comes next.
class GViewSwitch extends ConsumerWidget {
  const GViewSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final GViewMode mode = ref.watch(gViewModeProvider);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.panelAlt,
        borderRadius: GRadius.all(GRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (GViewMode value, IconData icon) in _options)
            _Segment(
              icon: icon,
              on: mode == value,
              onTap: () => ref.read(gViewModeProvider.notifier).select(value),
            ),
        ],
      ),
    );
  }

  static const List<(GViewMode, IconData)> _options = <(GViewMode, IconData)>[
    (GViewMode.grid, Icons.grid_view_rounded),
    (GViewMode.list, Icons.view_list_rounded),
    (GViewMode.details, Icons.view_agenda_outlined),
  ];
}

/// The same well, driven from outside instead of from the app wide provider.
///
/// GViewSwitch above is bound to gViewModeProvider on purpose: the grid and list
/// choice belongs to every file list at once. A section that needs its own
/// two way toggle must not borrow that provider, or switching a map would
/// reformat every file list in the app.
///
/// So: same look, same segment, caller holds the state.
class GSegmentedIcons extends StatelessWidget {
  const GSegmentedIcons({
    required this.icons,
    required this.index,
    required this.onChanged,
    super.key,
    this.labels,
  });

  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;

  /// One per icon, for screen readers. An icon only control says nothing out
  /// loud without them.
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.panelAlt,
        borderRadius: GRadius.all(GRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < icons.length; i++)
            Semantics(
              button: true,
              selected: i == index,
              label: labels != null && i < labels!.length ? labels![i] : null,
              child: _Segment(
                icon: icons[i],
                on: i == index,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.icon, required this.on, required this.onTap});

  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: GRadius.all(GRadius.chip),
        child: AnimatedContainer(
          duration: GMotion.fast,
          curve: GMotion.enter,
          width: 38,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.accentSoft : null,
            borderRadius: GRadius.all(GRadius.chip),
          ),
          child: Icon(icon, size: 17, color: on ? t.accentText : t.dim),
        ),
      ),
    );
  }
}
