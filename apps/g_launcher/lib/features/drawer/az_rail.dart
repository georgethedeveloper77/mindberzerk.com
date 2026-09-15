/// PHASE L1: the alphabet index down the drawer's trailing edge.
///
/// ─── WHY A PAINTER AND NOT TWENTY-SEVEN WIDGETS ─────────────────────────────
///
/// Every letter moves on every frame while a finger is down. As widgets that is
/// 27 `Transform`s rebuilding against a `ValueListenable`, 27 layout passes and
/// 27 repaint boundaries for glyphs that never change shape. As a painter it is
/// one repaint of one layer, the `TextPainter`s are laid out once when the
/// theme changes, and the per-frame work is a translate, a scale and a blit.
///
/// The same argument `DrawerTransition` makes about matrices: the motion is not
/// where the cost is, provided nothing rebuilds to produce it.
///
/// ─── THE THREE PLACES A NEW RAIL STYLE HAS TO REACH ─────────────────────────
///
/// [IndexRail.parse], [IndexRail.catalogue], and `LayoutResolver`'s
/// `drawerIndexRail` allow-list. The first two are in this file and a value
/// missing from either is visible immediately. The allow-list is not, and it
/// drops an unknown value silently while handing back something plausible.
/// This is the same trap `drawer_transition.dart` documents, written out again
/// because the next person to add a style will be reading this file, not that
/// one.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../engine/effective_theme.dart';

/// How the index behaves, or whether it is there at all.
enum IndexRail {
  /// No index. The list scrolls and nothing sits on its edge.
  off,

  /// The letters sit still. The one under the finger lifts and the puck
  /// follows, and that is all.
  ///
  /// Here because the arc is motion for its own sake to some people, and
  /// because it is the honest fallback when animations are disabled system
  /// wide. See [AzRail] for how that case is handled without this value.
  plain,

  /// The letters bow away from the finger, nearest first, and settle back on a
  /// spring when it lifts.
  arc;

  /// The value stored in prefs.
  ///
  /// Identical to [name] for all three, unlike `DrawerTransition.value`, which
  /// carries a legacy spelling. Written as a getter anyway so that a later
  /// rename cannot silently change what is on disk.
  String get value => name;

  /// How a picker names it, and the one line under that name.
  ///
  /// LITERALS rather than `context.t` keys, matching `DrawerTransition.copy`
  /// and both drawer pickers. `ref.t` against a key that does not exist renders
  /// the key, which is worse on screen than English is, and the i18n sweep has
  /// not reached these rows.
  (String, String) get copy => switch (this) {
        IndexRail.off => ('Off', 'No index on the edge.'),
        IndexRail.plain => ('Plain', 'The letters hold still.'),
        IndexRail.arc => ('Arc', 'The letters bow away from your finger.'),
      };

  /// Every style a picker offers, in the order it should read.
  static const List<IndexRail> catalogue = [
    IndexRail.off,
    IndexRail.plain,
    IndexRail.arc,
  ];

  /// A string from prefs or a newer build.
  ///
  /// DEGRADES to [arc], never throws, and deliberately not to [off]: an
  /// unrecognised value means a profile written by a build that knows more than
  /// this one, and answering "no index" would read as the feature having been
  /// removed. A slightly wrong animation is a non-event.
  static IndexRail parse(String? raw) => switch (raw) {
        'off' => IndexRail.off,
        'plain' => IndexRail.plain,
        _ => IndexRail.arc,
      };
}

/// The label every non-alphabetic app files under.
///
/// Shared with `_AzList._sectionOf`, which produces it. Two spellings of this
/// string is one silent mismatch between the list and its index.
const String kIndexOther = '#';

/// Every label the rail draws, in order.
///
/// The full alphabet regardless of what is installed, because an index that
/// grows and shrinks with the app list gives the finger a different target
/// every time it comes back. Absent letters are drawn faint and route to the
/// nearest section that exists.
final List<String> kIndexLabels = [
  kIndexOther,
  for (var c = 65; c <= 90; c++) String.fromCharCode(c),
];

