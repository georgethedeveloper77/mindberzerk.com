import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/components.dart';
import '../../design/wallpaper_paint.dart';
import '../../engine/effective_theme.dart';
import '../../engine/wallpaper_framing.dart';
import 'wallpaper_screen.dart';

/// Frame ONE wallpaper against the chrome it will sit behind.
///
/// ─── WHY THIS IS A SCREEN AND NOT A SHEET ───────────────────────────────────
///
/// The setting it replaces was a Fit sheet: four rows of text, no picture. It
/// could be, because a fit is a fact about the whole image and you can name it.
/// A focal point is a fact about WHERE, and there is no wording for "the dragon
/// is a bit low". You have to see it, and you have to see it at the size it
/// will actually be drawn, with the dock and the clock on top, because the
/// question is not "is this centred" but "does anything important land under
/// something opaque". A half-height sheet answers a different question.
///
/// ─── WHY THE GHOST CHROME IS DRAWN HERE AND NOT BY DevicePreview ────────────
///
/// [DevicePreview] takes an `ImageProvider` and draws it its own way, which is
/// the correct behaviour everywhere else and exactly wrong here: this screen's
/// whole subject is the arrangement it would override. So the wallpaper is
/// painted locally at the framing under edit, and the chrome over it is
/// deliberately crude. It is a ghost, not a mock: making it convincing would
/// invite reading detail off it that this screen does not control.
class WallpaperFramingScreen extends ConsumerStatefulWidget {
  const WallpaperFramingScreen({
    super.key,
    required this.theme,
    required this.source,
  });

  final EffectiveTheme theme;

  /// The STORED source string, the same one used as the key in
  /// `prefs.wallpaperFraming`. Not the encoded form native receives.
  final String source;

  @override
  ConsumerState<WallpaperFramingScreen> createState() =>
      _WallpaperFramingScreenState();
}

