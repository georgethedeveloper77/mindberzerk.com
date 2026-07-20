/// A pack, as the UI needs to talk about it.
///
/// Deliberately NOT a mirror of Kotlin's `CdnPack`. That type carries the
/// remote path, the signed sizes and the file list, none of which any widget
/// should ever see: a screen that knows the CDN path is a screen that could be
/// tempted to fetch it. This is the presentation subset that crosses Pigeon.
class PackRef {
  const PackRef({
    required this.packId,
    required this.packType,
    required this.title,
    required this.summary,
    required this.version,
    required this.sizeBytes,
    required this.state,
    this.sku,
  });

  final String packId;

  /// theme, brand, hero, icon. A String rather than an enum ON PURPOSE: adding
  /// a pack type must not require an app release to parse, and the Pigeon codec
  /// assigns enum ids positionally so a new one would shift every id after it.
  /// Same rule `brandTreatment` already follows.
  final String packType;

  final String title;
  final String summary;
  final int version;
  final int sizeBytes;
  final PackState state;

  /// null = free. Presentation only. Whether the user OWNS this is Play's
  /// answer, held in g_account, and must never be inferred from this field.
  final String? sku;

  bool get isFree => sku == null;
}

/// Where a pack is, from the device's point of view.
enum PackState {
  /// In the catalogue, not on disk.
  available,

  /// On disk and current.
  installed,

  /// On disk, but the catalogue advertises a newer version.
  updateAvailable,

  /// Ships inside the APK. Always present; may still update over the CDN.
  bundled,

  /// The catalogue offers it but this build is too old to run it. A distinct
  /// state because the action is "update the app", not "buy" or "download",
  /// and a storefront that shows a Get button here is lying.
  requiresAppUpdate,
}
