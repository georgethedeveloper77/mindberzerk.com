/// Shared content types: what a pack is, what the catalogue says, what came
/// back from a verification attempt.
///
/// WHAT BELONGS HERE: types and pure functions. Pack ids, catalogue entries,
/// entitlement grants, result unions. Things both G Launcher and G Recovery
/// need to say the same words about.
///
/// WHAT DOES NOT: anything that touches a platform channel, a file, or a
/// socket. The download and verification themselves are NATIVE (see
/// PackVerifier.kt and PackDownloader.kt) and stay native — this package is the
/// Dart-side vocabulary for talking about their results, not a second
/// implementation of them.
///
/// The temptation to "just put the http call here so both apps can use it" is
/// exactly how the verified path grows a second, unverified twin.
library g_content;

export 'src/pack_ref.dart';
