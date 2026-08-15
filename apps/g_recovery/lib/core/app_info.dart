/// What this build actually is, read from the installed package.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'logging.dart';

/// ─── READ, NOT WRITTEN DOWN ──────────────────────────────────────────────────
///
/// The About row used to carry the version as a string literal, which is a
/// number nobody remembers to change. It survived one release cycle before it
/// would have started lying, and a version number that lies is worse than none:
/// it is the first thing anyone reports in a bug and the one thing they cannot
/// verify themselves.
///
/// PackageManager holds the values gradle put in the manifest, which gradle
/// took from the pubspec. Reading them at the far end of that chain means the
/// only way this can be wrong is if the APK itself is wrong.
@immutable
class GAppInfo {
  const GAppInfo({
    required this.version,
    required this.buildNumber,
    required this.packageName,
  });

  /// versionName. 2.0.0 in the current pubspec.
  final String version;

  /// versionCode, as a string because that is how the platform hands it over.
  /// Use [build] for the parsed form.
  final String buildNumber;

  final String packageName;

  /// Every field empty, which every reader treats as an absent line rather
  /// than as a value to print. There is no 'unknown' to render: a row that
  /// cannot state the version omits it.
  static const GAppInfo unknown = GAppInfo(
    version: '',
    buildNumber: '',
    packageName: '',
  );

  bool get hasVersion => version.isNotEmpty;

  /// Null when the platform gave nothing or gave something unparseable, which
  /// is what lets a caller compare against a Play build number without
  /// inventing a zero.
  int? get build => int.tryParse(buildNumber);

  /// Never throws. An About row is not worth failing a launch over, and the
  /// empty result degrades to a row that simply does not mention a version.
  static Future<GAppInfo> read() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return GAppInfo(
        version: info.version,
        buildNumber: info.buildNumber,
        packageName: info.packageName,
      );
    } on Object catch (cause) {
      GLog.w('package info unavailable', scope: 'boot', cause: cause);
      return unknown;
    }
  }
}

/// Overridden in bootstrap, for the same reason PrefsStore is: resolving it
/// asynchronously inside the tree would make the About row arrive a frame after
/// everything around it.
final Provider<GAppInfo> gAppInfoProvider = Provider<GAppInfo>((Ref ref) {
  throw StateError('gAppInfoProvider was not overridden in bootstrap');
});
