import 'package:flutter/material.dart';

import '../design/meridian.dart';
import 'server_map_view.dart';

/// The whole map, opened from Home. Connecting closes it, so the user
/// watches the flight to the server on Home.
class FullMapScreen extends StatelessWidget {
  const FullMapScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FullMapScreen()));

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Scaffold(
      backgroundColor: m.bg,
      body: ServerMapView(
        topInset: MediaQuery.paddingOf(context).top,
        leading: Material(
          color: m.surface,
          shape: CircleBorder(side: BorderSide(color: m.line)),
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: m.text),
          ),
        ),
        onConnected: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
