import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_button.dart';
import '../../ui/g_thumbnail.dart';
import '../recovery/state/recovery_providers.dart';

/// ONE RECOVERED ITEM, FULL SCREEN.
///
/// The recovery twin of the storage frame, and it had to be written rather than
/// shared because the two carry different types and reach the platform through
/// different bridges. Everything a user can tell apart is identical: images
/// pinch, video plays, text and CSV render, PDF renders, and anything else is
/// handed to an app that can open it.
///
/// ─── TWO THINGS THE STORAGE SIDE NEVER FACED ─────────────────────────────────
///
/// A trashed MediaStore row is hidden by IS_TRASHED, so its URI is real but some
/// OEM builds refuse to decode from it. The player is therefore allowed to fail
/// and falls through to the preview rather than sitting black.
///
/// A loose file in an app trash folder has no URI at all. It cannot be played
/// and it cannot be handed to another app without FileProvider, but it CAN be
/// read, so text and PDF still work where video does not.
class RecoveredFrame extends ConsumerWidget {
  const RecoveredFrame({required this.item, super.key});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String mime = item.mimeType ?? '';
    final String name = item.name.toLowerCase();

    if (item.kind == 'image') return _Image(item: item);
    if (item.kind == 'video' || item.kind == 'audio') {
      return _Play(item: item);
    }

    // Mime type first where MediaStore recorded one. Extensions are the
    // fallback, because a file rescued from a trash folder frequently has no
    // recorded type at all.
    if (mime.startsWith('text/') ||
        name.endsWith('.txt') ||
        name.endsWith('.log') ||
        name.endsWith('.md') ||
        name.endsWith('.json')) {
      return _Text(item: item, table: false);
    }
    if (mime.contains('csv') || name.endsWith('.csv')) {
      return _Text(item: item, table: true);
    }
    if (mime.contains('pdf') || name.endsWith('.pdf')) {
      return _Pdf(item: item);
    }

    return _HandOff(item: item);
  }
}

class _Image extends ConsumerWidget {
  const _Image({required this.item});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: Center(
        child: GThumbnail(
          itemId: item.itemId,
          bridge: ref.watch(recoveryBridgeProvider),
          kind: item.kind,
          // 2048, the largest the native thumbnailer produces. Full resolution
          // would be the original file, which for a 108 megapixel photo is a
          // decode nobody asked for.
          maxPixels: 2048,
          fit: BoxFit.contain,
          radius: 0,
        ),
      ),
    );
  }
}

/// Video and audio, from a content URI.
///
/// One widget for both because ExoPlayer treats them the same and the only
/// difference is whether there is a picture. An audio track gets its cover art
/// behind the controls instead of a black rectangle.
class _Play extends ConsumerStatefulWidget {
  const _Play({required this.item});

  final RecoverableItem item;

  @override
  ConsumerState<_Play> createState() => _PlayState();
}

class _PlayState extends ConsumerState<_Play> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final String? uri = await ref
        .read(recoveryBridgeProvider)
        .itemUri(widget.item.itemId);
    if (!mounted) return;

    // A loose file has no URI and never will. That is not a failure, it is the
    // shape of scoped storage, and the fallback shows the preview instead.
    if (uri == null) {
      setState(() => _failed = true);
      return;
    }

    final VideoPlayerController controller = VideoPlayerController.contentUri(
      Uri.parse(uri),
    );
    try {
      await controller.initialize();
    } catch (_) {
      // A codec this phone lacks, or an OEM refusing to decode from a trashed
      // row. Both are ordinary and both fall back rather than sitting black.
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    await controller.setLooping(true);
    await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (_failed) return _Unplayable(item: widget.item);

    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _Waiting(t: t);
    }

    final bool audio = widget.item.kind == 'audio';

    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (audio)
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: GThumbnail(
                  itemId: widget.item.itemId,
                  bridge: ref.watch(recoveryBridgeProvider),
                  kind: widget.item.kind,
                  maxPixels: 512,
                  radius: GRadius.card,
                ),
              ),
            )
          else
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          if (!controller.value.isPlaying)
            DecoratedBox(
              decoration: BoxDecoration(color: t.scrim, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(GSpace.md),
                child: Icon(Icons.play_arrow_rounded, size: 34, color: t.text),
              ),
            ),
          Positioned(
            left: GSpace.gutter,
            right: GSpace.gutter,
            bottom: 96,
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
    );
  }
}

class _Text extends ConsumerWidget {
  const _Text({required this.item, required this.table});

  final RecoverableItem item;
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AsyncValue<Uint8List?> bytes = ref.watch(
      recoveredBytesProvider(item.itemId),
    );

