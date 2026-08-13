library;

import 'package:flutter/material.dart';

import 'folder_entry.dart';

/// Folder sizes as a fixed slot layout.
///
/// Deliberately not a squarified treemap. The arrangement is four slots and a
/// remainder, and only the weights come from the data, which means no packing
/// pass, no slivers, and no tile that cannot hold its own label.
///
///   +-----------+-----------+
///   |           |     1     |
///   |     0     +-----------+
///   |           |     2     |
///   |           +-----+-----+
///   |           |  3  | rest|
///   +-----------+-----+-----+
///
/// When the biggest folder passes [wideThreshold] the right column collapses to
/// one tile plus the remainder, because three stacked tiles would each be
/// shorter than their own text.
class FolderMap extends StatelessWidget {
  const FolderMap({
    required this.folders,
    required this.totalBytes,
    required this.tintFor,
    required this.restTint,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.formatBytes,
    required this.onTapFolder,
    super.key,
    this.onTapRest,
    this.height = 216,
    this.radius = const BorderRadius.all(Radius.circular(10)),
  });

  /// Every folder, largest first. This widget decides how many it can draw.
  final List<FolderEntry> folders;

  /// The denominator for every share drawn here: what was scanned, not the
  /// capacity of the volume.
  final int totalBytes;

  final Color Function(FolderEntry folder) tintFor;
  final Color restTint;

  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  final String Function(int bytes) formatBytes;
  final void Function(FolderEntry folder) onTapFolder;
  final VoidCallback? onTapRest;

  final double height;
  final BorderRadius radius;

  static const double gap = 5;
  static const int minFlex = 9;
  static const double wideThreshold = 0.7;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty || totalBytes <= 0) return const SizedBox.shrink();

    final double topShare = folders.first.shareOf(totalBytes);
    final bool wide = topShare > wideThreshold || folders.length < 4;
    final int keep = wide ? 2 : 4;

    final List<FolderEntry> shown = folders.take(keep).toList(growable: false);
    final List<FolderEntry> rest = folders.skip(keep).toList(growable: false);
    final int restBytes = rest.fold<int>(
      0,
      (int sum, FolderEntry f) => sum + f.bytes,
    );

    final Widget map;
    if (shown.length == 1) {
      map = _tile(shown.first);
    } else {
      final int leftFlex = _clamp((topShare * 100).round(), 40, 66);
      map = Row(
        children: <Widget>[
          Expanded(flex: leftFlex, child: _tile(shown.first)),
          const SizedBox(width: gap),
          Expanded(
            flex: 100 - leftFlex,
            child: wide
                ? _narrowColumn(shown, restBytes, rest.length)
                : _fullColumn(shown, restBytes, rest.length),
          ),
        ],
      );
    }

    return SizedBox(height: height, child: map);
  }

  Widget _narrowColumn(List<FolderEntry> shown, int restBytes, int restCount) {
    if (restCount <= 0) return _tile(shown[1]);
    return Column(
      children: <Widget>[
        Expanded(flex: _flexFor(shown[1].bytes), child: _tile(shown[1])),
        const SizedBox(height: gap),
        Expanded(
          flex: _flexFor(restBytes),
          child: _restTile(restBytes, restCount),
        ),
      ],
    );
  }

  Widget _fullColumn(List<FolderEntry> shown, int restBytes, int restCount) {
    final FolderEntry fourth = shown[3];
    final int bottomFlex =
        _flexFor(fourth.bytes) + (restCount > 0 ? _flexFor(restBytes) : 0);

    return Column(
      children: <Widget>[
        Expanded(flex: _flexFor(shown[1].bytes), child: _tile(shown[1])),
        const SizedBox(height: gap),
        Expanded(flex: _flexFor(shown[2].bytes), child: _tile(shown[2])),
        const SizedBox(height: gap),
        Expanded(
          flex: bottomFlex,
          child: restCount <= 0
              ? _tile(fourth)
              : Row(
                  children: <Widget>[
                    // Clamped hard, and not by share. Across a row this narrow,
                    // proportional widths give the fourth folder about forty
                    // pixels, which is one character and an ellipsis. The
                    // remainder is not a folder and has no claim to the space.
                    Expanded(
                      flex: _clamp(_flexFor(fourth.bytes), 40, 60),
                      child: _tile(fourth),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      flex: _clamp(_flexFor(restBytes), 40, 60),
                      child: _restTile(restBytes, restCount),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tile(FolderEntry folder) {
    final Color tint = tintFor(folder);
    final int percent = (folder.shareOf(totalBytes) * 100).round();

    return Semantics(
      button: true,
      label: '${folder.name}, ${formatBytes(folder.bytes)}, $percent percent',
      excludeSemantics: true,
      child: _surface(
        tint: tint,
        onTap: () => onTapFolder(folder),
        child: _body(
          title: folder.name,
          subtitle: formatBytes(folder.bytes),
          footer: '$percent%',
        ),
      ),
    );
  }

  Widget _restTile(int restBytes, int restCount) {
    return Semantics(
      button: true,
      label: '$restCount smaller folders, ${formatBytes(restBytes)}',
      excludeSemantics: true,
      child: _surface(
        tint: restTint,
        onTap: onTapRest,
        child: _body(
          title: '$restCount more',
          subtitle: formatBytes(restBytes),
          footer: null,
        ),
      ),
    );
  }

  Widget _surface({
    required Color tint,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return Material(
      color: tint.withValues(alpha: 0.18),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tint.withValues(alpha: 0.34)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Density falls back as the slot gets shorter, and the name is the last thing
  /// to go. That is what makes an unlabelled tile impossible: the old treemap
  /// dropped the label whenever the cell was tight, which is how four of ten
  /// blocks ended up anonymous.
  ///
  /// The thresholds are MEASURED, not guessed. Fixed pixel numbers only hold for
  /// the type scale they were written against, and being two pixels out is the
  /// difference between a tile and a yellow overflow stripe.
  Widget _body({
    required String title,
    required String subtitle,
    required String? footer,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double titleHeight = _lineHeight(title, titleStyle);
        final double subHeight = _lineHeight(subtitle, subtitleStyle);

        double pad = 9;
        double needSubtitle = pad * 2 + titleHeight + 2 + subHeight;
        if (c.maxHeight < needSubtitle) {
          pad = 6;
          needSubtitle = pad * 2 + titleHeight + 2 + subHeight;
        }

        final double needTitle = pad * 2 + titleHeight;
        final double needFooter = needSubtitle + 2 + subHeight;

        if (c.maxHeight < needTitle) return const SizedBox.shrink();

        final bool tall = footer != null && c.maxHeight >= needFooter;
        final bool medium = c.maxHeight >= needSubtitle;

        return ClipRect(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: tall
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    if (medium) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ],
                ),
                if (tall)
                  Text(
                    footer,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _lineHeight(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return height;
  }

  /// Weights are clamped so a small folder still fits its label, which makes the
  /// tile slightly larger than its true share. That is why every tile prints its
  /// percentage: the geometry is approximate, the number is not.
  int _flexFor(int bytes) {
    if (totalBytes <= 0) return minFlex;
    return _clamp((bytes / totalBytes * 100).round(), minFlex, 100);
  }

  static int _clamp(int value, int low, int high) {
    if (value < low) return low;
    if (value > high) return high;
    return value;
  }
}
