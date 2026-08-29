/// THE ONLY SEAM. Everything the shell needs from the rest of the app is
/// declared here, so the command layer imports no repository, no Pigeon class
/// and no provider, and stays testable with a fake.
///
/// Every reading is NULLABLE, and null means unavailable, never zero. A command
/// that gets null prints no row rather than a placeholder, which is the same
/// rule the conky and the waybar already keep and the reason nothing in this
/// shell can print a number it did not measure.
///
/// Pure Dart. The implementation that wires this to `appListProvider`,
/// `systemStatsProvider`, `deviceInfoProvider` and the SAF bridge lives outside
/// this folder and is the only file that knows they exist.
library;

import 'term_path.dart';

/// One launchable app, as `/apps` renders it.
class TermApp {
  const TermApp({
    required this.slug,
    required this.label,
    required this.packageName,
    this.sizeBytes,
    this.targetSdk,
    this.system = false,
  });

  /// The entry name inside `/apps`.
  ///
  /// A slugged label, not the package name: nobody types
  /// `org.mozilla.firefox`. Labels collide, and on Transsion devices they
  /// collide constantly, so the adapter appends `-2`, `-3` on a clash. `ls -l`
  /// prints the package beside it, which is where the truthful identifier goes.
  final String slug;

  final String label;
  final String packageName;
  final int? sizeBytes;
  final int? targetSdk;
  final bool system;
}

enum TermEntryKind { directory, file, app }

/// One row in a listing, whichever namespace produced it.
class TermEntry {
  const TermEntry({
    required this.name,
    required this.kind,
    this.sizeBytes,
    this.modified,
    this.subtitle,
    this.childCount,
  });

  final String name;
  final TermEntryKind kind;
  final int? sizeBytes;
  final DateTime? modified;

  /// The package name for an app, null for a file.
  final String? subtitle;

  final int? childCount;

  /// Can `cd` enter this?
  ///
  /// AN APP CANNOT, and this getter used to say it could, so `ls /apps` printed
  /// `firefox/` while `cd /apps/firefox` answered "an app is a leaf". A trailing
  /// slash is a promise, and that one was refused one keystroke later. The
  /// display and the behaviour now come from the same fact.
  bool get isDirectory => kind == TermEntryKind.directory;

  /// Painted like a folder rather than like plain data, because an app is not
  /// a file either. It is the one thing here that is neither, which is exactly
  /// what makes `/apps` worth having.
  bool get isApp => kind == TermEntryKind.app;

  /// Accent ink: everything except an ordinary file.
  bool get standsOut => kind != TermEntryKind.file;
}

/// Did it work, and if not, why not.
///
/// EVERY action the host performs returns this, not just the file ones. A
/// `Future<void>` cannot tell the shell that nothing happened, and a bool
/// cannot tell it the difference between a device with no flash unit and a
/// build where the torch was never wired. Both of those printed a confident
/// sentence in the first cut of this adapter, which is the failure the whole
/// shell exists to refuse.
///
/// `message` is printed as typed, so it is written for the person reading it.
class TermOutcome {
  const TermOutcome.ok([this.message]) : failed = false;
  const TermOutcome.failed(this.message) : failed = true;

  final bool failed;
  final String? message;
}

class TermStorage {
  const TermStorage({required this.totalBytes, required this.usedBytes});
  final int totalBytes;
  final int usedBytes;
  int get freeBytes => totalBytes - usedBytes;
  double get fraction => totalBytes == 0 ? 0 : usedBytes / totalBytes;
}

class TermMemory {
  const TermMemory({required this.totalMb, required this.usedMb, this.cachedMb});
  final int totalMb;
  final int usedMb;
  final int? cachedMb;
  int get freeMb => totalMb - usedMb;
  double get fraction => totalMb == 0 ? 0 : usedMb / totalMb;
}

class TermBattery {
  const TermBattery({this.percent, this.celsius, this.health, this.charging});
  final int? percent;
  final double? celsius;
  final String? health;
  final bool? charging;
}

/// What the device will actually tell us about the network.
///
/// NO SSID AND NO IP, and that is not an omission to fill in later. Reading the
/// network NAME needs location permission on Android 10 and up, and this
/// ecosystem does not ask for location to draw a desktop widget. `SystemStats`
/// carries the TRANSPORT for exactly that reason, so the shell prints the
/// transport, and a `net` that printed an ssid would be a command that forced a
/// permission decision the rest of the app already refused to make.
///
/// Rates, not totals, because the poller computes rates and a cumulative
/// counter across a screen-off gap is the average over a night reported as if
/// it were happening now.
class TermNetwork {
  const TermNetwork({
    this.transport,
    this.downBytesPerSec,
    this.upBytesPerSec,
    this.connected,
  });

  /// "wifi", "cellular", "ethernet", "vpn", "none", or null when the device
  /// would not answer.
  final String? transport;

  final double? downBytesPerSec;
  final double? upBytesPerSec;
  final bool? connected;
}

