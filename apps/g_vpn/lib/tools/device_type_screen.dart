import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import 'device_memory.dart';
import 'devices_screen.dart';
import 'discovery.dart';
import 'lan.dart';
import 'tool_widgets.dart';

/// "What is it?": the user corrects a device's type, starting from our
/// guess. The choice is kept per network and address.
class DeviceTypeScreen extends ConsumerWidget {
  const DeviceTypeScreen({super.key, required this.device, required this.network});

  final LanDevice device;
  final String? network;

  static const _groups = [
    [DeviceKind.phone, DeviceKind.computer],
    [DeviceKind.tv, DeviceKind.speaker, DeviceKind.camera],
    [DeviceKind.router, DeviceKind.printer, DeviceKind.smartHome],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final key = deviceKey(network, device.ip);
    final mem = ref.watch(deviceMemoryProvider).value;
    final chosen = mem?.kinds[key];
    final guess = device.isSelf ? DeviceKind.phone : device.kind;
    final current = chosen ?? guess;
    final titles = [t.devices.groupPersonal, t.devices.groupHome, t.devices.groupNetwork];

    Future<void> pick(DeviceKind? kind) async {
      await ref.read(deviceMemoryProvider.notifier).setKind(key, kind == guess ? null : kind);
      if (context.mounted) Navigator.of(context).pop();
    }

    return ToolPage(
      title: t.devices.whatIsIt,
      icon: deviceIcon(current),
      color: deviceColor(current, m),
      children: [
        Material(
          color: m.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Meridian.rTile), side: BorderSide(color: m.line)),
          child: ListTile(
            onTap: () => pick(guess),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: deviceColor(guess, m).withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
              child: Icon(deviceIcon(guess), color: deviceColor(guess, m), size: 20),
            ),
            title: Text(t.devices.ourGuess(kind: deviceKindName(guess)),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
            subtitle: device.name == null ? null : Text(device.name!, style: TextStyle(fontSize: 12, color: m.muted)),
            trailing: chosen == null ? Icon(Icons.check_rounded, color: m.good) : null,
          ),
        ),
        for (final (i, group) in _groups.indexed) ...[
          ToolHeading(titles[i]),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              for (final kind in group)
                Semantics(
                  selected: current == kind,
                  button: true,
                  child: Material(
                    color: current == kind ? deviceColor(kind, m).withValues(alpha: .16) : m.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: current == kind ? deviceColor(kind, m) : m.line, width: current == kind ? 1.5 : 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => pick(kind),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(deviceIcon(kind), size: 26, color: current == kind ? deviceColor(kind, m) : m.text),
                          const SizedBox(height: 8),
                          Text(deviceKindName(kind),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: current == kind ? deviceColor(kind, m) : m.text)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
