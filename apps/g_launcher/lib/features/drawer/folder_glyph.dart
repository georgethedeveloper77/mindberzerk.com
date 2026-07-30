import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import 'app_icon.dart';

/// A real folder, with its contents sitting in it.
///
/// ─── WHY THIS IS ARTWORK AND NOT A 2x2 GRID OF TILES ────────────────────────
///
/// The 2x2 preview in `home_grid.dart` and the drawer is the phone convention,
/// and its comment is right that it is the one everyone already knows. It is
/// also the reason the folders screen reads as a phone launcher: iOS invented
/// that square, Android copied it, and no desktop has ever drawn a folder that
/// way. A Linux file manager draws a FOLDER, and this whole product is the bet
/// that the desktop metaphor is worth the effort.
///
/// So: `assets/svg/folder.svg` behind, and the first few app icons overlapping
/// its front edge the way documents sit in a real one.
///
/// ─── THE ARTWORK IS RENDERED AS AUTHORED ────────────────────────────────────
///
/// No colour filter by default. The bundled glyph is full-colour art with its
/// own shading, and tinting it to the accent would flatten it to a silhouette,
/// which is exactly the folder-shaped rectangle this replaces. [tint] exists
/// for a distro that ships a monochrome glyph and wants it wearing the palette,
/// and for that case only.
///
/// ─── WHY IT LIVES BESIDE app_icon AND NOT IN design/ ────────────────────────
///
/// It draws app icons, and `AppIcon` lives here. Putting this in `design/`
/// would make the design layer import a feature, which nothing in `design/`
/// does today and which is backwards: chrome primitives are meant to know
/// nothing about the app list. `app_icon.dart` is already the shared icon
/// widget that home, settings and setup all import from, so this sits next to
/// it and follows the same rule.
///
/// ─── DECLARING THE ASSET ────────────────────────────────────────────────────
///
/// `assets/svg/` has to be in pubspec.yaml's asset list. A missing declaration
/// does not throw: flutter_svg logs and draws nothing, so the folders read as
/// captions floating over empty space, which looks like a layout bug rather
/// than a packaging one.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({
    super.key,
    required this.theme,
    required this.size,
    this.members = const [],
    this.tint,
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

  /// How many icons read as "contents" rather than as clutter at this size.
  static const _maxShown = 3;

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/folder.svg',
              fit: BoxFit.contain,
              colorFilter:
                  tint == null ? null : ColorFilter.mode(tint!, BlendMode.srcIn),
            ),
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
  });

  final EffectiveTheme theme;
  final String name;
  final double size;
  final List<AppEntry> members;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderGlyph(theme: theme, size: size, members: members),
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
