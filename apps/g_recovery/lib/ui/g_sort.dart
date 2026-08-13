import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/tokens.dart';
import 'g_sheet.dart';
import '../core/i18n/g_strings.dart';

/// How a list of files is ordered.
///
/// The app shipped six detail screens with no sort at all, which is defensible
/// only while every list is short. On a phone with two thousand photos, a list
/// you cannot reorder is a list you cannot use.
enum GSortMode {
  /// Newest first. The default everywhere, because the commonest question is
  /// about something that happened recently.
  newest,
  oldest,
  largest,
  smallest,
  name,

  /// Soonest to be lost. Recovery only, and it is the one sort that can prevent
  /// a loss rather than merely find something.
  expiring;

  String get label => switch (this) {
    GSortMode.newest => 'Newest first',
    GSortMode.oldest => 'Oldest first',
    GSortMode.largest => 'Largest first',
    GSortMode.smallest => 'Smallest first',
    GSortMode.name => 'Name, A to Z',
    GSortMode.expiring => 'Expiring soonest',
  };

  /// Whether this order can be cut into days.
  ///
  /// THE DECISION THE SORT CONTROL FORCES, and it is not cosmetic.
  ///
  /// Date headers describe why a run of files sits together. Under a size sort
  /// they would put a 94 MB video under "Today" and say nothing about why it is
  /// first, so the headers come off and a rank appears instead. Two different
  /// questions, two different lists: "what did I lose on Saturday" wants days,
  /// "what is eating my storage" wants a ranking.
  /// EVERY sort groups by date now.
  ///
  /// The earlier rule dropped the headers under a size sort, on the grounds
  /// that "Today" over a 94 MB video explains nothing about why it is first.
  /// That was right about the headers and wrong about the fix: losing the days
  /// altogether costs the one piece of context a person always wants.
  ///
  /// So the days stay and the ORDER OF THE DAYS follows the sort. Under
  /// largest first, the day holding the biggest file comes first and its files
  /// are biggest first within it. The header still means what it says, and the
  /// top of the screen is still the answer to "what is taking the space".
  bool get groupsByDate => true;

  /// Whether the day groups themselves are ranked by size rather than by date.
  bool get ranksGroups =>
      this == GSortMode.largest || this == GSortMode.smallest;
}

/// The chosen order, shared by every file list.
///
/// App wide for the same reason the view mode is: someone who thinks in sizes
/// thinks in sizes everywhere, and making them set it again per screen reads as
/// the app not paying attention.
class GSortController extends Notifier<GSortMode> {
  @override
  GSortMode build() => GSortMode.newest;

  void select(GSortMode mode) {
    if (mode == state) return;
    state = mode;
  }
}

final NotifierProvider<GSortController, GSortMode> gSortProvider =
    NotifierProvider<GSortController, GSortMode>(GSortController.new);

/// The control: a pill showing the current order, opening a sheet.
///
/// A pill rather than an icon, because the current sort is a fact the user needs
/// while reading the list. An icon alone would mean opening the sheet to find
/// out what order they are already looking at.
class GSortButton extends ConsumerWidget {
  const GSortButton({super.key, this.allowExpiring = false});

  /// Recovery pages only. Nothing in storage expires, and offering the option
  /// there would produce a list ordered by a field that is null for every row.
  final bool allowExpiring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final GSortMode mode = ref.watch(gSortProvider);

    return Material(
      color: t.panelAlt,
      borderRadius: GRadius.all(GRadius.chip),
      child: InkWell(
        borderRadius: GRadius.all(GRadius.chip),
        onTap: () => _open(context, ref, mode),
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
              // Flexible, and it is not decoration.
              //
              // MainAxisSize.min asks for the label's full width, so wrapping
              // this pill in a Flexible from outside does nothing: the parent
              // offers less room and this Row still lays out at its intrinsic
              // size and overflows. Every screen that puts anything beside the
              // sort control hits it, and "Expiring soonest" is long enough to
              // do it on a narrow phone with nothing beside it at all.
              //
              // Ellipsis rather than a shorter label set, because the current
              // order is a fact the user is reading off this pill and a
              // truncated phrase still says more than an icon.
              Flexible(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.micro.copyWith(color: t.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, GSortMode current) {
    final GTokens t = context.g;

    showGSheet(
      context: context,
      title: context.s('Sort'),
      children: <Widget>[
        for (final GSortMode mode in GSortMode.values)
          if (mode != GSortMode.expiring || allowExpiring)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: GRadius.all(GRadius.tile),
                onTap: () {
                  ref.read(gSortProvider.notifier).select(mode);
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
    );
  }
}
