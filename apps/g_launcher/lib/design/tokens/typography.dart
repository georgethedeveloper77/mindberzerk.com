import 'package:flutter/material.dart';
import 'colors.dart';

/// House type.
///
/// The rule that carries the whole visual identity across both apps:
/// **every data value is set in mono.** GB, dBm, timestamps, hostnames,
/// version numbers. Prose is sans. That single habit is what makes these
/// read as instruments rather than as cleaner apps.
abstract final class GType {
  static const _sans = 'Inter';
  static const mono = 'UbuntuMono';

  static const display = TextStyle(
    fontFamily: _sans, fontSize: 24, fontWeight: FontWeight.w500,
    color: GColors.text, letterSpacing: -0.3,
  );
  static const title = TextStyle(
    fontFamily: _sans, fontSize: 16, fontWeight: FontWeight.w500, color: GColors.text,
  );
  static const body = TextStyle(
    fontFamily: _sans, fontSize: 14, height: 1.45, color: GColors.text,
  );
  static const caption = TextStyle(
    fontFamily: _sans, fontSize: 12, color: GColors.textMuted,
  );
  static const label = TextStyle(
    fontFamily: _sans, fontSize: 11, fontWeight: FontWeight.w600,
    color: GColors.textFaint, letterSpacing: 0.6,
  );

  /// Data. Always.
  static const value = TextStyle(
    fontFamily: mono, fontSize: 13, color: GColors.text,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
