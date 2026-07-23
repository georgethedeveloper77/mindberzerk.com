import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'translations.dart';

export 'app_locale.dart';
export 'translations.dart';

/// Persisted under this key. Global scalar, like setupCompleted.v1, NOT a
/// per-theme pref: language is a property of the user, not of the distro skin.
const String _kLocalePrefKey = 'appLocale.v1';

/// The whole i18n state the UI needs in one immutable value.
@immutable
class I18nState {
  const I18nState({required this.selectedCode, required this.translations});

  /// The user's explicit choice, or null when following the device language.
  final String? selectedCode;

  /// Resolved strings for whatever language is actually active.
  final Translations translations;

  /// Handed to MaterialApp.locale. Derived from the loaded translations' code
  /// so the framework's text direction (RTL for ar) matches the strings on
  /// screen.
  Locale get locale => codeToLocale(translations.code);

  /// The AppLocale the user picked, or null for "System default".
  AppLocale? get selectedLocale => localeForCode(selectedCode);

  /// A neutral starting value for tests and for the split second before
  /// bootstrap overrides the provider with real, loaded strings.
  factory I18nState.fallback() =>
      I18nState(selectedCode: null, translations: Translations.empty());
}

/// Reads the saved code (or matches the device language) and loads the
/// strings. Call this in bootstrap and feed the result into the provider
/// override below, so the very first frame already has real copy.
Future<I18nState> loadInitialI18n() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kLocalePrefKey); // null => follow system
  final effective = saved ?? systemMatchCode(PlatformDispatcher.instance.locale);
  final translations = await Translations.load(effective);
  return I18nState(selectedCode: saved, translations: translations);
}

class I18nController extends Notifier<I18nState> {
  I18nController(this._seed);
  final I18nState _seed;

  @override
  I18nState build() => _seed;

  /// Switch language. Pass null to go back to following the device language.
  /// Loads the new strings first, then swaps state and persists, so a slow
  /// asset read never leaves the UI in a half-changed state.
  Future<void> select(AppLocale? choice) async {
    final code = choice?.code; // null => follow system
    final effective = code ?? systemMatchCode(PlatformDispatcher.instance.locale);
    final loaded = await Translations.load(effective);
    // Never .update() on a notifier; assign state directly.
    state = I18nState(selectedCode: code, translations: loaded);
    await _persist(code);
  }

  Future<void> _persist(String? code) async {
    // shared_preferences is already your storage layer, so writing here is
    // consistent at the storage level even though it does not go through
    // prefs_repository. If you route global scalars through that repository
    // (like setupCompleted), move this write there and delete this method.
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_kLocalePrefKey);
    } else {
      await prefs.setString(_kLocalePrefKey, code);
    }
  }
}

/// The default create seeds a harmless fallback so tests and a forgotten
/// override do not crash. Bootstrap overrides this with the loaded state:
///
///   overrides: [ i18nProvider.overrideWith(() => I18nController(initial)) ]
final i18nProvider = NotifierProvider<I18nController, I18nState>(
  () => I18nController(I18nState.fallback()),
);

/// Watch just the strings, so widgets rebuild on a language change without
/// depending on the selected-code field.
final translationsProvider = Provider<Translations>(
  (ref) => ref.watch(i18nProvider.select((s) => s.translations)),
);

/// Primary lookup in Consumer widgets. Rebuilds only this widget on a
/// language switch. Usage:  Text(ref.t('setup.language.title'))
extension I18nRefX on WidgetRef {
  String t(String key, [Map<String, String>? vars]) =>
      watch(translationsProvider).t(key, vars);
}

/// Convenience lookup where no WidgetRef is handy (matches your
/// context.showMessage ergonomics). This does not itself listen, but a
/// language switch changes MaterialApp.locale and rebuilds the tree anyway,
/// so the string still updates. Prefer ref.t inside ConsumerWidgets.
extension I18nContextX on BuildContext {
  String t(String key, [Map<String, String>? vars]) =>
      ProviderScope.containerOf(this, listen: false)
          .read(i18nProvider)
          .translations
          .t(key, vars);
}
