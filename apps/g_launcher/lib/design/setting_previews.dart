/// The live pictures in Settings: what a setting will look like, drawn from the
/// setting itself.
///
/// ─── IN design/, NOT features/settings/ ─────────────────────────────────────
///
/// Next to [DevicePreview], which it wraps, and which the setup wizard already
/// uses. A preview is a design primitive rather than a settings screen: the
/// same picture belongs in setup, in the folders screen, and in the wallpaper
/// screen, and none of those should import a settings file to get it.
///
/// Everything here paints from the palette, so switching distro repaints every
/// preview in the app with no wiring at all.
library;

import 'package:flutter/material.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../engine/effective_theme.dart';
import '../engine/theme_spec.dart' show ThemePalette;
import 'components/components.dart';
import 'device_preview.dart';
import 'drawer_transition.dart';

/// A page-level preview: one picture at the top of a settings section, showing
/// what the settings below it do.
///
/// ─── ONE PER PAGE, NOT ONE PER GROUP ────────────────────────────────────────
///
/// Both were on the table. Per group is more directly connected to the control
/// you are touching, and it is what [PanelPreview] already does, correctly:
/// blur, tint and corner radius are impossible to describe in a subtitle and
/// obvious the instant you see them, and the surface they change only appears
/// when you have stopped looking at this screen. That case earns its own
/// picture inside its own group.
///
/// It does not generalise. A page with a picture over every group is a page
/// that is mostly pictures, and the reader loses the thread of the list. So the
/// default is one at the top, answering "what am I about to change" for the
/// whole section, and a group keeps its own only when the thing it changes is
/// invisible from here.
///
/// ─── AND IT IS HIDDEN WHILE SEARCHING ───────────────────────────────────────
///
/// A preview is not a search result. Sitting above a filtered list it would
/// look like one, and it would be the only thing on screen that did not match
/// what was typed. [query] does that here rather than at each call site, so a
/// section cannot forget.
class SettingPreview extends StatelessWidget {
  const SettingPreview({
    super.key,
    required this.child,
    required this.caption,
    this.query = '',
  });

  final Widget child;

  /// One quiet line naming what is being shown. Not a title: the section
  /// already has one, and a heading over a picture that repeats the page name
  /// is a heading that earns nothing.
  final String caption;

  /// Already trimmed. Non-empty means a search is active and this renders
  /// nothing.
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) return const SizedBox.shrink();
    final c = ChromeScope.of(context).colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        children: [
          child,
          const SizedBox(height: 8),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A single framed phone at a readable size, centred.
///
/// [DevicePreview] fills whatever it is given, and a full-width phone on a
/// settings page is a phone drawn nearly life size. The pair in
/// [LayoutPreview] is constrained by being two across; a lone one needs saying.
class SinglePreview extends StatelessWidget {
  const SinglePreview({super.key, required this.child, this.width = 132});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) =>
      Center(child: SizedBox(width: width, child: child));
}

/// One option in a [PreviewChoice]: the picture, the word, and the value.
class PreviewOption<T> {
  const PreviewOption({
    required this.value,
    required this.label,
    required this.child,
  });

  final T value;
  final String label;

  /// The picture. Drawn at whatever width the row divides into, so it should be
  /// something that scales rather than something with a fixed size inside it.
  final Widget child;
}

