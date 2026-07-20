/// Entitlements: which Play SKUs this user owns.
///
/// THE ONE RULE: ownership is Play's answer.
///
/// Not the CDN's, which serves the payload and must never also decide who may
/// have it. Not a local flag in shared_preferences, which is a claim the device
/// makes about itself and survives exactly as long as nobody looks at it.
/// Play's record, queried on start, refreshed underneath the UI.
///
/// This package knows WHICH SKUS ARE OWNED and nothing about what they unlock.
/// The mapping from sku to packs lives in the signed CDN index, because bundle
/// membership is content and changes constantly, while a Play product ID is
/// immutable and cannot even be reused after deletion. Keeping the two apart is
/// what lets a bundle gain a distro with no Play change and no app release.
library g_account;

export 'src/entitlement_service.dart';
