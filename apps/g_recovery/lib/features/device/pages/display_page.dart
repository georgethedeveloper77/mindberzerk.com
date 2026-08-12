import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_card.dart';
import 'spec_rows.dart';

/// THE SCREEN.
///
/// No chart. Nothing on this page is a series or a distribution, and a graph
/// over a spec list is decoration that makes the page slower to read.
class DisplayPage extends ConsumerWidget {
  const DisplayPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const DisplayPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final DisplayInfo? d = ref.watch(displayProvider).value;
    final FeatureFlags? f = ref.watch(featuresProvider).value;

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
              title: 'Display',
              subtitle: d == null
                  ? null
                  : '${d.widthPx} x ${d.heightPx}  ·  '
                        '${d.refreshHz.round()} Hz',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (d != null) ...<Widget>[
              Text('SCREEN', style: GType.overline.copyWith(color: t.dim)),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: SpecRows(
                  rows: <(String, String?)>[
                    ('Resolution', '${d.widthPx} x ${d.heightPx}'),
                    ('Aspect ratio', _aspect(d.widthPx, d.heightPx)),
                    ('Density', '${d.densityDpi} dpi'),
                    ('Refresh rate', '${d.refreshHz.round()} Hz'),
                    (
                      'Also supports',
                      d.supportedHz.length < 2
                          ? null
                          : d.supportedHz
                                .where(
                                  (double hz) =>
                                      hz.round() != d.refreshHz.round(),
                                )
                                .map((double hz) => '${hz.round()}')
                                .join(', '),
                    ),
                  ],
                ),
              ),

