import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/compress_api.g.dart';
import '../../bridge/compress_bridge.dart';
import '../../bridge/server_api.g.dart';
import '../../bridge/server_bridge.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import 'state/pro_providers.dart';

/// PRICED AGAINST THIS PHONE.
///
/// ─── WHY THE OLD VERSION WAS GENERIC ─────────────────────────────────────────
///
/// A price, three ticks and two paragraphs. The same screen every app ships,
/// and it said nothing that could not have been written before the app existed.
///
/// Everything else in this product refuses to claim a number it has not
/// measured. The paywall can be held to the same standard, because by the time
/// somebody reaches it the app already knows how many of their clips qualify,
/// roughly what that is worth in gigabytes, and when they last backed up.
///
/// On a phone with no eligible video and no server the top block is short and
/// the honest reading is that Pro is not for them yet. That is a feature: an
/// offer that cannot describe itself in the reader's own numbers is an offer
/// they should probably decline.
///
/// ─── AND THE RULE IS DRAWN RATHER THAN LISTED ────────────────────────────────
///
/// Two columns, by hand and while you are away, carrying the same rows so the
/// difference is visible instead of asserted. Free sits BESIDE the paid column
/// rather than in a footnote beneath the button, which is what makes "nothing
/// moves out of the left column" believable.
class ProPage extends ConsumerWidget {
  const ProPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ProPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ProState pro = ref.watch(proProvider);

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: 'Pro',
              subtitle: pro.unlocked
                  ? 'Active on this account'
                  : 'One payment, no subscription',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (pro.unlocked) ...<Widget>[
              const _Owned(),
              const SizedBox(height: GSpace.lg),
              const _Overline('What is running for you'),
              const _Running(),
            ] else ...<Widget>[
              const _Overline('What it would do on this phone'),
              const _Yours(),

              const SizedBox(height: GSpace.lg),
              const _Overline('The difference, exactly'),
              const _Ledger(),

              const SizedBox(height: GSpace.lg),
              _Price(pro: pro),

              if (pro.problem != null) ...<Widget>[
                const SizedBox(height: GSpace.sm),
                Text(
                  pro.problem!,
                  textAlign: TextAlign.center,
                  style: GType.micro.copyWith(color: t.danger),
                ),
              ],

              const SizedBox(height: GSpace.sm),
              GButton(
                label: pro.busy
                    ? 'Talking to Play'
                    : !pro.storeAvailable
                    ? 'Not available on this device'
                    : 'Unlock Pro',
                onPressed: pro.busy || !pro.storeAvailable
                    ? null
                    : () => ref.read(proProvider.notifier).buy(),
              ),
              const SizedBox(height: GSpace.sm),
              GButton(
                label: 'Restore a previous purchase',
                kind: GButtonKind.ghost,
                onPressed: pro.busy || !pro.storeAvailable
                    ? null
                    : () => ref.read(proProvider.notifier).restore(),
              ),
            ],

            const SizedBox(height: GSpace.lg),
            _Never(owned: pro.unlocked),
          ],
        ),
      ),
    );
  }
}

/// THE ONLY PART OF THIS PAGE THAT IS NOT THE SAME FOR EVERYBODY.
///
/// Rows appear only when their fact is true, so a phone with nothing to offer
/// shows nothing rather than a row of noughts arguing for a purchase.
class _Yours extends ConsumerWidget {
  const _Yours();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final CompressSummary? compress = ref.watch(compressSummaryProvider).value;
    final ServerConfig? server = ref.watch(serverConfigProvider).value;
    final TransferState? transfer = ref.watch(transferProvider).value;

    final int clips = compress?.videoCount ?? 0;
    final int clipBytes = compress?.videoBytes ?? 0;

