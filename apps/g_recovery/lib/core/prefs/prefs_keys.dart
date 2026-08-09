/// Every preference key in the app. Nothing writes a raw string literal to
/// prefs: a typo in a key is silent data loss that surfaces to the user as
/// "my settings reset themselves".
class GPrefsKeys {
  const GPrefsKeys._();

  static const String theme = 'theme';
  static const String shellTab = 'shell_tab';
  static const String onboardingComplete = 'onboarding_complete';
}
