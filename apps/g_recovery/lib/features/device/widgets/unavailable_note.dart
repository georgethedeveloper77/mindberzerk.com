import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_sheet.dart';
import '../../../core/i18n/g_strings.dart';

/// Shown in place of a card the device will not serve.
///
/// This is the Device tab's version of the fidelity stamp. Competitors either
/// hide the section, which makes the app look different on every phone with no
/// explanation, or draw empty bars, which reads as broken. Saying which read was
/// refused turns a limitation into information: SELinux policy is per ROM and
/// there is nothing the app can do about it.
///
/// ─── THE REASON MOVED INTO A SHEET ───────────────────────────────────────────
///
/// It used to be a paragraph on the card. Four lines of explanation where a
/// reading should be turns a diagnostics page into an essay, and on a phone that
/// refuses two or three reads the page becomes almost entirely apology.
///
/// The words are unchanged and one tap away. What is on the page is the fact:
/// this is not available. Anyone who wants to know why can ask, and everyone
/// else gets a page of readings.
class UnavailableNote extends StatelessWidget {
  const UnavailableNote({required this.title, required this.reason, super.key});

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: () => showGSheet(
        context: context,
        title: title,
        children: <Widget>[
          GSheetPoint(
            icon: Icons.info_outline_rounded,
            tone: t.dim,
            text: reason,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: GType.heading.copyWith(color: t.text)),
          ),
          const SizedBox(width: GSpace.sm),
          GBadge(label: context.s('Not available')),
          const SizedBox(width: GSpace.sm - 2),
          Icon(Icons.info_outline_rounded, size: 17, color: t.dim),
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