/// A row of pictures where the picture IS the control.
///
/// ─── WHY THIS REPLACES A VALUE PLUS A SHEET ─────────────────────────────────
///
/// A row reading "Dock position   Left" with a chevron makes you open a sheet,
/// pick a word, close it, and look at the desktop to find out what the word
/// meant. Every step of that except the last is overhead, and the last one
/// happens on a different screen. The picture collapses it: you can see the
/// three answers at once and the tap that selects is the same tap that showed
/// you.
///
/// It is the pattern Android's own Display and Navigation bar screens use, and
/// they did not invent it either: a settings panel showing you the layouts
/// rather than naming them is how every desktop has done this for twenty years.
/// It suits this launcher better than most, because the thing being chosen is
/// almost always spatial.
///
/// ─── WHAT IT IS NOT FOR ─────────────────────────────────────────────────────
///
/// Numbers and continuous values. A column count is a stepper, an opacity is a
/// slider, and three tiles showing 4, 5 and 6 columns would be a worse stepper
/// with a lower ceiling. This is for a small closed set of shapes.
///
/// The radio under each label is not decoration. The accent border alone
/// carries the selection on a page whose accent is also the distro's accent and
/// therefore appears on half the other rows, and a border is the one selection
/// affordance that disappears entirely for anyone who cannot separate those two
/// colours.
class PreviewChoice<T> extends StatelessWidget {
  const PreviewChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onSelect,
    this.title,
    this.subtitle,
    this.enabled = true,
    this.following = false,
    this.onFollow,
    this.perRow = 4,
  });

  /// The setting's name, above the pictures. Optional, because a chooser that
  /// is the only thing in its group already has the group heading and a second
  /// line would say it twice.
  final String? title;
  final String? subtitle;

  final List<PreviewOption<T>> options;
  final T value;
  final ValueChanged<T> onSelect;

  /// True when no preference is stored and [value] is the DISTRO's answer.
  ///
  /// ─── A CHOOSER WITH NO WAY BACK IS A TRAP ───────────────────────────────
  ///
  /// Dock position had four tiles and every one of them wrote a pref, so the
  /// first tap pinned the dock on EVERY distro forever. Mint authors
  /// `dock: "off"` and showed one anyway; so would Arch, EndeavourOS, Pop and
  /// Zorin, and nothing on the screen said why or offered a way out.
  ///
  /// `OpacityRow` has carried this pair since it shipped and the same two
  /// arguments do the same job here: a chip that says the value is inherited,
  /// and a tap that clears the pref and hands the row back to the theme.
  final bool following;

  /// Clears the pref. Null hides the chip, for a setting with no distro answer
  /// to fall back to.
  final VoidCallback? onFollow;

  /// How many tiles fit on one line before this wraps.
  ///
  /// ─── FOUR, BECAUSE SEVEN DID NOT FIT AND SAID SO WITH AN ELLIPSIS ─────────
  ///
  /// This was one `Row` of `Expanded` children, which is correct for the four
  /// options every caller had. The drawer motion row now has seven, so each got
  /// about 50dp on a phone, "Cylinder" needs about 55, and the labels rendered
  /// as `Cyli` and `Sph` with an ellipsis.
  ///
  /// `TextOverflow.ellipsis` is allowed here and elsewhere: it is runtime
  /// truncation, the thing that saves a long app name from overflowing. But a
  /// label that truncates EVERY time on EVERY device is not a long name, it is
  /// a layout that does not fit, and hiding it behind a character is the
  /// version of this that ships.
  ///
  /// Wrapped rather than scrolled horizontally: a scroller would put three of
  /// the seven off screen, and an option nobody scrolls to is an option nobody
  /// knows exists. Four across also makes each tile nearly twice as wide, which
  /// matters more here than in any other picker, because these tiles are
  /// demonstrating a MOTION and a 50dp one is a smudge.
  ///
  /// Callers with four or fewer are laid out exactly as before.
  final int perRow;

  /// False dims the tiles and stops them answering a tap.
  ///
  /// ─── THE SAME RULE SettingsToggleRow ALREADY STATES ───────────────────────
  ///
  /// Dimmed and inert, never absent. A choice that only applies under some
  /// other mode is shown greyed with the reason in [subtitle], because hiding
  /// it makes someone who has read about the feature conclude this build does
  /// not have it.
  ///
  /// The SELECTED tile keeps its accent ring while dimmed, deliberately. The
  /// row still has an answer, it is just not one you can change from here, and
  /// a disabled control that also loses its value looks broken rather than
  /// locked.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    // 0.4 is the alpha `SettingsToggleRow` dims its title by (settings_rows,
    // `enabled ? s.tx : s.mut.withValues(alpha: 0.4)`), so a greyed picture row
    // and a greyed switch row sit at the same weight in one list.
    // How many go on a line. Never more than there are, so a picker with two
    // options does not lay itself out as if it had four.
    final across = options.length < perRow ? options.length : perRow;

    Widget tile(int i) => GestureDetector(
              // Opaque, so the gap under the label is part of the target.
              // The picture is the affordance but the whole column is the
              // tap, which is what makes this usable with a thumb.
              behavior: HitTestBehavior.opaque,
              // Null, not an ignored call. A GestureDetector with no callback
              // registers no recognizer at all, so a disabled row does not
              // quietly swallow a tap that the scroll underneath it could have
              // used.
              onTap: enabled ? () => onSelect(options[i].value) : null,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: options[i].value == value ? c.accent : c.line,
                        width: options[i].value == value ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: AspectRatio(
                          aspectRatio: 10 / 15,
                          child: options[i].child,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    options[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: options[i].value == value ? c.accent : c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    options[i].value == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: options[i].value == value ? c.accent : c.textFaint,
                  ),
                ],
              ),
            );

    final lines = <Widget>[];
    for (var start = 0; start < options.length; start += across) {
      final end = (start + across) < options.length
          ? (start + across)
          : options.length;
      lines.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = start; i < end; i++) ...[
              if (i > start) const SizedBox(width: 12),
              Expanded(child: tile(i)),
            ],
            // ── THE LAST LINE IS PADDED, AND IT HAS TO BE ──────────────────
            //
            // `Expanded` divides whatever the Row has, so a final line of three
            // would draw three tiles a third wider than the four above them.
            // The empty slots keep every tile the same size, which is the whole
            // reason these read as a set rather than as two unrelated groups.
            for (var pad = end - start; pad < across; pad++) ...[
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      );
    }

    final row = Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            lines[i],
          ],
        ],
      ),
    );

    if (title == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: TextStyle(color: c.text, fontSize: 14.5),
                ),
              ),
              // ── THE WAY BACK ──────────────────────────────────────────
              //
              // Beside the title rather than a fifth tile: it is not another
              // value, it is the absence of one, and putting it in the row of
              // pictures would make "no preference" look like a shape you can
              // choose. `OpacityRow` puts its chip in the same place.
              //
              // Drawn only when a pref IS set, so a row that is already
              // following says nothing. A chip that is present and inert on
              // most visits is a control people stop reading.
              if (onFollow != null && !following)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? onFollow : null,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      context.t('settings.follow'),
                      style: TextStyle(color: c.accent, fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(color: c.textMuted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 12),
          row,
        ],
      ),
    );
  }
}

