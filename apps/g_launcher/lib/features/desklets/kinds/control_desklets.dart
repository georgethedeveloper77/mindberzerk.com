import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/desklet_layout.dart';
import '../../../data/prefs/launcher_prefs.dart';
import '../../../data/prefs/prefs_repository.dart';
import '../../../design/components/components.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/desklet_spec.dart';
import '../../../engine/effective_theme.dart';
import '../../drawer/drawer_state.dart';
import '../desklet_frame.dart';

/// The two kinds that are controls rather than readouts. PHASE D5.
///
/// Both go through [DeskletFrame] so they still look like the distro, and both
/// use its `custom` escape hatch because neither is label/value rows.

// ─── notes ───────────────────────────────────────────────────────────────────

/// A sticky note. Genuinely a KDE plasmoid and a macOS Stickies window, so it
/// earns its place twice, and it is the kind that proves free-form
/// [Desklet.config] was worth having from day one: the note IS its config.
///
/// Tap opens a dialog rather than editing in place. An always-live TextField on
/// the desktop would take focus from the launcher, raise the keyboard over the
/// wallpaper on any stray tap, and fight the workspace pager for drags. A
/// dialog costs one tap and none of that.
class NotesDesklet extends ConsumerWidget {
  const NotesDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = DeskletKinds.notes.read<String>(desklet.config, 'text', '');
    final p = theme.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _edit(context, ref, text),
      child: DeskletFrame(
        theme: theme,
        skin: skin,
        body: DeskletBody(
          command: 'cat note.txt',
          // Never empty, so the frame does not vanish: an empty note still has
          // to be tappable, or there is no way to write the first word in it.
          custom: Text(
            text.isEmpty ? 'Tap to write' : text,
            style: TextStyle(
              fontFamily: skin.font == DeskletFont.mono
                  ? theme.typography.mono
                  : theme.typography.display,
              fontSize: skin.num_('rowSize', 13),
              height: 1.45,
              color: text.isEmpty
                  ? p.onDark.withValues(alpha: 0.45)
                  : p.onDark.withValues(alpha: 0.92),
              shadows: skin.surface == DeskletSurface.bare
                  ? [
                      Shadow(
                        color: p.bgBottom.withValues(alpha: 0.55),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Uses [ThemedSheet] and [ThemedListRow] and nothing else, because those
  /// are the two chrome primitives with call sites I could verify. A themed
  /// dialog would be the nicer surface; wire it once its signature is to hand.
  Future<void> _edit(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);

    void save(BuildContext sheet) {
      Navigator.pop(sheet);
      // configure() MERGES, so a note written by a newer build carrying a key
      // this one does not know keeps it.
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => DeskletLayout.configure(
              p,
              desklet.id,
              {'text': controller.text},
            ),
          );
    }

    await ThemedSheet.show<void>(
      context,
      builder: (sheet) => Padding(
        // The sheet has to clear the keyboard it is about to raise, or the
        // field lands underneath it and the note is written blind.
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(sheet).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Note',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => save(sheet),
            ),
            const SizedBox(height: 4),
            ThemedListRow(
              icon: Icons.check,
              title: 'Save',
              onTap: () => save(sheet),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── search ──────────────────────────────────────────────────────────────────

/// A search box on the desktop, which opens the shell's own drawer.
///
/// DELIBERATELY NOT A LIVE TEXT FIELD, and this is the same call the note makes
/// for the same reasons: a focused field on the home screen raises the keyboard
/// over the wallpaper, steals focus from the launcher, and competes with the
/// workspace pager for vertical drags. It also would not be authentic — GNOME's
/// search opens the Activities overview, KDE's opens Kickoff, rofi opens a
/// floating box. Every one of those is a full-screen surface, which is exactly
/// what [ShellDrawer] already resolves per shell.
///
/// So the tile is the affordance and the drawer is the search. One tap, and the
/// distro's real search experience rather than a text field pretending.
class SearchDesklet extends ConsumerWidget {
  const SearchDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;
    final hint = DeskletKinds.search
        .read<String>(desklet.config, 'hint', 'Search apps');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(activitiesOpenProvider.notifier).state = true,
      child: DeskletFrame(
        theme: theme,
        skin: skin,
        body: DeskletBody(
          command: 'rofi -show drun',
          custom: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 16, color: p.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: skin.font == DeskletFont.mono
                        ? theme.typography.mono
                        : theme.typography.display,
                    fontSize: skin.num_('rowSize', 13),
                    color: p.onDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
