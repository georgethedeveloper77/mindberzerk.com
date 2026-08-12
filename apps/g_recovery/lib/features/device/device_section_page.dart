import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';

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
class DeviceSectionPage extends StatelessWidget {
  const DeviceSectionPage({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  static Route<void> route({
    required String title,
    required Widget child,
    String? subtitle,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) =>
        DeviceSectionPage(title: title, subtitle: subtitle, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: title,
              subtitle: subtitle,
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
