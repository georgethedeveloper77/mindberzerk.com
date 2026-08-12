import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../bridge/server_api.g.dart';
import '../../../bridge/server_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_card.dart';
import '../../recovery/category_page.dart';
import '../../recovery/state/recovery_providers.dart';
import '../../server/server_page.dart';

/// WHAT IS ABOUT TO GO WRONG, AND NOTHING ELSE.
///
/// ─── IT RENDERS NOTHING WHEN NOTHING IS TRUE ─────────────────────────────────
///
/// Not an empty state, not a green all clear row. Absent. A strip that always
/// has something in it teaches people to stop reading it, and the one time it
/// matters is the time they will skip.
///
/// ─── EXPIRING COMES FIRST, ALWAYS ────────────────────────────────────────────
///
/// It is the only preventable loss on this screen. Duplicates will still be
/// duplicates next week and a stale backup gets no staler in a day, but a file
/// with forty hours left is gone afterwards and nothing brings it back.
///
/// ─── AND IT NEVER STARTS A SCAN TO FILL ITSELF IN ────────────────────────────
///
/// Every figure here comes from something the app already knows: the prescan,
/// which runs anyway, and the server state, which is a preference read. A home
/// screen that began decoding every photograph because somebody opened the app
/// would be unforgivable, and it is exactly what a duplicates count would cost.
class AttentionStrip extends ConsumerWidget {
  const AttentionStrip({super.key});

  /// Past this, a backup is worth mentioning. Under a week is a phone somebody
  /// is using normally, and nagging about it is how a warning becomes wallpaper.
  static const int _staleDays = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final ServerConfig? server = ref.watch(serverConfigProvider).value;
    final TransferState? transfer = ref.watch(transferProvider).value;

    final List<Widget> cards = <Widget>[];

    // 1. Expiring. First because it is the only thing here that cannot wait.
    final int expiring = summary?.expiringSoonItems ?? 0;
    if (expiring > 0) {
      cards.add(
        _Card(
          icon: Icons.timer_outlined,
          tone: t.danger,
          value: GFormat.count(expiring),
          label: 'expire within 48 hours',
          onTap: () => Navigator.of(context).push(
            CategoryPage.route(title: 'Expiring', sourceIds: kAllSourceIds),
          ),
        ),
      );
    }

    // 2. A backup that has not run. Only when a server exists: telling someone
    //    their backup is stale when they never set one up is nonsense.
    final int? last = transfer?.lastRunMillis;
    if (server != null && last != null) {
      final int days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(last))
          .inDays;
      if (days >= _staleDays) {
        cards.add(
          _Card(
            icon: Icons.cloud_off_outlined,
            tone: t.warning,
            value: '$days days',
            label: 'since the last backup',
            onTap: () => Navigator.of(context).push(ServerPage.route()),
          ),
        );
      }
    }

    // 3. A server that has never run at all. Different fact, different sentence:
    //    the first is neglect, this is an unfinished setup.
    if (server != null && last == null) {
      cards.add(
        _Card(
          icon: Icons.cloud_upload_outlined,
          tone: t.warning,
          value: 'Never',
          label: 'backed up to your server',
          onTap: () => Navigator.of(context).push(ServerPage.route()),
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 1),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: GSpace.sm + 1),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color tone;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      padding: const EdgeInsets.all(GSpace.md - 1),
      borderColour: tone.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: tone),
          const SizedBox(height: GSpace.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.monoSmall.copyWith(
              color: t.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            style: GType.micro.copyWith(color: t.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
