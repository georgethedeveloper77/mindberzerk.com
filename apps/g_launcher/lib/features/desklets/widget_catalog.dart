import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/launcher_api.g.dart' as api;

/// Third-party AppWidget providers, grouped by owning app. PHASE D-widgets.
///
/// The image-2 shape: one row per app ("Adblock Browser", "AliExpress") with a
/// count, expanding to that app's individual widgets. The native side already
/// returns providers sorted by app label and filtered to home-screen widgets;
/// this only folds them into groups so the list reads as apps rather than as a
/// flat wall of providers.
///
/// Nothing here HOSTS a widget — enumeration and hosting are separate Android
/// capabilities, and the live-placement half arrives with the host slice. Until
/// then this is a real, previewable catalogue that simply cannot place yet.

/// One app and the widgets it offers.
class WidgetAppGroup {
  const WidgetAppGroup({
    required this.packageName,
    required this.appLabel,
    required this.providers,
  });

  final String packageName;
  final String appLabel;
  final List<api.WidgetProviderInfo> providers;
}

/// Every installed home-screen widget provider, grouped by app.
///
/// A plain [FutureProvider]: the list changes rarely (install / uninstall), the
/// picker is opened on demand, and re-reading on each open is cheaper than
/// wiring an invalidation channel for a screen most sessions never see. If a
/// live-updating catalogue is ever wanted, invalidate this from the existing
/// `onAppsChanged` path.
final installedWidgetProvidersProvider =
    FutureProvider<List<WidgetAppGroup>>((ref) async {
  final list = await api.LauncherHostApi().getInstalledWidgetProviders();

  // Preserve first-seen app label per package; the native list is already
  // sorted by app label, so insertion order is alphabetical by app.
  final byPkg = <String, List<api.WidgetProviderInfo>>{};
  final labels = <String, String>{};
  for (final p in list) {
    byPkg.putIfAbsent(p.packageName, () => <api.WidgetProviderInfo>[]).add(p);
    labels.putIfAbsent(p.packageName, () => p.appLabel);
  }

  final groups = [
    for (final entry in byPkg.entries)
      WidgetAppGroup(
        packageName: entry.key,
        appLabel: labels[entry.key] ?? entry.key,
        providers: entry.value,
      ),
  ];
  groups.sort(
    (a, b) => a.appLabel.toLowerCase().compareTo(b.appLabel.toLowerCase()),
  );
  return groups;
});

/// A single provider's preview, rendered natively to PNG at a requested size.
///
/// Keyed by provider + pixel size so two tiles asking for the same preview at
/// the same size share one native render, and a re-layout at a new size is a
/// distinct cache entry rather than a stale bitmap. The size is passed in
/// because a provider cannot read the widget's constraints; the caller measures
/// and asks.
typedef WidgetPreviewRequest = ({String providerKey, int width, int height});

final widgetPreviewProvider =
    FutureProvider.family<Uint8List?, WidgetPreviewRequest>((ref, req) async {
  return api.LauncherHostApi().getWidgetPreview(
    req.providerKey,
    req.width,
    req.height,
  );
});
