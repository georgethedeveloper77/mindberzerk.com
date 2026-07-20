import 'package:flutter/material.dart';

/// Every value here is lifted from `g-launcher-mockup.html`, not eyeballed.
/// The `:root` block is the source of truth; if the mockup changes, this file
/// changes, and nothing else does.
///
/// These are the Ubuntu 24.04 *defaults*. They live in the bundled `theme.json`
/// too — this class is the compile-time mirror used by the shell chrome, so the
/// GNOME shell can render before any theme has resolved. A downloaded theme
/// overrides them through `EffectiveTheme`; nothing here is hardcoded into a
/// widget.
///
/// Rule from §6: everything the shell renders reads `EffectiveTheme`, never
/// `ThemeSpec`. These constants are the fallback, not the path.
abstract final class Ubuntu {
  // --ub-orange / --ub-bar / --ub-dock
  static const orange = Color(0xFFE95420);
  static const barBg = Color(0xFF1A171B);
  static const dockBg = Color(0xBD201B21); // rgba(32,27,33,.74)

  // --ub-tx / --ub-mut
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFD6CDD3);

  static const dockBorder = Color(0x1AFFFFFF); // rgba(255,255,255,.1)
  static const separator = Color(0x29FFFFFF); // rgba(255,255,255,.16)
  static const dotIdle = Color(0x52FFFFFF); // rgba(255,255,255,.32)

  /// Conky text sits on a photograph. These are the exact alphas the mockup
  /// uses, and they are load-bearing — pure white looks cheap, and anything
  /// dimmer disappears on a light wallpaper.
  static const conkyPrimary = Color(0xE6FFFFFF); // .9
  static const conkyDate = Color(0xC7FFFFFF); // .78
  static const conkyStat = Color(0xB3FFFFFF); // .7
  static const conkyRule = Color(0x2EFFFFFF); // .18

  static const display = 'Ubuntu';
  static const mono = 'UbuntuMono';

  /// The mockup's stand-in wallpaper. Only ever visible if the real wallpaper
  /// fails to load — but it must never be *black*, because a launcher whose
  /// wallpaper failed should still look deliberate.
  static const wallpaperFallback = RadialGradient(
    center: Alignment(0.56, -0.76), // 78% 12%
    radius: 1.25,
    colors: [Color(0xFF622A4C), Color(0xFF3C1230), Color(0xFF220817)],
    stops: [0.0, 0.46, 1.0],
  );

  /// Text on the desktop has no background to sit on. Without a shadow the
  /// conky is illegible over a bright wallpaper.
  static const List<Shadow> desktopTextShadow = [
    Shadow(color: Color(0x8C000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const topBarHeight = 30.0;
}
