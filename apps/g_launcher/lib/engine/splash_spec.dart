import 'theme_spec.dart' show ShellKind;

/// The quick boot splash, expressed as data — [BootSpec]'s smaller sibling.
///
/// Two different things happen between "you picked a theme" and "here is your
/// desktop", and they are not the same feature:
///
///   * [BootSpec] is the VERBOSE boot: the scrolling `[  OK  ]` systemd spew,
///     six seconds of theatre, opt-in per theme because most people want their
///     phone, not a performance.
///   * [SplashSpec] is what everyone else gets: a logo, under a second, the
///     thing a real distro shows while it starts a session. Plymouth on Ubuntu,
///     the KDE progress bar, Arch's bare text.
///
/// Same rules as the rest of the theme layer: data not code, forward-compatible
/// parse, and a sane per-shell default so a theme that ships no `splash` block
/// still comes up looking like its family.
///
/// Deliberately NOT played on every home press. A launcher that flashes a logo
/// each time you hit HOME is a launcher people uninstall in a week — see
/// home_screen, which plays this on cold start and on a theme SWITCH only.
enum SplashStyle {
  /// Ubuntu/Plymouth: the logo, with a row of pulsing dots beneath it.
  dots,

  /// KDE: the logo over a thin determinate progress bar.
  bar,

  /// A quiet circular spinner under the logo. The generic desktop answer.
  spinner,

  /// Arch and friends: no logo, just the distro name in mono. A tiling WM does
  /// not have a splash screen, and pretending otherwise is less authentic than
  /// showing nothing pretty.
  text,

  /// No splash at all. The terminal shell boots INTO a terminal; a graphical
  /// splash in front of it would be a lie about what this theme is.
  none;

  static SplashStyle parse(String? raw) => switch (raw) {
        'dots' => SplashStyle.dots,
        'bar' => SplashStyle.bar,
        'spinner' => SplashStyle.spinner,
        'text' => SplashStyle.text,
        'none' => SplashStyle.none,
        // Unknown style from a newer CDN theme degrades to the safe middle
        // rather than throwing. Same contract as BootLineKind.parse.
        _ => SplashStyle.spinner,
      };
}

class SplashSpec {
  const SplashSpec({
    this.style = SplashStyle.spinner,
    this.logo,
    int durationMs = defaultDurationMs,
  }) : durationMs = durationMs < minDurationMs
            ? minDurationMs
            : (durationMs > maxDurationMs ? maxDurationMs : durationMs);

  /// Long enough to read as intentional, short enough not to be a tax on every
  /// theme switch. The plan's 800ms–1.5s, enforced rather than documented:
  /// a CDN theme cannot decide your desktop takes eight seconds to appear.
  static const int minDurationMs = 400;
  static const int defaultDurationMs = 900;
  static const int maxDurationMs = 1500;

  final SplashStyle style;

  /// Splash artwork. Null falls back to the theme's own [ThemeLogo] (dark
  /// variant, since a splash paints on the distro's dark base), and then to the
  /// style's logo-less rendering. A theme therefore gets a correct splash
  /// without authoring anything.
  final String? logo;

  /// Clamped by the constructor to [minDurationMs]..[maxDurationMs].
  final int durationMs;

  /// Forward-compatible parse. A theme with no `splash` block, or a malformed
  /// one, yields null and the caller falls back to [defaultForShell].
  static SplashSpec? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return SplashSpec(
      style: SplashStyle.parse(j['style'] as String?),
      logo: j['logo'] as String?,
      durationMs:
          (j['durationMs'] as num?)?.toInt() ?? defaultDurationMs,
    );
  }

  /// Built-in splashes keyed by SHELL, not by distro id — the same rule
  /// [BootSpec.defaultForShell] follows, and for the same reason: keying on
  /// `theme.id == 'fedora'` is exactly the trap ThemeSpec exists to avoid.
  static SplashSpec defaultForShell(ShellKind shell) => switch (shell) {
        // Plymouth: logo, pulsing dots underneath.
        ShellKind.gnome => const SplashSpec(style: SplashStyle.dots),
        // KDE's splash is a logo over a progress bar.
        ShellKind.plasma => const SplashSpec(style: SplashStyle.bar),
        // A tiling WM has no splash. Bare text is the honest version.
        ShellKind.tiling =>
          const SplashSpec(style: SplashStyle.text, durationMs: 600),
        // The terminal boots into a terminal.
        ShellKind.tui => const SplashSpec(style: SplashStyle.none),
        // A Mac boots to a mark over a thin determinate progress bar — the same
        // shape as KDE's, which is why `bar` already covers it. The MARK itself
        // is the theme's own logo, and the bundled Aqua theme deliberately
        // ships none (see its theme.json), so this renders logo-less.
        ShellKind.aqua => const SplashSpec(style: SplashStyle.bar),
      };

  @override
  bool operator ==(Object other) =>
      other is SplashSpec &&
      other.style == style &&
      other.logo == logo &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(style, logo, durationMs);
}
