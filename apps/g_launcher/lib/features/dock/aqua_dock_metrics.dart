/// Aqua dock geometry, as pure functions. No Flutter imports — testable at every
/// screen size without a device, same treatment [DockMetrics] and [GridMetrics]
/// already get.
///
/// This is the magnifying dock: icons swell as the focus approaches and settle
/// back as it leaves. It is a SEPARATE file from dock_metrics.dart on purpose.
/// The GNOME/KDE dock is fit-to-run — every slot the same size, shrinking as the
/// dock fills. Aqua's slots are all different sizes at once and change every
/// frame. Folding both into one abstraction would produce a function with a mode
/// flag and two disjoint halves.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// MACOS MAGNIFICATION IS A HOVER EFFECT, AND A PHONE HAS NO HOVER.
///
/// On a desktop the cursor approaches an icon without touching it, and the dock
/// responds continuously to something that is not a click. There is no such
/// input on a phone. So [focus] is nullable and means "where the finger is, if
/// one is down": during a drag along the dock the icons swell under the thumb,
/// and on release everything relaxes to rest.
///
/// That makes the Aqua dock a scrubbing control rather than a hover target,
/// which is a genuinely different interaction from the desktop one. It reads
/// well — drag along, watch it swell, lift to launch — but it is a decision, not
/// a port, and it is written down here so nobody later "fixes" it back toward
/// hover semantics that cannot exist.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:math' as math;

/// One laid-out dock slot: where its centre sits and how big it is right now.
class AquaSlot {
  const AquaSlot({required this.center, required this.size});

  /// Centre position along the dock's run, in logical pixels, measured in the
  /// SAME coordinate space the focus is given in — i.e. screen coordinates
  /// within the dock, already centred. Getting these two spaces out of step is
  /// the one bug this API is shaped to prevent; it puts the swell one slot away
  /// from the finger, which looks like lag rather than like an off-by-one.
  final double center;

  /// Current edge length. Between [AquaDockMetrics.minSlot] and
  /// [AquaDockMetrics.peakSlot].
  final double size;

  @override
  bool operator ==(Object other) =>
      other is AquaSlot && other.center == center && other.size == size;

  @override
  int get hashCode => Object.hash(center, size);

  @override
  String toString() =>
      'AquaSlot(center: ${center.toStringAsFixed(1)}, size: ${size.toStringAsFixed(1)})';
}

abstract final class AquaDockMetrics {
  /// Resting slot size. Smaller than [DockMetrics.maxSlot] deliberately: an
  /// Aqua dock is a horizontal strip of many icons that grow on demand, so its
  /// rest state is denser than a dock whose icons never change size.
  static const baseSlot = 46.0;

  /// The magnified peak. Roughly 1.7x rest, which is close to the macOS default
  /// and is about the largest swell that still reads as one dock rather than as
  /// an icon that has jumped out of it.
  static const peakSlot = 78.0;

  /// The floor when the dock is packed. Below this, taps get fiddly on a budget
  /// screen — the same reasoning as [DockMetrics.minSlot], one point lower
  /// because magnification means a small resting icon is still reachable.
  static const minSlot = 34.0;

  static const gap = 6.0;

  /// How far the swell reaches, in slot widths either side of the focus. 2.4
  /// means roughly two neighbours each way are visibly affected. Lower looks
  /// twitchy (one icon pops), higher looks like the whole dock is inflating.
  static const spreadSlots = 2.4;

  /// A magnifying dock tolerates more icons than a static one, because a small
  /// resting icon is still readable the moment you scrub over it. Still capped:
  /// past this it stops being a dock and starts being a list.
  static const maxApps = 8;

  /// Below this it stops being a dock.
  static const minCapacity = 3;

  // ─── HOW MUCH DESKTOP THIS DOCK OCCUPIES ────────────────────────────────
  //
  // The counterpart to [DockMetrics.reserve], and separate for the same reason
  // this whole file is separate: the two docks do not share a geometry. See
  // that constant for why the desklet grid needs to ask at all.

  /// `AquaDock`'s own `EdgeInsets.all(_padding)` around the slot run.
  static const panelPadding = 8.0;

  /// How far the shell holds the dock off the bottom edge.
  ///
  /// Carried over from `gnome_shell`'s 9 rather than read from `aqua_shell`,
  /// which I have not confirmed. Being a few dp generous costs a sliver of
  /// desktop; being short puts a desklet back under the dock.
  static const edgeOffset = 9.0;

