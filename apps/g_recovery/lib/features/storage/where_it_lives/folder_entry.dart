library;

import 'package:flutter/foundation.dart';

import 'known_folders.dart';

/// How the section is presented. Map is the default; list is the fallback and
/// the route that stays readable for screen readers and for small folder counts.
enum WhereItLivesView { map, list }

/// What a folder mostly holds, guessed from the folder itself.
///
/// A GUESS, and named as one. Native returns a folder's total bytes and nothing
/// about what is inside it, so this cannot be measured the way every other
/// figure in the app is. It drives colour and nothing else: no figure, no
/// promise, no action is derived from it. If FolderUsage ever carries a per kind
/// breakdown, this becomes a measurement and the legend can come back with it.
enum FolderKind { photos, video, audio, docs, apps, cache, other }

/// One folder as the section draws it.
@immutable
class FolderEntry {
  const FolderEntry({
    required this.name,
    required this.path,
    required this.bytes,
    required this.kind,
    this.regenerable = false,
    this.appOwned = false,
  });

  /// The resolved name, never the path. This is what stops the label truncating.
  final String name;

  final String path;
  final int bytes;
  final FolderKind kind;

  /// The system rebuilds this folder, so clearing it costs the user nothing.
  final bool regenerable;

  final bool appOwned;

  /// Share of what was scanned, not of the volume.
  double shareOf(int totalBytes) {
    if (totalBytes <= 0) return 0;
    final double value = bytes / totalBytes;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }
}

const List<String> _audioRoots = <String>[
  'music',
  'recordings',
  'podcasts',
  'audiobooks',
  'ringtones',
  'alarms',
  'notifications',
];

FolderKind folderKindFor(String path, KnownFolder known) {
  if (known.regenerable) return FolderKind.cache;
  if (known.appOwned) return FolderKind.apps;

  final String lower = normaliseFolderPath(path).toLowerCase();
  if (lower.startsWith('dcim') || lower.startsWith('pictures')) {
    return FolderKind.photos;
  }
  if (lower.startsWith('movies')) return FolderKind.video;
  if (_audioRoots.any(lower.startsWith)) return FolderKind.audio;
  if (lower.startsWith('documents') || lower.startsWith('download')) {
    return FolderKind.docs;
  }
  if (lower.startsWith('whatsapp') || lower.startsWith('telegram')) {
    return FolderKind.apps;
  }
  return FolderKind.other;
}

/// Turns a raw folder path into an entry a person can read.
FolderEntry folderEntryFor({
  required String path,
  required int bytes,
  String? Function(String packageName)? appLabelFor,
}) {
  final KnownFolder known = resolveKnownFolder(path, appLabelFor: appLabelFor);
  return FolderEntry(
    name: known.name,
    path: normaliseFolderPath(path),
    bytes: bytes,
    kind: folderKindFor(path, known),
    regenerable: known.regenerable,
    appOwned: known.appOwned,
  );
}
