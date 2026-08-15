/// Is this install Terminal Pro?
///
/// ─── WHY THIS DOES NOT GO THROUGH CdnIndex.isUnlocked ───────────────────────
///
/// `entitlements.dart` states the rule this file has to answer to: no Dart code
/// decides what a SKU unlocks, because the rule lives once, natively, in
/// `CdnIndex.isUnlocked`, tested by `EntitlementTest`. Re-deriving it here would
/// be a second implementation in a second language that nothing tests together,
/// and the day they disagree one gives a pack away and the other charges twice.
///
/// That rule is about PACKS. `isUnlocked(packId, ownedSkus)` asks whether an
/// owned SKU covers a downloadable pack, and the answer is a genuine derivation:
/// a pack carries its own sku, an `EntitlementSet` can grant it, and a wildcard
/// can grant everything present and future. All of that is authored in the
/// signed index, so it MUST be resolved where the index is verified.
///
/// Terminal Pro is not a pack. Nothing is downloaded, no signature is involved,
/// and there is no mapping to get wrong: owning `terminal_pro` IS being Pro.
/// Set membership, not a rule. Running it through the pack machinery would mean
/// inventing a pack that does not exist so that a function about packs could
/// answer a question that is not about packs.
///
/// ─── WHAT WOULD CHANGE THAT ─────────────────────────────────────────────────
///
/// The moment a SECOND sku grants Pro, this becomes a derivation and belongs in
/// the index like every other one. A bundle that includes Pro would do it. That
/// bundle was considered and rejected, deliberately: it would hand someone every
/// distro to sell them a terminal feature.
///
/// If it ever comes back, the honest move is to give Pro a pack id in the index
/// and let `isUnlocked` answer, not to add a second sku to a list here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/entitlements.dart';

/// The Play product ID. Must exist in the console before anyone can buy it.
///
/// Lowercase alphanumeric and underscore, which is Play's own rule and the one
/// `CdnIndex.isSafeSku` enforces on the pack side. A malformed id fails by never
/// matching anything Play reports as owned, which looks exactly like the user
/// not having bought it.
const String kTerminalProSku = 'terminal_pro';

/// The whole rule, as a pure function.
///
/// Separated from the provider so it can be tested without Play, a container or
/// a network, which for a paywall check is worth the extra six lines.
bool isTerminalPro(Set<String> ownedSkus) => ownedSkus.contains(kTerminalProSku);

/// Live Pro state.
///
/// FALSE UNTIL PLAY ANSWERS, and that is the correct direction to fail. A person
/// who has paid sees a locked feature for a moment on a cold start with no
/// network; the alternative is trusting a cached flag, and failing open on a
/// paywall is how an app ends up on a modding forum. `ownedSkusProvider` makes
/// the same call for packs and says so in the same words.
final terminalProProvider = Provider<bool>((ref) {
  final owned = ref.watch(ownedSkusProvider).asData?.value ?? const <String>{};
  return isTerminalPro(owned);
});

/// The localised price, or null when Play has not answered.
///
/// A LOCALISED STRING FROM PLAY, never a formatted number of our own: Play
/// renders it for the user's country and currency, and a hand-written price
/// would be wrong in every market this launcher actually targets.
///
/// Null is also the signal that the product does not exist in the console yet,
/// which is exactly the state `terminal_pro` is in until it is created. The
/// paywall has to render that as "not available right now" rather than as a free
/// unlock, the same way the theme storefront already handles a card with no
/// price.
final terminalProPriceProvider = Provider<String?>((ref) {
  return ref.watch(productPriceProvider(kTerminalProSku));
});

/// Start the purchase. False when Play is unreachable or the product is not in
/// the console.
final buyTerminalProProvider = Provider<Future<bool> Function()>((ref) {
  return () => ref.read(buyProvider)(kTerminalProSku);
});