  /// The band this dock occupies, measured AT REST rather than magnified.
  ///
  /// The swell is transient and reaches [peakSlot], so reserving for it would
  /// permanently surrender 32dp of desktop to a state that exists only while a
  /// finger is down. A magnified icon growing over a desklet for the length of
  /// a scrub is the correct trade: it is what a Mac does.
  static const reserve = baseSlot + panelPadding * 2 + edgeOffset;

  /// The most apps this dock will hold in [available] logical pixels, measured
  /// at [minSlot] — the smallest a slot is allowed to rest at, hence the true
  /// ceiling.
  static int capacityFor(double available) {
    final fits = ((available + gap) / (minSlot + gap)).floor();
    return fits.clamp(minCapacity, maxApps);
  }

  /// The resting slot size for [count] apps in a dock of usable length
  /// [available]. Shrinks below [baseSlot] only when the dock is genuinely full.
  static double baseSlotFor({required int count, required double available}) {
    if (count <= 0) return baseSlot;
    final fit = (available - (count - 1) * gap) / count;
    return fit.clamp(minSlot, baseSlot);
  }

  /// The magnification curve: 1.0 at the focus, 0.0 at the edge of the spread.
  ///
  /// A RAISED COSINE, not a linear ramp and not a gaussian. Linear has a corner
  /// at the focus — the icon's growth reverses direction instantly as the finger
  /// crosses its centre, and the eye reads that as a glitch. A gaussian never
  /// actually reaches zero, so the outermost icons twitch by a fraction of a
  /// pixel forever and the dock never looks still. The raised cosine is flat at
  /// BOTH ends: no corner at the peak, and it settles to exactly zero at the
  /// edge of the spread.
  static double falloff(double normalizedDistance) {
    if (normalizedDistance >= 1.0) return 0.0;
    if (normalizedDistance <= 0.0) return 1.0;
    return (1.0 + math.cos(math.pi * normalizedDistance)) / 2.0;
  }

  /// Lays out [count] slots in [available] logical pixels.
  ///
  /// [focus] is the finger's position along the dock, in the same coordinate
  /// space the returned centres use. Null means no finger: every slot rests at
  /// [baseSlotFor] and the result is a plain centred row.
  ///
  /// TOTAL WIDTH IS CONSERVED. macOS lets the dock grow into desktop space as it
  /// magnifies; a phone has none, so a swelling icon would shove its neighbours
  /// off the screen edge. When the magnified run would exceed [available] the
  /// sizes are scaled to fit, which keeps the relative swell intact and makes
  /// the neighbours visibly compress instead. The dock therefore cannot clip at
  /// any focus position or app count — see the unit tests, which assert exactly
  /// that across every combination.
  static List<AquaSlot> layout({
    required int count,
    required double available,
    double? focus,
  }) {
    if (count <= 0) return const [];

    final base = baseSlotFor(count: count, available: available);

    // Resting centres, already CENTRED in `available`, because that is the
    // space `focus` arrives in. Measuring distance against an un-centred run is
    // the coordinate-space bug this comment exists to prevent.
    final restRun = count * base + (count - 1) * gap;
    final restShift = (available - restRun) / 2;
    final rest = <double>[
      for (var i = 0; i < count; i++) restShift + base / 2 + i * (base + gap),
    ];

    var sizes = <double>[];
    if (focus == null) {
      sizes = List<double>.filled(count, base);
    } else {
      // The peak scales with the resting size, so a packed dock magnifies
      // proportionally rather than jumping to a fixed 78 that no longer fits.
      final peak = peakSlot * (base / baseSlot);
      final spread = spreadSlots * (base + gap);
      sizes = [
        for (final r in rest)
          base + (peak - base) * falloff((r - focus).abs() / spread),
      ];
    }

    final sum = sizes.fold<double>(0, (a, b) => a + b);
    final run = sum + (count - 1) * gap;
    if (run > available) {
      final k = (available - (count - 1) * gap) / sum;
      sizes = [for (final s in sizes) s * k];
    }

    final total =
        sizes.fold<double>(0, (a, b) => a + b) + (count - 1) * gap;
    final shift = (available - total) / 2;

    final out = <AquaSlot>[];
    var x = shift;
    for (final s in sizes) {
      out.add(AquaSlot(center: x + s / 2, size: s));
      x += s + gap;
    }
    return out;
  }

  /// The dock's current run length, for sizing the glass panel behind it.
  static double runLengthOf(List<AquaSlot> slots) {
    if (slots.isEmpty) return 0;
    final first = slots.first;
    final last = slots.last;
    return (last.center + last.size / 2) - (first.center - first.size / 2);
  }
}
