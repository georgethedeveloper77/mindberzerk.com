import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';

/// One row of the recovery ledger.
///
/// The fidelity stamp is not decoration. It is the promise the app is built on:
/// you always know what quality you are getting back before you tap restore, and
/// a source that can return nothing says so instead of being hidden.
class SourceTile extends StatelessWidget {
  const SourceTile({
    required this.source,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final RecoverySource source;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dimmed = !source.available;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: GCard(
        onTap: source.available ? onTap : null,
        borderColour: expanded ? t.accent : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        source.label,
                        style: GType.heading.copyWith(color: t.text),
                      ),
                      Text(
                        <String>[
                          '${GFormat.count(source.itemCount)} items',
                          GFormat.bytes(source.totalBytes),
                          if (source.retentionDays != null)
                            'up to ${source.retentionDays} days',
                        ].join(' / '),
                        style: GType.monoSmall.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                _stamp(),
              ],
            ),
            if (source.detail != null) ...<Widget>[
              const SizedBox(height: GSpace.sm),
              Text(
                source.detail!,
                style: GType.micro.copyWith(color: t.dim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stamp() {
    switch (source.fidelity) {
      case 'full':
        return GBadge.full('Full quality');
      case 'preview':
        return GBadge.partial('Preview only');
      default:
        return GBadge(label: 'Gone');
    }
  }
}