    final int? lastRun = transfer?.lastRunMillis;
    final int? staleDays = lastRun == null
        ? null
        : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastRun))
              .inDays;

    final List<Widget> rows = <Widget>[
      if (clips > 0)
        _Row(
          icon: Icons.play_arrow_rounded,
          tone: t.video,
          title: '${GFormat.count(clips)} '
              '${clips == 1 ? 'clip' : 'clips'} could be re-encoded',
          detail: 'Measured from a real sample of each one',
          // What they weigh now, not what would come back. The saving is an
          // estimate that costs seconds per clip to produce, and this page is
          // not allowed to spend that to make an argument.
          value: GFormat.bytes(clipBytes),
          unit: 'NOW',
        ),

      if (server != null && staleDays != null && staleDays >= 2)
        _Row(
          icon: Icons.schedule_rounded,
          tone: t.warning,
          title: 'Last backup was $staleDays days ago',
          detail: 'A nightly run would have made it one',
          value: '$staleDays',
          unit: 'DAYS',
        ),

      if (server != null && lastRun == null)
        _Row(
          icon: Icons.cloud_upload_outlined,
          tone: t.warning,
          title: 'Your server has never been used',
          detail: 'A nightly run would start it without you',
          value: 'Never',
          unit: 'RUN',
        ),
    ];

    if (rows.isEmpty) {
      // ─── AN HONEST NOTHING ──────────────────────────────────────────────
      //
      // No eligible video, no server, nothing stale. There is no case to make
      // from this phone's own numbers, and inventing one would be the exact
      // move this whole page exists to avoid.
      return _Shell(
        child: Padding(
          padding: const EdgeInsets.all(GSpace.md + 2),
          child: Text(
            'Nothing on this phone would gain from Pro today. It is worth '
            'coming back when you have set up a server, or recorded video the '
            'camera app has not already compressed.',
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
        ),
      );
    }

    return _Shell(child: Column(children: rows));
  }
}

/// The same block after paying, reporting rather than forecasting.
class _Running extends ConsumerWidget {
  const _Running();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final ServerConfig? server = ref.watch(serverConfigProvider).value;
    final int? next = ref.watch(nextRunProvider).value;
    final List<CompressedEntry> history =
        ref.watch(compressHistoryProvider).value ?? const <CompressedEntry>[];

    final int freed = history.fold<int>(
      0,
      (int sum, CompressedEntry e) => sum + (e.originalBytes - e.newBytes),
    );

    return _Shell(
      child: Column(
        children: <Widget>[
          if (server != null)
            _Row(
              icon: Icons.schedule_rounded,
              tone: server.scheduled ? t.success : t.dim,
              title: server.scheduled
                  ? 'Nightly backup is on'
                  : 'Nightly backup is available',
              detail: server.scheduled
                  ? next == null
                        ? 'About once a day, charging and on Wi-Fi'
                        : 'Next run ${GFormat.relativeDay(DateTime.fromMillisecondsSinceEpoch(next), DateTime.now())}'
                  : 'Turn it on from the home server page',
              value: server.scheduled ? 'On' : 'Off',
              unit: 'SCHEDULE',
            ),

          if (history.isNotEmpty)
            _Row(
              icon: Icons.compress_rounded,
              tone: t.accent,
              title: '${GFormat.count(history.length)} files made smaller',
              detail: 'Every original is still in the trash for thirty days',
              value: GFormat.bytes(freed),
              unit: 'FREED',
            ),
        ],
      ),
    );
  }
}

/// TWO COLUMNS, SO THE RULE IS VISIBLE RATHER THAN ASSERTED.
class _Ledger extends StatelessWidget {
  const _Ledger();

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return _Shell(
      child: Column(
        children: <Widget>[
          Container(
            color: t.panelAlt,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Head(text: 'BY HAND  ·  FREE', tone: t.success),
                ),
                Container(width: 1, height: 34, color: t.line),
                Expanded(
                  child: _Head(
                    text: 'WHILE YOU ARE AWAY  ·  PRO',
                    tone: t.accent,
                  ),
                ),
              ],
            ),
          ),
          const _Pair(
            free: 'Back up',
            freeDetail: 'You open the app and tap',
            pro: 'Nightly',
            proDetail: 'Once a day, charging, on Wi-Fi',
          ),
          const _Pair(
            free: 'Compress photos',
            freeDetail: 'Screenshots and pictures, measured',
            pro: 'Compress video',
            proDetail: 'Long encodes that keep running',
          ),
          const _Pair(
            free: 'Everything else',
            freeDetail:
                'Recovery, scanning, duplicates, reclaim, device tools, '
                'the message archive',
            // ─── THE ROW THAT MATTERS ────────────────────────────────────
            //
            // Said on the paid side, in the paid column, where somebody
            // weighing the offer is looking. A promise that nothing moves out
            // of the left column is worth more here than in a paragraph under
            // the button.
            pro: null,
            proDetail: 'Unchanged. Nothing moves out of the left column.',
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.free,
    required this.freeDetail,
    required this.pro,
    required this.proDetail,
  });

  final String free;
  final String freeDetail;
  final String? pro;
  final String proDetail;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _Cell(title: free, detail: freeDetail, tone: t.success),
            ),
            Container(width: 1, color: t.line),
            Expanded(
              child: ColoredBox(
                color: t.accent.withValues(alpha: 0.05),
                child: _Cell(title: pro, detail: proDetail, tone: t.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.title, required this.detail, required this.tone});

  final String? title;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.all(GSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(title!, style: GType.heading.copyWith(color: tone)),
            const SizedBox(height: 3),
          ],
          Text(
            detail,
            style: GType.micro.copyWith(
              color: title == null ? t.dim : t.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: GSpace.md,
      vertical: GSpace.md - 1,
    ),
    child: Text(text, style: GType.overline.copyWith(color: tone)),
  );
}

