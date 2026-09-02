/// Play's in-app update, as a state machine the settings page can read.
///
/// ─── WHY THIS IS A NOTIFIER AND NOT A FutureProvider ────────────────────────
///
/// A check is not the only thing that happens here. A download runs for as long
/// as a download takes, an install waits for a user decision that may never
/// come, and the process can be killed between the two and come back to find
/// Play still holding a downloaded APK. A future models the first of those and
/// none of the rest.
///
/// ─── AND WHY THE STATE IS PINNED AT `_Root` ─────────────────────────────────
///
/// See the comment at the watch site in `app.dart`. Short version: a completed
/// flexible download is a fact about the PROCESS, and the settings screen is not
/// alive for most of the process.
///
/// ─── THE PLUGIN SURFACE THIS FILE DEPENDS ON ────────────────────────────────
///
/// Four names, and they are the entire contract with `in_app_update`:
/// `UpdateAvailability`, `InstallStatus`, `AppUpdateResult`, and the four static
/// methods on `InAppUpdate`. Nothing else in `lib/` imports the package, so a
/// version bump is verified by running `flutter analyze` against this one file.
/// Keep it that way: the moment a screen calls `InAppUpdate` directly, the
/// throttle and the persisted record stop being the only path to Play.
///
/// ─── WHAT IS DELIBERATELY MISSING: A PERCENTAGE ─────────────────────────────
///
/// Android's `InstallState` carries `bytesDownloaded` and `totalBytesToDownload`
/// and the Flutter plugin does not surface either: `startFlexibleUpdate()`
/// returns one future that completes when the download is finished. So
/// [UpdateStatus.downloading] is INDETERMINATE, and the row that renders it must
/// not show a number. Every figure shown is measured; there is no figure here to
/// measure, so there is no figure.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../prefs/prefs_repository.dart';
import '../repositories/app_repository.dart';

/// How long a check is good for.
///
/// Twenty-four hours, and the alternative was not a shorter interval: it was a
/// `WorkManager` job. That is rejected in the plan and it stays rejected. A
/// background wake-up to ask about updates is battery cost on the one app that
/// must never be blamed for battery, and Play already auto-updates most
/// installs without being asked.
const kUpdateCheckInterval = Duration(hours: 24);

/// Its own top-level key, NOT a field on `LauncherPrefs` or `GlobalPrefs`.
///
/// Both of those are cleared by `resetEverything`, which is what the Restore
/// defaults screen calls. Putting the throttle stamp in either would mean every
/// reset triggers a Play round trip on the next Settings open, and a stamp is
/// not a setting: nobody chose it and nobody wants it restored.
const kUpdateRecordKey = 'update.lastCheck.v1';

enum UpdateStatus {
  /// Nothing has been asked yet. Renders as a plain "Check for updates" row.
  unknown,

  checking,
  upToDate,

  /// Play has one and it can be taken.
  available,

  /// Downloading in the background, with the launcher still usable. No
  /// percentage exists; see the file header.
  downloading,

  /// Downloaded and waiting for a restart. THE RESTART KILLS THE HOME SCREEN,
  /// which is why nothing in this file completes an update on its own.
  readyToInstall,

  /// Play cannot answer: a sideloaded or debug build, a de-Googled ROM, a
  /// disabled Play Store. A FACT, not an error, and the row says so plainly.
  ///
  /// This is the state every debug build on a test device sits in permanently,
  /// so it is the first one anyone developing this will see.
  unavailable,
}

@immutable
class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.unknown,
    this.availableVersionCode,
    this.flexibleAllowed = true,
    this.lastCheckedAt,
  });

  final UpdateStatus status;

  /// Play's code for the waiting build, or null when there is none. Persisted,
  /// and compared against `getVersionCode()` on the throttled path so a record
  /// cannot outlive the update it describes.
  final int? availableVersionCode;

  /// Whether Play will allow the flexible flow for this update.
  ///
  /// It normally will. When it will not, the fallback is the store listing
  /// rather than `performImmediateUpdate`: an immediate update throws a
  /// blocking full-screen Play UI over the home screen, and a home screen that
  /// cannot be dismissed is a bricked phone for the length of a download.
  final bool flexibleAllowed;

  final DateTime? lastCheckedAt;

  bool get hasUpdate =>
      status == UpdateStatus.available ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.readyToInstall;

  UpdateState copyWith({
    UpdateStatus? status,
    int? availableVersionCode,
    bool? flexibleAllowed,
    DateTime? lastCheckedAt,
  }) =>
      UpdateState(
        status: status ?? this.status,
        availableVersionCode: availableVersionCode ?? this.availableVersionCode,
        flexibleAllowed: flexibleAllowed ?? this.flexibleAllowed,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is UpdateState &&
      other.status == status &&
      other.availableVersionCode == availableVersionCode &&
      other.flexibleAllowed == flexibleAllowed &&
      other.lastCheckedAt == lastCheckedAt;

  @override
  int get hashCode =>
      Object.hash(status, availableVersionCode, flexibleAllowed, lastCheckedAt);
}

