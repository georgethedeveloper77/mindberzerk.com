import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/platform/launcher_api.g.dart';

import '../repositories/app_repository.dart';
import 'launcher_prefs.dart';
import 'prefs_backup.dart';

/// Who the apps in a backup are, and which of them this phone has.
///
/// ─── WHY A BACKUP HAS TO CARRY LABELS ───────────────────────────────────────
///
/// A layout is a set of `componentKey`s, and a key is
/// "packageName/className#userSerial". On the phone that made the backup that
/// resolves to an app with a name and an icon. On a different phone half of
/// them resolve to nothing at all, and a restore screen that can only say
/// "com.termux/.HomeActivity is missing" is asking the user to read package
/// names.
///
/// So v2 records a label and a package per placed app. It is a few kilobytes on
/// a file already carrying photos, and it is what lets a missing app be named
/// in a list, and later be named on the placeholder tile standing in its slot.
///
/// ─── AND WHY IT CARRIES `system` ────────────────────────────────────────────
///
/// There is no way to ask Play whether a package exists without shipping a Play
/// query, so "not installed" cannot be split into "installable" and "gone" from
/// this side. What the SOURCE phone knew is the missing half: an app that was
/// preinstalled there is an OEM app, and an OEM app from a Samsung does not
/// exist for an Infinix at any price. That single bit turns a list of eleven
/// things to go and find into eight you can get and three that were never
/// yours to have.
///
/// ─── PLACEMENTS ONLY ────────────────────────────────────────────────────────
///
/// [referencedKeys] reads the fields that PUT an app somewhere: the dock, home
/// items, folders on both surfaces, and drawer slots. `hiddenApps` and
/// `dockExcluded` hold decisions ABOUT apps rather than placements of them, and
/// a decision about an app this phone does not have costs nothing and needs no
/// reconciling. Carrying them would inflate the list with rows nobody can act
/// on.
class BackupAppRef {
  const BackupAppRef({
    required this.label,
    required this.packageName,
    required this.system,
  });

  final String label;
  final String packageName;

  /// Preinstalled on the phone that made the backup.
  final bool system;

  Map<String, dynamic> toJson() => {
        'label': label,
        'package': packageName,
        'system': system,
      };

  static BackupAppRef? fromJson(Map<String, dynamic> j) {
    final label = j['label'] as String?;
    final pkg = j['package'] as String?;
    if (label == null || pkg == null) return null;
    return BackupAppRef(
      label: label,
      packageName: pkg,
      system: j['system'] as bool? ?? false,
    );
  }
}

/// The package half of a componentKey, which is what Play is addressed by.
///
/// Parsed rather than stored separately for the keys we did not record: the
/// format is fixed and documented on `AppEntry.componentKey`, and an empty
/// result simply means nothing can be offered for that key.
String packageOfComponent(String componentKey) {
  final slash = componentKey.indexOf('/');
  return slash <= 0 ? '' : componentKey.substring(0, slash);
}

/// Every componentKey one distro's prefs actually places somewhere.
Set<String> referencedKeys(LauncherPrefs p) {
  final keys = <String>{
    ...p.favourites,
    for (final i in p.homeItems)
      if (i.componentKey != null) i.componentKey!,
    for (final s in p.drawerSlots)
      if (s.componentKey != null) s.componentKey!,
    for (final f in p.folders) ...f.members,
    for (final f in p.drawerFolders) ...f.members,
  };
  keys.removeWhere((k) => k.isEmpty);
  return keys;
}

/// Which bucket one app in a backup falls into on THIS phone.
enum AppStanding {
  /// Already here. Restores into its slot exactly as it was.
  installed,

  /// Not here, and the source phone did not have it preinstalled either, so
  /// Play is worth offering.
  installable,

  /// Not here, and it was preinstalled on the source phone. An OEM app from
  /// another brand, or something sideloaded. Nothing to offer.
  unavailable,
}

class BackupApp {
  const BackupApp({
    required this.componentKey,
    required this.label,
    required this.packageName,
    required this.standing,
  });

  final String componentKey;

  /// The recorded label, or the package name for a v1 file that recorded
  /// nothing. Never the raw componentKey: the class part is noise to a reader.
  final String label;

  final String packageName;
  final AppStanding standing;
}

