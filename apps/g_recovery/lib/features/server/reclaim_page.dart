import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/server_api.g.dart';
import '../../bridge/server_bridge.dart';
import '../../bridge/storage_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_enter.dart';
import '../storage/state/storage_providers.dart';
import '../../core/i18n/g_strings.dart';

/// FREEING SPACE THAT IS ALREADY SAFE.
///
/// The point of the whole backup feature, and the only screen in the app that
/// deliberately removes originals.
///
/// ─── TWO INDEPENDENT SAFETY NETS ─────────────────────────────────────────────
///
/// First, nothing is removed until it has been hashed on both sides and the
/// hashes matched. A file that fails, throws, or is missing on the server is
/// left alone.
///
/// Second, what is removed goes to the system trash, not out. Thirty days of
/// grace on top of the verification, because the cost of being wrong here is a
/// photograph that exists in no other place.
///
/// ─── THE VERIFY IS NOT SKIPPABLE ─────────────────────────────────────────────
///
/// There is no "trust the list" path and there will not be. The listing compares
/// sizes, which is cheap over a whole library and misses a corrupted file of the
/// same length, and that is precisely the case where deleting the local copy
/// loses something.
class ReclaimPage extends ConsumerStatefulWidget {
  const ReclaimPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ReclaimPage(),
  );

  @override
  ConsumerState<ReclaimPage> createState() => _ReclaimPageState();
}

class _ReclaimPageState extends ConsumerState<ReclaimPage> {
  final Set<String> _picked = <String>{};

  /// Null until a run starts, then 0 to 1.
  double? _progress;
  String? _stage;

  /// Ids that failed verification, kept so the list can say which and why.
  final Set<String> _failed = <String>{};

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<ReclaimCandidate> all =
        ref.watch(reclaimableProvider).value ?? const <ReclaimCandidate>[];

    // Only what the server actually has. An unverified candidate is not offered
    // at all rather than offered with a warning: a checkbox next to a file the
    // app is unsure about is an invitation to lose it.
    final List<ReclaimCandidate> ready = all
        .where((ReclaimCandidate c) => c.verified)
        .toList();

    final int bytes = ready
        .where((ReclaimCandidate c) => _picked.contains(c.fileId))
        .fold<int>(0, (int sum, ReclaimCandidate c) => sum + c.sizeBytes);