/// Two pictures in one tile, split down the middle.
///
/// Exists for "Match the system", which is not a third appearance but the other
/// two taking turns. A tile showing one of them would be a lie half the time,
/// and a tile showing neither would be the only blank one in the row.
class SplitTile extends StatelessWidget {
  const SplitTile({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: FractionallySizedBox(widthFactor: 2, child: left),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 0.5,
                child: FractionallySizedBox(widthFactor: 2, child: right),
              ),
            ),
          ),
        ],
      );
}

/// How the drawer moves, as a picture.
///
/// Its own painter rather than a [DevicePreview] mode: the difference between a
/// list, a pager and a cube is MOTION, and none of the three is distinguishable
/// from a still grid of tiles. So each tile shows the artefact that gives the
/// style away instead: a list that runs off the bottom edge, a page with dots
/// under it, two faces meeting at an angle.
/// A drawer transition, PLAYING, at the size of a settings tile.
///
/// ─── IT USED TO BE A STILL, AND A STILL CANNOT SHOW THIS ────────────────────
///
/// The old version hand-drew each of three styles: a grid running off the
/// bottom for the list, two skewed halves for the cube, a grid over page dots
/// for pages. Each was chosen as the artefact that gives that style away in one
/// frame, and for three styles it worked.
///
/// It stops working at six. Cube, cylinder and sphere are all one rotation with
/// different numbers, so a still frame of any of them is the same picture, and
/// a picker whose job is "try these against each other" would be offering three
/// identical thumbnails.
///
/// So the tile animates, and it animates from [drawerTransformFor], which is
/// the same function the real pager applies. A tile cannot claim a motion the
/// drawer does not have, and a style added later gets a working tile without
/// anyone drawing one.
///
/// ─── ONE CONTROLLER FOR THE WHOLE ROW ───────────────────────────────────────
///
/// Six tiles each running their own [AnimationController] is six tickers, six
/// wakeups per frame, and six loops drifting out of phase so the row reads as
/// noise. [phase] is driven by the chooser above them instead, so all six
/// demonstrate the same swipe at the same moment and the row reads as a
/// comparison rather than a fidget.
///
/// The `vertical` style is drawn the way it always was, as a grid running past
/// the bottom edge. It is not a transition and there is no motion to play; what
/// it does that a page does not is exactly that it keeps going.
class ScrollStyleTile extends StatelessWidget {
  const ScrollStyleTile({
    super.key,
    required this.style,
    required this.palette,
    this.phase = 0,
  });

