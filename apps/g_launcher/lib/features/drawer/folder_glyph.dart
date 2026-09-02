import 'package:flutter/widgets.dart';

import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import 'app_icon.dart';
import 'folder_glyphs.dart';

/// A folder, with its contents sitting in it.
///
/// ─── WHY THIS IS NOT A 2x2 GRID OF TILES ────────────────────────────────────
///
/// The 2x2 preview in `home_grid.dart` is the phone convention, and its comment
/// is right that it is the one everyone already knows. It is also the reason
/// the folders screen reads as a phone launcher: iOS invented that square,
/// Android copied it, and no desktop has ever drawn a folder that way. So this
/// draws a folder with the first few app icons overlapping its front edge, the
/// way documents sit in a real one.
///
/// ─── THE FOLDER IS A GLYPH, NOT ARTWORK, AND THAT IS A RETREAT ──────────────
///
/// This drew `assets/svg/folder.svg`: full-colour art with its own shading,
/// which is a better picture than an outline and was never once on screen. A
/// missing pubspec asset declaration does not throw. `flutter_svg` logs and
/// draws nothing, so every folder in the app rendered as its members floating
/// over empty space, and it took a screenshot of the Zorin rail to notice.
///
/// A code point in a font Flutter already ships cannot fail that way, needs no
/// asset declaration, and is the same shape [showFolderGlyphPicker] offers, so
/// a folder with no glyph and a folder wearing the default now draw identically
/// instead of being two unrelated pictures. If the artwork is ever wired up
/// properly it belongs here again, behind the same [glyph] check.
///
/// ─── WHY IT LIVES BESIDE app_icon AND NOT IN design/ ────────────────────────
///
/// It draws app icons, and `AppIcon` lives here. Putting this in `design/`
/// would make the design layer import a feature, which nothing in `design/`
/// does today and which is backwards: chrome primitives are meant to know
/// nothing about the app list.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({
    super.key,
    required this.theme,
    required this.size,
    this.members = const [],
    this.tint,
    this.glyph,
  });

  final EffectiveTheme theme;

  /// The glyph's width. Height follows the artwork's own aspect.
  final double size;

  /// Shown tucked into the folder, in order. Only the first few fit; the rest
  /// are deliberately not counted or badged, because a folder in a file manager
  /// does not print how many things are in it either.
  final List<AppEntry> members;

  /// Only for a monochrome glyph. See the class doc.
  final Color? tint;

  /// A `folder_glyphs.dart` catalogue id, which REPLACES the artwork.
  ///
  /// ─── REPLACES RATHER THAN DECORATES ─────────────────────────────────────
  ///
  /// The alternative was to keep the folder and stamp the chosen icon on its
  /// face. That reads as a folder with a sticker on it at tile size and as
  /// unresolvable mush anywhere smaller, and it makes the user's choice the
  /// least visible thing in the picture. A folder wearing a controller says
  /// Games; a folder with a two-millimetre controller on it says folder.
  ///
  /// The members are NOT drawn when a glyph is set, for the same reason: the
  /// contents preview and a chosen symbol are two different answers to "what is
  /// in here", and showing both means neither lands.
  ///
  /// An id this build does not know draws the fallback rather than nothing.
  final String? glyph;

  /// How many icons read as "contents" rather than as clutter at this size.
  static const _maxShown = 3;

  /// One resolution of the glyph's colour, read by both branches.
  ///
  /// [tint] was documented as being only for a distro shipping a monochrome
  /// glyph, because the bundled artwork was full colour and tinting it would
  /// flatten it to a silhouette. Every glyph is monochrome now, so tint is
  /// simply the colour, and the default is the palette's own ink rather than
  /// nothing.
  Color get _ink => tint ?? theme.palette.onDark;

  @override
  Widget build(BuildContext context) {
    final chosen = folderGlyphFor(glyph);

    // ─── A CHOSEN GLYPH STANDS ALONE ────────────────────────────────────
    //
    // No member preview under it. The contents preview and a chosen symbol are
    // two different answers to "what is in here", and drawing both means
    // neither lands. Somebody who picked a controller wants to see a
    // controller.
    if (chosen != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(chosen, size: size * 0.78, color: _ink),
      );
    }

    final shown = members.take(_maxShown).toList();

    // The icons sit low and centre, over the folder's front face. Sized as a
    // fraction of the glyph so it holds at drawer size and at setup size
    // without a second set of numbers.
    final iconSize = size * 0.30;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ─── A MATERIAL GLYPH, NOT `assets/svg/folder.svg` ──────────────
          //
          // The artwork was the better picture and it was not on screen. A
          // missing pubspec asset declaration does not throw: `flutter_svg`
          // logs and draws nothing, so every folder rendered as its member
          // icons floating over empty space. In the Zorin rail that looked
          // like squashed strips of app icons; on the folders screen it looked
          // like captions over a gap.
          //
          // A code point in a font Flutter already ships cannot fail that way,
          // it needs no asset declaration, and it is the same shape the picker
          // offers, so an unglyphed folder and a folder wearing the default now
          // draw identically instead of being two different pictures.
          //
          // THE MEMBERS STAY. The overlap below is what makes a folder look
          // full rather than empty, and it is the only thing on this tile that
          // says which folder it is before you read the label.
          Positioned.fill(
            child: Icon(kFolderGlyphFallback, size: size * 0.78, color: _ink),
          ),
          if (shown.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              // Low in the frame: the artwork's front face occupies the bottom
              // two thirds, and icons floating over the tab at the top would
              // read as sitting behind the folder rather than in it.
              bottom: size * 0.14,
              child: Center(
                // OVERLAPPED, VIA A STACK, NOT NEGATIVE PADDING.
                //
                // The obvious spelling is a Row of Paddings with a negative
                // left inset, and `Padding` asserts `isNonNegative`, so that
                // throws in debug the first time a folder has two members. A
                // Stack with explicit offsets is the same picture and is legal.
                child: SizedBox(
                  width: iconSize + (shown.length - 1) * iconSize * 0.78,
                  height: iconSize,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * iconSize * 0.78,
                          child: AppIcon(entry: shown[i], size: iconSize),
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
}

/// A folder with its name under it, at drawer-tile proportions.
///
/// The pairing exists because every surface that shows a folder shows its name,
/// and three of them getting the gap and the label style subtly different is
/// how a set of screens stops looking like one product.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.theme,
    required this.name,
    required this.size,
    this.members = const [],
    this.labelColor,
    this.glyph,
  });

  final EffectiveTheme theme;
  final String name;
  final double size;
  final List<AppEntry> members;
  final Color? labelColor;

  /// Passed straight to [FolderGlyph]. See that field.
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderGlyph(
          theme: theme,
          size: size,
          members: members,
          glyph: glyph,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: theme.labelLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: labelColor ?? theme.palette.onDark,
            fontSize: 11 * theme.textScale,
            fontFamily: theme.typography.display,
          ),
        ),
      ],
    );
  }
}
