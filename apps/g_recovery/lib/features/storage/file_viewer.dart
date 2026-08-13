import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/storage_api.g.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_button.dart';
import 'state/storage_files.dart';
import 'state/storage_providers.dart';
import '../../core/i18n/g_strings.dart';

/// LOOKING AT A FILE THAT IS STILL YOURS.
///
/// Five branches, and the fifth is the honest one. Images and video play here,
/// text and CSV are rendered from bytes, PDF renders through the platform's own
/// renderer, and anything else is handed to an app that can open it rather than
/// shown as a grey rectangle.
///
/// ─── WHY NOT EVERYTHING IN APP ───────────────────────────────────────────────
///
/// Because there is no credible Flutter renderer for a Word or Excel document,
/// and there will not be one soon. Shipping a half working one would produce
/// documents that look almost right, which is worse than a chooser: a user who
/// leaves the app for ten seconds and comes back knows exactly what they saw.
class FileViewer extends ConsumerStatefulWidget {
  const FileViewer({required this.files, required this.index, super.key});

  final List<StorageFile> files;
  final int index;

  static Route<void> route({
    required List<StorageFile> files,
    required int index,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => FileViewer(files: files, index: index),
  );

  @override
  ConsumerState<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends ConsumerState<FileViewer> {
  late final PageController _pages;
  late int _at;

  @override
  void initState() {
    super.initState();
    _at = widget.index;
    _pages = PageController(initialPage: widget.index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final StorageFile current = widget.files[_at];

    return Scaffold(
      backgroundColor: t.ink,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            itemCount: widget.files.length,
            onPageChanged: (int index) => setState(() => _at = index),
            itemBuilder: (BuildContext context, int index) =>
                _Frame(file: widget.files[index]),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(GSpace.sm),
                child: Row(
                  children: <Widget>[
                    _Round(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: GSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            current.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GType.heading.copyWith(
                              color: t.text,
                              shadows: <Shadow>[
                                Shadow(color: t.scrim, blurRadius: 8),
                              ],
                            ),
                          ),
                          Text(
                            <String>[
                              GFormat.bytes(current.sizeBytes),
                              '${_at + 1} of ${widget.files.length}',
                            ].join('  ·  '),
                            style: GType.monoSmall.copyWith(
                              color: t.muted,
                              fontSize: 10.5,
                              shadows: <Shadow>[
                                Shadow(color: t.scrim, blurRadius: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Round(
                      icon: Icons.open_in_new_rounded,
                      onTap: () => _openOut(current),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOut(StorageFile file) async {
    final bool ok = await ref
        .read(storageBridgeProvider)
        .openExternally(file.fileId);
    if (!mounted || ok) return;
    GMessenger.show(
      context,
      GMessage.warning('No app on this phone can open that file'),
    );
  }
}

/// Picks the branch, from the mime type first and the name second.
class _Frame extends ConsumerWidget {
  const _Frame({required this.file});

  final StorageFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String mime = file.mimeType ?? '';
    final String name = file.name.toLowerCase();

    if (file.kind == 'image') return _Image(file: file);
    if (file.kind == 'video') return _Video(file: file);

    // The mime type is authoritative where MediaStore recorded one. Extensions
    // are a fallback, because a file dropped in by a file manager frequently
    // has no type at all.
    if (mime.startsWith('text/') ||
        name.endsWith('.txt') ||
        name.endsWith('.log') ||
        name.endsWith('.md') ||
        name.endsWith('.json')) {
      return _Text(file: file, table: false);
    }
    if (mime.contains('csv') || name.endsWith('.csv')) {
      return _Text(file: file, table: true);
    }
    if (mime.contains('pdf') || name.endsWith('.pdf')) {
      return _Pdf(file: file);
    }

    return _HandOff(file: file);
  }
}

class _Image extends ConsumerWidget {
  const _Image({required this.file});

  final StorageFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final Uint8List? bytes = ref
        .watch(storageThumbProvider(ThumbRequest.of(file, maxPixels: 1600)))
        .value;
    if (bytes == null) return _Waiting(t: t);

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
              _HandOff(file: file),
        ),
      ),
    );
  }
}

/// Video, played from a content URI.
///
/// contentUri is the only VideoPlayerController constructor that works here.
/// The file path behind a MediaStore row is unreadable under scoped storage
/// even when the row itself reads perfectly, and Dart cannot resolve the id on
/// its own.
class _Video extends ConsumerStatefulWidget {
  const _Video({required this.file});

  final StorageFile file;

  @override
  ConsumerState<_Video> createState() => _VideoState();
}

class _VideoState extends ConsumerState<_Video> {
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
        .read(storageBridgeProvider)
        .contentUri(widget.file.fileId);
    if (!mounted) return;
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
      // A codec this phone cannot decode, which is a real and common outcome.
      // Saying so beats a black rectangle that never starts.
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
    if (_failed) return _HandOff(file: widget.file);

    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _Waiting(t: t);
    }

    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
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
            bottom: GSpace.xl,
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

/// Text and CSV, rendered from bytes.
class _Text extends ConsumerWidget {
  const _Text({required this.file, required this.table});

  final StorageFile file;

  /// True for CSV, which is laid out as columns rather than as a wall of commas.
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final AsyncValue<Uint8List?> bytes = ref.watch(
      _rawBytesProvider(file.fileId),
    );

    return bytes.when(
      loading: () => _Waiting(t: t),
      error: (Object e, StackTrace s) => _HandOff(file: file),
      data: (Uint8List? data) {
        if (data == null) {
          // Null is missing OR over the cap, and the size tells us which.
          return _TooBig(file: file, t: t);
        }
        // allowMalformed, because a log with one bad byte in the middle should
        // still be readable rather than throwing the whole file away.
        final String text = utf8.decode(data, allowMalformed: true);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.gutter,
              72,
              GSpace.gutter,
              GSpace.lg,
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
/// that is an accepted limit: this is a preview so someone can recognise a file,
/// not a spreadsheet engine. Anything needing real parsing goes to a real app
/// through the button in the corner.
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          columns: <DataColumn>[
            for (final String cell in lines.first.split(','))
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
                  for (int i = 0; i < lines.first.split(',').length; i++)
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

/// PDF, through the platform renderer.
class _Pdf extends ConsumerStatefulWidget {
  const _Pdf({required this.file});

  final StorageFile file;

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
    // Ten megabytes, well above any document someone would open on a phone and
    // well below what would hurt to hold.
    final Uint8List? bytes = await ref
        .read(storageBridgeProvider)
        .readBytes(widget.file.fileId, maxBytes: 10 * 1024 * 1024);
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
    if (_failed) return _HandOff(file: widget.file);

    final PdfControllerPinch? controller = _controller;
    if (controller == null) return _Waiting(t: t);

    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: PdfViewPinch(controller: controller),
    );
  }
}

/// Everything with no in app renderer.
class _HandOff extends ConsumerWidget {
  const _HandOff({required this.file});

  final StorageFile file;

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
              file.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              // Says why rather than only that. A person who knows this app
              // cannot draw a Word document stops expecting it to.
              context.s(
                'This app can show photos, video, text and PDF. Anything else '
                'opens in an app built for it.',
              ),
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.lg),
            GButton(
              label: context.s('Open with another app'),
              icon: Icons.open_in_new_rounded,
              expand: false,
              onPressed: () async {
                final bool ok = await ref
                    .read(storageBridgeProvider)
                    .openExternally(file.fileId);
                if (!context.mounted || ok) return;
                GMessenger.show(
                  context,
                  GMessage.warning('No app on this phone can open that file'),
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
  const _TooBig({required this.file, required this.t});

  final StorageFile file;
  final GTokens t;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
      child: Text(
        'This file is ${GFormat.bytes(file.sizeBytes)}, too large to '
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
    child: Text(
      context.s('Loading'),
      style: GType.monoSmall.copyWith(color: t.dim),
    ),
  );
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      color: t.scrim,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(GSpace.sm + 1),
          child: Icon(icon, size: 20, color: t.text),
        ),
      ),
    );
  }
}

/// The file itself, for text and CSV. Two megabytes, which is a very long text
/// file and a very short anything else.
final _rawBytesProvider = FutureProvider.family<Uint8List?, String>(
  (Ref ref, String fileId) =>
      ref.watch(storageBridgeProvider).readBytes(fileId),
);