/// ─── GEOMETRY, IN DP, MEASURED IN THE HTML PROBE ────────────────────────────
///
/// Tuned against a 360x800 frame, which is the budget viewport this is really
/// for. `_kPush` is how far the nearest letter travels inward; `_kFalloff` is
/// the distance over which its neighbours stop caring.
const double _kPush = 64;
const double _kFalloff = 110;

/// Spring constants. Ratio is 26 / (2 * sqrt(260)), a little over 0.8, so the
/// letters overshoot once by a hair on release rather than easing dead flat.
const double _kStiffness = 260;
const double _kDamping = 26;

/// The touch strip. Narrower than 48dp on purpose: see [AzRail]'s note on why
/// the rail is not the accessible path to any of this.
const double _kRailWidth = 44;

/// How far left of the rail the puck sits, and how big it is.
const double _kPuckLane = 76;
const double _kPuckRadius = 30;

/// Tallest a letter's slot is allowed to get on a short list.
const double _kMaxSlot = 22;

/// Clearance at the top and bottom of the strip.
const double _kEndPad = 24;

/// Per-letter spring state plus the live touch, as one repaint signal.
///
/// A [ChangeNotifier] handed to `CustomPainter.repaint` rather than a
/// `setState`: the rail repaints up to 120 times a second while a finger is
/// down, and every one of those going through the element tree would rebuild
/// the drawer's whole `Stack` to move some glyphs.
class _RailMotion extends ChangeNotifier {
  _RailMotion(int count)
      : x = List<double>.filled(count, 0),
        v = List<double>.filled(count, 0);

  final List<double> x;
  final List<double> v;

  /// Where the finger is, in local dp, or null when it is up.
  double? touchY;

  /// Which label is selected, or -1 when the finger is up.
  int activeIndex = -1;

  /// Letter centres for the current box height. Written at paint time because
  /// they depend on a size only the painter is told.
  List<double> centres = const [];

  /// True while anything is still moving, so the ticker can stop.
  bool get settling {
    for (var i = 0; i < x.length; i++) {
      if (x[i].abs() > 0.05 || v[i].abs() > 0.05) return true;
    }
    return false;
  }

  void tick() => notifyListeners();
}

/// The alphabet index. Sits over the list, on its trailing edge.
///
/// ─── IT IS NOT THE ACCESSIBLE PATH, AND SAYS SO ─────────────────────────────
///
/// Twenty-seven targets down an 800dp screen is roughly 24dp each, half the
/// 48dp floor this app holds everywhere else. That is not an oversight to fix
/// by making the rail taller; it is what a fast-scroll index is, and every
/// platform that ships one has the same number.
///
/// So the rail is excluded from semantics entirely and the list behind it keeps
/// the accessible ordering: a screen reader user swipes through sections and
/// hears the headers, which is a better path than 27 one-character buttons
/// would be. The rail is a shortcut for a finger that can already see.
class AzRail extends StatefulWidget {
  const AzRail({
    super.key,
    required this.style,
    required this.theme,
    required this.present,
    required this.onJump,
  });

  /// [IndexRail.off] never reaches here; the caller omits the widget. Kept in
  /// the signature so the enum is complete where it is read.
  final IndexRail style;

  final EffectiveTheme theme;

  /// Which labels have a section in the list. Everything else is drawn faint
  /// and routes to its nearest neighbour.
  final Set<String> present;

  /// Called with a label from [present], and only when the selection changes.
  final void Function(String label) onJump;

  @override
  State<AzRail> createState() => _AzRailState();
}

class _AzRailState extends State<AzRail> with SingleTickerProviderStateMixin {
  late final _RailMotion _motion = _RailMotion(kIndexLabels.length);
  late final _ticker = createTicker(_onTick);

  Duration _last = Duration.zero;

  /// Laid out once per theme, not per frame. Rebuilt in [didUpdateWidget] when
  /// the palette or the display family changes, which is the only time a glyph
  /// here is a different picture.
  List<TextPainter> _letters = const [];
  Map<String, TextPainter> _puckLabels = const {};

  @override
  void initState() {
    super.initState();
    _buildPainters();
  }

