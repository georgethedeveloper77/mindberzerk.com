import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';

/// Shown in place of a card the device will not serve.
///
/// This is the Device tab's version of the fidelity stamp. Competitors either
/// hide the section, which makes the app look different on every phone with no
/// explanation, or draw empty bars, which reads as broken. Saying which read was
/// refused turns a limitation into information, and it is the honest answer:
/// SELinux policy is per-ROM and there is nothing the app can do about it.
class UnavailableNote extends StatelessWidget {
  const UnavailableNote({
    required this.title,
    required this.reason,
    super.key,
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title, style: GType.heading.copyWith(color: t.text)),
              ),
              GBadge(label: 'Not available'),
            ],
          ),
          const SizedBox(height: GSpace.sm),
          Text(reason, style: GType.bodySmall.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

/// A pending card. Distinct from [UnavailableNote] on purpose: pending means
/// wait, unavailable means stop waiting.
class PendingNote extends StatelessWidget {
  const PendingNote({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.dim),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(title, style: GType.bodySmall.copyWith(color: t.muted)),
          ),
        ],
      ),
    );
  }
}
