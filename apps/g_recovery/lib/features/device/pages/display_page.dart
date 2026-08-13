import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/hardware_api.g.dart';
import '../../../bridge/hardware_bridge.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_detail_page.dart';
import '../../../ui/g_stat.dart';

/// THE SCREEN.
///
/// No chart. Nothing on this page is a series or a distribution, and a graph
/// over a spec list is decoration that makes the page slower to read.
class DisplayPage extends ConsumerWidget {
  const DisplayPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => DisplayPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final DisplayInfo? d = ref.watch(displayProvider).value;
    final FeatureFlags? f = ref.watch(featuresProvider).value;

    return GDetailPage(
      hue: hue,
      icon: Icons.smartphone_rounded,
      title: 'Display',
      subtitle: d == null
          ? null
          : '${d.widthPx} x ${d.heightPx}  ·  ${d.refreshHz.round()} Hz',
      children: <Widget>[
        if (d != null) ...<Widget>[
          const GOverline('Screen'),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
            rows: <(String, String?)>[
              ('Resolution', '${d.widthPx} x ${d.heightPx}'),
              ('Aspect ratio', _aspect(d.widthPx, d.heightPx)),
              ('Density', '${d.densityDpi} dpi'),
              ('Refresh rate', '${d.refreshHz.round()} Hz'),
              ('Also supports', _otherRates(d)),
            ],
          ),

          if (d.maxLuminance != null) ...<Widget>[
            const SizedBox(height: GSpace.lg),
            const GOverline('Brightness'),
            const SizedBox(height: GSpace.sm + 1),
            GSpecCard(
              rows: <(String, String?)>[
                ('Maximum', '${d.maxLuminance!.round()} cd/m2'),
                (
                  'Typical',
                  d.averageLuminance == null
                      ? null
                      : '${d.averageLuminance!.round()} cd/m2',
                ),
                (
                  'Minimum',
                  d.minLuminance == null
                      ? null
                      : '${d.minLuminance!.toStringAsFixed(4)} cd/m2',
                ),
              ],
            ),
          ],

          const SizedBox(height: GSpace.lg),
          const GOverline('Supported'),
          const SizedBox(height: GSpace.sm + 1),
          GFlagCard(
            flags: <(String, bool)>[
              ('HDR', d.hdr),
              ('Wide colour', d.wideColour),
            ],
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
          const GOverline('This phone has'),
          const SizedBox(height: GSpace.sm + 1),
          GFlagCard(
            flags: <(String, bool)>[
              ('Fingerprint reader', f.fingerprint),
              ('NFC', f.nfc),
              ('GPS', f.gps),
              ('Ultra wideband', f.uwb),
              ('USB host', f.usbHost),
              ('Bluetooth LE', f.bluetoothLe),
            ],
          ),
        ],
      ],
    );
  }

  /// Every mode except the one already on the row above it.
  static String? _otherRates(DisplayInfo d) {
    if (d.supportedHz.length < 2) return null;
    final List<String> others = <String>[
      for (final double hz in d.supportedHz)
        if (hz.round() != d.refreshHz.round()) '${hz.round()}',
    ];
    if (others.isEmpty) return null;
    return '${others.join(', ')} Hz';
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

/// THE CAMERAS.
///
/// ─── A SCATTER, AND IT EARNS ITS PLACE ───────────────────────────────────────
///
/// Focal length against aperture, one dot per lens, sized by megapixels. Six
/// cameras as six rows of numbers tells a person nothing; the same six as dots
/// shows immediately which is the wide, which is the telephoto, and which is a
/// 2 MP depth sensor padding the spec sheet.
class CamerasPage extends ConsumerWidget {
  const CamerasPage({required this.hue, super.key});

  final Color hue;

  static Route<void> route({required Color hue}) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CamerasPage(hue: hue),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<CameraInfo> cameras =
        ref.watch(camerasProvider).value ?? const <CameraInfo>[];

    return GDetailPage(
      hue: hue,
      icon: Icons.photo_camera_rounded,
      title: 'Cameras',
      subtitle: cameras.isEmpty ? null : '${cameras.length} found',
      children: <Widget>[
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
                    Text('wider', style: GType.micro.copyWith(color: t.dim)),
                    const Spacer(),
                    Text(
                      'longer lens',
                      style: GType.micro.copyWith(color: t.dim),
                    ),
                  ],
                ),
                const SizedBox(height: GSpace.sm),
                GStackKeys(
                  entries: <(String, Color)>[
                    ('Back', t.accent),
                    ('Front', t.photo),
                    ('size is megapixels', t.dim),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: GSpace.lg),
        ],

        for (final CameraInfo camera in cameras) ...<Widget>[
          GOverline(
            '${_lensName(camera, cameras)}  ·  '
            '${camera.megapixels.toStringAsFixed(1)} MP',
          ),
          const SizedBox(height: GSpace.sm + 1),
          GSpecCard(
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
          const SizedBox(height: GSpace.md - 1),
        ],
      ],
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
