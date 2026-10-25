import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../i18n/strings.g.dart';

/// Play in-app updates.
///
/// A normal update downloads in the background while the app keeps working,
/// then a bar offers Restart. An update released with in-app update priority
/// 4 or 5 (set per release in Play Console) is an urgent fix and installs
/// immediately, full screen.
///
/// Only Play-installed release builds can update this way; everything else
/// (debug runs, sideloads, no update) returns quietly.
abstract final class AppUpdate {
  static bool _checked = false;

  static Future<void> check(BuildContext context) async {
    if (_checked || kDebugMode || !Platform.isAndroid) return;
    _checked = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (!info.flexibleUpdateAllowed) return;

      // Completes once the user has accepted and the download has finished.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Stays until acted on: restarting is the user's call, since it
          // briefly interrupts the VPN.
          duration: const Duration(days: 1),
          content: Text(t.update.ready),
          action: SnackBarAction(label: t.update.restart, onPressed: InAppUpdate.completeFlexibleUpdate),
        ),
      );
    } on Object {
      // No Play Store, no network, or Play declined: try again next launch.
    }
  }
}
