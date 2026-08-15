/// Play in-app updates, without the nagging.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../logging.dart';

/// Where an update currently is.
///
/// ─── UNAVAILABLE IS NOT AN ERROR ─────────────────────────────────────────────
///
/// AppUpdateManager only answers for a build the Play Store itself installed.
/// A sideload, a flutter run install, a device with no Play Services and an
/// APK from a mirror all throw from checkForUpdate, and none of them is a
/// fault the user can act on. They all land on [unavailable], which the UI
/// draws as nothing at all rather than as a failure.
///
/// This is also why the whole feature is invisible during development. On the
/// test device this state machine never leaves [unavailable].
enum GUpdateStage {
  /// Nothing has been asked yet this launch.
  idle,

  checking,

  /// Play answered and this build is the newest one.
  current,

  /// A newer build exists and nothing is downloading.
  available,

  /// A flexible update is being fetched in the background.
  downloading,

  /// Fetched and sitting on disk. One tap installs and restarts.
  ready,

  /// Play could not or would not answer.
  unavailable,
}

@immutable
class GUpdateState {
  const GUpdateState({
    required this.stage,
    this.availableVersionCode,
    this.stalenessDays,
    this.priority = 0,
    this.flexibleAllowed = false,
    this.immediateAllowed = false,
  });

  final GUpdateStage stage;

  /// The versionCode waiting on Play. Null everywhere except [available],
  /// [downloading] and [ready], and rendered as an absent line rather than a
  /// placeholder when it is null.
  final int? availableVersionCode;

  /// How long Play has known about this update. Null when Play does not say,
  /// which it often does not.
  final int? stalenessDays;

  /// inAppUpdatePriority from the Play release, 0 to 5. Set per release under
  /// Edits.tracks.releases and NOT editable from the Play Console UI, so it is
  /// 0 for every release published by hand.
  final int priority;

  final bool flexibleAllowed;
  final bool immediateAllowed;

  static const GUpdateState idle = GUpdateState(stage: GUpdateStage.idle);

  static const GUpdateState unavailable = GUpdateState(
    stage: GUpdateStage.unavailable,
  );

  /// The threshold at which an update stops being an offer.
  ///
  /// Reserved for a release that fixes something that eats data or loses it.
  /// Nothing below this ever takes the screen: an app that blocks itself to
  /// announce a new icon set has taught the user to dread opening it.
  static const int urgentPriority = 4;

  bool get isUrgent => priority >= urgentPriority;

  /// Whether there is anything worth putting in front of the user.
  bool get hasNews =>
      stage == GUpdateStage.available ||
      stage == GUpdateStage.downloading ||
      stage == GUpdateStage.ready;

  GUpdateState withStage(GUpdateStage value) => GUpdateState(
    stage: value,
    availableVersionCode: availableVersionCode,
    stalenessDays: stalenessDays,
    priority: priority,
    flexibleAllowed: flexibleAllowed,
    immediateAllowed: immediateAllowed,
  );

  @override
  bool operator ==(Object other) =>
      other is GUpdateState &&
      other.stage == stage &&
      other.availableVersionCode == availableVersionCode &&
      other.stalenessDays == stalenessDays &&
      other.priority == priority &&
      other.flexibleAllowed == flexibleAllowed &&
      other.immediateAllowed == immediateAllowed;

  @override
  int get hashCode => Object.hash(
    stage,
    availableVersionCode,
    stalenessDays,
    priority,
    flexibleAllowed,
    immediateAllowed,
  );
}

/// What the caller asked for, and what happened.
///
/// Returned rather than messaged, so the widget that started the action is the
/// one that decides whether to say anything. A refresh fired from a lifecycle
/// resume should be silent; the same refresh fired from a tap should not be.
enum GUpdateOutcome { done, denied, failed, notPossible }

