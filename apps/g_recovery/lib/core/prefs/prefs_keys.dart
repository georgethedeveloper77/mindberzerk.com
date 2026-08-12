/// Every preference key in the app. Nothing writes a raw string literal to
/// prefs: a typo in a key is silent data loss that surfaces to the user as
/// "my settings reset themselves".
class GPrefsKeys {
  const GPrefsKeys._();

  static const String theme = 'theme';
  static const String shellTab = 'shell_tab';
  static const String onboardingComplete = 'onboarding_complete';

  /// Mirrors a purchase, and is never the record of one.
  ///
  /// A preference is editable by anyone with a rooted phone. That is fine for a
  /// cache of something Play has already verified and is not fine as the only
  /// evidence, which is why this key becomes a mirror the moment billing lands
  /// rather than the source of truth it currently is.
  static const String proUnlocked = 'pro_unlocked';
}
