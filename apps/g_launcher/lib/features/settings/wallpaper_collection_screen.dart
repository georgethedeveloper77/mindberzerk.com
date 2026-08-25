import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import 'wallpaper_screen.dart';

/// One collection: its images as a grid, plus add, rename and delete.
///
/// Applying, encoding and rescheduling all go through the shared functions in
/// wallpaper_screen.dart, so this screen cannot drift from the main one, which
/// is the exact failure the encoder's history there documents.
class WallpaperCollectionScreen extends ConsumerWidget {
  const WallpaperCollectionScreen({
    super.key,
    required this.theme,
    required this.collectionId,
  });

  final EffectiveTheme theme;
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live, hasValue not asData: same reasoning as every settings page, the
    // grid must gain a photo the moment it is added, and asData is null
    // through the reload every write causes.
    final async = ref.watch(effectiveThemeProvider);
    final theme = async.hasValue ? async.requireValue : this.theme;

    final colsAsync = ref.watch(wallpaperCollectionsProvider);
    final collections = colsAsync.hasValue
        ? colsAsync.requireValue
        : const <WallpaperCollection>[];

    WallpaperCollection? found;
    for (final c in collections) {
      if (c.id == collectionId) found = c;
    }
    if (found == null) {
      // Deleted while this page was open (the delete flow below pops before
      // this can render; this covers any other route here). Nothing to show
      // and nothing to mutate, so an empty themed page beats a crash or a
      // phantom grid.
      return const ThemedScaffold(
        title: 'Collection',
        body: SizedBox.shrink(),
      );
    }
    final collection = found;

    final notifier = ref.read(wallpaperCollectionsProvider.notifier);
    final prefs = ref.read(prefsProvider(theme.spec.id).notifier);

    /// An ACTIVE rotation follows every content change immediately. Reads the
    /// post-mutation list back out of the provider, because [collections]
    /// above is the pre-mutation snapshot.
    Future<void> resync() {
      final now = ref.read(wallpaperCollectionsProvider);
      return rescheduleRotation(
        ref,
        theme,
        now.hasValue ? now.requireValue : collections,
        source: theme.prefs.wallpaperRotationSource,
      );
    }

    Future<void> addPhotos() async {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;

      final added = await notifier.addImages(
        collectionId,
        [for (final x in picked) x.path],
      );
      await resync();
      if (!context.mounted) return;
      context.showMessage(
        added == 0
            ? 'Could not add those photos'
            : added == 1
                ? 'Added 1 photo'
                : 'Added $added photos',
      );
    }

    Future<void> removeImage(String path) async {
      final ok = await ThemedDialog.confirm(
        context,
        title: 'Remove this wallpaper?',
        message: 'It leaves the collection and this copy is deleted. Your '
            'original is not touched, and if it is on screen right now the '
            'screen does not change.',
        confirmLabel: 'Remove',
        danger: true,
      );
      if (ok != true) return;

      // Same contract as forgetting one of Yours on the main screen: the
      // screen is Android's and stays put, but a cleared record must not leave
      // wallpaperCurrent pointing at a path nobody can see or change.
      final wasCurrent = theme.prefs.wallpaperCurrent == path;
      await notifier.removeImage(collectionId, path);
      if (wasCurrent) {
        await prefs.edit((p) => p.clearing(wallpaperCurrent: true));
      }
      await resync();
      if (context.mounted) context.showMessage('Removed');
    }

    Future<void> deleteCollection() async {
      final ok = await ThemedDialog.confirm(
        context,
        title: 'Delete ${collection.name}?',
        message: 'The copies in this collection are deleted. Your originals '
            'are not touched, and the screen does not change.',
        confirmLabel: 'Delete',
        danger: true,
      );
      if (ok != true) return;

      final current = theme.prefs.wallpaperCurrent;
      if (current != null && collection.paths.contains(current)) {
        await prefs.edit((p) => p.clearing(wallpaperCurrent: true));
      }
      await notifier.delete(collectionId);
      // A rotation pointed at this collection degrades to the distro pool
      // inside rotationPoolFor; resyncing is what makes that take effect now
      // rather than on the next interval pick.
      await resync();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      context.showMessage('Collection deleted');
    }

    final c = ChromeScope.of(context).colors;

    return ThemedScaffold(
      title: collection.name,
      body: ListView(
        // Clears the navigation bar. Trailing padding rather than a SafeArea,
        // so the list still scrolls behind a transparent bar.
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          if (collection.paths.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Nothing here yet. Add photos and this set can rotate on '
                'its own.',
                style: TextStyle(color: c.textFaint),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // Portrait tiles, matching what a wallpaper is.
                  childAspectRatio: 9 / 16,
                ),
                itemCount: collection.paths.length,
                itemBuilder: (context, i) {
                  final path = collection.paths[i];
                  return GestureDetector(
                    // Tap applies, hold removes: the exact gesture pair the
                    // main screen's strips already taught.
                    onTap: () => applyWallpaper(context, ref, theme, path),
                    onLongPress: () => removeImage(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: c.surfaceAlt,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: c.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          ThemedListRow(
            icon: Icons.add_photo_alternate_outlined,
            title: 'Add photos',
            onTap: addPhotos,
          ),
          ThemedListRow(
            icon: Icons.drive_file_rename_outline,
            title: 'Rename',
            onTap: () => promptCollectionName(
              context,
              title: 'Rename this collection',
              initial: collection.name,
              onSubmit: (name) => notifier.rename(collectionId, name),
            ),
          ),
          ThemedListRow(
            icon: Icons.delete_outline,
            title: 'Delete collection',
            subtitle: 'Your originals are not touched',
            onTap: deleteCollection,
          ),
        ],
      ),
    );
  }
}

/// Name a collection, new or existing, in a themed sheet.
///
/// The body is a StatefulWidget that OWNS its controller, for the reason
/// `_RenameFolderBody` in drawer_actions.dart documents at length: a
/// closure-owned controller is disposed when the route's Future completes,
/// which is while the sheet is still animating out, and every frame of that
/// exit rebuilds the TextField against a dead controller.
void promptCollectionName(
  BuildContext context, {
  required String title,
  String initial = '',
  required Future<void> Function(String name) onSubmit,
}) {
  ThemedSheet.show<void>(
    context,
    title: title,
    isScrollControlled: true,
    builder: (sheet) => _NameBody(initial: initial, onSubmit: onSubmit),
  );
}

class _NameBody extends StatefulWidget {
  const _NameBody({required this.initial, required this.onSubmit});

  final String initial;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_NameBody> createState() => _NameBodyState();
}

class _NameBodyState extends State<_NameBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Preselected, so the first keystroke replaces rather than appends.
    _controller = TextEditingController(text: widget.initial)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initial.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _controller.text.trim();
    Navigator.pop(context);
    // Blank falls through: the store refuses it too, but not calling at all
    // avoids a message-less no-op round trip.
    if (name.isEmpty) return;
    widget.onSubmit(name);
  }

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: c.text),
            cursorColor: c.accent,
            decoration: InputDecoration(
              hintText: 'Family',
              hintStyle: TextStyle(color: c.textFaint),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.line),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.accent),
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
          const SizedBox(height: 14),
          ThemedButton(label: 'Save', onPressed: _commit),
        ],
      ),
    );
  }
}