  /// A `drawerScrollStyle` value: `vertical`, or anything
  /// [DrawerTransition.parse] recognises.
  final String style;
  final ThemePalette palette;

  /// Where in the swipe this tile is, 0 to 1.
  ///
  /// 0 and 1 are both settled pages; 0.5 is mid-turn. Supplied rather than
  /// generated, so one player drives the whole row. See [ScrollStylePlayer].
  final double phase;

  /// What a tile shows when it is not playing.
  ///
  /// ─── MID-TURN, NOT SETTLED ────────────────────────────────────────────────
  ///
  /// A settled page is a plain grid, identical for all six styles, so a row of
  /// resting tiles would be six copies of the same picture and the picker would
  /// be back to naming things instead of showing them.
  ///
  /// A third of the way through the turn is where the styles are furthest
  /// apart: the cube is folding, the cylinder is curving, the sphere is
  /// pinching, depth is shrinking, stack is holding still. Frozen there, each
  /// one is recognisable without moving, and tapping it plays the rest.
  ///
  /// Not 0.5, which is the symmetric point and where the outgoing and incoming
  /// pages are the same size. The asymmetry is what reads as direction.
  static const double restPhase = 0.34;

  @override
  Widget build(BuildContext context) {
    final ink = palette.onDark;

    Widget tile() => DecoratedBox(
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(2),
          ),
        );
    Widget grid(int rows) => Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: 3),
                        Expanded(child: tile()),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );

    final body = style == 'vertical'
        // Runs past the bottom edge, which is the whole of what a list does
        // that a page does not.
        ? ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 200,
              child: SizedBox(height: 120, child: grid(6)),
            ),
          )
        : _Turning(
            transition: DrawerTransition.parse(style),
            phase: phase,
            palette: palette,
            page: grid(3),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bgTop, palette.bgBottom],
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(6), child: body),
    );
  }
}

/// Two pages mid-swipe, transformed exactly as the drawer would transform them.
///
/// ─── TWO, NOT SIX ───────────────────────────────────────────────────────────
///
/// A real pager keeps three live pages and clamps the offset to one either
/// side, so at any moment at most two are on screen. Drawing more here would be
/// drawing pages the transform has already sent past ninety degrees, which is a
/// face pointing away from the viewer.
class _Turning extends StatelessWidget {
  const _Turning({
    required this.transition,
    required this.phase,
    required this.palette,
    required this.page,
  });

