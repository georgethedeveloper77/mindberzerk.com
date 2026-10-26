import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alerts/alert_watcher.dart';
import 'alerts/alerts.dart' show alertsProvider;
import 'history/usage.dart';
import 'home/meridian_home.dart';
import 'i18n/strings.g.dart';
import 'pro/billing.dart';
import 'pro/pro_screen.dart';
import 'providers/provider_api.dart' show providerRegistrarProvider;
import 'rules/rules_screen.dart';
import 'rules/rules_store.dart';
import 'servers/servers_screen.dart';
import 'tools/tools_screen.dart';
import 'ui/add_server_sheet.dart';
import 'update/app_update.dart';
import 'vpn/tunnel_store.dart';
import 'vpn/vpn_controller.dart';

/// The five tabs. Only the visible tab is built: animations, timers and
/// speed tests on other tabs do not run unseen. Riverpod keeps their state.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  void _go(int tab) => setState(() => _tab = tab);

  @override
  void initState() {
    super.initState();
    // Once per launch, after the first frame so the update bar has a
    // Scaffold to appear on.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppUpdate.check(context);
      _takeShared();
      takeAlertRoute(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _takeShared();
      takeAlertRoute(context);
      // The background checks may have added alerts while the app slept.
      ref.read(alertsProvider.notifier).reload();
    }
  }

  /// A server shared to G VPN from another app (a QR image or the settings
  /// as text): open Servers and the add-server sheet with it.
  Future<void> _takeShared() async {
    try {
      final text = await ref.read(vpnApiProvider).takeSharedServer();
      if (text == null || !mounted) return;
      _go(1);
      await AddServerSheet.show(context,
          name: suggestServerName(text) ?? t.servers.scannedServer,
          config: text);
    } on PlatformException catch (e) {
      if (mounted && e.code == 'no_qr') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.add.noQr)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps native auto-connect in step with the selected server and rules.
    ref.watch(autoConnectSyncProvider);
    // Recents and the stats count whatever tab is open.
    ref.watch(historyRecorderProvider);
    // Tells the provider directory which provider this phone uses.
    ref.watch(providerRegistrarProvider);
    // Turns what the app notices into alerts, and the week into a report.
    ref.watch(alertWatcherProvider);
    // Play can deliver a purchase at any launch; listen from the start.
    ref.watch(billingProvider);

    final body = switch (_tab) {
      0 => MeridianHome(
          openServers: () => _go(1),
          openTools: () => _go(2),
          openRules: () => _go(3),
          openPro: () => _go(4),
        ),
      1 => ServersScreen(openHome: () => _go(0), openPro: () => _go(4)),
      2 => const ToolsScreen(),
      3 => const RulesScreen(),
      _ => const ProScreen(),
    };

    // Back on any other tab returns to VPN, like other modern apps; only
    // from VPN does back leave the app. Screens opened on top of a tab
    // close first as usual, since they are their own routes.
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.power_settings_new_rounded),
                label: t.nav.vpn),
            NavigationDestination(
                icon: const Icon(Icons.public_rounded), label: t.nav.servers),
            NavigationDestination(
                icon: const Icon(Icons.speed_rounded), label: t.nav.tools),
            NavigationDestination(
                icon: const Icon(Icons.tune_rounded), label: t.nav.rules),
            NavigationDestination(
                icon: const Icon(Icons.workspace_premium_rounded),
                label: t.nav.pro),
          ],
        ),
      ),
    );
  }
}
