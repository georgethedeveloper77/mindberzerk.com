import 'package:flutter/material.dart';

/// House chrome — Settings, Themes gallery, dialogs.
/// Neutral on purpose: it must never fight the distro theme on the desktop.
abstract final class GColors {
  static const bg = Color(0xFF100C12);
  static const surface = Color(0xFF191320);
  static const surfaceAlt = Color(0xFF211A29);

  static const text = Color(0xFFEDEAF0);
  static const textMuted = Color(0xFF9A8FA4);
  static const textFaint = Color(0xFF5E5566);

  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x24FFFFFF);

  static const accent = Color(0xFFE95420); // Ubuntu orange — the brand thread
  static const ok = Color(0xFF5FD08C);
  static const warn = Color(0xFFF2B441);
  static const danger = Color(0xFFF0736F);
}

/// The Ubuntu 24.04 desktop palette.
///
/// This lives here ONLY as the bundled fallback theme. Every other distro
/// arrives as JSON over the CDN — see engine/theme_spec.dart. Resist the urge
/// to add a `GColors.fedora`; that road ends in a rebuild per distro.
abstract final class UbuntuPalette {
  static const bgTop = Color(0xFF622A4C);
  static const bgBottom = Color(0xFF220817);
  static const bar = Color(0xFF1A171B);
  static const dock = Color(0xBD201B21);
  static const accent = Color(0xFFE95420);
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkMuted = Color(0xFFD6CDD3);
}
