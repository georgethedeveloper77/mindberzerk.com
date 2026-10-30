import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_family/g_family.dart';

/// G VPN's live status, for every surface that shows it: the tray key, the
/// clock panel's VPN row. (The VPN desklet keeps its own subscription, since
/// it predates this and draws a countdown off its own timer.)
///
/// Starts `unavailable` and stays there when g_family cannot reach G VPN, so a
/// surface reading this never has to handle an error: unavailable already
/// means "show the way to open G VPN", which is the right fallback for both.
final gvpnStatusProvider = StreamProvider<GVpnStatus>((ref) async* {
  try {
    yield await GVpn.status();
  } catch (_) {
    yield const GVpnStatus(GVpnState.unavailable);
  }
  yield* GVpn.watch().handleError((Object _) {});
});