  final DrawerTransition transition;
  final double phase;
  final ThemePalette palette;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        // The two live pages, at their `PageView` positions. The outgoing one
        // is `phase` of a width to the left, the incoming one that much to its
        // right, which is exactly the arrangement `drawerTransformFor` expects
        // its delta to describe.
        Widget at(double delta) {
          final spec = drawerTransformFor(transition, delta, w);
          return Positioned(
            left: delta * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Opacity(
              opacity: spec.opacity,
              child: Transform(
                alignment: spec.alignment,
                transform: spec.matrix,
                child: page,
              ),
            ),
          );
        }

        return ClipRect(
          child: Stack(
            // The arriving page is drawn LAST so it lands on top, which is what
            // makes `stack` and `depth` read correctly: both of them depend on
            // one page passing over the other rather than under it.
            children: [at(-phase), at(1 - phase)],
          ),
        );
      },
    );
  }
}

/// Plays one transition, once, when the user asks for it.
///
/// ─── IT USED TO LOOP ALL SIX, FOREVER ───────────────────────────────────────
///
/// The first version ran a single controller in `repeat(reverse: true)` and
/// handed its phase to every tile, so the whole row turned continuously. That
/// solved the real problem, which is that a still cannot tell a cube from a
/// cylinder, and created two others: six thumbnails moving at once is a settings
/// page that will not sit still to be read, and a ticker running for as long as
/// the screen is open is a ticker running for as long as the screen is open.
///
/// So the row rests, and a tap plays. Resting is not a still of a settled page,
/// which would be six identical grids; it is [ScrollStyleTile.restPhase], a
/// freeze a third of the way through the turn where the six look least alike.
/// Tapping a style selects it and runs it through, which is the question a
/// picker is actually being asked: show me that one.
///
/// ─── THE TAP IS THE TRIGGER, NOT THE VALUE ──────────────────────────────────
///
/// [play] is handed to the builder rather than the player watching a selected
/// value, because tapping the style that is ALREADY selected has to replay it.
/// Watching the value would make that tap a no-op, which reads as the control
/// having stopped working.
///
/// The currently selected style plays once on mount, so opening the page
/// answers "what is my drawer doing" without a tap at all.
class ScrollStylePlayer extends StatefulWidget {
  const ScrollStylePlayer({super.key, this.initial, required this.builder});

  /// Played once when this mounts. Null plays nothing.
  final String? initial;

  /// Given the phase, which style is playing, and how to start one.
  final Widget Function(
    BuildContext context,
    double phase,
    String? playing,
    void Function(String style) play,
  ) builder;

  @override
  State<ScrollStylePlayer> createState() => _ScrollStylePlayerState();
}

class _ScrollStylePlayerState extends State<ScrollStylePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    // Slower than a real swipe, which is over in about 300ms. This is a
    // demonstration rather than a simulation, and at swipe speed the difference
    // between a cube and a cylinder is finished before the eye has arrived.
    duration: const Duration(milliseconds: 1100),
  );

  /// Eases at both ends, so the turn starts from a settled page and arrives at
  /// one rather than snapping out of and into rest.
  late final Animation<double> _phase =
      CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  /// Which style is mid-demonstration, or null when the row is at rest.
  String? _playing;

  @override
  void initState() {
    super.initState();
    // Back to rest when it finishes, so the tile returns to the frozen pose
    // that says what it is. Leaving it settled would make the SELECTED tile the
    // one picture in the row that gives nothing away.
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _playing = null);
      }
    });

    final first = widget.initial;
    if (first != null) {
      // After the first frame: this widget is built inside a settings list that
      // is still laying out, and starting a controller during build is the
      // classic setState-during-build assertion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(first);
      });
    }
  }

  void _play(String style) {
    setState(() => _playing = style);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _phase,
      builder: (context, _) =>
          widget.builder(context, _phase.value, _playing, _play),
    );
  }
}

