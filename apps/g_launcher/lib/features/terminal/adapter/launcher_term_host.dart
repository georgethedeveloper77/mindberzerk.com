/// The adapter. The ONLY file that imports both the shell and the rest of the
/// launcher, which is what keeps every command file free of a repository.
///
/// Everything it maps was read from the source it maps: `shellAppsProvider` for
/// the app list (so `/apps` respects per-theme hidden apps), `AppList` for
/// launch, info and uninstall, `usageProvider` for the launch record,
/// `systemStatsProvider` for every reading, `deviceInfoProvider` for the model,
/// `prefsStoreProvider` for aliases.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/data/usage/usage_repository.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../design/terminal_tokens.dart';
import '../../../engine/effective_theme.dart';
import '../../../platform/launcher_api.g.dart';
import '../../../system/system_stats.dart';
import '../term_host.dart';
import '../term_path.dart';
import 'app_slugs.dart';
import 'files_bridge.dart';

/// Keyed by [EffectiveTheme] for the same reason `shellAppsProvider` is: hidden
/// apps are a per-theme preference, so `/apps` in Ubuntu and `/apps` in KDE are
/// legitimately different listings. The theme is used ONLY as the key and as
/// the argument to `shellAppsProvider`; nothing here reads its styling.
/// Opens one of the launcher's own pages.
///
/// A CALLBACK rather than something the adapter does itself, because opening a
/// page needs a BuildContext and an adapter has none. The view has both, so the
/// view supplies this, and `GshShell` takes it as a REQUIRED parameter: wiring
/// the terminal without a navigator is a compile error rather than four
/// commands that quietly stop working.
typedef TermPageOpener = Future<TermOutcome> Function(TermLauncherPage page);

/// Returns [LauncherTermHost], not [TermHost], so the view can install the
/// opener on it. Everything else reads it through the interface.
final launcherTermHostProvider =
    Provider.family<LauncherTermHost, EffectiveTheme>((ref, theme) {
  final LauncherTermHost host = LauncherTermHost(ref, theme);

  // LISTEN, do not watch. `systemStatsProvider` is a stream and watching it here
  // would rebuild this provider on every three-second sample, throwing away the
  // files bridge's cached grant flag and re-slugging the whole app list forty
  // times a minute. The listener also keeps the stream subscribed for as long
  // as the terminal is on screen, which is what makes the first `df` instant
  // rather than a three-second wait.
  ref.listen(
    systemStatsProvider,
    (previous, next) {
      // hasValue, not asData: a stream in flight still carries its previous
      // value and asData is null right through it.
      if (next.hasValue) host.cacheStats(next.requireValue);
    },
    fireImmediately: true,
  );

  ref.onDispose(host.dispose);
  return host;
});

class LauncherTermHost extends TermHost {
  LauncherTermHost(this._ref, this._theme) {
    // Fire and forget: the grant flag starts false, which is the safe answer,
    // and corrects itself before the user can type a storage verb.
    _files.refreshGrant();
  }

  final Ref _ref;
  final EffectiveTheme _theme;
  final FilesBridge _files = FilesBridge();

  SystemStats? _stats;
  void cacheStats(SystemStats stats) => _stats = stats;
  void dispose() {}

  // ── /apps ───────────────────────────────────────────────────────────
  //
  // Slugs are recomputed whenever the underlying list identity changes, and
  // cached otherwise. Native pushes the WHOLE list on every install, uninstall
  // and profile switch (see AppList), so identity comparison is exactly the
  // right trigger: a new list object means the set really did change.
  List<AppEntry>? _sourceList;
  List<TermApp> _apps = const <TermApp>[];
  Map<String, AppEntry> _entryBySlug = const <String, AppEntry>{};

  @override
  Future<List<TermApp>> apps() async {
    final List<AppEntry> source = _ref.read(shellAppsProvider(_theme));
    if (identical(source, _sourceList)) return _apps;

    final List<String> slugs = assignSlugs(source.map((AppEntry e) => e.label));
    final List<TermApp> apps = <TermApp>[];
    final Map<String, AppEntry> bySlug = <String, AppEntry>{};

    for (var i = 0; i < source.length; i++) {
      final AppEntry entry = source[i];
      apps.add(TermApp(
        slug: slugs[i],
        label: entry.label,
        packageName: packageOfComponentKey(entry.componentKey),
        // NO SIZE AND NO TARGET SDK. Neither is on the app list today, and an
        // estimate would be the first invented number in the shell. `du /apps`
        // therefore reports that it measured nothing, which is true. See the
        // handoff: one appended field on AppEntry turns this on.
      ));
      bySlug[slugs[i]] = entry;
    }

    _sourceList = source;
    _apps = apps;
    _entryBySlug = bySlug;
    return apps;
  }

