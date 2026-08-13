import 'package:flutter/material.dart';

import '../../ui/g_detail_page.dart';

/// A section of the Device tab, as its own page.
///
/// The cards already existed and were switched inline by a row of chips. Chips
/// work for four sections and break at twelve: the strip scrolls sideways, the
/// selected one hides off screen, and there is no way to see what is available
/// without dragging.
///
/// This changes the navigation and nothing else. Every card is unmodified and
/// still renders exactly as it did, which is why this is a host rather than a
/// rewrite.
///
/// ─── IT NOW CARRIES A HUE AND A GLYPH ────────────────────────────────────────
///
/// Both come from the bubble that opened it, so a hosted card gets the same
/// header as a page written against [GDetailPage] directly. That is the
/// whole reason this type survived the chrome change: seven sections got the new
/// header for the cost of two parameters rather than seven rewrites.
class DeviceSectionPage extends StatelessWidget {
  const DeviceSectionPage({
    required this.title,
    required this.hue,
    required this.icon,
    required this.child,
    super.key,
    this.subtitle,
  });

  final String title;
  final Color hue;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  static Route<void> route({
    required String title,
    required Color hue,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => DeviceSectionPage(
      title: title,
      hue: hue,
      icon: icon,
      subtitle: subtitle,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GDetailPage(
      hue: hue,
      icon: icon,
      title: title,
      subtitle: subtitle,
      children: <Widget>[child],
    );
  }
}