/// Owns the update state. Never acts on its own.
///
/// ─── ONE AUTOMATIC BEHAVIOUR, AND IT IS A READ ───────────────────────────────
///
/// This checks. It does not download, it does not prompt, and it does not take
/// the screen. Every state change that costs the user data or attention starts
/// at a tap. That includes the case Play would rather we handled ourselves: an
/// immediate update that was interrupted comes back as
/// developerTriggeredUpdateInProgress, and Google's guidance is to resume it on
/// the spot. Resuming means a full screen Play sheet appearing over whatever
/// the user opened the app to do, so it is surfaced as an offer instead.
class GUpdateController extends Notifier<GUpdateState> {
  /// The shortest gap between two checks that nobody asked for.
  ///
  /// The shell refreshes on every resume, and a resume happens each time
  /// someone comes back from the camera or the file manager. Without this the
  /// app would query Play a dozen times in a session to learn the same answer.
  static const Duration _autoGap = Duration(minutes: 30);

  DateTime? _lastAutoCheck;
  StreamSubscription<InstallStatus>? _installs;
  bool _closed = false;
  bool _busy = false;

  @override
  GUpdateState build() {
    if (!_supported) return GUpdateState.unavailable;

    // The only way to see a flexible download finish while the user is doing
    // something else. Polling checkForUpdate would catch it eventually and
    // would also mean asking Play a question on a timer forever.
    try {
      _installs = InAppUpdate.installUpdateListener.listen(
        _onInstallStatus,
        onError: (Object cause) {
          GLog.w('install listener failed', scope: 'update', cause: cause);
        },
      );
    } on Object catch (cause) {
      GLog.w('install listener unavailable', scope: 'update', cause: cause);
    }

    ref.onDispose(() {
      _closed = true;
      _installs?.cancel();
    });

    return GUpdateState.idle;
  }

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Asks Play what it has.
  ///
  /// [force] skips the throttle and is what a Check for updates row passes. An
  /// automatic call from a lifecycle resume leaves it false and will often do
  /// nothing at all, which is the point.
  Future<GUpdateOutcome> refresh({bool force = false}) async {
    if (!_supported) return GUpdateOutcome.notPossible;
    if (_busy) return GUpdateOutcome.notPossible;

    final DateTime now = DateTime.now();
    if (!force && _lastAutoCheck != null) {
      if (now.difference(_lastAutoCheck!) < _autoGap) {
        return GUpdateOutcome.done;
      }
    }
    // Recorded before the call, not after. A check that hangs on a bad
    // connection should still hold off the next one.
    _lastAutoCheck = now;

    _busy = true;
    // Only a deliberate check says so on screen. A silent background check
    // that flipped a row to Checking and back would be a flicker nobody
    // asked to see.
    if (force) _record(state.withStage(GUpdateStage.checking));

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      _record(_readInfo(info));
      return GUpdateOutcome.done;
    } on Object catch (cause) {
      // Not owned by Play, no Play Services, no network. All the same answer.
      GLog.w('update check did not answer', scope: 'update', cause: cause);
      _record(GUpdateState.unavailable);
      return GUpdateOutcome.notPossible;
    } finally {
      _busy = false;
    }
  }

  /// Starts a background download. Play shows its own consent sheet first.
  Future<GUpdateOutcome> download() async {
    if (state.stage != GUpdateStage.available || !state.flexibleAllowed) {
      return GUpdateOutcome.notPossible;
    }

    _record(state.withStage(GUpdateStage.downloading));
    try {
      final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
      switch (result) {
        case AppUpdateResult.success:
          // Not ready yet. success here means the download finished, and the
          // listener has usually already moved the stage. Setting it again is
          // harmless and covers the case where the stream never fired.
          _record(state.withStage(GUpdateStage.ready));
          return GUpdateOutcome.done;
        case AppUpdateResult.userDeniedUpdate:
          _record(state.withStage(GUpdateStage.available));
          return GUpdateOutcome.denied;
        case AppUpdateResult.inAppUpdateFailed:
          _record(state.withStage(GUpdateStage.available));
          return GUpdateOutcome.failed;
      }
    } on Object catch (cause) {
      GLog.w('flexible update failed', scope: 'update', cause: cause);
      _record(state.withStage(GUpdateStage.available));
      return GUpdateOutcome.failed;
    }
  }

  /// Installs what was downloaded. The app is killed and restarted by Play, so
  /// nothing after this call is guaranteed to run.
  Future<GUpdateOutcome> install() async {
    if (state.stage != GUpdateStage.ready) return GUpdateOutcome.notPossible;
    try {
      await InAppUpdate.completeFlexibleUpdate();
      return GUpdateOutcome.done;
    } on Object catch (cause) {
      GLog.w('install did not complete', scope: 'update', cause: cause);
      return GUpdateOutcome.failed;
    }
  }

  /// The full screen Play flow, which downloads and installs in one go.
  ///
  /// Offered only where [GUpdateState.isUrgent] or where flexible is not
  /// allowed, because it takes the whole screen and cannot be backgrounded.
  Future<GUpdateOutcome> updateNow() async {
    if (!state.immediateAllowed) return GUpdateOutcome.notPossible;
    try {
      final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();
      switch (result) {
        case AppUpdateResult.success:
          return GUpdateOutcome.done;
        case AppUpdateResult.userDeniedUpdate:
          return GUpdateOutcome.denied;
        case AppUpdateResult.inAppUpdateFailed:
          return GUpdateOutcome.failed;
      }
    } on Object catch (cause) {
      GLog.w('immediate update failed', scope: 'update', cause: cause);
      return GUpdateOutcome.failed;
    }
  }

  /// Reads one AppUpdateInfo into a state.
  ///
  /// developerTriggeredUpdateInProgress is folded into [GUpdateStage.available]
  /// rather than given a stage of its own. From the user's side it is the same
  /// sentence: there is a newer build and you have not got it yet. The
  /// difference only matters to Play, and Play remembers it without our help.
  static GUpdateState _readInfo(AppUpdateInfo info) {
    switch (info.updateAvailability) {
      case UpdateAvailability.updateAvailable:
      case UpdateAvailability.developerTriggeredUpdateInProgress:
        return GUpdateState(
          stage: _stageFor(info.installStatus),
          availableVersionCode: info.availableVersionCode,
          stalenessDays: info.clientVersionStalenessDays,
          priority: info.updatePriority,
          flexibleAllowed: info.flexibleUpdateAllowed,
          immediateAllowed: info.immediateUpdateAllowed,
        );
      case UpdateAvailability.updateNotAvailable:
        return const GUpdateState(stage: GUpdateStage.current);
      case UpdateAvailability.unknown:
        return GUpdateState.unavailable;
    }
  }

  /// An update already part way through, picked up from a previous session.
  ///
  /// downloaded is the one that matters: a flexible download that finished
  /// while the app was closed leaves the file on disk and Play waiting to be
  /// told to install it. Without this the user would be offered the download
  /// again and Play would hand back the same finished file instantly, which
  /// looks like the button did nothing.
  static GUpdateStage _stageFor(InstallStatus status) {
    switch (status) {
      case InstallStatus.pending:
      case InstallStatus.downloading:
        return GUpdateStage.downloading;
      case InstallStatus.downloaded:
      case InstallStatus.installing:
        return GUpdateStage.ready;
      case InstallStatus.installed:
      case InstallStatus.failed:
      case InstallStatus.canceled:
      case InstallStatus.unknown:
        return GUpdateStage.available;
    }
  }

  void _onInstallStatus(InstallStatus status) {
    if (!state.hasNews && state.stage != GUpdateStage.checking) return;
    _record(state.withStage(_stageFor(status)));
  }

  void _record(GUpdateState next) {
    if (_closed || next == state) return;
    state = next;
  }
}

final NotifierProvider<GUpdateController, GUpdateState> gUpdateProvider =
    NotifierProvider<GUpdateController, GUpdateState>(GUpdateController.new);
