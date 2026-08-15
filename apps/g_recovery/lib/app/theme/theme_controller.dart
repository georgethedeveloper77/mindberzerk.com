import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/prefs_keys.dart';
import '../../core/prefs/prefs_store.dart';
import 'accent.dart';
import 'tokens.dart';
import 'typeface.dart';

@immutable
class GThemeState {
  const GThemeState({
    required this.mode,
    required this.accent,
    required this.typeface,
  });

  final ThemeMode mode;
  final GAccent accent;
  final GTypeface typeface;

  static const GThemeState fallback = GThemeState(
    mode: ThemeMode.system,
    accent: GAccent.fallback,
    typeface: GTypeface.fallback,
  );

  GThemeState withMode(ThemeMode value) =>
      GThemeState(mode: value, accent: accent, typeface: typeface);

  GThemeState withAccent(GAccent value) =>
      GThemeState(mode: mode, accent: value, typeface: typeface);

  GThemeState withTypeface(GTypeface value) =>
      GThemeState(mode: mode, accent: accent, typeface: value);

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': _modeId(mode),
    'accent': accent.id,
    'typeface': typeface.id,
  };

  /// A blob written before the typeface existed has no 'typeface' key, and
  /// GTypeface.fromId turns the resulting null into System. That is the same
  /// face those users are already looking at, so an upgrade changes nothing on
  /// screen, which is the only acceptable outcome for a silent migration.
  factory GThemeState.fromJson(Map<String, Object?> json) {
    if (json.isEmpty) return fallback;
    return GThemeState(
      mode: _modeFromId(json['mode'] as String?),
      accent: GAccent.fromId(json['accent'] as String?),
      typeface: GTypeface.fromId(json['typeface'] as String?),
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
      other is GThemeState &&
      other.mode == mode &&
      other.accent == accent &&
      other.typeface == typeface;

  @override
  int get hashCode => Object.hash(mode, accent, typeface);
}

/// Owns theme mode, accent and typeface, and persists all three.
///
/// Note the method names. There is no update() here by design: a bare update()
/// on a notifier hides what changed at the call site, and tool/no_bare_update.sh
/// fails the build if one appears.
class GThemeController extends Notifier<GThemeState> {
  @override
  GThemeState build() {
    final PrefsStore store = ref.read(prefsStoreProvider);
    final GThemeState restored = GThemeState.fromJson(
      store.readJson(GPrefsKeys.theme),
    );
    // Bootstrap already did this before the first frame. Repeating it here
    // costs an equality check and covers the case where this provider is built
    // in a test or a tool that never ran bootstrap.
    GType.install(restored.typeface);
    return restored;
  }

  void setMode(ThemeMode mode) => _record(state.withMode(mode));

  void setAccent(GAccent accent) => _record(state.withAccent(accent));

  void setTypeface(GTypeface typeface) => _record(state.withTypeface(typeface));

  void _record(GThemeState next) {
    if (next == state) return;
    // BEFORE the assignment, not after. Assigning state schedules the rebuild
    // that reads GType, so installing afterwards would paint one frame in the
    // old face.
    GType.install(next.typeface);
    state = next;
    // Fire and forget. A failed prefs write must never block the repaint, and
    // the worst case is the choice not surviving a restart.
    ref.read(prefsStoreProvider).writeJson(GPrefsKeys.theme, next.toJson());
  }
}

final NotifierProvider<GThemeController, GThemeState> gThemeProvider =
    NotifierProvider<GThemeController, GThemeState>(GThemeController.new);
