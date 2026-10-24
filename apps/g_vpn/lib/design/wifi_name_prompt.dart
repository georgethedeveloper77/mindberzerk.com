import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_scan.dart';
import '../tools/tools_providers.dart';
import '../vpn/vpn_controller.dart';
import 'meridian.dart';

/// Play's prominent-disclosure rule: say what the permission is for, in the
/// app, BEFORE Android's own dialog. Then, because Android also needs the
/// phone's Location switch on, offer that second step if it is off.
/// Returns whether Wi-Fi names are now readable.
Future<bool> askForWifiNames(BuildContext context, WidgetRef ref) async {
  final api = ref.read(vpnApiProvider);
  if (!await api.wifiNamesAllowed()) {
    if (!context.mounted) return false;
    final go = await _sheet(
      context,
      icon: Icons.wifi_rounded,
      title: 'Allow location for Wi-Fi',
      items: const [
        (Icons.home_outlined, 'Show your Wi-Fi name on Home'),
        (Icons.wifi_find_rounded, 'Scan nearby networks and channels'),
        (Icons.phonelink_lock_outlined, 'Stays on this phone. Your location is never collected.'),
      ],
      confirm: 'Continue',
    );
    if (!go) return false;
    if (!await api.requestWifiNames()) return false;
  }
  if (!await api.locationServicesOn()) {
    if (!context.mounted) return false;
    final open = await _sheet(
      context,
      icon: Icons.location_off_outlined,
      title: 'Turn on Location',
      items: const [
        (Icons.toggle_on_outlined, 'Android hides Wi-Fi names while the Location switch is off'),
      ],
      confirm: 'Open settings',
    );
    if (open) await api.openLocationSettings();
  }
  ref.invalidate(networkScanProvider);
  ref.invalidate(networkSnapshotProvider);
  return api.locationServicesOn();
}

Future<bool> _sheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required List<(IconData, String)> items,
  required String confirm,
}) async {
  final m = context.mer;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: m.surface,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: m.brand),
            ),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
            const SizedBox(height: 14),
            for (final (i, label) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(i, size: 20, color: m.muted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: m.text))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(confirm),
              ),
            ),
            Center(child: TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now'))),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
