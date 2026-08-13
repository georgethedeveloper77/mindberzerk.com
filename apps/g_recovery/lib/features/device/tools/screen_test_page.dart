import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/i18n/g_strings.dart';

/// FINDING WHAT IS WRONG WITH A SCREEN.
///
/// Two checks, because they catch different faults and neither finds the other.
///
/// FLOOD FILLS find dead and stuck pixels, backlight bleed and tint. A dead
/// pixel is invisible on anything but a full white field and obvious on it.
///
/// A TOUCH GRID finds a digitiser that has stopped responding in one area,
/// which is the commonest fault on a phone that has been dropped and the one no
/// amount of looking will reveal.
///
/// ─── FULL BRIGHTNESS, AND PUT IT BACK ────────────────────────────────────────
///
/// A dim screen hides exactly the faults this is looking for. The brightness is
/// raised on entry and the system value restored on exit, because leaving a
/// phone at maximum after a diagnostic is a battery cost the user did not ask
/// for and will not connect to this screen.
class ScreenTestPage extends StatefulWidget {
  const ScreenTestPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ScreenTestPage(),
  );

  @override
  State<ScreenTestPage> createState() => _ScreenTestPageState();
}

class _ScreenTestPageState extends State<ScreenTestPage> {
  int _step = 0;

  /// Which cells of the touch grid have been reached.
  final Set<int> _touched = <int>{};

  static const int _columns = 5;
  static const int _rows = 9;

  @override
  void initState() {
    super.initState();
    // Immersive, because a status bar over a white field hides the corner of
    // the screen that is most likely to have a fault.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// THE ONLY COLOUR LITERALS IN THE APP OUTSIDE THE THEME, and they are the
  /// point of the screen rather than an oversight.
  ///
  /// A theme colour here would defeat the test. Finding a dead pixel needs
  /// exactly 0xFFFFFFFF, and finding a dead red subpixel needs a field with no
  /// green or blue in it at all. Every token in this app is chosen to sit
  /// comfortably on a phone screen, which is the opposite of what a diagnostic
  /// field is for.
  ///
  /// If no_constants.sh flags these, the exception belongs in the script.
  ///
  /// Solid fields first, then the grid. White and black find most faults, the
  /// three primaries find a single dead subpixel that a white field hides,
  /// and grey finds tint and uneven backlight.
  static const List<(String, Color)> _fields = <(String, Color)>[
    ('White, look for dead pixels', Color(0xFFFFFFFF)),
    ('Black, look for stuck pixels and bleed', Color(0xFF000000)),
    ('Red', Color(0xFFFF0000)),
    ('Green', Color(0xFF00FF00)),
    ('Blue', Color(0xFF0000FF)),
    ('Grey, look for tint and uneven light', Color(0xFF808080)),
  ];

  bool get _onGrid => _step >= _fields.length;

  void _next() {
    if (_step < _fields.length) {
      setState(() => _step++);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_onGrid) return _grid(context);

    final (String label, Color colour) = _fields[_step];
    // Black text on a light field, white on a dark one. Computed rather than
    // hardcoded per entry, so adding a field cannot get it wrong.
    final Color ink = colour.computeLuminance() > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: colour,
      body: GestureDetector(
        onTap: _next,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: GSpace.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GType.bodySmall.copyWith(
                          color: ink.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: GSpace.sm),
                      Text(
                        'Tap for the next one  ·  ${_step + 1} of '
                        '${_fields.length + 1}',
                        style: GType.micro.copyWith(
                          color: ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final GTokens t = context.g;
    final int total = _columns * _rows;
    final bool done = _touched.length == total;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(GSpace.md),
              child: Text(
                done
                    ? 'Every square responded. The digitiser is reaching the '
                          'whole screen.'
                    : 'Drag a finger over every square. Any that stay dark are '
                          'not registering touch.',
                textAlign: TextAlign.center,
                style: GType.bodySmall.copyWith(
                  color: done ? t.success : t.muted,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: GSpace.sm),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final double cellWidth = box.maxWidth / _columns;
                    final double cellHeight = box.maxHeight / _rows;

                    // One gesture detector over the whole grid rather than one
                    // per cell. A drag across cell borders would otherwise be
                    // handed to whichever child claimed it first and the rest
                    // would never see the finger.
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (DragDownDetails d) =>
                          _mark(d.localPosition, cellWidth, cellHeight),
                      onPanUpdate: (DragUpdateDetails d) =>
                          _mark(d.localPosition, cellWidth, cellHeight),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: total,
                        itemBuilder: (BuildContext context, int index) =>
                            AnimatedContainer(
                              duration: GMotion.fast,
                              decoration: BoxDecoration(
                                color: _touched.contains(index)
                                    ? t.accent
                                    : t.panelAlt,
                                borderRadius: GRadius.all(4),
                              ),
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(GSpace.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_touched.length} of $total',
                      style: GType.monoSmall.copyWith(color: t.dim),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(GSpace.sm),
                      child: Text(
                        context.s('Done'),
                        style: GType.label.copyWith(color: t.accentText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mark(Offset at, double cellWidth, double cellHeight) {
    final int column = (at.dx / cellWidth).floor();
    final int row = (at.dy / cellHeight).floor();
    if (column < 0 || column >= _columns) return;
    if (row < 0 || row >= _rows) return;

    final int index = row * _columns + column;
    if (_touched.contains(index)) return;
    setState(() => _touched.add(index));
  }
}
