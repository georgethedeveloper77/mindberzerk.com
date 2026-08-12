import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// Not a Material AppBar.
///
/// AppBar brings its own height, its own elevation overlay, and a title
/// alignment that fights the two line title in the mockup. This is a plain row
/// that scrolls with the page.
class GAppBar extends StatelessWidget {
  const GAppBar({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(top: GSpace.xs, bottom: GSpace.md + 2),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 11)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GType.micro.copyWith(color: t.muted, fontSize: 11.5),
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
