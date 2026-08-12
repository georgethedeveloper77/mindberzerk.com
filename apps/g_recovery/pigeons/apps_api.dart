import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the app storage bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/apps_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/apps_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/apps/AppsApi.g.kt
///
/// ─── WHAT THIS CANNOT DO, STATED AT THE TOP ──────────────────────────────────
///
/// It cannot clear another app's cache. clearApplicationUserData has been
/// system only since Android 6. Every app on Play advertising "clear all cache"
/// either drives the screen through an accessibility service, which is against
/// policy, or reports a number it invented.
///
/// So there is no clear method here, and there never will be. What exists is
/// [openAppSettings], which takes the user to the one screen where the button
/// genuinely works.
///
/// ─── USAGE STATS FIRST, PACKAGE VISIBILITY SECOND ────────────────────────────
///
/// Package names come from UsageStatsManager, which needs Usage Access, a
/// settings toggle rather than a Play restricted permission. QUERY_ALL_PACKAGES
/// is declared in the manifest as a widener, not a dependency: if Play refuses
/// that declaration the list simply covers apps the user has actually used,
/// which is the set that matters for storage anyway.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 AppEntry   130 AppsState
///
/// ADD NEW TYPES AT THE END. NO ENUMS, ever.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/apps_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/apps/AppsApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.apps'),
    dartPackageName: 'g_recovery',
  ),
)

/// One installed app and what it occupies. Codec 129.
class AppEntry {
  AppEntry({
    required this.packageName,
    required this.label,
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
    required this.system,
    required this.lastUsedMillis,
  });

  final String packageName;
  final String label;

  /// The APK and its libraries.
  final int appBytes;

  /// Everything the app saved: accounts, messages, downloaded media.
  ///
  /// SEPARATE FROM CACHE, and the distinction is the whole point of this
  /// screen. Cache can be thrown away with no loss. Data is the app's actual
  /// content, and clearing it signs you out and deletes what you had.
  final int dataBytes;

  /// Rebuildable. This is the number a person is looking for.
  final int cacheBytes;

  final bool system;

  /// Null when the app has never been opened, or when usage access is off.
  final int? lastUsedMillis;
}

/// Whether this can work at all. Codec 130.
class AppsState {
  AppsState({
    required this.usageAccess,
    required this.totalBytes,
    required this.cacheBytes,
    required this.count,
  });

  /// Usage Access, granted on a settings screen. Without it no size can be read
  /// at all, so the UI asks before it shows an empty list.
  final bool usageAccess;

  final int totalBytes;
  final int cacheBytes;
  final int count;
}

@HostApi()
abstract class AppsHostApi {
  @async
  AppsState state();

  /// Opens the Usage Access settings screen.
  @async
  bool requestUsageAccess();

  /// Every app this phone will admit to, largest first.
  ///
  /// Slow. StorageStatsManager reads each package separately and a phone with
  /// two hundred apps takes a few seconds, which is why the caller shows a
  /// loading state rather than blocking.
  @async
  List<AppEntry> apps();

  /// The system storage screen for one app, where Clear cache actually works.
  @async
  bool openAppSettings(String packageName);
}
