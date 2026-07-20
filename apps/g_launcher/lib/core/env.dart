/// Build-time configuration. Nothing secret lives here - this ships inside the
/// APK and anyone can read it.
///
/// Override at build time:
///   flutter build appbundle --dart-define=CDN_BASE=https://cdn.example.com
class Env {
  static const cdnBase = String.fromEnvironment(
    'CDN_BASE',
    defaultValue: 'https://cdn.mindhunter.app',
  );

  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api.mindhunter.app',
  );

  /// Public half of the ed25519 pair that signs CDN content.
  /// The private half never leaves your CI secrets.
  static const contentPublicKey = String.fromEnvironment('CONTENT_PUBLIC_KEY');

  static const isProd = bool.fromEnvironment('dart.vm.product');
}
