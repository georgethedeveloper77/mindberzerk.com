/// The storage half of the shell, over a plain MethodChannel.
///
/// ─── WHY A CHANNEL AND NOT PIGEON ───────────────────────────────────────────
///
/// Same reason `notification_badges.dart` gives, and it applies harder here. A
/// file bridge wants result objects with an ok flag and a reason, which is a
/// class, and `launcher_api.dart` is a codec a shipped APK already agrees on.
/// Appending is safe; a new schema is safer still, and a plain channel needs no
/// schema and cannot shift anything.
///
/// ─── SAF, NOT ALL FILES ACCESS ──────────────────────────────────────────────
///
/// One `ACTION_OPEN_DOCUMENT_TREE` grant, persisted. Play's declared use cases
/// for `MANAGE_EXTERNAL_STORAGE` are file managers, backup and antivirus, and a
/// launcher is on none of those lists. A folder grant needs no declaration, no
/// justification video, and no Data Safety answer that contradicts the rest of
/// this ecosystem.
///
/// Every method returns null or an ok-false result rather than throwing, and a
/// missing native half is treated exactly like a device that will not answer,
/// so a Dart build that ships ahead of its Kotlin half degrades to "no folder
/// granted" instead of crashing the shell.
library;

import 'package:flutter/services.dart';

import '../term_host.dart';
import '../term_path.dart';

const MethodChannel _channel = MethodChannel('g_launcher/files');

class FilesBridge {
  FilesBridge();

  /// Cached so `filesGranted` can be synchronous, which it must be: the VFS
  /// checks it before every storage verb and an await there would make the
  /// gate itself a source of jank.
  bool _granted = false;
  bool get granted => _granted;

  /// Call once at startup and again after a grant.
  Future<bool> refreshGrant() async {
    _granted = await _call<bool>('hasGrant') ?? false;
    return _granted;
  }

  Future<bool> requestGrant() async {
    _granted = await _call<bool>('requestGrant') ?? false;
    return _granted;
  }

  /// Segments BELOW `/sdcard`. Native resolves them against the granted tree,
  /// so a path can never address anything outside what the user handed over.
  List<String> _segments(TermPath path) => path.rest;

  Future<List<TermEntry>?> list(TermPath path) async {
    final List<Object?>? raw = await _call<List<Object?>>(
      'list',
      <String, Object?>{'segments': _segments(path)},
    );
    if (raw == null) return null;
    return raw.whereType<Map<Object?, Object?>>().map(_entry).toList();
  }

  Future<TermEntry?> stat(TermPath path) async {
    final Map<Object?, Object?>? raw = await _call<Map<Object?, Object?>>(
      'stat',
      <String, Object?>{'segments': _segments(path)},
    );
    return raw == null ? null : _entry(raw);
  }

  Future<List<String>?> readLines(TermPath path, int maxLines) async {
    final List<Object?>? raw = await _call<List<Object?>>(
      'read',
      <String, Object?>{'segments': _segments(path), 'maxLines': maxLines},
    );
    return raw?.whereType<String>().toList();
  }

  Future<int?> size(TermPath path) => _call<int>(
        'size',
        <String, Object?>{'segments': _segments(path)},
      );

  Future<TermOutcome> makeDirectory(TermPath path) =>
      _mutate('mkdir', <String, Object?>{'segments': _segments(path)});

  Future<TermOutcome> createFile(TermPath path) =>
      _mutate('create', <String, Object?>{'segments': _segments(path)});

  Future<TermOutcome> delete(TermPath path, bool recursive) => _mutate(
        'delete',
        <String, Object?>{
          'segments': _segments(path),
          'recursive': recursive,
        },
      );

  Future<TermOutcome> copy(TermPath from, TermPath to) => _mutate(
        'copy',
        <String, Object?>{'from': _segments(from), 'to': _segments(to)},
      );

  Future<TermOutcome> move(TermPath from, TermPath to) => _mutate(
        'move',
        <String, Object?>{'from': _segments(from), 'to': _segments(to)},
      );

  Future<TermOutcome> open(TermPath path) =>
      _mutate('open', <String, Object?>{'segments': _segments(path)});

  TermEntry _entry(Map<Object?, Object?> raw) {
    final int? modified = raw['modified'] as int?;
    return TermEntry(
      name: raw['name'] as String? ?? '',
      kind: (raw['dir'] as bool? ?? false)
          ? TermEntryKind.directory
          : TermEntryKind.file,
      // Absent, never zero. Native sends null when the provider did not supply
      // a size, and a document provider frequently does not.
      sizeBytes: raw['size'] as int?,
      modified: modified == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(modified),
    );
  }

  Future<TermOutcome> _mutate(String method, Map<String, Object?> args) async {
    final Map<Object?, Object?>? raw =
        await _call<Map<Object?, Object?>>(method, args);
    if (raw == null) {
      return const TermOutcome.failed('storage did not answer');
    }
    final bool ok = raw['ok'] as bool? ?? false;
    final String? message = raw['message'] as String?;
    return ok ? TermOutcome.ok(message) : TermOutcome.failed(message ?? 'failed');
  }

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      // A provider that refused, a tree the user revoked, a document that is
      // gone. All of them are the same answer to the shell: unavailable.
      return null;
    } on MissingPluginException {
      // The Dart half shipped ahead of the native half.
      return null;
    }
  }
}