    return bytes.when(
      loading: () => _Waiting(t: t),
      error: (Object e, StackTrace s) => _HandOff(item: item),
      data: (Uint8List? data) {
        if (data == null) return _TooBig(item: item, t: t);

        // allowMalformed, because a recovered log with one bad byte should
        // still be readable rather than thrown away whole.
        final String text = utf8.decode(data, allowMalformed: true);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.gutter,
              72,
              GSpace.gutter,
              120,
            ),
            child: table
                ? _Csv(text: text)
                : SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: GType.monoSmall.copyWith(color: t.text),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// CSV as columns.
///
/// A deliberately simple split. Quoted fields containing commas will break, and
/// that is accepted: this is a preview so someone can recognise a file, not a
/// spreadsheet engine.
class _Csv extends StatelessWidget {
  const _Csv({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<String> lines = const LineSplitter()
        .convert(text)
        .where((String line) => line.trim().isNotEmpty)
        .take(200)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    final List<String> header = lines.first.split(',');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          columns: <DataColumn>[
            for (final String cell in header)
              DataColumn(
                label: Text(
                  cell.trim(),
                  style: GType.micro.copyWith(color: t.text),
                ),
              ),
          ],
          rows: <DataRow>[
            for (final String line in lines.skip(1))
              DataRow(
                cells: <DataCell>[
                  for (int i = 0; i < header.length; i++)
                    DataCell(
                      Text(
                        i < line.split(',').length
                            ? line.split(',')[i].trim()
                            : '',
                        style: GType.monoSmall.copyWith(color: t.muted),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Pdf extends ConsumerStatefulWidget {
  const _Pdf({required this.item});

  final RecoverableItem item;

  @override
  ConsumerState<_Pdf> createState() => _PdfState();
}

class _PdfState extends ConsumerState<_Pdf> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final Uint8List? bytes = await ref
        .read(recoveryBridgeProvider)
        .itemBytes(widget.item.itemId, maxBytes: 10 * 1024 * 1024);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _controller = PdfControllerPinch(document: PdfDocument.openData(bytes));
    });
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (_failed) return _HandOff(item: widget.item);

    final PdfControllerPinch? controller = _controller;
    if (controller == null) return _Waiting(t: t);

    return Padding(
      padding: const EdgeInsets.only(top: 64, bottom: 96),
      child: PdfViewPinch(controller: controller),
    );
  }
}

/// A video or track that will not play here.
///
/// Distinct from the general hand-off because the reason is specific and the
/// user deserves it. A trashed file is not corrupt, and saying so stops someone
/// concluding the recovery failed when it did not.
class _Unplayable extends ConsumerWidget {
  const _Unplayable({required this.item});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    return Stack(
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: GThumbnail(
              itemId: item.itemId,
              bridge: ref.watch(recoveryBridgeProvider),
              kind: item.kind,
              maxPixels: 512,
              radius: GRadius.card,
            ),
          ),
        ),
        Positioned(
          left: GSpace.gutter,
          right: GSpace.gutter,
          bottom: 110,
          child: Text(
            'This cannot be played while it is still in the trash. Restore it '
            'and it will open in your usual player.',
            textAlign: TextAlign.center,
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
        ),
      ],
    );
  }
}

class _HandOff extends ConsumerWidget {
  const _HandOff({required this.item});

  final RecoverableItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.description_outlined, size: 40, color: t.dim),
            const SizedBox(height: GSpace.lg),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              'This app shows photos, video, audio, text and PDF. Anything '
              'else opens in an app built for it.',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.lg),
            GButton(
              label: 'Open with another app',
              icon: Icons.open_in_new_rounded,
              expand: false,
              onPressed: () async {
                final bool ok = await ref
                    .read(recoveryBridgeProvider)
                    .openItemExternally(item.itemId);
                if (!context.mounted || ok) return;
                GMessenger.show(
                  context,
                  GMessage.warning(
                    'Nothing on this phone can open that, and a file still in '
                    'the trash cannot be shared. Restore it first.',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TooBig extends StatelessWidget {
  const _TooBig({required this.item, required this.t});

  final RecoverableItem item;
  final GTokens t;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
      child: Text(
        'This file is ${GFormat.bytes(item.sizeBytes)}, too large to '
        'preview here.',
        textAlign: TextAlign.center,
        style: GType.bodySmall.copyWith(color: t.muted),
      ),
    ),
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.t});

  final GTokens t;

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Loading', style: GType.monoSmall.copyWith(color: t.dim)),
  );
}

/// The file itself, for text, CSV and PDF.
final recoveredBytesProvider = FutureProvider.family<Uint8List?, String>(
  (Ref ref, String itemId) =>
      ref.watch(recoveryBridgeProvider).itemBytes(itemId),
);
