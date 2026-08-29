import 'package:g_launcher/features/terminal/term_host.dart';
import 'package:g_launcher/features/terminal/term_path.dart';

/// An in-memory host, so every command is testable without a device.
///
/// It is deliberately literal: a map of paths to entries. If a test passes here
/// and fails on device, the bug is in the adapter, which is exactly the split
/// the seam exists to give.
class FakeNode {
  FakeNode.dir() : isDirectory = true, size = 0, lines = null;
  FakeNode.file(this.size, {this.lines}) : isDirectory = false;

  final bool isDirectory;
  final int size;
  final List<String>? lines;
  final Map<String, FakeNode> children = <String, FakeNode>{};
}

class FakeHost extends TermHost {
  FakeHost({this.granted = true}) {
    final FakeNode download = FakeNode.dir();
    download.children['notes.txt'] =
        FakeNode.file(412, lines: <String>['one', 'two', 'three']);
    download.children['app.apk'] = FakeNode.file(28844102);

    final FakeNode dcim = FakeNode.dir();
    dcim.children['IMG_0001.jpg'] = FakeNode.file(3841221);

    root.children['Download'] = download;
    root.children['DCIM'] = dcim;
    root.children['.thumbnails'] = FakeNode.dir();
  }

  final FakeNode root = FakeNode.dir();
  bool granted;

  /// Counters, so a test can assert HOW OFTEN something happened rather than
  /// only that it did. Both bugs these catch were about repetition.
  int grantRequests = 0;
  int aliasWrites = 0;
  int runCountWrites = 0;

  final List<String> launched = <String>[];
  final List<String> uninstalled = <String>[];
  bool torchOn = false;

  @override
  bool get filesGranted => granted;

  @override
  Future<bool> requestFilesAccess() async {
    grantRequests++;
    return granted;
  }

  FakeNode? _node(TermPath path) {
    if (path.root != TermRoot.files) return null;
    FakeNode current = root;
    for (final String segment in path.rest) {
      final FakeNode? next = current.children[segment];
      if (next == null) return null;
      current = next;
    }
    return current;
  }

  /// Set to model a real phone. 247 apps is an ordinary Android device and the
  /// number the old cap was quietly hiding.
  List<TermApp>? manyApps;

  @override
  Future<List<TermApp>> apps() async => manyApps ?? _apps;

  static const List<TermApp> _apps = <TermApp>[
        TermApp(
          slug: 'firefox',
          label: 'Firefox',
          packageName: 'org.mozilla.firefox',
          sizeBytes: 62400000,
          targetSdk: 34,
        ),
        TermApp(
          slug: 'signal',
          label: 'Signal',
          packageName: 'org.thoughtcrime.securesms',
          sizeBytes: 118200000,
        ),
        TermApp(
          slug: 'settings',
          label: 'Settings',
          packageName: 'com.android.settings',
          system: true,
        ),
      ];

  @override
  Future<void> launchApp(TermApp app) async => launched.add(app.packageName);

  /// Set to a reason string to test the refusal path.
  String? uninstallRefusal;

  @override
  Future<String?> requestUninstall(TermApp app) async {
    if (uninstallRefusal != null) return uninstallRefusal;
    uninstalled.add(app.packageName);
    return null;
  }

  @override
  Future<void> openAppSettings(TermApp app) async {}

  @override
  Future<List<TermEntry>?> list(TermPath path) async {
    final FakeNode? node = _node(path);
    if (node == null || !node.isDirectory) return null;
    return node.children.entries
        .map((MapEntry<String, FakeNode> e) => TermEntry(
              name: e.key,
              kind: e.value.isDirectory
                  ? TermEntryKind.directory
                  : TermEntryKind.file,
              sizeBytes: e.value.isDirectory ? null : e.value.size,
            ))
        .toList();
  }

  @override
  Future<TermEntry?> stat(TermPath path) async {
    final FakeNode? node = _node(path);
    if (node == null) return null;
    return TermEntry(
      name: path.name ?? '~',
      kind: node.isDirectory ? TermEntryKind.directory : TermEntryKind.file,
      sizeBytes: node.isDirectory ? null : node.size,
    );
  }

  @override
  Future<List<String>?> readLines(TermPath path, {int maxLines = 200}) async =>
      _node(path)?.lines;