/// The price, from Play, with the terms beside it rather than in bullets.
class _Price extends StatelessWidget {
  const _Price({required this.pro});

  final ProState pro;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: GRadius.all(GRadius.card),
        border: Border.all(color: t.accent.withValues(alpha: 0.34)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            t.accent.withValues(alpha: 0.10),
            t.accent.withValues(alpha: 0.01),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              // Absent rather than guessed while Play is answering, and never a
              // literal: a hardcoded price is right in one country and wrong in
              // every other.
              pro.price ?? ' ',
              style: GType.monoDisplay.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.xs + 1),
            Text(
              'from Google Play, in your own currency',
              style: GType.micro.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.md),
            Wrap(
              spacing: GSpace.md,
              runSpacing: GSpace.sm,
              children: <Widget>[
                _Term(text: 'ONCE'),
                _Term(text: 'EVERY DEVICE ON THIS ACCOUNT'),
                _Term(text: 'NO RENEWAL'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_rounded, size: 12, color: t.success),
        const SizedBox(width: 4),
        Text(text, style: GType.badge.copyWith(color: t.dim)),
      ],
    );
  }
}

/// THE STRONGEST THING ON THE PAGE, AND IT COSTS NOTHING TO KEEP.
///
/// Stays after a purchase and changes tense. It is worth as much to somebody
/// who has paid as to somebody deciding, and a purchase could otherwise be
/// assumed to have voided it.
class _Never extends StatelessWidget {
  const _Never({required this.owned});

  final bool owned;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final List<String> lines = owned
        ? <String>[
            'No ads, no subscription, nothing to renew',
            'No cloud of ours holding your files',
            'Nothing you have made smaller or copied depends on this staying '
                'paid',
          ]
        : <String>[
            'Show an ad, or ship a disabled ad library',
            'Charge a subscription',
            'Rent you cloud storage of ours',
            'Stop anything working if you never pay',
          ];

    return _Shell(
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md + 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              owned ? 'STILL TRUE' : 'WHAT WE WILL NEVER DO',
              style: GType.overline.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.md - 2),
            for (final String line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.sm - 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.close_rounded, size: 13, color: t.danger),
                    const SizedBox(width: GSpace.sm),
                    Expanded(
                      child: Text(
                        line,
                        style: GType.micro.copyWith(color: t.dim),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Owned extends StatelessWidget {
  const _Owned();

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: GRadius.all(GRadius.card),
        border: Border.all(color: t.success.withValues(alpha: 0.32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            t.success.withValues(alpha: 0.10),
            t.success.withValues(alpha: 0.01),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.check_rounded, size: 19, color: t.success),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Thank you',
                    style: GType.heading.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Active on every device signed in to the same Google '
                    'account. There is nothing to renew and nothing to manage.',
                    style: GType.micro.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parts
// ─────────────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String detail;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Container(
      padding: const EdgeInsets.all(GSpace.md + 1),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              borderRadius: GRadius.all(9),
            ),
            child: Icon(icon, size: 15, color: tone),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GType.bodySmall.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ),
          const SizedBox(width: GSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                value,
                style: GType.monoSmall.copyWith(
                  color: t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(unit, style: GType.badge.copyWith(color: t.dim)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A bordered box with the last divider trimmed.
///
/// The rows above draw their own bottom border, which is right in the middle of
/// a list and wrong at the end of one. Clipping is cheaper than teaching every
/// row where it sits.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: GRadius.all(GRadius.card),
        border: Border.all(color: t.line),
      ),
      child: ClipRRect(
        borderRadius: GRadius.all(GRadius.card),
        child: child,
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: GSpace.sm + 1),
      child: Text(
        text.toUpperCase(),
        style: GType.overline.copyWith(color: t.dim),
      ),
    );
  }
}
