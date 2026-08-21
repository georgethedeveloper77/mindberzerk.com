import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The sticky date header above a group.
///
/// A pinned sliver rather than a row inside the list, because the point of
/// grouping a long grid is knowing which day you are looking at after you have
/// scrolled past the label. A plain list item cannot do that.
///
/// MUST be placed inside a SliverMainAxisGroup holding that day's items, not
/// dropped straight into the scroll view's sliver list. Pinning is scoped to the
/// nearest sliver container, so laid out flat these accumulate: every header
/// scrolled past stays stuck to the top and the stack grows by one per group
/// until it covers the content. Grouped, each header evicts the one before it.
///
/// It paints its own opaque background. A transparent pinned header lets the
/// grid scroll through the text underneath it.
class GGroupHeader extends SliverPersistentHeaderDelegate {
  const GGroupHeader({
    required this.label,
    required this.meta,
    required this.tokens,
    this.muted = false,
    this.selected,
    this.onToggleAll,
  });

  final String label;

  /// The count and size line. Kept on one row with the label rather than under
  /// it, so a header costs 38 dp instead of 56 in a screen that is mostly grid.
  final String meta;

  final GTokens tokens;

  /// True for the undated catch-all, which is a real group but not a day.
  final bool muted;

  /// Whether every item in this group is already picked. Null hides the control
  /// entirely, which is the state before anything at all is selected.
  final bool? selected;

  /// Takes the whole day, or gives it back.
  ///
  /// A day is the unit people actually think in when clearing a phone. Without
  /// this, taking a Saturday of ninety photos is ninety taps, and the header is
  /// already the thing they are looking at when they decide.
  final VoidCallback? onToggleAll;

  static const double _height = 38;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: tokens.ink,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(GSpace.gutter, 0, GSpace.gutter, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.heading.copyWith(
                color: muted ? tokens.muted : tokens.text,
              ),
            ),
          ),
          const SizedBox(width: GSpace.sm + 1),
          Text(
            meta,
            style: GType.monoSmall.copyWith(color: tokens.dim, fontSize: 10.5),
          ),
          if (selected != null && onToggleAll != null) ...<Widget>[
            const SizedBox(width: GSpace.sm),
            _All(on: selected!, tokens: tokens, onTap: onToggleAll!),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(GGroupHeader old) =>
      old.label != label ||
      old.meta != meta ||
      old.muted != muted ||
      old.selected != selected ||
      old.tokens.ink != tokens.ink;
}

/// The whole day, as one target.
///
/// A ring rather than a checkbox, matching the one on every cell so the gesture
/// reads as the same act performed on a bigger object.
class _All extends StatelessWidget {
  const _All({required this.on, required this.tokens, required this.onTap});

  final bool on;
  final GTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: GRadius.all(GRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                on ? 'None' : 'All',
                style: GType.micro.copyWith(
                  color: on ? tokens.accentText : tokens.muted,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: on ? tokens.accent : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on ? tokens.accent : tokens.lineStrong,
                    width: 1.5,
                  ),
                ),
                child: on
                    ? Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: tokens.onAccent,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