class TermDevice {
  const TermDevice({
    this.model,
    this.androidRelease,
    this.sdkInt,
    this.user,
    this.host,
  });
  final String? model;
  final String? androidRelease;
  final int? sdkInt;

  /// `george` and `infinix` in `george@infinix`.
  final String? user;
  final String? host;
}

/// Where a launcher command lands.
enum TermLauncherPage { settings, themes, wallpaper, icons }

/// A system surface the shell can open but cannot operate.
///
/// `wifi` and `bt` exist as commands precisely so they can SAY that Android
/// stopped letting an app toggle them at 10, instead of a shell that pretends
/// or a shell that leaves the word out and looks incomplete.
enum TermSystemPanel { wifi, bluetooth, doNotDisturb }

abstract class TermHost {
  const TermHost();

  // ── /apps ───────────────────────────────────────────────────────────
  /// Every launchable app, already slugged and collision resolved.
  Future<List<TermApp>> apps();

  Future<void> launchApp(TermApp app);

  /// Opens the system uninstall prompt.
  ///
  /// Returns null when the prompt opened, or the REASON it did not. Native
  /// already computes a specific reason (a preinstalled app, a work profile, no
  /// installer on the device), and `AppList.uninstall` carries it back as a
  /// status string. Returning void here would throw away the one thing the
  /// system went to the trouble of telling us and leave the shell claiming an
  /// uninstall was under way when nothing opened.
  ///
  /// A null return is still not a promise the app is gone. The user confirms in
  /// the system dialog, and the disappearance arrives separately through
  /// `onAppsChanged`, because the OS is the thing that knows.
  Future<String?> requestUninstall(TermApp app);

  Future<void> openAppSettings(TermApp app);

  // ── ~ ───────────────────────────────────────────────────────────────
  /// Whether a folder has been granted yet.
  bool get filesGranted;

  /// Fires `ACTION_OPEN_DOCUMENT_TREE`. True when a folder came back.
  Future<bool> requestFilesAccess();

  /// Null means the path does not exist or is not readable.
  Future<List<TermEntry>?> list(TermPath path);
  Future<TermEntry?> stat(TermPath path);

  /// Up to [maxLines] lines. Null for a path that is not readable text, which
  /// is how `cat` tells a binary from a missing file.
  Future<List<String>?> readLines(TermPath path, {int maxLines = 200});

  /// Recursive size. Null when it could not be measured, so `du` omits the row.
  Future<int?> sizeOf(TermPath path);

  Future<TermOutcome> makeDirectory(TermPath path);
  Future<TermOutcome> createFile(TermPath path);
  Future<TermOutcome> delete(TermPath path, {required bool recursive});
  Future<TermOutcome> copy(TermPath from, TermPath to);
  Future<TermOutcome> move(TermPath from, TermPath to);

  /// Hands the file to whichever app owns the type.
  Future<TermOutcome> openFile(TermPath path);

  // ── readings ────────────────────────────────────────────────────────
  Future<TermStorage?> storage();
  Future<TermMemory?> memory();
  Future<TermBattery?> battery();
  Future<TermNetwork?> network();
  Future<int?> cpuPercent();
  Duration? get uptime;
  TermDevice get device;

  // ── device ──────────────────────────────────────────────────────────
  //
  // All four return [TermOutcome] rather than void or bool, because "it did not
  // happen" has several causes and the shell has to print the right one. A
  // device with no flash unit and a build that never wired the torch are not
  // the same sentence.
  Future<TermOutcome> setTorch({required bool on});

  /// [steps] is positive, negative, or a large negative for mute. The message
  /// carries the resulting level, so the command never has to guess at it.
  Future<TermOutcome> nudgeVolume(int steps);

  Future<TermOutcome> openSystemPanel(TermSystemPanel panel);
  Future<TermOutcome> openLauncherPage(TermLauncherPage page);

  /// Commands this build genuinely cannot perform.
  ///
  /// ─── WHY THE SHELL NEEDS TO BE TOLD, RATHER THAN FINDING OUT ─────────────
  ///
  /// A command that always fails is worse than a command that is absent: it
  /// takes a row in the `?` sheet, it takes a match row while the user types,
  /// and it teaches a word that does nothing. So the discovery surfaces hide
  /// these names.
  ///
  /// Typing one anyway still RESOLVES, and the command explains itself rather
  /// than answering "command not found". Someone who read about `torch`
  /// somewhere deserves to be told it is not in this build, not told it does
  /// not exist.
  Set<String> get unwired => const <String>{};

  // ── persistence ─────────────────────────────────────────────────────
  /// Aliases and the run count live in prefs as JSON, the same way every other
  /// preference in this app does. The run count is here because the suggestion
  /// block under an empty prompt stops at eight, and a teaching surface that
  /// forgets is a teaching surface that nags.
  Future<Map<String, String>> loadAliases();
  Future<void> saveAliases(Map<String, String> aliases);
  Future<int> loadRunCount();
  Future<void> saveRunCount(int count);
}
