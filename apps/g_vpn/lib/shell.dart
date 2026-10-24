import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/meridian_home.dart';
import 'pro/billing.dart';
import 'pro/pro_screen.dart';
import 'rules/rules_screen.dart';
import 'rules/rules_store.dart';
import 'servers/servers_screen.dart';
import 'tools/tools_screen.dart';

/// The five tabs. Only the visible tab is built: animations, timers and
/// speed tests on other tabs do not run unseen. Riverpod keeps their state.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _tab = 0;

  void _go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    // Keeps native auto-connect in step with the selected server and rules.
    ref.watch(autoConnectSyncProvider);
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

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.power_settings_new_rounded), label: 'VPN'),
          NavigationDestination(icon: Icon(Icons.public_rounded), label: 'Servers'),
          NavigationDestination(icon: Icon(Icons.speed_rounded), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Rules'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_rounded), label: 'Pro'),
        ],
      ),
    );
  }
}