  @override
  void didUpdateWidget(AzRail old) {
    super.didUpdateWidget(old);
    if (old.theme.palette != widget.theme.palette ||
        old.theme.typography.display != widget.theme.typography.display ||
        !setEquals(old.present, widget.present)) {
      _buildPainters();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  /// ─── TextScaler.noScaling, DELIBERATELY ───────────────────────────────────
  ///
  /// Twenty-seven glyphs at the user's 1.3x font setting do not fit down a
  /// phone, and the failure is the last letters falling off the bottom rather
  /// than anything reporting a problem. The rail is chrome sized by the screen;
  /// the list behind it honours the font setting in full, and the list is what
  /// anyone who has turned their font up is reading.
  void _buildPainters() {
    final ink = widget.theme.palette.onDark;
    final family = widget.theme.typography.display;

    TextPainter make(String s, double size, Color colour, FontWeight weight) {
      final p = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: weight,
            color: colour,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      return p;
    }

    _letters = [
      for (final l in kIndexLabels)
        make(
          l,
          16,
          // Faint for a letter with no section. It still occupies its slot, so
          // the alphabet stays in the same place on every drawer.
          ink.withValues(alpha: widget.present.contains(l) ? 0.92 : 0.32),
          FontWeight.w600,
        ),
    ];

    // ─── DERIVED HERE, NOT READ FROM ChromeScope ───────────────────────────
    //
    // `onAccent` lives on ChromeColors, not on ThemePalette, and `AppIcon`
    // already carries this exact derivation for the same reason: relative
    // luminance picks the ink, so Ubuntu orange takes white and a pastel accent
    // flips to dark. Third copy of the pair, and if that rule ever changes it
    // changes in all three.
    final onAccent = widget.theme.palette.accent.computeLuminance() > 0.5
        ? const Color(
            0xFF12080D) // theme-exempt: mirrors ChromeColors.onAccent
        : const Color(
            0xFFFFFFFF); // theme-exempt: mirrors ChromeColors.onAccent

    _puckLabels = {
      for (final l in kIndexLabels) l: make(l, 29, onAccent, FontWeight.w700),
    };
  }

  void _onTick(Duration now) {
    // Clamped so a frame lost to a dropped GC pass cannot detonate the spring.
    final dt = math.min((now - _last).inMicroseconds / 1e6, 0.05);
    _last = now;

    final touch = _motion.touchY;
    final centres = _motion.centres;
    if (centres.length != _letters.length) return;

    for (var i = 0; i < centres.length; i++) {
      final goal = touch == null
          ? 0.0
          : -_kPush *
              math.exp(-math.pow((centres[i] - touch) / _kFalloff, 2).toDouble());
      _motion.v[i] +=
          (_kStiffness * (goal - _motion.x[i]) - _kDamping * _motion.v[i]) * dt;
      _motion.x[i] += _motion.v[i] * dt;
    }
    _motion.tick();

    // Stop when nothing is moving and nothing is touching. A ticker left
    // running is a wakeup a frame for a screen that is holding still.
    if (touch == null && !_motion.settling) {
      for (var i = 0; i < _motion.x.length; i++) {
        _motion.x[i] = 0;
        _motion.v[i] = 0;
      }
      _motion.tick();
      _ticker.stop();
    }
  }

  void _start() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  /// The nearest label that actually has a section.
  ///
  /// Ties go to the EARLIER letter, so a finger between an absent P and an
  /// absent R with sections at O and S lands on O. Scrolling slightly short of
  /// a target reads as the list being where you left it; scrolling past reads
  /// as having missed.
  String? _resolve(int index) {
    for (var d = 0; d < kIndexLabels.length; d++) {
      final before = index - d;
      if (before >= 0 && widget.present.contains(kIndexLabels[before])) {
        return kIndexLabels[before];
      }
      final after = index + d;
      if (after < kIndexLabels.length &&
          widget.present.contains(kIndexLabels[after])) {
        return kIndexLabels[after];
      }
    }
    return null;
  }

  void _select(double y) {
    final centres = _motion.centres;
    if (centres.isEmpty) return;

    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < centres.length; i++) {
      final d = (centres[i] - y).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }

    _motion.touchY = y;
    if (best == _motion.activeIndex) {
      _motion.tick();
      return;
    }
    _motion.activeIndex = best;

    final target = _resolve(best);
    if (target != null) {
      // A detent per letter, the same feedback a physical index has. Selection
      // click rather than a heavier impact: this fires up to 27 times in one
      // swipe, and anything stronger reads as the phone objecting.
      HapticFeedback.selectionClick();
      widget.onJump(target);
    }
    _motion.tick();
  }

  void _release() {
    _motion.touchY = null;
    _motion.activeIndex = -1;
    _start();
    _motion.tick();
  }

  @override
  Widget build(BuildContext context) {
    // ─── REDUCED MOTION COLLAPSES ARC TO PLAIN ─────────────────────────────
    //
    // Rather than skipping the rail or animating anyway. The index is a
    // navigation control first and the bow is decoration on top of it, so the
    // control survives the setting and only the decoration goes.
    final bowing = widget.style == IndexRail.arc &&
        !MediaQuery.disableAnimationsOf(context);

    return ExcludeSemantics(
      child: SizedBox(
        width: _kRailWidth + _kPuckLane,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RailPainter(
                      motion: _motion,
                      letters: _letters,
                      puckLabels: _puckLabels,
                      accent: widget.theme.palette.accent,
                      bowing: bowing,
                    ),
                  ),
                ),
              ),
            ),
            // Only the strip listens. The puck lane to its left stays
            // transparent to touch so the tiles under it are still tappable.
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: _kRailWidth,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  if (bowing) _start();
                  _select(e.localPosition.dy);
                },
                onPointerMove: (e) => _select(e.localPosition.dy),
                onPointerUp: (_) => _release(),
                onPointerCancel: (_) => _release(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the letters, their displacement, and the puck.
class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.motion,
    required this.letters,
    required this.puckLabels,
    required this.accent,
    required this.bowing,
  }) : super(repaint: motion);

  final _RailMotion motion;
  final List<TextPainter> letters;
  final Map<String, TextPainter> puckLabels;
  final Color accent;
  final bool bowing;

  @override
  void paint(Canvas canvas, Size size) {
    final n = letters.length;
    if (n == 0) return;

    // Slots are derived from the box rather than fixed, so the alphabet fits a
    // 640dp phone and a tablet without either clipping or stranding the letters
    // at the top. Centred as a block when there is room to spare.
    final slot = math.min(_kMaxSlot, (size.height - _kEndPad * 2) / n);
    final top = (size.height - slot * n) / 2;

    // Written back for the hit test in `_select`. The painter is the only place
    // that knows the box, and a second derivation of this arithmetic is how the
    // finger and the glyph end up disagreeing by half a letter.
    if (motion.centres.length != n) {
      motion.centres = List<double>.filled(n, 0);
    }
    for (var i = 0; i < n; i++) {
      motion.centres[i] = top + slot * (i + 0.5);
    }

    final railCentreX = size.width - _kRailWidth / 2;

    for (var i = 0; i < n; i++) {
      final p = letters[i];
      final dx = bowing ? motion.x[i] : 0.0;
      // Scale is DERIVED from displacement rather than tracked separately, so
      // the two can never drift apart mid-gesture. On the plain rail there is
      // no displacement, so the active letter is lifted explicitly instead.
      final grow = bowing
          ? 1 + math.min(1.0, dx.abs() / _kPush) * 0.45
          : (i == motion.activeIndex ? 1.45 : 1.0);

      canvas
        ..save()
        ..translate(railCentreX + dx, motion.centres[i])
        ..scale(grow)
        ..translate(-p.width / 2, -p.height / 2);
      p.paint(canvas, Offset.zero);
      canvas.restore();
    }

    final touch = motion.touchY;
    final active = motion.activeIndex;
    if (touch == null || active < 0 || active >= letters.length) return;

    final puckX = size.width - _kRailWidth - _kPuckLane / 2;
    canvas.drawCircle(
      Offset(puckX, touch),
      _kPuckRadius,
      Paint()..color = accent,
    );

    final label = puckLabels[kIndexLabels[active]];
    if (label != null) {
      label.paint(
        canvas,
        Offset(puckX - label.width / 2, touch - label.height / 2),
      );
    }
  }

  /// Repainting is driven by [motion]; this only has to catch a theme change.
  @override
  bool shouldRepaint(_RailPainter old) =>
      old.letters != letters ||
      old.accent != accent ||
      old.bowing != bowing ||
      old.puckLabels != puckLabels;
}
