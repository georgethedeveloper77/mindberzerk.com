import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/prefs_keys.dart';
import '../../core/prefs/prefs_store.dart';
import 'accent.dart';

@immutable
class GThemeState {
  const GThemeState({required this.mode, required this.accent});

  final ThemeMode mode;
  final GAccent accent;

  static const GThemeState fallback = GThemeState(
    mode: ThemeMode.system,
    accent: GAccent.fallback,
  );

  GThemeState withMode(ThemeMode value) =>
      GThemeState(mode: value, accent: accent);

  GThemeState withAccent(GAccent value) =>
      GThemeState(mode: mode, accent: value);

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': _modeId(mode),
    'accent': accent.id,
  };

  factory GThemeState.fromJson(Map<String, Object?> json) {
    if (json.isEmpty) return fallback;
    return GThemeState(
      mode: _modeFromId(json['mode'] as String?),
      accent: GAccent.fromId(json['accent'] as String?),
    );
  }

  static String _modeId(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _modeFromId(String? id) {
    switch (id) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GThemeState && other.mode == mode && other.accent == accent;

  @override
  int get hashCode => Object.hash(mode, accent);
}

/// Owns theme mode and accent, and persists both.
///
/// Note the method names. There is no update() here by design: a bare update()
/// on a notifier hides what changed at the call site, and tool/no_bare_update.sh
/// fails the build if one appears.
class GThemeController extends Notifier<GThemeState> {
  @override
  GThemeState build() {
    final PrefsStore store = ref.read(prefsStoreProvider);
    return GThemeState.fromJson(store.readJson(GPrefsKeys.theme));
  }

  void setMode(ThemeMode mode) => _record(state.withMode(mode));

  void setAccent(GAccent accent) => _record(state.withAccent(accent));

  void _record(GThemeState next) {
    if (next == state) return;
    state = next;
    // Fire and forget. A failed prefs write must never block the repaint, and
    // the worst case is the choice not surviving a restart.
    ref.read(prefsStoreProvider).writeJson(GPrefsKeys.theme, next.toJson());
  }
}

final NotifierProvider<GThemeController, GThemeState> gThemeProvider =
    NotifierProvider<GThemeController, GThemeState>(GThemeController.new);
