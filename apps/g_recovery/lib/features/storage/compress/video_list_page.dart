import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../core/format.dart';
import '../../../core/messenger/g_message.dart';
import '../../../core/messenger/g_messenger.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_enter.dart';
import '../../pro/pro_page.dart';
import '../../pro/state/pro_providers.dart';
import '../state/storage_providers.dart';

/// CLIPS, AND WHAT RE-ENCODING THEM WOULD PROBABLY DO.
///
/// ─── ESTIMATED, AND THE WORD IS NEVER SHARED WITH PHOTOS ─────────────────────
///
/// The photo list says "saves 4.3 MB" because it re-encoded the whole file. A
/// two gigabyte clip cannot be measured that way, because measuring it IS the
/// job. So fifteen seconds of each is really encoded and the rest extrapolated,
/// every figure here is prefixed with a tilde, and the real number appears when
/// the file is done.
///
/// ─── ONE AT A TIME, IN VIEW ONLY ─────────────────────────────────────────────
///
/// Each estimate is seconds of encoding, so estimating a list on open would
/// leave someone watching an empty screen for a minute. Rows ask as they are
/// built and a queue runs them singly: two encoders competing for the same
/// hardware block is slower than either alone.
///
/// ─── AND THE WALL COMES AFTER THE NUMBERS ────────────────────────────────────
///
/// A free user sees the list, the per clip figures and which clips qualify.
/// They are then deciding whether a quantity they can read is worth one
/// payment, rather than deciding whether to trust a claim.
class VideoListPage extends ConsumerStatefulWidget {
  const VideoListPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const VideoListPage(),
  );

  @override
  ConsumerState<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends ConsumerState<VideoListPage> {
  /// Clips the user has taken OUT. Everything starts in, as elsewhere.
  final Set<String> _excluded = <String>{};

  final Map<String, VideoEstimate> _estimates = <String, VideoEstimate>{};

  /// Ids waiting on the encoder, and the one it is working on.
  final List<String> _queue = <String>[];
  String? _working;

  String _preset = 'same';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool pro = ref.watch(proUnlockedProvider);

    final List<VideoCandidate> all =
        ref.watch(videoCandidatesProvider).value ?? const <VideoCandidate>[];
    final List<VideoCandidate> usable =
        all.where((VideoCandidate c) => c.eligible).toList();
    final List<VideoCandidate> refused =
        all.where((VideoCandidate c) => !c.eligible).toList();

    int saving = 0;
    int chosen = 0;
    for (final VideoCandidate clip in usable) {
      if (_excluded.contains(clip.fileId)) continue;
      final VideoEstimate? e = _estimates[clip.fileId];
      if (e == null) continue;
      final int delta = e.originalBytes - e.estimatedBytes;
      if (delta <= 0) continue;
      saving += delta;
      chosen++;
    }

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: 'Video',
                subtitle: usable.isEmpty
                    ? null
                    : '${GFormat.count(usable.length)} worth re-encoding',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            if (_busy)
              const Expanded(child: _Encoding())
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    GSpace.gutter,
                    0,
                    GSpace.gutter,
                    GSpace.xl,
                  ),
                  children: <Widget>[
                    if (usable.isEmpty && refused.isEmpty)
                      GCard(
                        child: Text(
                          'No video on this phone is large enough to be worth '
                          'looking at.',
                          style: GType.bodySmall.copyWith(color: t.muted),
                        ),
                      ),

                    if (usable.isNotEmpty) ...<Widget>[
                      _Note(
                        text:
                            'Fifteen seconds of each clip is really encoded to '
                            'work these out, so they are close rather than '
                            'exact. The true figure appears as each one '
                            'finishes.',
                      ),
                      const SizedBox(height: GSpace.md),

                      _Preset(
                        preset: _preset,
                        onChanged: (String value) => setState(() {
                          _preset = value;
                          // Everything measured was measured at the old
                          // setting. Keeping the figures under a changed
                          // preset is how a measurement quietly becomes a
                          // guess, so they go and the queue starts again.
                          _estimates.clear();
                          _queue.clear();
                          _working = null;
                        }),
                      ),
                      const SizedBox(height: GSpace.md),

                      for (int i = 0; i < usable.length; i++)
                        GEnter(
                          index: i,
                          child: _Clip(
                            clip: usable[i],
                            estimate: _estimates[usable[i].fileId],
                            working: _working == usable[i].fileId,
                            excluded: _excluded.contains(usable[i].fileId),
                            onTap: () => _toggle(usable[i].fileId),
                            onNeeded: () => _want(usable[i].fileId),
                          ),
                        ),
                    ],

                    if (refused.isNotEmpty) ...<Widget>[
                      const SizedBox(height: GSpace.lg),
                      Text(
                        'NOT WORTH RE-ENCODING',
                        style: GType.overline.copyWith(color: t.dim),
                      ),
                      const SizedBox(height: GSpace.sm + 1),
                      // Shown rather than filtered away. A person whose largest
                      // video is simply missing from a list about making files
                      // smaller will conclude the app never saw it.
                      for (final VideoCandidate clip in refused)
                        _Refused(clip: clip),
                    ],
                  ],
                ),
              ),

            if (!_busy && usable.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: pro
                    ? GButton(
                        label: saving == 0
                            ? 'Measuring'
                            : 'Compress ${GFormat.count(chosen)}, save about '
                                  '${GFormat.bytes(saving)}',
                        icon: Icons.compress_rounded,
                        onPressed: saving == 0 ? null : _run,
                      )
                    : _Gate(saving: saving),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Behaviour
  // ───────────────────────────────────────────────────────────────────────────

  void _toggle(String fileId) => setState(() {
    if (!_excluded.remove(fileId)) _excluded.add(fileId);
  });

  /// A row asking for its own estimate.
  ///
  /// Called from build, so it can only enqueue. Starting work here would mark
  /// the tree dirty while it is being built.
  void _want(String fileId) {
    if (_estimates.containsKey(fileId)) return;
    if (_queue.contains(fileId) || _working == fileId) return;
    _queue.add(fileId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  /// Runs the queue, strictly one at a time.
  ///
  /// Two exports at once compete for the same hardware encoder and finish later
  /// than either would alone, and on some devices the second simply fails.
  Future<void> _drain() async {
    if (_working != null || _queue.isEmpty || !mounted) return;

    final String fileId = _queue.removeAt(0);
    setState(() => _working = fileId);

    final VideoEstimate? estimate = await ref
        .read(compressBridgeProvider)
        .estimateVideo(fileId, preset: _preset);

    if (!mounted) return;
    setState(() {
      _working = null;
      if (estimate != null) _estimates[fileId] = estimate;
      // A clip the encoder refused is dropped from the run rather than left
      // sitting selected with no figure behind it.
      if (estimate == null) _excluded.add(fileId);
    });

    await _drain();
  }

  Future<void> _run() async {
    final List<VideoCandidate> all =
        ref.read(videoCandidatesProvider).value ?? const <VideoCandidate>[];

    final List<String> ids = all
        .where((VideoCandidate c) => c.eligible)
        .map((VideoCandidate c) => c.fileId)
        .where((String id) {
          if (_excluded.contains(id)) return false;
          final VideoEstimate? e = _estimates[id];
          return e != null && e.estimatedBytes < e.originalBytes;
        })
        .toList();
    if (ids.isEmpty) return;

    setState(() => _busy = true);

    final List<CompressOutcome> outcomes = await ref
        .read(compressBridgeProvider)
        .compressVideo(ids, preset: _preset);

    if (!mounted) return;

    final int replaced =
        outcomes.where((CompressOutcome o) => o.status == 'replaced').length;
    final int saved = outcomes.fold<int>(
      0,
      (int sum, CompressOutcome o) => sum + o.savedBytes,
    );

    setState(() {
      _busy = false;
      _excluded.clear();
      _estimates.clear();
    });

    ref.invalidate(videoCandidatesProvider);
    ref.invalidate(compressSummaryProvider);
    ref.invalidate(compressHistoryProvider);
    ref.invalidate(storageOverviewProvider);

    GMessenger.show(
      context,
      GMessage.success('$replaced compressed, ${GFormat.bytes(saved)} freed'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rows
// ─────────────────────────────────────────────────────────────────────────────

class _Clip extends StatelessWidget {
  const _Clip({
    required this.clip,
    required this.estimate,
    required this.working,
    required this.excluded,
    required this.onTap,
    required this.onNeeded,
  });

  final VideoCandidate clip;
  final VideoEstimate? estimate;
  final bool working;
  final bool excluded;
  final VoidCallback onTap;
  final VoidCallback onNeeded;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    // Asked for on build, so a clip that scrolls into view starts being
    // measured and one that never does costs nothing.
    if (estimate == null && !working) onNeeded();

    final int? saving = estimate == null
        ? null
        : estimate!.originalBytes - estimate!.estimatedBytes;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        onTap: onTap,
        padding: const EdgeInsets.all(GSpace.sm + 2),
        borderColour: excluded ? null : t.accent.withValues(alpha: 0.4),
        child: Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: excluded ? null : t.accent,
                borderRadius: GRadius.all(7),
                border: Border.all(color: excluded ? t.lineStrong : t.accent),
              ),
              child: excluded
                  ? null
                  : Icon(Icons.check_rounded, size: 14, color: t.onAccent),
            ),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    clip.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // The codec is on the row because it is what decides the
                    // outcome, and it is the answer to why one clip is here and
                    // another is in the section below.
                    '${GFormat.bytes(clip.sizeBytes)}  ·  '
                    '${clip.codec.toUpperCase()}  ·  '
                    '${clip.widthPx}x${clip.heightPx}  ·  '
                    '${_length(clip.durationMillis)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSpace.sm),
            if (working)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: t.accent,
                  strokeWidth: 2,
                ),
              )
            else if (saving != null && saving > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    // A tilde, and never the word the photo list uses. One of
                    // these numbers is a fact and the other is a forecast.
                    '~${GFormat.bytes(saving)}',
                    style: GType.monoSmall.copyWith(
                      color: t.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('ABOUT', style: GType.badge.copyWith(color: t.dim)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _length(int millis) {
    final int seconds = millis ~/ 1000;
    final int minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _Refused extends StatelessWidget {
  const _Refused({required this.clip});

  final VideoCandidate clip;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: Opacity(
        opacity: 0.6,
        child: GCard(
          padding: const EdgeInsets.all(GSpace.sm + 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      clip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.bodySmall.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${GFormat.bytes(clip.sizeBytes)}  ·  '
                      '${clip.codec.toUpperCase()}',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GSpace.sm),
              Text(
                clip.reason ?? 'Left alone',
                style: GType.micro.copyWith(color: t.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two options, not a slider. Resolution is never touched by either.
class _Preset extends StatelessWidget {
  const _Preset({required this.preset, required this.onChanged});

  final String preset;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Choice(
          value: 'same',
          selected: preset == 'same',
          title: 'Same quality',
          detail:
              'A newer codec at matched settings. You will not be able to tell '
              'them apart.',
          onTap: () => onChanged('same'),
        ),
        const SizedBox(height: GSpace.sm),
        _Choice(
          value: 'smaller',
          selected: preset == 'smaller',
          title: 'Smaller',
          detail:
              'Lower bitrate as well. Fine on a phone, softer on a large '
              'screen during fast motion.',
          onTap: () => onChanged('smaller'),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.selected,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      borderColour: selected ? t.accent.withValues(alpha: 0.5) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.accent : t.lineStrong,
                width: 1.5,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: GSpace.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GType.heading.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wall, after the numbers rather than before them.
class _Gate extends StatelessWidget {
  const _Gate({required this.saving});

  final int saving;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Column(
      children: <Widget>[
        GButton(
          // The outcome in gigabytes, not the name of the SKU. The person is
          // deciding whether their own footage is worth a payment, which is a
          // question they can answer.
          label: saving > 0
              ? 'Unlock and recover about ${GFormat.bytes(saving)}'
              : 'Video compression is part of Pro',
          icon: Icons.workspace_premium_outlined,
          onPressed: () => Navigator.of(context).push(ProPage.route()),
        ),
        const SizedBox(height: GSpace.sm),
        Text(
          'Screenshots and photos stay free, and so does everything else here.',
          textAlign: TextAlign.center,
          style: GType.micro.copyWith(color: t.dim),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.08),
        border: Border.all(color: t.warning.withValues(alpha: 0.3)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.straighten_rounded, size: 17, color: t.warning),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Text(
                text,
                style: GType.micro.copyWith(color: t.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The run, watching the progress the bridge already publishes.
class _Encoding extends ConsumerWidget {
  const _Encoding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final CompressProgress? p = ref.watch(compressProgressProvider).value;

    final int done = p?.done ?? 0;
    final int total = p?.total ?? 0;
    final int saved = p?.savedBytes ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            saved > 0 ? GFormat.bytes(saved) : 'Working',
            style: GType.monoDisplay.copyWith(color: t.accent),
          ),
          const SizedBox(height: GSpace.xs),
          Text('freed so far', style: GType.micro.copyWith(color: t.muted)),

          if (total > 0) ...<Widget>[
            const SizedBox(height: GSpace.xl),
            ClipRRect(
              borderRadius: GRadius.all(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: ColoredBox(color: t.panelAlt)),
                    FractionallySizedBox(
                      widthFactor: (done / total).clamp(0.0, 1.0),
                      child: ColoredBox(color: t.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GSpace.sm + 2),
            Text(
              '${GFormat.count(done)} of ${GFormat.count(total)}',
              style: GType.monoSmall.copyWith(color: t.dim),
            ),
          ],

          const SizedBox(height: GSpace.lg),
          Text(
            // Said here because it is the difference between this and every
            // other wait in the app, and because a person who does not know it
            // will sit and watch a progress bar for twenty minutes.
            'You can leave the app. This keeps running and tells you when it '
            'is done.',
            textAlign: TextAlign.center,
            style: GType.micro.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}