/// What a restore would find, and what it would not.
class AppReconciliation {
  const AppReconciliation({
    required this.installed,
    required this.installable,
    required this.unavailable,
  });

  static const empty = AppReconciliation(
    installed: [],
    installable: [],
    unavailable: [],
  );

  final List<BackupApp> installed;
  final List<BackupApp> installable;
  final List<BackupApp> unavailable;

  int get total => installed.length + installable.length + unavailable.length;
  bool get isEmpty => total == 0;
}

/// Bucket the apps a backup places against the apps this phone has.
///
/// [themeIds] narrows it to the distros actually selected for restore, so
/// unticking a distro drops the apps only it placed. Null means every distro in
/// the file.
///
/// ─── MATCHED ON PACKAGE, NOT ON componentKey ────────────────────────────────
///
/// The key carries a class name and a user serial, and both move: an app can
/// rename its launcher activity in an update, and the serial is per profile and
/// differs between two phones by construction. Matching on the whole key would
/// report a freshly installed app as missing on the grounds that its work
/// profile is numbered differently.
///
/// That is also why the reconciliation is advisory. It answers "can this app be
/// found on this phone", which is the question the list is asking. Whether a
/// restored TILE resolves is a separate question with a separate answer, and it
/// belongs to the layout code, not here.
AppReconciliation reconcileApps(
  BackupSummary summary,
  List<AppEntry> installed, {
  Set<String>? themeIds,
}) {
  final themes =
      ((summary.data['themes'] as Map?) ?? const {}).cast<String, dynamic>();

  final keys = <String>{};
  for (final e in themes.entries) {
    if (themeIds != null && !themeIds.contains(e.key)) continue;
    try {
      keys.addAll(
        referencedKeys(
          LauncherPrefs.fromJson((e.value as Map).cast<String, dynamic>()),
        ),
      );
    } catch (_) {
      // A distro whose prefs will not parse contributes no apps rather than
      // failing the whole reconciliation. It will not restore either, and
      // `PrefsBackup.apply` already drops it for the same reason.
    }
  }

  final here = {for (final a in installed) a.packageName};
  final recorded = summary.apps;

  final inPlace = <BackupApp>[];
  final gettable = <BackupApp>[];
  final gone = <BackupApp>[];

  for (final key in keys) {
    final ref = recorded[key];
    final pkg = ref?.packageName ?? packageOfComponent(key);
    if (pkg.isEmpty) continue;

    final app = BackupApp(
      componentKey: key,
      // Falls back to the package for a v1 file, which recorded no labels. A
      // package name is poor but readable; the raw componentKey is neither.
      label: ref?.label ?? pkg,
      packageName: pkg,
      standing: here.contains(pkg)
          ? AppStanding.installed
          : (ref?.system ?? false)
              ? AppStanding.unavailable
              : AppStanding.installable,
    );

    switch (app.standing) {
      case AppStanding.installed:
        inPlace.add(app);
      case AppStanding.installable:
        gettable.add(app);
      case AppStanding.unavailable:
        gone.add(app);
    }
  }

  int byLabel(BackupApp a, BackupApp b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());

  return AppReconciliation(
    installed: inPlace..sort(byLabel),
    installable: gettable..sort(byLabel),
    unavailable: gone..sort(byLabel),
  );
}

/// Open one app's Play listing.
///
/// `market://` first, so the Play app opens directly rather than the browser
/// bouncing through a redirect. The https form is the fallback for a device
/// with no Play app at all, which is every de-Googled ROM and a fair number of
/// the cheaper imports this launcher targets. False means neither worked and
/// the caller should say so rather than let the tap do nothing.
///
/// Async because every Pigeon method is, on this side of the bridge. `@async`
/// in the schema decides whether KOTLIN gets a callback; the Dart wrapper
/// returns a Future either way, since the call is a message across a channel
/// no matter what the far end does with it.
final openPlayListingProvider = Provider<Future<bool> Function(String)>((ref) {
  return (packageName) async {
    final api = ref.read(launcherHostApiProvider);
    const view = 'android.intent.action.VIEW';
    if (await api.openIntent(view, 'market://details?id=$packageName', null)) {
      return true;
    }
    return api.openIntent(
      view,
      'https://play.google.com/store/apps/details?id=$packageName',
      null,
    );
  };
});
