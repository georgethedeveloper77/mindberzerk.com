import 'dart:math' as math;

/// Unit conversion for the Device tab.
///
/// Lives here rather than in core/format.dart because every function is about a
/// platform unit the probe deliberately did not convert. The rule from the
/// schema holds on this side too: convert ONCE, at display.
///
/// Every function returns null for null input. A missing reading is an absent
/// row, never a dash.
class DeviceFormat {
  const DeviceFormat._();

  /// kHz as sysfs reports it, to GHz or MHz.
  ///
  /// Below 1 GHz it shows MHz, because "0.7 GHz" reads as a rounding artefact
  /// while "691 MHz" reads as a measurement.
  static String? frequency(int? kilohertz) {
    if (kilohertz == null || kilohertz <= 0) return null;
    if (kilohertz >= 1000000) {
      return '${(kilohertz / 1000000).toStringAsFixed(2)} GHz';
    }
    return '${(kilohertz / 1000).round()} MHz';
  }

  /// Millidegrees to a single decimal.
  static String? celsiusFromMilli(int? milli) {
    if (milli == null) return null;
    return '${(milli / 1000).toStringAsFixed(1)} C';
  }

  /// Tenths of a degree, which is the unit the battery broadcast uses.
  static String? celsiusFromDeci(int? deci) {
    if (deci == null) return null;
    return '${(deci / 10).toStringAsFixed(1)} C';
  }

  /// Microamps to milliamps, MAGNITUDE ONLY.
  ///
  /// The sign is not portable: most OEMs report negative while discharging,
  /// several Samsung and Xiaomi builds report positive. Direction comes from the
  /// charging flag, which is the one signal that is consistent everywhere.
  static String? milliAmps(int? microAmps) {
    if (microAmps == null) return null;
    final int milli = (microAmps.abs() / 1000).round();
    return '$milli mA';
  }

  static String? volts(int? milliVolts) {
    if (milliVolts == null || milliVolts <= 0) return null;
    return '${(milliVolts / 1000).toStringAsFixed(2)} V';
  }

  static String? microAmpHours(int? value) {
    if (value == null || value <= 0) return null;
    return '${(value / 1000).round()} mAh';
  }

  /// PowerManager thermal status, 0 to 6.
  static String? thermalStatus(int? status) {
    switch (status) {
      case 0:
        return 'Normal';
      case 1:
        return 'Light';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Critical';
      case 5:
        return 'Emergency';
      case 6:
        return 'Shutdown';
      default:
        return null;
    }
  }

  /// Where a temperature sits on a 20 C to 70 C scale, for a bar fill.
  ///
  /// The floor is 20 rather than 0 because a phone is never near freezing in
  /// use, and anchoring at 0 makes every reading look like a third of the way
  /// up regardless of what it is doing.
  static double? thermalFraction(int? milliCelsius) {
    if (milliCelsius == null) return null;
    final double celsius = milliCelsius / 1000;
    return ((celsius - 20) / 50).clamp(0.0, 1.0);
  }

  /// Current frequency against the cluster ceiling.
  static double? frequencyFraction(int? currentKhz, int? maxKhz) {
    if (currentKhz == null || maxKhz == null || maxKhz <= 0) return null;
    return (currentKhz / maxKhz).clamp(0.0, 1.0);
  }

  /// Title case for the enum-shaped strings the schema carries: "notCharging"
  /// becomes "Not charging", "overVoltage" becomes "Over voltage".
  ///
  /// Done here rather than natively so an OEM value nobody anticipated still
  /// renders as readable text instead of falling through to a default.
  static String? humanise(String? camel) {
    if (camel == null || camel.isEmpty) return null;
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < camel.length; i++) {
      final String char = camel[i];
      final bool isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) {
        out.write(' ');
        out.write(char.toLowerCase());
      } else if (i == 0) {
        out.write(char.toUpperCase());
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }

  /// Rounds a byte count to the nearest plausible RAM size for display next to
  /// the measured figure. Android reports 7.63 GB on an 8 GB phone because the
  /// kernel and the bootloader take their share before userspace sees it.
  static int nominalRamBytes(int totalBytes) {
    const List<int> sizes = <int>[2, 3, 4, 6, 8, 12, 16, 24];
    final double gb = totalBytes / 1000000000;
    int best = sizes.first;
    double bestDelta = double.infinity;
    for (final int size in sizes) {
      final double delta = (size - gb).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = size;
      }
    }
    return math.max(best, 1) * 1000000000;
  }
}
