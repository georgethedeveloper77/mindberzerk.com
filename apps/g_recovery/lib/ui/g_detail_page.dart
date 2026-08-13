import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import 'g_card.dart';

/// THE SHAPE EVERY PUSHED DETAIL PAGE IS BUILT FROM.
///
/// ─── WHY A PAGE TYPE AND NOT A SET OF WIDGETS ────────────────────────────────
///
/// Twenty odd destinations were each assembling their own Scaffold, SafeArea,
/// ListView and padding. Identical every time, and identical is exactly what
/// stops being true: two of them already disagreed about whether a section label
/// went through GOverline or through a raw Text, and the SIM page had picked a
/// different card padding from the Display page beside it.
///
/// The chrome is now one type. A new page declares a hue, a glyph, a title and a
/// list of sections, and cannot get the frame wrong because it does not draw it.
///
/// ─── THE HEADER SCROLLS AWAY, AND THAT IS THE POINT ──────────────────────────
///
/// The storage pages this replaced put their chrome OUTSIDE the scrollable: an
/// app bar, a sort row and a facts row in a Column, with the list in the
/// Expanded underneath. That is about 150dp of a phone screen that never moves,
/// and the list then scrolls inside whatever is left, which reads as a page
/// folded shut around a slot rather than a page that opens out.
///
/// Here the header is the first item in the same scrollable as everything else,
/// so the whole page moves together and the list gets the full screen the moment
/// a person starts reading.
///
/// ─── THE HUE IS THE ONE THING EACH PAGE OWNS ─────────────────────────────────
///
/// It comes from the tile that opened the page, not from a palette local to this
/// file. A cyan tile that opens a violet page reads as the wrong page having
/// opened, and the index is what a person looks at first.
class GDetailPage extends StatelessWidget {
  const GDetailPage({
    required this.hue,
    required this.icon,
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final Color hue;
  final IconData icon;
  final String title;

  /// The mono line under the title. Null renders nothing, rather than an empty
  /// row holding space open for a fact this device did not report.
  final String? subtitle;

  /// Sits at the right of the header. A badge, usually.
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Zero, because the header wash has to reach both edges. The body
          // below it carries the gutter itself.
          padding: EdgeInsets.zero,
          children: <Widget>[
            GDetailHeader(
              hue: hue,
              icon: icon,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                0,
                GSpace.gutter,
                GSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same page, for a body that has to be built lazily.
///
/// ─── WHEN TO REACH FOR THIS INSTEAD OF [GDetailPage] ─────────────────────────
///
/// [GDetailPage] takes a fixed list of boxes and is right for a page of
/// sections. A list of two thousand files is not a fixed list of boxes: it has
/// to be built as it is scrolled, and it may need pinned group headers, which
/// only a sliver can be.
///
/// Both draw the identical header, so a person cannot tell which one they are
/// looking at, which is the whole reason they are in one file.
class GDetailSliverPage extends StatelessWidget {
  const GDetailSliverPage({
    required this.hue,
    required this.icon,
    required this.title,
    required this.slivers,
    super.key,
    this.subtitle,
    this.trailing,
    this.footer,
    this.tailSpace = 120,
  });

  final Color hue;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// The body. Callers supply slivers and own their own horizontal padding,
  /// because a grid wants the gutter and a full bleed row does not.
  final List<Widget> slivers;

  /// Pinned under the list, outside the scrollable. An action bar armed by a
  /// selection belongs here: it has to stay reachable while the list moves, and
  /// it is the one thing on these pages that must NOT scroll away.
  final Widget? footer;

  /// Empty space after the last sliver.
  ///
  /// Generous on purpose. A list whose final row sits flush against the bottom
  /// edge reads as truncated even when it is complete, and on the pages with a
  /// footer the last row would otherwise sit under it.
  final double tailSpace;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: GDetailHeader(
                      hue: hue,
                      icon: icon,
                      title: title,
                      subtitle: subtitle,
                      trailing: trailing,
                    ),
                  ),
                  ...slivers,
                  SliverToBoxAdapter(child: SizedBox(height: tailSpace)),
                ],
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// The tinted top of a detail page.
class GDetailHeader extends StatelessWidget {
  const GDetailHeader({
    required this.hue,
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final Color hue;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Fades out well before the bottom of the header, so the first card on
        // the page sits on plain ink rather than on a tinted band. A wash that
        // runs the full height reads as a coloured panel, which is a different
        // and much louder element than the one intended.
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          stops: const <double>[0, 0.85],
          colors: <Color>[
            hue.withValues(alpha: dark ? 0.26 : 0.15),
            hue.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GSpace.gutter,
          GSpace.md,
          GSpace.gutter,
          GSpace.lg + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Back(),
            const SizedBox(height: GSpace.md),
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hue.withValues(alpha: dark ? 0.22 : 0.16),
                    borderRadius: GRadius.all(GRadius.button),
                  ),
                  child: Icon(icon, size: 21, color: hue),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GType.title.copyWith(color: t.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GType.monoSmall.copyWith(color: t.muted),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: GSpace.sm),
                  trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round, unlike the app bar icon button, which is a squircle.
///
/// The difference is deliberate and it is the only one: an app bar button sits
/// beside a title on the same line, and this one sits alone above a device name.
/// A circle at the top left of a tinted header reads as "out of here" at a
/// glance, which is the one thing this control has to do.
class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: t.panel,
        clipBehavior: Clip.antiAlias,
        shape: CircleBorder(side: BorderSide(color: t.line)),
        child: InkWell(
          // maybePop rather than pop. These pages are pushed from the index and
          // from the live cards above it, and a pop with nothing beneath would
          // black the app out rather than throw somewhere findable.
          onTap: () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card of label and value rows, and NOTHING when every value is null.
///
/// The empty check is here rather than in [SpecRows] because the card is the
/// part that would otherwise render: SpecRows already collapses to nothing, and
/// the result was an empty bordered panel on any phone that answered none of
/// the rows inside it.
class GSpecCard extends StatelessWidget {
  const GSpecCard({required this.rows, super.key});

  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    if (!SpecRows.any(rows)) return const SizedBox.shrink();
    return GCard(
      // Tighter than the default card padding. Each row already carries its own
      // vertical space, so the card's own would be counted twice at the top and
      // bottom of the list.
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md + 1,
        vertical: 2,
      ),
      child: SpecRows(rows: rows),
    );
  }
}

/// Yes and no rows, in the same shape as [GSpecCard].
///
/// A separate type rather than a caller mapping bools to the strings "Yes" and
/// "No", so the affirmative is the same colour on every page. It was mint on
/// one screen and plain text on the next.
class GFlagCard extends StatelessWidget {
  const GFlagCard({required this.flags, super.key});

  final List<(String, bool)> flags;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (flags.isEmpty) return const SizedBox.shrink();

    return GCard(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md + 1,
        vertical: 2,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < flags.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 1),
              decoration: BoxDecoration(
                border: i == flags.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      flags[i].$1,
                      style: GType.bodySmall.copyWith(color: t.text),
                    ),
                  ),
                  const SizedBox(width: GSpace.md),
                  Text(
                    flags[i].$2 ? 'Yes' : 'No',
                    style: GType.monoSmall.copyWith(
                      color: flags[i].$2 ? t.success : t.dim,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One slice of a [GStackBar].
@immutable
class GStackPart {
  const GStackPart({required this.bytes, required this.colour});

  /// The magnitude this slice takes. Zero and negative slices are dropped
  /// rather than drawn as a hairline, because a sliver of colour reads as a
  /// real quantity.
  ///
  /// No label here. The legend is a separate widget carrying its own strings,
  /// because a slice's caption almost always wants the figure folded into it
  /// and the bar has no business formatting bytes.
  final int bytes;

  final Color colour;
}

/// Used against free, as one bar.
///
/// ─── A BAR RATHER THAN A RING ────────────────────────────────────────────────
///
/// The question is "how much is left", which is a length. A ring answers "what
/// share of the whole", which nobody asks about memory, and it costs three
/// times the height to say the same thing.
class GStackBar extends StatelessWidget {
  const GStackBar({required this.parts, super.key, this.height = 14});

  final List<GStackPart> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final List<GStackPart> present = <GStackPart>[
      for (final GStackPart part in parts)
        if (part.bytes > 0) part,
    ];
    if (present.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: Row(
        // Stretch, not the default centre. Every slice is a childless
        // DecoratedBox, and a childless box handed loose cross axis
        // constraints takes the SMALLEST it is allowed, which is nothing at
        // all: the bar renders as an empty gap that looks like a layout bug.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < present.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              // Flex takes an int and every value here is a byte count, which
              // is already an int and already positive after the filter above.
              flex: present[i].bytes,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: present[i].colour,
                  borderRadius: GRadius.all(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The legend under a [GStackBar].
class GStackKeys extends StatelessWidget {
  const GStackKeys({required this.entries, super.key});

  /// Label already carrying its own figure, such as "Used 5.99 GB". One string
  /// rather than two, so a caller that has no figure to show still reads
  /// correctly instead of rendering a label followed by a gap.
  final List<(String, Color)> entries;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: GSpace.md,
      runSpacing: GSpace.sm - 2,
      children: <Widget>[
        for (final (String label, Color hue) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
              ),
              const SizedBox(width: GSpace.sm - 2),
              Text(label, style: GType.micro.copyWith(color: t.muted)),
            ],
          ),
      ],
    );
  }
}

/// One core's row in [GCoreBars].
@immutable
class GCoreBar {
  const GCoreBar({
    required this.label,
    required this.colour,
    this.value,
    this.fraction,
  });

  /// The core number, usually. Kept short: the column is 26 wide.
  final String label;

  final Color colour;

  /// Null draws an empty track, which is the honest picture of a core this
  /// kernel will not report. Never a zero, which would read as idle.
  final double? fraction;

  final String? value;
}

/// Per core frequency, as a distribution.
///
/// ─── BARS, NOT A LINE ────────────────────────────────────────────────────────
///
/// Eight simultaneous readings are not a history. A line chart of them would put
/// core 0 next to core 1 on an axis that means time, and invite a reader to see
/// a trend across the silicon rather than across the second.
class GCoreBars extends StatelessWidget {
  const GCoreBars({required this.cores, super.key});

  final List<GCoreBar> cores;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (cores.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        for (int i = 0; i < cores.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 7),
          Row(
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  cores[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.monoSmall.copyWith(color: t.dim, fontSize: 10),
                ),
              ),
              const SizedBox(width: GSpace.sm + 1),
              Expanded(
                child: ClipRRect(
                  borderRadius: GRadius.all(4),
                  child: Container(
                    height: 12,
                    color: t.panelHigh,
                    alignment: Alignment.centerLeft,
                    child: cores[i].fraction == null
                        ? null
                        : FractionallySizedBox(
                            widthFactor: cores[i].fraction!.clamp(0.0, 1.0),
                            child: AnimatedContainer(
                              duration: GMotion.fast,
                              decoration: BoxDecoration(
                                color: cores[i].colour,
                                borderRadius: GRadius.all(4),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: GSpace.sm + 1),
              SizedBox(
                width: 58,
                child: Text(
                  cores[i].value ?? '',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GType.monoSmall.copyWith(color: t.muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The line that names a permission, and only that.
///
/// ─── WHY THIS IS NOT A GENERAL DISCLAIMER ────────────────────────────────────
///
/// It renders where rows are missing BECAUSE Android refused, and nowhere else.
/// A page that apologises for every absent reading teaches people to skip the
/// apology, and the one that actually has a button behind it goes with it.
class GMissNote extends StatelessWidget {
  const GMissNote({
    required this.text,
    super.key,
    this.onTap,
    this.icon = Icons.lock_outline_rounded,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md + 1,
        vertical: GSpace.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: t.dim),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(text, style: GType.bodySmall.copyWith(color: t.muted)),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: t.dim),
        ],
      ),
    );
  }
}

/// A card whose only job is to hold a chart and its caption.
class GChartCard extends StatelessWidget {
  const GChartCard({
    required this.child,
    super.key,
    this.caption,
    this.header,
    this.axis = const <String>[],
  });

  /// Sits above the chart, in place of [header].
  final String? caption;

  /// A richer alternative to [caption], for the pages that put live figures
  /// where the caption would go.
  final Widget? header;

  final Widget child;

  /// Labels spread across the bottom edge. Two reads as "from, to"; three reads
  /// as "floor, now, ceiling".
  final List<String> axis;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (header != null) ...<Widget>[header!, const SizedBox(height: 6)],
          if (header == null && caption != null) ...<Widget>[
            Text(caption!, style: GType.micro.copyWith(color: t.muted)),
            const SizedBox(height: GSpace.sm),
          ],
          child,
          if (axis.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: axis.length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final String label in axis)
                  Text(
                    label,
                    style: GType.monoSmall.copyWith(
                      color: t.dim,
                      fontSize: 9.5,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A list of label and value rows, with the absent ones removed.
///
/// Every hardware page is mostly this. Sharing it means a null is dropped the
/// same way on all of them, rather than one page showing a dash, another an
/// empty string, and a third the word "Unknown".
class SpecRows extends StatelessWidget {
  const SpecRows({required this.rows, super.key});

  /// Null values are not rendered.
  final List<(String, String?)> rows;

  /// Whether anything at all would render.
  ///
  /// Callers wrapping this in a card need to know BEFORE they draw the card:
  /// SpecRows collapses to nothing on a device that answered none of the rows,
  /// and the card around it was left drawing an empty bordered panel.
  static bool any(List<(String, String?)> rows) {
    for (final (String _, String? value) in rows) {
      if (value != null && value.isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final List<(String, String)> present = <(String, String)>[
      for (final (String label, String? value) in rows)
        if (value != null && value.isNotEmpty) (label, value),
    ];
    if (present.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        for (int i = 0; i < present.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 1),
            decoration: BoxDecoration(
              border: i == present.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    present[i].$1,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                ),
                const SizedBox(width: GSpace.md),
                Flexible(
                  child: Text(
                    present[i].$2,
                    textAlign: TextAlign.right,
                    style: GType.monoSmall.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
