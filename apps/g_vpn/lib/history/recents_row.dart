import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/flag.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../vpn/vpn_controller.dart';
import 'recents.dart';

/// The servers used last, one tap to connect. Hidden until there is one.
class RecentsRow extends ConsumerWidget {
  const RecentsRow({super.key, required this.openServers});

  final VoidCallback openServers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final recents = ref.watch(usableRecentsProvider);
    final vpn = ref.watch(vpnProvider);
    if (recents.isEmpty) return const SizedBox.shrink();
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    final current = vpn.phase == VpnPhase.on ? vpn.tunnelId : null;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(t.recents.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
            ),
            MerAction(t.recents.allServers, onPressed: openServers),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (recent, choice) = recents[i];
              final on = current == choice.id;
              final sub = switch (recent.kind) {
                RecentKind.free => t.recents.free,
                RecentKind.gserver => t.recents.gserver,
                RecentKind.own => t.recents.yours,
              };
              return SizedBox(
                width: 150,
                child: Material(
                  color: on ? m.good.withValues(alpha: .10) : m.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Meridian.rTile),
                    side: BorderSide(color: on ? m.good.withValues(alpha: .5) : m.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Meridian.rTile),
                    onTap: busy || on ? null : () => connectRecent(ref, choice),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              switch (recent.kind) {
                                RecentKind.free when recent.country != null => CountryFlag(recent.country!, width: 26),
                                RecentKind.gserver => Icon(Icons.bolt_rounded, size: 20, color: m.good),
                                _ => Icon(Icons.dns_outlined, size: 20, color: m.brand),
                              },
                              const Spacer(),
                              if (on) Icon(Icons.check_circle_rounded, size: 18, color: m.good),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            recent.name,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text),
                          ),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(fontSize: 12, color: m.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}