  AppEntry? _entryFor(TermApp app) => _entryBySlug[app.slug];

  @override
  Future<void> launchApp(TermApp app) async {
    final AppEntry? entry = _entryFor(app);
    if (entry == null) return;
    await _ref.read(appListProvider.notifier).launch(entry);
    // Every other launch surface records, and the palette is named in
    // usage_repository's own list of the three features that read this. A
    // terminal launch that did not record would slowly bias the dock against
    // the way this user actually opens things.
    await _ref.read(usageProvider.notifier).record(entry.componentKey);
  }

  @override
  Future<String?> requestUninstall(TermApp app) async {
    final AppEntry? entry = _entryFor(app);
    if (entry == null) return 'no longer installed';
    final String status =
        await _ref.read(appListProvider.notifier).uninstall(entry);
    if (UninstallStatus.succeeded(status)) return null;
    return _uninstallReason(status);
  }

  /// The status vocabulary, in the words the shell prints.
  ///
  /// An UNRECOGNISED status is a failure, not a success, which is the rule
  /// `UninstallStatus.succeeded` already enforces. This just gives each known
  /// one a sentence, because "refused" on its own tells the user nothing about
  /// which of five different things happened.
  String _uninstallReason(String status) => switch (status) {
        UninstallStatus.unknownApp => 'the system no longer has this app',
        UninstallStatus.systemApp => 'a preinstalled app cannot be uninstalled',
        UninstallStatus.workProfile =>
          'work profile apps are managed by your organisation',
        UninstallStatus.noInstaller =>
          'this device has no package installer to open',
        UninstallStatus.refused => 'the system refused to open the prompt',
        _ => 'the system did not open the prompt',
      };

  @override
  Future<void> openAppSettings(TermApp app) async {
    final AppEntry? entry = _entryFor(app);
    if (entry == null) return;
    await _ref.read(appListProvider.notifier).openInfo(entry);
  }

  // ── ~ ───────────────────────────────────────────────────────────────
  @override
  bool get filesGranted => _files.granted;

  @override
  Future<bool> requestFilesAccess() => _files.requestGrant();

  @override
  Future<List<TermEntry>?> list(TermPath path) => _files.list(path);

  @override
  Future<TermEntry?> stat(TermPath path) => _files.stat(path);

  @override
  Future<List<String>?> readLines(TermPath path, {int maxLines = 200}) =>
      _files.readLines(path, maxLines);

  @override
  Future<int?> sizeOf(TermPath path) => _files.size(path);

  @override
  Future<TermOutcome> makeDirectory(TermPath path) =>
      _files.makeDirectory(path);

  @override
  Future<TermOutcome> createFile(TermPath path) => _files.createFile(path);

  @override
  Future<TermOutcome> delete(TermPath path, {required bool recursive}) =>
      _files.delete(path, recursive);

  @override
  Future<TermOutcome> copy(TermPath from, TermPath to) => _files.copy(from, to);

  @override
  Future<TermOutcome> move(TermPath from, TermPath to) => _files.move(from, to);

  @override
  Future<TermOutcome> openFile(TermPath path) => _files.open(path);