    final bool busy = _progress != null;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: context.s('Reclaim space'),
                subtitle: ready.isEmpty
                    ? null
                    : '${GFormat.count(ready.length)} files  ·  '
                          '${GFormat.bytes(_total(ready))}',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            if (busy)
              Expanded(
                child: _Running(progress: _progress!, stage: _stage),
              )
            else if (ready.isEmpty)
              Expanded(child: _Empty(hadCandidates: all.isNotEmpty))
            else ...<Widget>[
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    GSpace.gutter,
                    0,
                    GSpace.gutter,
                    GSpace.xl,
                  ),
                  itemCount: ready.length + 1,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return _Explainer(cost: _remoteCost(ready));
                    }
                    final ReclaimCandidate item = ready[index - 1];
                    return GEnter(
                      index: index - 1,
                      child: _Row(
                        item: item,
                        selected: _picked.contains(item.fileId),
                        failed: _failed.contains(item.fileId),
                        onTap: () => setState(() {
                          if (!_picked.remove(item.fileId)) {
                            _picked.add(item.fileId);
                          }
                        }),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: Row(
                  children: <Widget>[
                    GButton(
                      label: _picked.length == ready.length ? 'None' : 'All',
                      kind: GButtonKind.ghost,
                      expand: false,
                      onPressed: () => setState(() {
                        if (_picked.length == ready.length) {
                          _picked.clear();
                        } else {
                          _picked
                            ..clear()
                            ..addAll(
                              ready.map((ReclaimCandidate c) => c.fileId),
                            );
                        }
                      }),
                    ),
                    const SizedBox(width: GSpace.sm + 1),
                    Expanded(
                      child: GButton(
                        label: _picked.isEmpty
                            ? 'Choose files'
                            : 'Check and free ${GFormat.bytes(bytes)}',
                        icon: Icons.verified_outlined,
                        onPressed: _picked.isEmpty ? null : _run,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _total(List<ReclaimCandidate> items) =>
      items.fold<int>(0, (int sum, ReclaimCandidate c) => sum + c.sizeBytes);

  /// How much has to be downloaded to check this list, when that is not free.
  ///
  /// ─── THE CONTRACT DOES NOT BEND FOR A SLOW LINK ──────────────────────────
  ///
  /// Verifying means hashing both copies, which means reading the server's copy
  /// back. Over SMB on a home network that costs nothing anyone notices. Over
  /// https to a server across the internet it is a full download of every file
  /// being reclaimed, which is the same volume as the space about to be freed.
  ///
  /// The answer is not to skip the check. It is to say so before the tap, so
  /// nobody discovers it from their data bill.
  int? _remoteCost(List<ReclaimCandidate> ready) {
    final ServerConfig? config = ref.watch(serverConfigProvider).value;
    if (config == null) return null;
    if (!_isRemote(config)) return null;
    return _total(ready);
  }

  /// Whether the server is somewhere this phone has to leave the house to
  /// reach.
  ///
  /// A guess, and deliberately a conservative one: anything that does not look
  /// like a private address is treated as remote, so the warning appears for a
  /// LAN server with an odd host name rather than being missed for a real
  /// remote one. Being wrong here costs a sentence nobody needed, and being
  /// wrong the other way costs somebody's data allowance.
  static bool _isRemote(ServerConfig config) {
    if (config.protocol != 'webdav') return false;

    final String host = config.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.local')) return false;
    // A bare name with no dots is resolved on the local network by definition.
    if (!host.contains('.')) return false;
    if (host.startsWith('192.168.') || host.startsWith('10.')) return false;
    if (host.startsWith('169.254.')) return false;

    // 172.16.0.0 to 172.31.255.255, which is the one private range that cannot
    // be matched on a prefix string.
    final List<String> parts = host.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final int? second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) return false;
    }

    return true;
  }

  /// Verify, then trash what passed.
  ///
  /// The two steps are visible as two stages, because the first one takes the
  /// time and a person watching a bar move deserves to know which half they are
  /// in.
  Future<void> _run() async {
    setState(() {
      _progress = 0;
      _stage = 'Checking each file is really on the server';
      _failed.clear();
    });

    final List<String> chosen = _picked.toList();
    final List<String> verified = await ref
        .read(serverBridgeProvider)
        .verify(chosen);
    if (!mounted) return;

    final Set<String> ok = verified.toSet();
    final List<String> failed = chosen
        .where((String id) => !ok.contains(id))
        .toList();

    if (verified.isEmpty) {
      setState(() {
        _progress = null;
        _stage = null;
        _failed.addAll(failed);
      });
      GMessenger.show(
        context,
        GMessage('Nothing matched. Files left where they are.'),
      );
      return;
    }

    setState(() {
      _progress = 0.6;
      _stage = 'Moving ${GFormat.count(verified.length)} to the trash';
    });

    final List<StorageOutcome> outcomes = await ref
        .read(storageBridgeProvider)
        .remove(verified, permanent: false);
    if (!mounted) return;

    final int removed = outcomes
        .where(
          (StorageOutcome o) => o.status == 'trashed' || o.status == 'deleted',
        )
        .length;

    setState(() {
      _progress = null;
      _stage = null;
      _picked.removeAll(verified);
      _failed.addAll(failed);
    });

    ref.invalidate(reclaimableProvider);
    ref.invalidate(storageOverviewProvider);

    GMessenger.show(
      context,
      failed.isEmpty
          ? GMessage.success('$removed moved to trash')
          : GMessage(
              '$removed freed. ${failed.length} did not match and were kept.',
            ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({this.cost});

  /// Bytes that will be downloaded to run the check, when that is not free.
  /// Null on a home network, where it is.
  final int? cost;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int? cost = this.cost;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md),
      child: Column(
        children: <Widget>[
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Step(
                  icon: Icons.verified_outlined,
                  tone: t.success,
                  text: context.s(
                    'Each file is hashed here and on the server before '
                    'anything is touched.',
                  ),
                ),
                const SizedBox(height: GSpace.sm),
                _Step(
                  icon: Icons.restore_from_trash_outlined,
                  tone: t.docs,
                  text: context.s(
                    'What matches goes to the trash, where Android keeps '
                    'it for thirty days.',
                  ),
                ),
              ],
            ),
          ),
          if (cost != null && cost > 0) ...<Widget>[
            const SizedBox(height: GSpace.sm + 1),
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.warning.withValues(alpha: 0.10),
                border: Border.all(color: t.warning.withValues(alpha: 0.32)),
                borderRadius: GRadius.all(GRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(GSpace.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.data_usage_rounded, size: 18, color: t.warning),
                    const SizedBox(width: GSpace.md - 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Checking everything here downloads '
                            '${GFormat.bytes(cost)}',
                            style: GType.heading.copyWith(color: t.warning),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.s(
                              'This server is not on your network, so the only '
                              'way to be sure a copy is intact is to read it '
                              'back. On Wi-Fi that costs nothing. On mobile '
                              'data it costs the same as the space you are '
                              'freeing. Choosing fewer files costs less.',
                            ),
                            style: GType.bodySmall.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: tone),
        const SizedBox(width: GSpace.md - 2),
        Expanded(
          child: Text(text, style: GType.micro.copyWith(color: t.muted)),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.progress, required this.stage});

  final double progress;
  final String? stage;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            stage ?? 'Working',
            textAlign: TextAlign.center,
            style: GType.title.copyWith(color: t.text),
          ),
          const SizedBox(height: GSpace.lg),
          // Indeterminate, deliberately. Native returns one answer at the end
          // rather than per file progress, and a bar that crawls to 60% and
          // waits is a lie about how far along it is.
          GBar(fraction: null, colour: t.accent),
          const SizedBox(height: GSpace.md),
          Text(
            context.s('Reading both copies takes a moment on a large file.'),
            textAlign: TextAlign.center,
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hadCandidates});

  final bool hadCandidates;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_done_outlined, size: 40, color: t.dim),
            const SizedBox(height: GSpace.lg),
            Text(
              hadCandidates ? 'Nothing verified' : 'Nothing to reclaim yet',
              textAlign: TextAlign.center,
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              hadCandidates
                  // The distinction matters: one is "back up first", the other
                  // is "your server may have lost something".
                  ? 'Files were uploaded but the server no longer has them at '
                        'the same size. Back up again before freeing space.'
                  : 'Back up to your server first. Anything it holds can then '
                        'be removed from the phone.',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.selected,
    required this.failed,
    required this.onTap,
  });

  final ReclaimCandidate item;
  final bool selected;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        onTap: failed ? null : onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? t.accent : t.line,
                  width: 1.5,
                ),
                borderRadius: GRadius.all(7),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 14, color: t.onAccent)
                  : null,
            ),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.bodySmall.copyWith(
                      color: failed ? t.muted : t.text,
                    ),
                  ),
                  if (failed)
                    Text(
                      context.s('Did not match, kept'),
                      style: GType.micro.copyWith(color: t.warning),
                    ),
                ],
              ),
            ),
            const SizedBox(width: GSpace.sm),
            Text(
              GFormat.bytes(item.sizeBytes),
              style: GType.monoSmall.copyWith(color: t.dim),
            ),
          ],
        ),
      ),
    );
  }
}
