import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/features/storage/state/storage_providers.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../../core/i18n/g_strings.dart';

/// WATCHING WHAT IT WOULD ACTUALLY BECOME.
///
/// ─── THIS IS THE OUTPUT, NOT A PREDICTION OF IT ──────────────────────────────
///
/// Estimating already encodes fifteen real seconds at the chosen settings. That
/// file used to be weighed and deleted. Keeping it means the preview is the
/// encoder's own work rather than a description of it, which is a stronger
/// guarantee than the photo path can give: there, both versions are stills and
/// the eye has to hunt for the artefact.
///
/// ─── PLAYING THE ORIGINAL WOULD NOT BE A PREVIEW ─────────────────────────────
///
/// It shows what is already on the phone and says nothing about what would
/// happen to it. The original is here for comparison, one tap away, and it is
/// deliberately the secondary thing.
///
/// ─── ONE PLAYER AT A TIME, AND THE POSITION SURVIVES ─────────────────────────
///
/// Two initialised controllers would switch instantly and hold two hardware
/// decoders open, which on a mid range phone is how the second one silently
/// fails to start. Switching disposes and rebuilds at the same timestamp
/// instead. It costs a moment, and the sample is the first fifteen seconds of
/// the original, so the timestamps line up exactly.
class VideoPreviewPage extends ConsumerStatefulWidget {
  const VideoPreviewPage({
    required this.clip,
    required this.estimate,
    super.key,
  });

  final VideoCandidate clip;
  final VideoEstimate estimate;

  static Route<void> route({
    required VideoCandidate clip,
    required VideoEstimate estimate,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) =>
        VideoPreviewPage(clip: clip, estimate: estimate),
  );

  @override
  ConsumerState<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends ConsumerState<VideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _showingOriginal = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(Duration.zero);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load(Duration at) async {
    final VideoPlayerController? old = _controller;
    if (mounted) setState(() => _controller = null);
    await old?.dispose();

    final VideoPlayerController? next = _showingOriginal
        ? await _original()
        : await _sample();

    if (next == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    try {
      await next.initialize();
    } catch (_) {
      // A codec this phone cannot decode. Real, and commoner on the original
      // than on the sample, since the sample was made by this device.
      await next.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (!mounted) {
      await next.dispose();
      return;
    }

    setState(() {
      _controller = next;
      _failed = false;
    });

    await next.setLooping(true);
    // The sample is the opening of the original, so the same timestamp shows
    // the same frame in both. That is the whole reason a comparison is possible
    // at all rather than being two clips playing near each other.
    await next.seekTo(at);
    await next.play();
  }

  Future<VideoPlayerController?> _sample() async {
    final String? path = widget.estimate.samplePath;
    if (path == null) return null;

    final File file = File(path);
    // Swept after an hour, so a screen left open overnight comes back to
    // nothing. Saying so beats a player that never starts.
    if (!file.existsSync()) return null;

    return VideoPlayerController.file(file);
  }

  Future<VideoPlayerController?> _original() async {
    final String? uri = await ref
        .read(storageBridgeProvider)
        .contentUri(widget.clip.fileId);
    if (uri == null) return null;

    // contentUri is the only constructor that works for a MediaStore row. The
    // path behind it is unreadable under scoped storage even when the row reads
    // perfectly.
    return VideoPlayerController.contentUri(Uri.parse(uri));
  }

  Future<void> _swap() async {
    final Duration at = _controller?.value.position ?? Duration.zero;
    setState(() => _showingOriginal = !_showingOriginal);
    await _load(at);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final VideoPlayerController? controller = _controller;
    final int saving =
        widget.estimate.originalBytes - widget.estimate.estimatedBytes;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(GSpace.sm),
              child: Row(
                children: <Widget>[
                  _Round(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      widget.clip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.bodySmall.copyWith(color: t.muted),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFF000000),
                      child: _failed
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(GSpace.xl),
                                child: Text(
                                  _showingOriginal
                                      ? 'This phone cannot play the original.'
                                      : 'The sample is no longer on disk. Go '
                                            'back and measure this clip again.',
                                  textAlign: TextAlign.center,
                                  style: GType.bodySmall.copyWith(
                                    color: t.muted,
                                  ),
                                ),
                              ),
                            )
                          : controller == null ||
                                !controller.value.isInitialized
                          ? Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: t.accent,
                                  strokeWidth: 2.2,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: () => setState(() {
                                controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play();
                              }),
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: controller.value.aspectRatio,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            ),
                    ),
                  ),

                  Positioned(
                    top: GSpace.md,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _Pill(
                        label: _showingOriginal
                            ? 'Original'
                            : 'After  ·  ${widget.estimate.preset == "smaller" ? "smaller" : "same quality"}',
                        tone: _showingOriginal ? t.warning : t.accent,
                      ),
                    ),
                  ),

                  if (controller != null && controller.value.isInitialized)
                    Positioned(
                      left: GSpace.gutter,
                      right: GSpace.gutter,
                      bottom: GSpace.md,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: t.accent,
                          bufferedColor: t.panelAlt,
                          backgroundColor: t.panel,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                GSpace.md,
                GSpace.gutter,
                GSpace.lg,
              ),
              child: Column(
                children: <Widget>[
                  GCard(
                    padding: const EdgeInsets.all(GSpace.md),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _Side(
                            label: context.s('Now'),
                            value: GFormat.bytes(widget.estimate.originalBytes),
                            highlight: false,
                          ),
                        ),
                        Expanded(
                          child: _Side(
                            label: context.s('After, about'),
                            value: GFormat.bytes(
                              widget.estimate.estimatedBytes,
                            ),
                            highlight: true,
                          ),
                        ),
                        Expanded(
                          child: _Side(
                            label: context.s('Saving'),
                            value: saving > 0
                                ? '~${GFormat.bytes(saving)}'
                                : 'none',
                            highlight: false,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: GSpace.sm),
                  Text(
                    // Said plainly, because the player above is fifteen seconds
                    // of a clip that may run for six minutes, and somebody will
                    // otherwise assume the whole thing was already encoded.
                    'You are watching the first '
                    '${widget.estimate.sampledMillis ~/ 1000} seconds, really '
                    'encoded at these settings. The rest is estimated from it.',
                    textAlign: TextAlign.center,
                    style: GType.micro.copyWith(color: t.dim),
                  ),

                  const SizedBox(height: GSpace.md),
                  GButton(
                    label: _showingOriginal
                        ? 'Back to the compressed version'
                        : 'Compare with the original',
                    icon: Icons.compare_rounded,
                    kind: GButtonKind.ghost,
                    onPressed: _swap,
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

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: GType.badge.copyWith(color: t.dim)),
        const SizedBox(height: 3),
        Text(
          value,
          style: GType.monoSmall.copyWith(
            color: highlight ? t.accent : t.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md,
        vertical: GSpace.sm - 2,
      ),
      decoration: BoxDecoration(
        color: t.ink.withValues(alpha: 0.74),
        borderRadius: GRadius.all(GRadius.chip),
        border: Border.all(color: t.line),
      ),
      child: Text(label, style: GType.micro.copyWith(color: tone)),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      color: t.panelAlt,
      borderRadius: GRadius.all(GRadius.tile),
      child: InkWell(
        borderRadius: GRadius.all(GRadius.tile),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: t.muted),
        ),
      ),
    );
  }
}