  @override
  Future<int?> sizeOf(TermPath path) async {
    final FakeNode? node = _node(path);
    if (node == null) return null;
    var total = node.size;
    for (final FakeNode child in node.children.values) {
      total += child.size;
      for (final FakeNode grandchild in child.children.values) {
        total += grandchild.size;
      }
    }
    return total;
  }

  @override
  Future<TermOutcome> makeDirectory(TermPath path) async {
    final FakeNode? parent = _node(path.parent);
    if (parent == null) return const TermOutcome.failed('no parent');
    parent.children[path.name!] = FakeNode.dir();
    return const TermOutcome.ok();
  }

  @override
  Future<TermOutcome> createFile(TermPath path) async {
    final FakeNode? parent = _node(path.parent);
    if (parent == null) return const TermOutcome.failed('no parent');
    parent.children[path.name!] = FakeNode.file(0, lines: <String>['']);
    return const TermOutcome.ok();
  }

  @override
  Future<TermOutcome> delete(TermPath path, {required bool recursive}) async {
    final FakeNode? parent = _node(path.parent);
    if (parent == null) return const TermOutcome.failed('no parent');
    parent.children.remove(path.name);
    return const TermOutcome.ok();
  }

  @override
  Future<TermOutcome> copy(TermPath from, TermPath to) async =>
      const TermOutcome.ok();

  @override
  Future<TermOutcome> move(TermPath from, TermPath to) async =>
      const TermOutcome.ok();

  @override
  Future<TermOutcome> openFile(TermPath path) async =>
      const TermOutcome.ok();

  @override
  Future<TermStorage?> storage() async =>
      const TermStorage(totalBytes: 128000000000, usedBytes: 96000000000);

  @override
  Future<TermMemory?> memory() async =>
      const TermMemory(totalMb: 8192, usedMb: 5412, cachedMb: 1180);

  @override
  Future<TermBattery?> battery() async =>
      const TermBattery(percent: 86, celsius: 31.4, health: 'good');

  @override
  Future<TermNetwork?> network() async => const TermNetwork(
        transport: 'wifi',
        connected: true,
        downBytesPerSec: 1400000,
      );

  @override
  Future<int?> cpuPercent() async => 18;

  @override
  Duration? get uptime => const Duration(hours: 3, minutes: 12);

  @override
  TermDevice get device => const TermDevice(
        model: 'Infinix NOTE 40',
        androidRelease: '14',
        sdkInt: 34,
        user: 'george',
        host: 'infinix',
      );

  /// Names this fake refuses, so a test can assert the honest refusal.
  Set<String> unwiredNames = const <String>{};

  @override
  Set<String> get unwired => unwiredNames;

  @override
  Future<TermOutcome> setTorch({required bool on}) async {
    if (unwiredNames.contains('torch')) {
      return const TermOutcome.failed('the torch is not available in this build');
    }
    torchOn = on;
    return const TermOutcome.ok();
  }

  @override
  Future<TermOutcome> nudgeVolume(int steps) async =>
      const TermOutcome.ok('media volume 60%');

  @override
  Future<TermOutcome> openSystemPanel(TermSystemPanel panel) async =>
      const TermOutcome.ok();

  final List<TermLauncherPage> opened = <TermLauncherPage>[];

  /// Set to simulate a terminal wired without a navigator.
  bool hasNavigator = true;

  /// Set to simulate a page the opener declines to reach.
  String? pageRefusal;

  @override
  Future<TermOutcome> openLauncherPage(TermLauncherPage page) async {
    if (!hasNavigator) {
      return const TermOutcome.failed('this terminal has no navigator attached');
    }
    final String? refusal = pageRefusal;
    if (refusal != null) return TermOutcome.failed(refusal);
    opened.add(page);
    return const TermOutcome.ok();
  }

  final Map<String, String> savedAliases = <String, String>{};
  int savedRuns = 0;

  @override
  Future<Map<String, String>> loadAliases() async => savedAliases;

  @override
  Future<void> saveAliases(Map<String, String> aliases) async {
    aliasWrites++;
    savedAliases
      ..clear()
      ..addAll(aliases);
  }

  @override
  Future<int> loadRunCount() async => savedRuns;

  @override
  Future<void> saveRunCount(int count) async {
    runCountWrites++;
    savedRuns = count;
  }
}
