import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/content_api.g.dart';
import '../../bridge/content_bridge.dart';
import '../logging.dart';

/// Where the CDN content lives.
///
/// A constant, not Remote Config. The launcher puts its base in Remote Config
/// because it swaps hosts for staging; this app has one host and adding a
/// remote knob would be one more thing that can be changed without a release
/// for no benefit it currently needs. Native validates it as https regardless,
/// because a value that arrives from anywhere other than a literal is still a
/// value to check.
const String kContentBaseUrl = 'https://cdn.mindberzerk.com/g-recovery';

/// Every piece of shipped content, verified pack first, bundled asset second.
///
/// THE FALLBACK IS PERMANENT, not a placeholder. A phone with no network on
/// first launch still gets a working trashmap and a readable guide, and a CDN
/// outage degrades to slightly stale content rather than to an empty app. That
/// is also why nothing above this class ever learns which source answered.
class ContentStore {
  const ContentStore(this._bridge);

  final ContentBridge _bridge;

  static const String trashMap = 'trashmap';
  static const String learn = 'learn-en';

  static const Map<String, String> _bundledAssets = <String, String>{
    trashMap: 'assets/packs/trashmap-bundled.json',
    learn: 'assets/content/learn-en.json',
  };

  Future<String?> read(String id) async {
    // Installed pack first. Native only returns bytes it verified, so there is
    // no trust decision to make here.
    final String? installed = await _bridge.readContent(id);
    if (installed != null && installed.isNotEmpty) return installed;

    final String? asset = _bundledAssets[id];
    if (asset == null) {
      GLog.w('no content registered for $id', scope: 'content');
      return null;
    }
    try {
      return await rootBundle.loadString(asset);
    } catch (cause) {
      // A missing asset is a packaging error, not a runtime condition: someone
      // forgot the pubspec entry. Loud in logs, silent on screen.
      GLog.e('content asset missing: $asset', scope: 'content', cause: cause);
      return null;
    }
  }

  Future<Map<String, Object?>> readJson(String id) async {
    final String? raw = await read(id);
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
    } on FormatException catch (cause) {
      GLog.e('content $id is not valid json', scope: 'content', cause: cause);
      return <String, Object?>{};
    }
  }
}

final Provider<ContentBridge> contentBridgeProvider = Provider<ContentBridge>(
  (Ref ref) => ContentBridge(),
);

final Provider<ContentStore> contentStoreProvider = Provider<ContentStore>(
  (Ref ref) => ContentStore(ref.watch(contentBridgeProvider)),
);

/// Runs one sync in the background and reports whether anything changed.
///
/// FIRE AND FORGET FROM THE UI. Nothing waits on it: the app is fully usable on
/// bundled content, and a sync that blocks a screen would trade a working app
/// for a marginally fresher one. When it does land, invalidating the readers is
/// enough.
final FutureProvider<ContentSyncResult?> contentSyncProvider =
    FutureProvider<ContentSyncResult?>((Ref ref) async {
      final ContentBridge bridge = ref.watch(contentBridgeProvider);
      await bridge.setBaseUrl(kContentBaseUrl);
      final ContentSyncResult? result = await bridge.sync();
      if (result != null) {
        GLog.i(
          'content sync ${result.status}: ${result.detail}',
          scope: 'content',
        );
      }
      return result;
    });

final FutureProvider<List<ContentPackInfo>> installedPacksProvider =
    FutureProvider<List<ContentPackInfo>>(
      (Ref ref) => ref.watch(contentBridgeProvider).packs(),
    );