class LayoutPreview extends StatelessWidget {
  const LayoutPreview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.desktop,
              dock: theme.dock,
              gridButton: theme.prefs.dockGridButton ?? 'end',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.drawer,
              cols: theme.drawerCols,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chrome resolver
// ─────────────────────────────────────────────────────────────────────────────

/// The framing that forks on [ChromeFamily] — the STRUCTURE of a group card, as
/// opposed to its colours. Adwaita is libadwaita's boxed-list look (rounded,
/// inset, plain header); Breeze is flatter and squarer with an upper-case
/// category header, like KDE System Settings; generic/aqua sit in between. This
/// is where the family split becomes visible on the settings page.

/// A live panel, drawn with the settings currently being dragged.
class PanelPreview extends StatelessWidget {
  const PanelPreview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The stand-in wallpaper. Diagonal so the blur has edges running
              // through the panel rather than a flat field, which is the only
              // way a blur is visible at all.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.palette.bgTop,
                      theme.palette.accent,
                      theme.palette.bgBottom,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),

              // A REAL scope carrying the live values, so this panel resolves
              // exactly what a sheet will. Built here rather than inherited
              // because the settings screen's own chrome is the page's, and
              // the page is not what is being previewed.
              Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                child: ChromeScope(
                  data: ChromeData.fromPalette(
                    theme.palette,
                    typography: theme.typography,
                    textScale: theme.textScale,
                    family: theme.chromeFamily,
                    opacity: theme.panelOpacity,
                    panelBlur: theme.panelBlur,
                    panelTint: theme.panelTint,
                    panelRadius: theme.panelRadius,
                  ),
                  child: Builder(
                    builder: (inner) {
                      final p = ChromeScope.of(inner);
                      return GlassPanel(
                        // Top corners only, the shape a real sheet takes.
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(p.panelRadius),
                        ),
                        border: Border(
                          top: BorderSide(color: p.colors.lineStrong),
                        ),
                        child: SizedBox(
                          height: 86,
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 8),
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: p.colors.lineStrong,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Text(
                                    inner.t('settings.panels.previewTitle'),
                                    style: p.text.title,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Text(
                                    inner.t('settings.panels.previewSub'),
                                    style: p.text.caption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

/// A labelled slider for one panel setting.
///
/// Shaped like [OpacityRow] on purpose, since they sit in the same group and
/// two slider layouts a row apart is the sort of inconsistency nobody names and
/// everybody feels. It carries no Follow action because these three have no
/// parent slider to follow: the panel OPACITY does, and it uses the existing
/// row for exactly that reason.
class PanelSlider extends StatelessWidget {
  const PanelSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    this.following = false,
    this.onFollow,
  });

  final IconData icon;
  final String label;
  final String sub;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  /// True while this setting has no value of its own and is showing whatever
  /// the distro ships. The Follow action only appears once it has stopped.
  ///
  /// ─── WHY BLUR NEEDS THIS MORE THAN OPACITY DOES ─────────────────────────
  ///
  /// This is the pair [OpacityRow] already carries, and the argument is sharper
  /// here. Blur is the one setting on the page with a PERFORMANCE reason to
  /// move it, and `settings.panels.blurSub` says so out loud: turn it down if
  /// the launcher feels slow. So it is the setting people actually touch.
  ///
  /// Every value here is per-user and global, not per distro. Turning blur off
  /// on a slow phone therefore pinned it off across every distro that person
  /// would ever install, including one whose entire identity is the glass.
  /// Without a way back, that is a one-way door dressed as a performance tip.
  final bool following;

  /// Clears the user's value so the setting shows the distro's again.
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: d.text.body)),
              // Placed BEFORE the value and styled as a link, matching
              // [OpacityRow] exactly. Two rows on one page offering the same
              // action in two positions is how a settings screen stops looking
              // like one screen.
              if (!following && onFollow != null)
                GestureDetector(
                  onTap: onFollow,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      context.t('settings.follow'),
                      style: d.text.caption.copyWith(color: c.accent),
                    ),
                  ),
                ),
              Text(
                format(value),
                style: d.text.value.copyWith(color: c.textMuted),
              ),
            ],
          ),
          ThemedSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child:
                Text(sub, style: d.text.caption.copyWith(color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}