              if (d.maxLuminance != null) ...<Widget>[
                const SizedBox(height: GSpace.lg),
                Text(
                  'BRIGHTNESS',
                  style: GType.overline.copyWith(color: t.dim),
                ),
                const SizedBox(height: GSpace.sm + 1),
                GCard(
                  child: SpecRows(
                    rows: <(String, String?)>[
                      ('Maximum', '${d.maxLuminance!.round()} cd/m2'),
                      (
                        'Typical',
                        d.averageLuminance == null
                            ? null
                            : '${d.averageLuminance!.round()} cd/m2',
                      ),
                      ('Minimum', d.minLuminance?.toStringAsFixed(4)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: GSpace.lg),
              Text('SUPPORTED', style: GType.overline.copyWith(color: t.dim)),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: Column(
                  children: <Widget>[
                    _Flag(label: 'HDR', on: d.hdr, last: false),
                    _Flag(label: 'Wide colour', on: d.wideColour, last: true),
                  ],
                ),
              ),

              if (d.hdrTypes.isNotEmpty) ...<Widget>[
                const SizedBox(height: GSpace.sm + 1),
                Wrap(
                  spacing: GSpace.sm,
                  runSpacing: GSpace.sm,
                  children: <Widget>[
                    for (final String type in d.hdrTypes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GSpace.md - 2,
                          vertical: GSpace.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: t.docs.withValues(alpha: 0.16),
                          borderRadius: GRadius.all(GRadius.chip),
                        ),
                        child: Text(
                          type,
                          style: GType.micro.copyWith(color: t.docs),
                        ),
                      ),
                  ],
                ),
              ],
            ],

            if (f != null) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              Text(
                'THIS PHONE HAS',
                style: GType.overline.copyWith(color: t.dim),
              ),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: Column(
                  children: <Widget>[
                    _Flag(
                      label: 'Fingerprint reader',
                      on: f.fingerprint,
                      last: false,
                    ),
                    _Flag(label: 'NFC', on: f.nfc, last: false),
                    _Flag(label: 'GPS', on: f.gps, last: false),
                    _Flag(label: 'Ultra wideband', on: f.uwb, last: false),
                    _Flag(label: 'USB host', on: f.usbHost, last: false),
                    _Flag(label: 'Bluetooth LE', on: f.bluetoothLe, last: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Reduced by the greatest common divisor, so a 2340 by 1080 panel reads
  /// 19.5:9 rather than 65:30.
  static String _aspect(int w, int h) {
    int a = w;
    int b = h;
    while (b != 0) {
      final int temp = b;
      b = a % b;
      a = temp;
    }
    if (a == 0) return '';
    final double x = w / a;
    final double y = h / a;
    if (y > 20) {
      return '${(w / h * 9).toStringAsFixed(1)}:9';
    }
    return '${x.round()}:${y.round()}';
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.on, required this.last});

  final String label;
  final bool on;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 1),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            on ? Icons.check_rounded : Icons.remove_rounded,
            size: 16,
            color: on ? t.success : t.dim,
          ),
          const SizedBox(width: GSpace.md - 2),
          Expanded(
            child: Text(
              label,
              style: GType.bodySmall.copyWith(color: on ? t.text : t.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// THE CAMERAS.
///
/// ─── A SCATTER, AND IT EARNS ITS PLACE ───────────────────────────────────────
///
/// Focal length against aperture, one dot per lens, sized by megapixels. Six
/// cameras as six rows of numbers tells a person nothing; the same six as dots
/// shows immediately which is the wide, which is the telephoto, and which is a
/// 2 MP depth sensor padding the spec sheet.
class CamerasPage extends ConsumerWidget {
  const CamerasPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const CamerasPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<CameraInfo> cameras =
        ref.watch(camerasProvider).value ?? const <CameraInfo>[];

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
              title: 'Cameras',
              subtitle: cameras.isEmpty ? null : '${cameras.length} found',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (cameras.length > 1) ...<Widget>[
              GCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Focal length against aperture',
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: GSpace.md),
                    SizedBox(
                      height: 168,
                      child: ScatterChart(
                        _scatter(cameras, t),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    const SizedBox(height: GSpace.sm),
                    Row(
                      children: <Widget>[
                        Text(
                          'wider',
                          style: GType.micro.copyWith(color: t.dim),
                        ),
                        const Spacer(),
                        Text(
                          'longer lens',
                          style: GType.micro.copyWith(color: t.dim),
                        ),
                      ],
                    ),
                    const SizedBox(height: GSpace.sm),
                    Row(
                      children: <Widget>[
                        _Dot(hue: t.accent, label: 'Back'),
                        const SizedBox(width: GSpace.md),
                        _Dot(hue: t.photo, label: 'Front'),
                        const Spacer(),
                        Text(
                          'size is megapixels',
                          style: GType.micro.copyWith(color: t.dim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GSpace.lg),
            ],

            for (final CameraInfo camera in cameras) ...<Widget>[
              Text(
                '${_lensName(camera, cameras)}  ·  '
                '${camera.megapixels.toStringAsFixed(1)} MP',
                style: GType.overline.copyWith(color: t.dim),
              ),
              const SizedBox(height: GSpace.sm + 1),
              GCard(
                child: SpecRows(
                  rows: <(String, String?)>[
                    ('Resolution', '${camera.widthPx} x ${camera.heightPx}'),
                    (
                      'Focal length',
                      camera.focalLengthsMm.isEmpty
                          ? null
                          : camera.focalLengthsMm
                                .map((double f) => '${f.toStringAsFixed(1)} mm')
                                .join(', '),
                    ),
                    (
                      'Aperture',
                      camera.apertures.isEmpty
                          ? null
                          : camera.apertures
                                .map((double a) => 'f/${a.toStringAsFixed(1)}')
                                .join(', '),
                    ),
                    (
                      'ISO range',
                      camera.isoMin == null || camera.isoMax == null
                          ? null
                          : '${camera.isoMin} to ${camera.isoMax}',
                    ),
                    ('RAW', camera.supportsRaw ? 'Supported' : 'No'),
                    ('Flash', camera.hasFlash ? 'Yes' : 'No'),
                  ],
                ),
              ),
              const SizedBox(height: GSpace.md - 1),
            ],
          ],
        ),
      ),
    );
  }

  ScatterChartData _scatter(List<CameraInfo> cameras, GTokens t) {
    final List<ScatterSpot> spots = <ScatterSpot>[];
    double maxFocal = 1;
    double maxAperture = 1;

    for (final CameraInfo c in cameras) {
      if (c.focalLengthsMm.isEmpty || c.apertures.isEmpty) continue;
      final double focal = c.focalLengthsMm.first;
      final double aperture = c.apertures.first;
      if (focal > maxFocal) maxFocal = focal;
      if (aperture > maxAperture) maxAperture = aperture;

      spots.add(
        ScatterSpot(
          focal,
          aperture,
          dotPainter: FlDotCirclePainter(
            // Radius from megapixels, so the sensor doing the real work is the
            // biggest dot and a 2 MP depth sensor is visibly a speck.
            radius: (4 + c.megapixels * 0.55).clamp(4, 16).toDouble(),
            color: (c.facing == 'front' ? t.photo : t.accent).withValues(
              alpha: 0.75,
            ),
            strokeWidth: 0,
          ),
        ),
      );
    }

    return ScatterChartData(
      minX: 0,
      maxX: maxFocal * 1.25,
      minY: 0,
      maxY: maxAperture * 1.35,
      scatterSpots: spots,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      // Not const. ScatterTouchData has no const constructor, unlike the grid
      // and titles types beside it.
      scatterTouchData: ScatterTouchData(enabled: false),
    );
  }

  /// Wide, ultra wide or telephoto, worked out from focal length.
  ///
  /// ─── RELATIVE TO THE OTHER LENSES, NOT TO ABSOLUTE NUMBERS ───────────────
  ///
  /// A 2.2mm lens is ultra wide on one phone and the only camera on another.
  /// The shortest back lens is the ultra wide only when there is something
  /// longer to compare it against, so the naming is done within the set rather
  /// than against fixed thresholds that would mislabel half of all phones.
  ///
  /// Falls back to Front or Back where there is nothing to compare, which is
  /// honest rather than guessing at a name.
  static String _lensName(CameraInfo camera, List<CameraInfo> all) {
    if (camera.facing != 'back') return _facing(camera.facing);
    if (camera.focalLengthsMm.isEmpty) return 'Back';

    final List<CameraInfo> backs =
        all
            .where(
              (CameraInfo c) =>
                  c.facing == 'back' && c.focalLengthsMm.isNotEmpty,
            )
            .toList()
          ..sort(
            (CameraInfo a, CameraInfo b) =>
                a.focalLengthsMm.first.compareTo(b.focalLengthsMm.first),
          );

    if (backs.length < 2) return 'Back';
    if (camera.id == backs.first.id) return 'Ultra wide';
    if (camera.id == backs.last.id) return 'Telephoto';

    // A depth or macro sensor is the giveaway: tiny, and never the one with the
    // longest or shortest lens.
    if (camera.megapixels < 3) return 'Depth or macro';
    return 'Wide';
  }

  static String _facing(String facing) => switch (facing) {
    'front' => 'Front',
    'back' => 'Back',
    _ => 'External',
  };
}

class _Dot extends StatelessWidget {
  const _Dot({required this.hue, required this.label});

  final Color hue;
  final String label;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
        ),
        const SizedBox(width: GSpace.xs + 2),
        Text(label, style: GType.micro.copyWith(color: t.muted)),
      ],
    );
  }
}
