import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs_repository.dart';

/// The Hidden folder tile: whether the drawer shows it, and what it is called.
///
/// Launcher-wide, like the hidden set it opens. Off by default, so nobody
/// finds a new tile in their drawer after an update. The name may be changed
/// so the tile can pass as an ordinary folder; null means the translated
/// default.
class HiddenFolderSettings {
  const HiddenFolderSettings({this.enabled = false, this.name});

  final bool enabled;
  final String? name;

  static const maxNameLength = 24;

  /// Trimmed and bounded, or null for an empty name.
  static String? cleanName(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.length > maxNameLength ? t.substring(0, maxNameLength) : t;
  }

  HiddenFolderSettings copyWith({bool? enabled}) =>
      HiddenFolderSettings(enabled: enabled ?? this.enabled, name: name);

  HiddenFolderSettings withName(String? raw) =>
      HiddenFolderSettings(enabled: enabled, name: cleanName(raw));

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (name != null) 'name': name,
      };

  static HiddenFolderSettings fromJson(Map<String, dynamic> j) =>
      HiddenFolderSettings(
        enabled: j['enabled'] == true,
        name: cleanName(j['name'] as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is HiddenFolderSettings &&
      other.enabled == enabled &&
      other.name == name;

  @override
  int get hashCode => Object.hash(enabled, name);
}

class HiddenFolderNotifier extends AsyncNotifier<HiddenFolderSettings> {
  static const storageKey = 'hiddenApps.folder.v1';

  @override
  Future<HiddenFolderSettings> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const HiddenFolderSettings();
    try {
      return HiddenFolderSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const HiddenFolderSettings();
    }
  }

  Future<void> setEnabled(bool on) => _save((s) => s.copyWith(enabled: on));

  Future<void> setName(String? name) => _save((s) => s.withName(name));

  Future<void> _save(
    HiddenFolderSettings Function(HiddenFolderSettings) change,
  ) async {
    final current = state.hasValue ? state.requireValue : await future;
    final next = change(current);
    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(storageKey, jsonEncode(next.toJson()));
  }
}

final hiddenFolderProvider =
    AsyncNotifierProvider<HiddenFolderNotifier, HiddenFolderSettings>(
  HiddenFolderNotifier.new,
);
