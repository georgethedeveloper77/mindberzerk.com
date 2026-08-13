import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_enter.dart';
import '../../ui/g_sheet.dart';
import '../learn/limits_page.dart';
import 'category_page.dart';
import 'state/recovery_providers.dart';
import 'widgets/source_tile.dart';
import '../../core/i18n/g_strings.dart';

/// WHERE ANY OF THIS COMES FROM.
///
/// The screen that makes the app's claim inspectable. Every other surface
/// answers what can be got back; this one answers how we know, place by place,
/// with the quality stamped on each row before anything is tapped.
///
/// No new bridge call. `RecoverySummary.sources` has carried this list since
/// Phase 4 and the pre-scan has been fetching it on every cold start. The data
/// was arriving and being discarded, and `SourceTile` was written, documented as
/// the promise the app is built on, and never once rendered.
///
/// Reads the PRE-scan rather than triggering a full one. A ledger of where
/// things live is a fast counting question, and making the honesty screen the
/// slowest one in the app would be a poor joke.
class SourcesPage extends ConsumerWidget {
  const SourcesPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const SourcesPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final List<RecoverySource> sources =
        summary?.sources ?? const <RecoverySource>[];

    // Readable sources first, then by how much they hold. One that cannot be
    // read is still shown, at the bottom, because a missing row reads as a place
    // we forgot rather than one this phone refuses.
    final List<RecoverySource> ordered = List<RecoverySource>.of(sources)
      ..sort((RecoverySource a, RecoverySource b) {
        if (a.available != b.available) return a.available ? -1 : 1;
        return b.itemCount.compareTo(a.itemCount);
      });

    final int reachable = ordered
        .where((RecoverySource s) => s.available)
        .length;
    final int items = ordered.fold<int>(
      0,
      (int total, RecoverySource s) => total + s.itemCount,
    );
    final int bytes = ordered.fold<int>(
      0,
      (int total, RecoverySource s) => total + s.totalBytes,
    );
    final int biggest = ordered.fold<int>(
      0,
      (int most, RecoverySource s) => s.totalBytes > most ? s.totalBytes : most,
    );

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
              title: context.s('Safety nets'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                GIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: () => _showDetail(context),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.md),
              child: Text(
                context.s(
                  'Every place on this phone where deleted data can still be '
                  'hiding, and what quality each one gives back.',
                ),
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
            ),

            if (summary != null) ...<Widget>[
              GEnter(
                index: 0,
                child: _Facts(
                  reachable: reachable,
                  total: ordered.length,
                  items: items,
                  bytes: bytes,
                ),
              ),
              const SizedBox(height: GSpace.md),
            ],

            if (summary == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: GSpace.xl),
                child: Center(
                  child: Text(
                    context.s('Checking your device'),
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ),
              )
            else
              for (int i = 0; i < ordered.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: GSpace.sm),
                  child: GEnter(
                    index: i + 1,
                    child: SourceTile(
                      source: ordered[i],
                      expanded: false,
                      share: biggest == 0 ? 0 : ordered[i].totalBytes / biggest,
                      // Straight into that source alone, every kind. The one
                      // place in the app where routing by SOURCE is correct
                      // rather than a bug: the user came here asking about a
                      // place, not about a kind.
                      onTap: () => Navigator.of(context).push(
                        CategoryPage.route(
                          title: ordered[i].label,
                          sourceIds: <String>[ordered[i].sourceId],
                        ),
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: GSpace.md),
            GEnter(
              index: ordered.length + 1,
              child: GCard(
                onTap: () => Navigator.of(context).push(LimitsPage.route()),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: t.accentText,
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: Text(
                        context.s('What cannot come back, and why'),
                        style: GType.heading.copyWith(color: t.text),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: t.dim),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: context.s('Reading this page'),
      children: <Widget>[
        Text(
          context.s(
            'A safety net is anywhere on the phone that holds onto something after '
            'you have deleted it. Each one behaves differently, so each row says '
            'what you would actually get back.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('The stamps'),
        GSheetPoint(
          icon: Icons.check_circle_outline_rounded,
          tone: t.success,
          text: context.s(
            'Full quality means the original file is still here. Restoring '
            'gives you exactly what you had.',
          ),
        ),
        GSheetPoint(
          icon: Icons.filter_drama_outlined,
          tone: t.warning,
          text: context.s(
            'Preview only means the original is gone and what survives is '
            'the small copy Android kept to draw your gallery quickly. It is '
            'a few hundred pixels wide.',
          ),
        ),
        GSheetPoint(
          icon: Icons.remove_circle_outline_rounded,
          tone: t.dim,
          text: context.s(
            'Gone means this phone will not let any app look there. The row '
            'stays visible so you know it was checked and not forgotten.',
          ),
        ),
        const GSheetHeading('The bar'),
        Text(
          context.s(
            'Each row carries a bar showing its size against the largest net. It '
            'answers which one is worth opening first, which a list of numbers on '
            'its own does not.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('Why the counts move'),
        Text(
          context.s(
            'These come from a fast count taken when the app opens. A full scan '
            'walks folders that counting cannot reach, so the numbers usually '
            'grow after one has run.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
      ],
    );
  }
}

/// The ledger in four numbers.
class _Facts extends StatelessWidget {
  const _Facts({
    required this.reachable,
    required this.total,
    required this.items,
    required this.bytes,
  });

  final int reachable;
  final int total;
  final int items;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool complete = reachable == total;

    return GCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Fact(
            value: '$reachable of $total',
            label: context.s('nets reachable'),
            // Amber whenever one is out of reach, because that is the reason a
            // total on another screen is lower than the user expected.
            tone: complete ? t.text : t.warning,
          ),
          _Fact(
            value: GFormat.count(items),
            label: context.s('items held'),
            tone: t.text,
          ),
          _Fact(
            value: GFormat.bytes(bytes),
            label: context.s('in total'),
            tone: t.text,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label, required this.tone});

  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.monoNumber.copyWith(color: tone, fontSize: 18),
          ),
          Text(label, style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