class _WallpaperFramingScreenState
    extends ConsumerState<WallpaperFramingScreen> {
  late WallpaperFraming _framing;
  late final WallpaperFraming _initial;

  /// Which face the ghost chrome is drawing. Not a preference and not stored:
  /// it is a way of looking at one framing, and both faces share it.
  bool _lockFace = false;

  bool _moved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Resolved ONCE, into local state. Reading it from the provider on every
    // build would mean the drag fights the rebuild: each frame would re-resolve
    // to the stored value and the image would snap back under the finger.
    _initial = resolveWallpaperFraming(
      user: widget.theme.prefs.wallpaperFraming,
      authored: widget.theme.spec.wallpaperMeta,
      source: widget.source,
      legacyFit: widget.theme.prefs.wallpaperFit,
    );
    _framing = _initial;
  }

  /// The pack's own answer, with no user framing on top. What Reset returns to.
  ///
  /// Not `const WallpaperFraming()`: resetting to a bare centre would throw
  /// away the author's focal point as well as the user's, and the two are not
  /// the same thing to undo. The row only appears when this differs from what
  /// is on screen, so a pack with nothing authored still gets a working reset
  /// back to centre.
  WallpaperFraming get _authored => resolveWallpaperFraming(
        user: const {},
        authored: widget.theme.spec.wallpaperMeta,
        source: widget.source,
        legacyFit: widget.theme.prefs.wallpaperFit,
      );

  bool get _framable => WallpaperFraming.fitIsFramable(_framing.fit);

  void _drag(DragUpdateDetails d, Size size) {
    if (!_framable || size.isEmpty) return;
    setState(() {
      _moved = true;
      _framing = _framing.copyWith(
        // Inverted: dragging the picture LEFT moves the window right, which is
        // what every photo cropper does and what the hand expects. The 0.8
        // factor makes a full swipe cross most of the image rather than all of
        // it, so the ends are reachable without the middle being twitchy.
        focalX: (_framing.focalX - (d.delta.dx / size.width) * 0.8)
            .clamp(0.0, 1.0),
        focalY: (_framing.focalY - (d.delta.dy / size.height) * 0.8)
            .clamp(0.0, 1.0),
      );
    });
  }

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    // applyWallpaper does the whole job: pushes to native, records
    // wallpaperCurrent, writes the applied stamp and persists the framing.
    // Duplicating any of that here is how the collection screen and this one
    // would drift.
    await applyWallpaper(
      context,
      ref,
      widget.theme,
      widget.source,
      framing: _framing,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final image = wallpaperImageFor(widget.theme, widget.source);

    return ThemedScaffold(
      // No title, so no app bar: the picture is the screen and the controls
      // float on it. Same arrangement the setup flow uses for the same reason.
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                onPanUpdate: (e) => _drag(e, size),
                child: _Stage(
                  theme: widget.theme,
                  image: image,
                  framing: _framing,
                  lockFace: _lockFace,
                ),
              );
            },
          ),

          // ── top actions ──────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 12,
            child: Row(
              children: [
                ThemedButton(
                  label: 'Wallpapers',
                  kind: ThemedButtonKind.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                ThemedButton(
                  label: 'Done',
                  onPressed: _saving ? null : _done,
                ),
              ],
            ),
          ),

          // ── zoom, on the fits where it means something ───────────────
          if (_framable)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _Plate(
                  child: SizedBox(
                    height: 168,
                    width: 40,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: ThemedSlider(
                        value: _framing.zoom,
                        min: 1.0,
                        max: 4.0,
                        onChanged: (v) => setState(() {
                          _moved = true;
                          _framing = _framing.copyWith(zoom: v);
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── bottom controls ─────────────────────────────────────────
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── THE NOTE IS NOT JUST A HINT ──────────────────────
                //
                // The default fit is 'fill', which is not framable, so the
                // common case is a user opening this screen and finding that
                // dragging does nothing. Without a line saying why, that reads
                // as the screen being broken rather than as the fit having
                // nothing to choose between. So the plate stays on both
                // branches and only its sentence changes: one invites the
                // gesture, the other explains its absence and points at the
                // control that restores it.
                if (!_moved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Plate(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          _framable
                              ? 'Drag the picture to frame it'
                              : 'This fit uses the whole image. Pick Scroll '
                                  'or Center to reposition it.',
                          textAlign: TextAlign.center,
                          style: d.text.caption.copyWith(color: c.text),
                        ),
                      ),
                    ),
                  ),
                _FitBar(
                  current: _framing.resolvedFit,
                  onPick: (v) => setState(() {
                    _moved = true;
                    _framing = _framing.copyWith(fit: v);
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Pill(
                      icon: Icons.swap_horiz,
                      label: _lockFace ? 'Lock' : 'Home',
                      onTap: () => setState(() => _lockFace = !_lockFace),
                    ),
                    if (_framing != _authored) ...[
                      const SizedBox(width: 10),
                      _Pill(
                        icon: Icons.restart_alt,
                        label: 'Reset',
                        onTap: () => setState(() {
                          _moved = false;
                          _framing = _authored;
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallpaper, drawn at [framing], with ghost chrome over it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.theme,
    required this.image,
    required this.framing,
    required this.lockFace,
  });

  final EffectiveTheme theme;
  final ImageProvider? image;
  final WallpaperFraming framing;
  final bool lockFace;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final p = theme.palette;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The SAME widget the settings preview draws with. Two copies of this
        // arithmetic is how the picture on the page and the picture on this
        // screen would come to disagree, which is the exact failure this screen
        // exists to fix one level down.
        WallpaperPaint(
          image: image,
          palette: p,
          framing: framing,
        ),
        IgnorePointer(
          child: lockFace ? _LockGhost(theme: theme) : _HomeGhost(theme: theme),
        ),
        // The clear-space marker. Dashed would be nicer and is not worth a
        // custom painter: what it has to communicate is where the edge is, and
        // a faint line does that.
        IgnorePointer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              lockFace ? 210 : 90,
              24,
              lockFace ? 60 : 130,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(d.panelRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon grid and dock, at roughly the positions the real ones occupy.
class _HomeGhost extends StatelessWidget {
  const _HomeGhost({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final tile = BoxDecoration(
      color: p.onDark.withValues(alpha: 0.16),
      border: Border.all(color: p.onDark.withValues(alpha: 0.24)),
      borderRadius: BorderRadius.circular(14),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 120, 28, 40),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var col = 0; col < 4; col++)
                    Container(width: 46, height: 46, decoration: tile),
                ],
              ),
            ),
          const Spacer(),
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: p.dock.withValues(alpha: 0.55),
              border: Border.all(color: p.onDark.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(width: 44, height: 44, decoration: tile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Clock and date, and nothing else.
///
/// NOTHING ELSE IS THE POINT. Android owns the lock screen and this launcher
/// cannot put a widget on it, so drawing one here would be promising something
/// the app is not able to deliver. The stand-in exists because the wallpaper
/// setting can apply to the lock screen, which is otherwise a claim the user
/// has to lock the phone to check.
class _LockGhost extends StatelessWidget {
  const _LockGhost({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final p = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Column(
        children: [
          Text(
            // A FIXED TIME, not the real one. This is a picture of where the
            // clock sits, and a ticking one on a framing screen is a rebuild
            // every second for no information the user needs.
            '23:57',
            style: d.text.display.copyWith(
              color: p.onDark,
              fontSize: 54,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tue, Aug 25',
            style: d.text.caption.copyWith(color: p.onDark),
          ),
        ],
      ),
    );
  }
}

/// The four native fits, as one row.
class _FitBar extends StatelessWidget {
  const _FitBar({required this.current, required this.onPick});

  final String current;
  final ValueChanged<String> onPick;

  /// Labels for the wire values. Kept here rather than on [WallpaperFraming]
  /// because the type is a leaf with no i18n and no business knowing what a
  /// user-facing string is; the wire values themselves live there, so a fifth
  /// fit cannot appear in this bar without appearing in the model first.
  static const _labels = <String, String>{
    'cover': 'Scroll',
    'fill': 'Fill',
    'contain': 'Fit',
    'center': 'Center',
  };

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return _Plate(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final fit in WallpaperFraming.fits)
              GestureDetector(
                onTap: () => onPick(fit),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: fit == current ? c.accent : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _labels[fit] ?? fit,
                    style: d.text.label.copyWith(
                      color: fit == current ? c.onAccent : c.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A rounded translucent slab, so a control stays legible over any photo.
class _Plate extends StatelessWidget {
  const _Plate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        // The chrome's own surface at the panel's own opacity, not a grey.
        // A photo underneath can be any colour, and a fixed scrim would read as
        // this distro's chrome on Ubuntu and as somebody else's on Kali.
        color: c.surface.withValues(alpha: 0.82),
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      onTap: onTap,
      child: _Plate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c.text),
              const SizedBox(width: 8),
              Text(label, style: d.text.label.copyWith(color: c.text)),
            ],
          ),
        ),
      ),
    );
  }
}