class AppUpdateNotifier extends Notifier<UpdateState> {
  bool _busy = false;

  @override
  UpdateState build() => const UpdateState();

  /// Check, unless a check inside [kUpdateCheckInterval] already answered.
  ///
  /// Called from two places and no others: once at process start (`_Root`) and
  /// once per Settings open. Both call THIS rather than [check], so neither has
  /// to know what the interval is.
  Future<void> checkIfStale() async {
    final record = await _readRecord();
    final at = record?.at;

    if (at != null && DateTime.now().difference(at) < kUpdateCheckInterval) {
      await _restore(record!);
      return;
    }
    await check();
  }

  /// Ask Play, ignoring the throttle. The row's own tap target.
  Future<void> check() async {
    if (_busy) return;

    // in_app_update is Android-only, and a channel call that is guaranteed to
    // throw is still a channel call. Cheaper to not make it.
    if (defaultTargetPlatform != TargetPlatform.android) {
      state = state.copyWith(status: UpdateStatus.unavailable);
      return;
    }

    _busy = true;
    state = state.copyWith(status: UpdateStatus.checking);
    try {
      final info = await InAppUpdate.checkForUpdate();
      final now = DateTime.now();

      // ORDER MATTERS. A build that finished downloading before the process
      // died still reports `updateAvailable`, so asking about availability
      // first would offer to download something already on disk.
      if (info.installStatus == InstallStatus.downloaded) {
        state = UpdateState(
          status: UpdateStatus.readyToInstall,
          availableVersionCode: info.availableVersionCode,
          lastCheckedAt: now,
        );
      } else if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        state = UpdateState(
          status: UpdateStatus.available,
          availableVersionCode: info.availableVersionCode,
          flexibleAllowed: info.flexibleUpdateAllowed,
          lastCheckedAt: now,
        );
      } else {
        state = UpdateState(status: UpdateStatus.upToDate, lastCheckedAt: now);
      }

      await _writeRecord(now, state.availableVersionCode);
    } catch (e) {
      // NOT recorded, and not reported. A throw here means Play will not talk
      // to this install, which is the normal condition of every debug build and
      // of every de-Googled ROM in this app's audience. Persisting it would
      // freeze the row in that state for a day after the user sideloads their
      // way onto a real Play install.
      debugPrint('Update check unavailable: $e');
      state = state.copyWith(status: UpdateStatus.unavailable);
    } finally {
      _busy = false;
    }
  }

  /// Start the flexible download, or fall back to the store listing.
  Future<void> startDownload() async {
    if (state.status != UpdateStatus.available || _busy) return;

    if (!state.flexibleAllowed) {
      await openStoreListing();
      return;
    }

    _busy = true;
    state = state.copyWith(status: UpdateStatus.downloading);
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      state = state.copyWith(
        status: result == AppUpdateResult.success
            ? UpdateStatus.readyToInstall
            // userDeniedUpdate and inAppUpdateFailed both land back on the
            // offer rather than on an error. One is a choice and the other is
            // retryable, and neither is worth a message the user has to dismiss.
            : UpdateStatus.available,
      );
    } catch (e) {
      debugPrint('Flexible update failed: $e');
      state = state.copyWith(status: UpdateStatus.available);
    } finally {
      _busy = false;
    }
  }

  /// Install what has been downloaded. THIS RESTARTS THE PROCESS.
  ///
  /// Never called on a timer, on resume, or from the check. The launcher IS the
  /// home screen: an install that fires on its own takes the desktop away
  /// mid-gesture and is indistinguishable from a crash. It is only ever reached
  /// from an explicit tap on a control that says the desktop will reload.
  Future<void> completeUpdate() async {
    if (state.status != UpdateStatus.readyToInstall) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      // If the restart does not happen, the offer must survive it.
      debugPrint('Completing update failed: $e');
    }
  }

  /// The Play listing for this app, for the case Play refuses the flexible flow.
  Future<void> openStoreListing() async {
    // The package name is not on the bridge and does not need to be: it is the
    // applicationId, fixed at build time and already spelled in
    // build.gradle.kts and the Pigeon Kotlin package. See [kApplicationId].
    final market = Uri.parse('market://details?id=$kApplicationId');
    if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$kApplicationId'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  // ---- the persisted record ------------------------------------------------

  Future<({DateTime? at, int? code})?> _readRecord() async {
    final raw = await ref.read(prefsStoreProvider).read(kUpdateRecordKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        at: DateTime.tryParse(map['at'] as String? ?? ''),
        code: map['code'] as int?,
      );
    } catch (_) {
      // A corrupt stamp means "never checked", which costs one Play call.
      return null;
    }
  }

  Future<void> _writeRecord(DateTime at, int? code) =>
      ref.read(prefsStoreProvider).write(
            kUpdateRecordKey,
            jsonEncode({'at': at.toIso8601String(), 'code': code}),
          );

  /// Rebuild state from the stamp, without calling Play.
  ///
  /// ─── WHY THE VERSION CODE IS CHECKED HERE ─────────────────────────────────
  ///
  /// Without this, a record written yesterday keeps the banner up for a day
  /// AFTER the update it describes has been installed, because Play is not being
  /// asked and the record does not know it is stale. Comparing the recorded code
  /// against the running one is the whole reason `getVersionCode()` exists on
  /// the bridge.
  Future<void> _restore(({DateTime? at, int? code}) record) async {
    // A download that finished in this process is newer than anything on disk.
    if (state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.readyToInstall) {
      return;
    }

    final code = record.code;
    if (code == null) {
      state = state.copyWith(
        status: UpdateStatus.upToDate,
        lastCheckedAt: record.at,
      );
      return;
    }

    var installed = 0;
    try {
      installed = await ref.read(launcherHostApiProvider).getVersionCode();
    } catch (e) {
      debugPrint('Version code unavailable: $e');
    }

    state = code > installed
        ? UpdateState(
            status: UpdateStatus.available,
            availableVersionCode: code,
            lastCheckedAt: record.at,
          )
        : UpdateState(status: UpdateStatus.upToDate, lastCheckedAt: record.at);
  }
}

