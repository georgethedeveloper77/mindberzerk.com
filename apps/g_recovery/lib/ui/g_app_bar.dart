import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// Not a Material AppBar.
///
/// AppBar brings its own height, its own elevation overlay, and a title
/// alignment that fights the two line title in the mockup. This is a plain row
/// that scrolls with the page.
///
/// ─── THE TITLE ROW IS FOR THE TITLE ──────────────────────────────────────────
///
/// [below] exists because [actions] was being used for things that are not
/// actions on the title. A view switch, a sort control and a refresh button all
/// ended up in this row, took roughly 250 dp of it, and left a 23 pt title with
/// about 80 dp to live in. "Everything" then broke across two lines in the
/// middle of a word, which reads as a bug rather than as truncation.
///
/// Anything that belongs under the title and above the content goes in [below]:
/// stats, filter chips, view switches. [actions] keeps only what genuinely acts
/// on the screen as a whole, which is one or two glyphs at most.
class GAppBar extends StatelessWidget {
  const GAppBar({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.below,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Rendered full width beneath the title row. Null on screens with nothing
  /// to put there, which is most of them.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(top: GSpace.xs, bottom: GSpace.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GType.micro.copyWith(
                          color: t.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    Text(
                      title,
                      // TWO lines, not one.
                      //
                      // A one line cap turned "How Android storage works" into a
                      // heading ending in an ellipsis, which reads as broken copy
                      // rather than as truncation. Two lines fit every title in the
                      // app at this size, and the cap stays so a pathological one
                      // cannot push the content off screen.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: subtitle == null
                          // Larger than GType.title. On home this line names the
                          // phone, which is the first thing a person checks to be
                          // sure the app is looking at the right device, and on
                          // every other screen it is the only thing telling them
                          // where they are.
                          ? GType.title.copyWith(color: t.text, fontSize: 23)
                          : GType.heading.copyWith(color: t.text),
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (below != null) ...<Widget>[
            const SizedBox(height: GSpace.md),
            below!,
          ],
        ],
      ),
    );
  }
}

/// The square icon button used in app bars.
class GIconButton extends StatelessWidget {
  const GIconButton({required this.icon, super.key, this.onTap, this.tone});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.glyph + 1);
    return Material(
      color: t.panel,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: t.line),
          ),
          child: Icon(icon, size: 17, color: tone ?? t.muted),
        ),
      ),
    );
  }
}