  // ── readings ────────────────────────────────────────────────────────
  //
  // All five read the SAME snapshot the conky and the waybar read. A terminal
  // that disagreed with the desklet two inches above it would discredit both.
  Future<SystemStats?> _snapshot() async {
    final SystemStats? cached = _stats;
    if (cached != null) return cached;
    try {
      // The first sample, if the listener has not landed one yet.
      final SystemStats first = await _ref.read(systemStatsProvider.future);
      _stats = first;
      return first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TermStorage?> storage() async {
    final SystemStats? s = await _snapshot();
    if (s == null || !s.hasStorage) return null;
    return TermStorage(
      totalBytes: s.storageTotalBytes!,
      usedBytes: s.storageUsedBytes!,
    );
  }

  @override
  Future<TermMemory?> memory() async {
    final SystemStats? s = await _snapshot();
    if (s == null || !s.hasMemory) return null;
    // The snapshot carries gigabytes as doubles. Rounding to megabytes here is
    // the only conversion, and it happens once.
    return TermMemory(
      totalMb: (s.memTotalGb! * 1024).round(),
      usedMb: (s.memUsedGb! * 1024).round(),
    );
  }

  @override
  Future<TermBattery?> battery() async {
    final SystemStats? s = await _snapshot();
    if (s == null) return null;
    return TermBattery(
      percent: s.batteryPercent,
      celsius: s.batteryTempC,
      charging: s.batteryCharging,
      // No health field on the snapshot, so no health row. Absent beats
      // inferred: "good" derived from a temperature would be a guess wearing a
      // medical word.
    );
  }

  @override
  Future<TermNetwork?> network() async {
    final SystemStats? s = await _snapshot();
    if (s == null) return null;
    return TermNetwork(
      transport: s.transport,
      downBytesPerSec: s.netDownBytesPerSec,
      upBytesPerSec: s.netUpBytesPerSec,
      connected: s.wifiConnected,
    );
  }

  @override
  Future<int?> cpuPercent() async => (await _snapshot())?.cpuPercent;

  @override
  Duration? get uptime => _stats?.uptime;

  @override
  TermDevice get device {
    final info = _ref.read(deviceInfoProvider).asData?.value;
    return TermDevice(
      model: info?.deviceModel,
      // The prompt native already composes, split back into its two halves so
      // the shell can put them in a per-distro prompt template. A prompt with
      // no @ in it is used whole as the host, which is what a bare `localhost`
      // style value should do.
      user: _promptPart(info?.prompt, before: true),
      host: _promptPart(info?.prompt, before: false),
    );
  }

  static String? _promptPart(String? prompt, {required bool before}) {
    if (prompt == null || prompt.isEmpty) return null;
    final int at = prompt.indexOf('@');
    if (at < 0) return before ? null : prompt;
    return before ? prompt.substring(0, at) : prompt.substring(at + 1);
  }

  // ── device controls ─────────────────────────────────────────────────
  //
  // NOT WIRED YET, and saying so exactly is the point. Each needs a native call
  // that does not exist: CameraManager.setTorchMode, AudioManager, and the
  // settings panel intents.
  //
  // The first cut of this file returned false and null here, which the commands
  // rendered as "no flash unit on this device" and "media volume unreadable".
  // Both are confident claims about hardware nobody asked. These say what is
  // true instead, and [unwired] keeps the words out of the discovery surfaces
  // so nobody is taught a command that cannot run.
  /// Everything this build cannot perform, in ONE place.
  ///
  /// `wall` and `icons` are here for a different reason than the rest: the
  /// pages exist, they are just not reachable from outside settings_screen.dart
  /// yet. See the last case in `view/launcher_pages.dart`, which is the other
  /// half of this and the file to change at the same time as this line.
  @override
  Set<String> get unwired => const <String>{
        'torch',
        'vol',
        'wifi',
        'bt',
        'dnd',
        'wall',
        'icons',
      };

  @override
  Future<TermOutcome> setTorch({required bool on}) async =>
      const TermOutcome.failed('the torch is not available in this build');

  @override
  Future<TermOutcome> nudgeVolume(int steps) async =>
      const TermOutcome.failed('volume is not available in this build');

  @override
  Future<TermOutcome> openSystemPanel(TermSystemPanel panel) async =>
      const TermOutcome.failed(
          'settings panels are not available in this build');

  /// Installed by the view. See [TermPageOpener].
  TermPageOpener? pageOpener;

  @override
  Future<TermOutcome> openLauncherPage(TermLauncherPage page) async {
    final TermPageOpener? open = pageOpener;
    if (open == null) {
      // Unreachable through GshShell, which requires one. Reachable if someone
      // constructs the host directly, and then it must NOT look like it worked.
      return const TermOutcome.failed(
          'this terminal has no navigator attached');
    }
    return open(page);
  }

  // ── persistence ─────────────────────────────────────────────────────
  //
  // shared_preferences and JSON through the SAME PrefsStore everything else
  // uses, and NOT per theme. Which words you taught the shell is a fact about
  // you, not about a colour scheme, which is the argument usage_repository
  // already makes for launch counts.
  static const String _aliasKey = 'terminal.aliases.v1';
  static const String _runsKey = 'terminal.runs.v1';

  @override
  Future<Map<String, String>> loadAliases() async {
    final String? raw = await _ref.read(prefsStoreProvider).read(_aliasKey);
    if (raw == null) return <String, String>{};
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return <String, String>{
        for (final MapEntry<String, dynamic> e in decoded.entries)
          if (e.value is String) e.key: e.value as String,
      };
    } catch (_) {
      // Corrupt aliases cost a shorthand, not a shell.
      return <String, String>{};
    }
  }

  @override
  Future<void> saveAliases(Map<String, String> aliases) =>
      _ref.read(prefsStoreProvider).write(_aliasKey, jsonEncode(aliases));

  @override
  Future<int> loadRunCount() async {
    final String? raw = await _ref.read(prefsStoreProvider).read(_runsKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  @override
  Future<void> saveRunCount(int count) =>
      _ref.read(prefsStoreProvider).write(_runsKey, '$count');
}
