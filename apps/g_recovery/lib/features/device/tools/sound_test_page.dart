import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_card.dart';

/// DOES THE SOUND WORK.
///
/// ─── EACH SPEAKER ALONE, THEN BOTH ───────────────────────────────────────────
///
/// A phone with one dead speaker sounds fine playing through both, so the test
/// that matters is the one that plays through one at a time. Anyone checking a
/// secondhand phone is doing exactly this by ear, and doing it with a tone is
/// more reliable than doing it with music.
class SoundTestPage extends ConsumerStatefulWidget {
  const SoundTestPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const SoundTestPage(),
  );

  @override
  ConsumerState<SoundTestPage> createState() => _SoundTestPageState();
}

class _SoundTestPageState extends ConsumerState<SoundTestPage> {
  String? _playing;
  double _hertz = 440;

  /// Held from initState, not read in dispose.
  ///
  /// ─── ref IS UNSAFE ONCE THE WIDGET IS DEACTIVATED ────────────────────────
  ///
  /// Ref resolves through BuildContext, and by the time dispose runs the
  /// element is on its way out, so reading a provider there throws. Capturing
  /// the object while the widget is alive is the documented way, and it is the
  /// only way for a resource that MUST be released: a tone that outlives its
  /// screen is the most alarming bug this page could have.
  late final HardwareBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = ref.read(hardwareBridgeProvider);
  }

  @override
  void dispose() {
    _bridge.stopTone();
    super.dispose();
  }

  Future<void> _play(String channel) async {
    setState(() => _playing = channel);
    await _bridge.playTone(_hertz, 1200, channel);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: 'Speakers',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            Text(
              'Turn the volume up. Each button plays a tone through one side '
              'only.',
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.lg),

            Row(
              children: <Widget>[
                Expanded(
                  child: _Pad(
                    label: 'Left',
                    icon: Icons.volume_down_rounded,
                    active: _playing == 'left',
                    onTap: () => _play('left'),
                  ),
                ),
                const SizedBox(width: GSpace.sm + 1),
                Expanded(
                  child: _Pad(
                    label: 'Right',
                    icon: Icons.volume_up_rounded,
                    active: _playing == 'right',
                    onTap: () => _play('right'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSpace.sm + 1),
            _Pad(
              label: 'Both',
              icon: Icons.surround_sound_rounded,
              active: _playing == 'both',
              onTap: () => _play('both'),
            ),

            const SizedBox(height: GSpace.lg),
            Text('PITCH', style: GType.overline.copyWith(color: t.dim)),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_hertz.round()} Hz',
                    style: GType.monoNumber.copyWith(
                      color: t.text,
                      fontSize: 18,
                    ),
                  ),
                  Slider(
                    value: _hertz,
                    // 100 to 8000. Below 100 a phone speaker cannot move enough
                    // air to be heard, and above 8000 a great many adults
                    // cannot hear it either, so both ends would test the
                    // listener rather than the phone.
                    min: 100,
                    max: 8000,
                    onChanged: (double value) => setState(() => _hertz = value),
                  ),
                  Text(
                    'A rattle or a buzz at one pitch and not another is a '
                    'damaged driver.',
                    style: GType.micro.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),

            const SizedBox(height: GSpace.lg),
            Text('VIBRATION', style: GType.overline.copyWith(color: t.dim)),
            const SizedBox(height: GSpace.sm + 1),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Pad(
                    label: 'Short',
                    icon: Icons.vibration_rounded,
                    active: false,
                    onTap: () => _bridge.vibrate('short'),
                  ),
                ),
                const SizedBox(width: GSpace.sm + 1),
                Expanded(
                  child: _Pad(
                    label: 'Long',
                    icon: Icons.vibration_rounded,
                    active: false,
                    onTap: () => _bridge.vibrate('long'),
                  ),
                ),
                const SizedBox(width: GSpace.sm + 1),
                Expanded(
                  child: _Pad(
                    label: 'Double',
                    icon: Icons.vibration_rounded,
                    active: false,
                    onTap: () => _bridge.vibrate('double'),
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

class _Pad extends StatelessWidget {
  const _Pad({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.card);

    return AnimatedContainer(
      duration: GMotion.fast,
      decoration: BoxDecoration(
        color: active ? t.accent.withValues(alpha: 0.2) : t.panel,
        border: Border.all(color: active ? t.accent : t.line),
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GSpace.lg - 2),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 24, color: active ? t.accent : t.muted),
                const SizedBox(height: GSpace.sm),
                Text(
                  label,
                  style: GType.bodySmall.copyWith(
                    color: active ? t.accent : t.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// HOW MANY FINGERS THE SCREEN CAN FOLLOW.
///
/// ─── PURE FLUTTER, AND IT HAS TO BE ──────────────────────────────────────────
///
/// Touch is the one thing on the device that Flutter sees more directly than
/// Kotlin would: the framework already receives every pointer with its id and
/// position. A native implementation would be a second touch pipeline reporting
/// on the first.
///
/// The screen test covers dead pixels; this covers a digitiser that has stopped
/// tracking a region or run out of simultaneous points, which is a different
/// fault with the same symptom of "the screen is broken".
class TouchTestPage extends StatefulWidget {
  const TouchTestPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const TouchTestPage(),
  );

  @override
  State<TouchTestPage> createState() => _TouchTestPageState();
}

class _TouchTestPageState extends State<TouchTestPage> {
  final Map<int, Offset> _points = <int, Offset>{};

  /// The most fingers seen at once, kept after they lift.
  ///
  /// The live count drops the moment someone lets go, which is exactly when
  /// they look at the number. The peak is the answer they came for.
  int _peak = 0;

  void _update(int id, Offset at) {
    setState(() {
      _points[id] = at;
      if (_points.length > _peak) _peak = _points.length;
    });
  }

  void _remove(int id) => setState(() => _points.remove(id));

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<Color> hues = <Color>[
      t.photo,
      t.video,
      t.audio,
      t.docs,
      t.chat,
      t.apps,
    ];

    return Scaffold(
      backgroundColor: t.ink,
      body: Listener(
        onPointerDown: (PointerDownEvent e) =>
            _update(e.pointer, e.localPosition),
        onPointerMove: (PointerMoveEvent e) =>
            _update(e.pointer, e.localPosition),
        onPointerUp: (PointerUpEvent e) => _remove(e.pointer),
        onPointerCancel: (PointerCancelEvent e) => _remove(e.pointer),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: t.ink)),

            for (final MapEntry<int, Offset> point in _points.entries)
              Positioned(
                left: point.value.dx - 38,
                top: point.value.dy - 38,
                child: IgnorePointer(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: hues[point.key % hues.length].withValues(
                        alpha: 0.28,
                      ),
                      border: Border.all(
                        color: hues[point.key % hues.length],
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    GAppBar(
                      title: 'Touch',
                      subtitle: 'Most at once: $_peak',
                      leading: GIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const Spacer(),
                    if (_points.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: GSpace.xl),
                        child: Text(
                          'Put as many fingers on the screen as you can, and '
                          'drag them into every corner.',
                          textAlign: TextAlign.center,
                          style: GType.bodySmall.copyWith(color: t.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
