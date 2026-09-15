/// The surface every panel applet opens on.
///
/// ─── WHY THIS IS NOT A BOTTOM SHEET ─────────────────────────────────────────
///
/// The applets opened `ThemedSheet`, which slides a full-width surface up from
/// the bottom of the screen. On a bottom panel that surface covers the panel it
/// came from, so tapping the battery to read the charge hid the battery, and on
/// a phone the sheet is most of the screen for two rows of content.
///
/// A desktop panel opens a popover ANCHORED to the applet, sitting against the
/// panel edge, and it does that for a reason that survives the port: the thing
/// you tapped stays visible, so a tap on the wrong glyph is obvious and
/// correctable rather than a surface you have to dismiss to find out.
/// `AnchoredMenu` already does the anchoring, the flip when there is no room,
/// and the light scrim that makes this read as a menu rather than a modal.
///
/// Sheets are still right in Settings, where the content IS the screen.
///
/// ─── AND WHY THE SIDE IS COMPUTED RATHER THAN PASSED ────────────────────────
///
/// A panel can sit on any of four edges, and the user can move it while the app
/// is running. Passing the side down would mean every applet taking a parameter
/// it does not otherwise use, and getting it wrong shows up as a popover that
/// opens off the top of the screen. The anchor's own position answers it: an
/// applet in the lower half opens upward, one in the upper half opens
/// downward, and `AnchoredMenu` flips either way when the room is not there.
library;

import 'package:flutter/material.dart';

import '../../../design/components/components.dart';

/// Open [rows] against the applet that [context] belongs to.
///
/// [context] must be the APPLET's own, not the panel's: it is measured for the
/// anchor, and a panel-wide rect would open the popover at the centre of a
/// 360dp strip rather than over the glyph that was tapped.
Future<void> showAppletMenu({
  required BuildContext context,
  required String title,
  required List<Widget> Function(BuildContext menuContext) rows,
}) {
  final anchor = AnchoredMenu.anchorOf(context);
  final height = MediaQuery.of(context).size.height;

  return AnchoredMenu.show(
    context: context,
    chrome: ChromeScope.of(context),
    anchor: anchor,
    title: title,
    // Narrower than an app menu's 240. These carry a readout and a route, and
    // at 240 the two rows sit in a panel wider than anything in them.
    width: 224,
    below: anchor == null || anchor.center.dy < height / 2
        ? AnchoredMenu.preferBelow
        : AnchoredMenu.preferAbove,
    rows: rows,
  );
}

/// A row that opens the app's own page for what the applet is reporting.
///
/// ─── WHY NOT STRAIGHT INTO ANDROID ─────────────────────────────────────────
///
/// These rows used to jump to `Settings.ACTION_WIFI_SETTINGS` and its
/// neighbours, which skipped past the pages this app already built. The Network
/// page has a throughput chart with history, a live transport row and its own
/// Android link at the foot; the Power page has the charge ring, the
/// temperature series and the same. Sending someone from the panel to Android
/// meant none of that was ever reached from the one place people tap it.
///
/// So the panel hands off to the page, and the page hands off to Android. Each
/// step goes somewhere with more than the last.
///
/// ─── AND WHY IT TAKES TWO CONTEXTS ─────────────────────────────────────────
///
/// `AnchoredMenu` says it outright: the menu's own context is dead the instant
/// it pops, and pushing a route onto a dead one silently does nothing. So the
/// pop uses the menu's context and the push uses [host], which is the applet
/// still sitting on the panel behind it.
ThemedListRow devicePageRow({
  required BuildContext menuContext,
  required BuildContext host,
  required String title,
  required Widget page,
}) {
  return ThemedListRow(
    icon: Icons.chevron_right,
    title: title,
    onTap: () {
      Navigator.pop(menuContext);
      if (!host.mounted) return;
      Navigator.of(host).push(MaterialPageRoute<void>(builder: (_) => page));
    },
  );
}

/// A row that leaves for one of Android's own screens.
///
/// Kept for the one applet with no page of its own to open. Volume reports
/// nothing the launcher measured, because reading a level needs an
/// `AudioManager` call the platform bridge does not have yet, so there is no
/// page to build and nothing to put on it.
ThemedListRow androidSettingsRow({
  required BuildContext menuContext,
  required String title,
  required String action,
  required Future<void> Function(String action) open,
}) {
  return ThemedListRow(
    icon: Icons.open_in_new,
    title: title,
    onTap: () {
      // Popped FIRST. `openAndroidSettings` leaves the app, and a popover still
      // mounted behind another activity is the one that is still there when the
      // user comes back.
      Navigator.pop(menuContext);
      open(action);
    },
  );
}