final appUpdateProvider =
    NotifierProvider<AppUpdateNotifier, UpdateState>(AppUpdateNotifier.new);

/// Watched once, from `_Root`. Returns nothing; it exists for its side effect.
///
/// `ref.watch` on the NOTIFIER, not `ref.read`. Read creates no dependency, and
/// without one the state is collectable the moment the last screen reading it
/// closes, which would forget a finished download. Watching the notifier does
/// not rebuild on state changes, so the microtask below fires exactly once.
///
/// The call is deferred to a microtask rather than awaited inline for the reason
/// `crash_context.dart` sets out at length: work that lands inside the build
/// phase is forbidden, and a provider mounted mid-build that emits during the
/// same flush is the exact shape that broke `icon_theme_screen.dart`.
final appUpdateWatchProvider = Provider<void>((ref) {
  final notifier = ref.watch(appUpdateProvider.notifier);
  Future.microtask(notifier.checkIfStale);
});

/// This build's version NAME, for the About row. "6.0.0", not "6.0.0 (21)".
///
/// ─── THE BUILD NUMBER IS DELIBERATELY NOT HERE ──────────────────────────────
///
/// It is still on the bridge and still read, by `_restore` above, which compares
/// it against the persisted available code. That is the only reader it needs: a
/// build number is a fact about the release process, and the person looking at
/// this row is not in it. "6.0.0 (21)" makes someone wonder which of the two
/// numbers is their version.
///
/// A separate provider from the update state because the two answer different
/// questions and fail differently: this is a package-manager read that cannot
/// fail on any device, and the one above is a Play call that fails on plenty.
/// Folding them together would let a de-Googled ROM hide its own version.
final appVersionProvider =
    FutureProvider<String>((ref) => ref.read(launcherHostApiProvider).getVersionName());

/// The applicationId, spelled once.
///
/// It matches `android { namespace }` and `defaultConfig.applicationId` in
/// `android/app/build.gradle.kts`. Nothing on the bridge returns it, and adding
/// a method that returns a compile-time constant would be a channel call to ask
/// this process what it already is.
const kApplicationId = 'com.mindhunter.g_launcher';
