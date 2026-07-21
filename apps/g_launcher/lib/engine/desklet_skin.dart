import 'theme_spec.dart' show ShellKind;

/// How a distro draws a desklet. PHASE D3.
///
/// The middle layer of the three-layer bet, and the one that has to earn its
/// keep: KIND is code, PLACEMENT is the user's, and everything between them,
/// what the thing actually looks like, is this, and it is data.
///
/// There is exactly ONE clock in the codebase. Ubuntu draws it as a big bare
/// GNOME desktop clock, KDE as a Breeze card, Arch as a waybar module, Aqua as
/// a thin Dashboard face, and the terminal as `date` output. None of those is a
/// branch in the clock widget; all of them are a [DeskletSkin]. Adding Kali
/// costs zero Dart.
///
/// ─── DEFAULTS ARE KEYED BY SHELL, NOT BY THEME ID ───────────────────────────
///
/// The same rule [BootSpec.defaultForShell] and [SplashSpec.defaultForShell]
/// already follow. Keying on `theme.id == 'fedora'` is precisely the trap the
/// whole theme layer exists to avoid: Fedora is a GNOME desktop, so it should
/// inherit GNOME's answer without authoring anything, and override only where
/// it genuinely differs.
enum DeskletSurface {
  /// No chrome at all. Text sits directly on the wallpaper, carrying a soft
  /// shadow so it stays readable over a light photo. The GNOME and macOS
  /// desktop-widget look.
  bare,

  /// A translucent rounded card with a hairline border. Breeze, and Adwaita's
  /// own dialogs.
  card,

  /// A flat, tight, square-cornered block with an accent edge. A waybar or
  /// polybar module lifted onto the desktop.
  panel,

  /// Monospace command output with a prompt line above it. Only coherent on the
  /// pane surface, where a desklet IS a command that stayed on screen.
  terminal;

  static DeskletSurface parse(String? raw) => switch (raw) {
        'bare' => DeskletSurface.bare,
        'card' => DeskletSurface.card,
        'panel' => DeskletSurface.panel,
        'terminal' => DeskletSurface.terminal,
        // Unknown surface from a newer CDN theme degrades to the safest thing
        // that renders on any background. Same contract as SplashStyle.parse.
        _ => DeskletSurface.card,
      };
}

/// Which of the theme's two families a desklet writes in. An enum rather than a
/// family STRING because a desklet must never name a typeface: the theme owns
/// that, and `no_constants.sh` polices it.
enum DeskletFont {
  display,
  mono;

  static DeskletFont parse(String? raw) =>
      raw == 'mono' ? DeskletFont.mono : DeskletFont.display;
}

/// ─── AUTHORED VERSUS EFFECTIVE, AND WHY THE FIELDS ARE PRIVATE ──────────────
///
/// This class stores what a theme ACTUALLY WROTE and exposes what should be
/// DRAWN. The two are different, and collapsing them was a real bug.
///
/// Before this split, `surface`, `font` and `accent` were non-nullable with
/// defaults, so [fromJson] filled in `card` and `display` for keys the theme had
/// never written, and [mergedWith] then copied those invented values over the
/// shell default. The result: a theme that wrote `{"timeSize": 72}` to get a
/// bigger clock ALSO silently turned GNOME's bare clock into a card, because the
/// parse had manufactured a `surface` out of nothing.
///
/// That is the worst possible shape for a data layer to fail in. The theme looks
/// correctly authored, the app does not crash, and the distro just quietly stops
/// looking like itself. Nothing in the JSON is wrong, so nothing in the JSON
/// suggests where to look.
///
/// So the three scalars are nullable behind getters. Null means "the theme said
/// nothing here", which is exactly what [mergedWith] needs in order to inherit.
class DeskletSkin {
  /// The named parameters stay PUBLIC (`surface:`, `font:`, `accent:`) so every
  /// existing call site is unchanged; the initialisers put them in the private
  /// nullable fields. A named parameter cannot begin with an underscore, which
  /// is why this is an initialiser list rather than `this._surface`.
  const DeskletSkin({
    DeskletSurface? surface,
    DeskletFont? font,
    bool? accent,
    this.props = const {},
  })  : _surface = surface,
        _font = font,
        _accent = accent;

  final DeskletSurface? _surface;
  final DeskletFont? _font;
  final bool? _accent;

  /// What to DRAW. The fallbacks here are the same values the non-nullable
  /// fields used to default to, so a skin with nothing authored renders exactly
  /// as it did before.
  DeskletSurface get surface => _surface ?? DeskletSurface.card;

  DeskletFont get font => _font ?? DeskletFont.display;

  /// Paint the primary value in the distro's accent rather than [onDark].
  bool get accent => _accent ?? false;

  /// Did the theme author this key at all? Only [mergedWith] should care.
  bool get hasSurface => _surface != null;
  bool get hasFont => _font != null;
  bool get hasAccent => _accent != null;

  /// Kind-specific skin values: sizes, weights, whether the date shows.
  ///
  /// FREE-FORM, and validated on READ by [num_]/[flag]/[text] below rather than
  /// on write, the same rule `Desklet.config`, `SplashSpec.durationMs` and
  /// `IconSizing.parseScale` all follow. A theme authored against a newer build
  /// carries keys this one ignores; a key of the wrong type falls back instead
  /// of throwing. A desktop must not fail to draw because somebody typed a
  /// string where a number belonged.
  final Map<String, Object?> props;

  double num_(String key, double fallback) {
    final v = props[key];
    return v is num ? v.toDouble() : fallback;
  }

  bool flag(String key, bool fallback) {
    final v = props[key];
    return v is bool ? v : fallback;
  }

  String text(String key, String fallback) {
    final v = props[key];
    return v is String ? v : fallback;
  }

  /// Parse a theme's `skins` entry.
  ///
  /// `containsKey` rather than a null check on the value, deliberately: an
  /// explicit `"surface": null` in JSON is indistinguishable from an absent key
  /// as far as inheritance goes, and both should inherit. Reading the key's
  /// PRESENCE is what keeps a partial override partial.
  static DeskletSkin fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DeskletSkin();
    return DeskletSkin(
      surface: j.containsKey('surface')
          ? DeskletSurface.parse(j['surface'] as String?)
          : null,
      font: j.containsKey('font')
          ? DeskletFont.parse(j['font'] as String?)
          : null,
      accent: j['accent'] as bool?,
      props: {
        for (final e in j.entries)
          if (e.key != 'surface' && e.key != 'font' && e.key != 'accent')
            e.key: e.value,
      },
    );
  }

  /// Merge a theme's partial override over a default.
  ///
  /// PARTIAL IS THE POINT, and it now applies to every field rather than to
  /// `props` alone. A theme that wants only a bigger clock writes
  /// `{"timeSize": 72}` and inherits its shell's surface, font, accent and every
  /// other prop. Wholesale replacement would force every theme to restate the
  /// entire skin to change one number, which is how a data layer quietly becomes
  /// a copy-paste layer.
  ///
  /// Reads the private fields on both sides, so an unauthored key on the
  /// override falls through to this skin instead of overwriting it with a
  /// manufactured default. That single `??` per scalar is the whole fix.
  DeskletSkin mergedWith(DeskletSkin? override) {
    if (override == null) return this;
    return DeskletSkin(
      surface: override._surface ?? _surface,
      font: override._font ?? _font,
      accent: override._accent ?? _accent,
      props: {...props, ...override.props},
    );
  }

  /// The built-in look for one kind on one shell family.
  ///
  /// Five genuinely different clocks, and this switch is the whole proof of the
  /// skin layer. If these five do not read as five different desktops, the bet
  /// is wrong and no amount of theme.json will save it.
  ///
  /// Every skin here authors its surface explicitly. That is not redundant now
  /// that the fields are nullable: these ARE the authored defaults a partial
  /// theme override inherits from, so leaving one null would push the fallback
  /// decision down to the getter and make `card` the silent answer for a
  /// desktop that wanted `bare`.
  static DeskletSkin defaultFor(ShellKind shell, String kindId) {
    if (kindId != 'clock') return _genericFor(shell);

    return switch (shell) {
      // GNOME's desktop clock: enormous, hairline weight, no box, date beneath.
      ShellKind.gnome => const DeskletSkin(
          surface: DeskletSurface.bare,
          font: DeskletFont.display,
          accent: false,
          props: {
            'timeSize': 56.0,
            'timeWeight': 200.0,
            'dateSize': 13.0,
            'showDate': true,
            'letterSpacing': -2.0,
          },
        ),
      // Breeze: a translucent card, medium weight, date on the same footing.
      ShellKind.plasma => const DeskletSkin(
          surface: DeskletSurface.card,
          font: DeskletFont.display,
          accent: false,
          props: {
            'timeSize': 34.0,
            'timeWeight': 500.0,
            'dateSize': 12.0,
            'showDate': true,
          },
        ),
      // A waybar module that happens to sit on the desktop: mono, small, tight,
      // accent edge, and the date collapsed into the same line.
      ShellKind.tiling => const DeskletSkin(
          surface: DeskletSurface.panel,
          font: DeskletFont.mono,
          accent: true,
          props: {
            'timeSize': 18.0,
            'timeWeight': 700.0,
            'dateSize': 11.0,
            'showDate': true,
            'inline': true,
          },
        ),
      // Aqua: thin, quiet, no box, date above the time in small caps, the
      // Dashboard face rather than a widget with a border.
      ShellKind.aqua => const DeskletSkin(
          surface: DeskletSurface.bare,
          font: DeskletFont.display,
          accent: false,
          props: {
            'timeSize': 44.0,
            'timeWeight': 100.0,
            'dateSize': 11.0,
            'showDate': true,
            'dateAbove': true,
            'letterSpacing': -1.0,
          },
        ),
      // `date` and its output. Not a clock widget at all.
      ShellKind.tui => const DeskletSkin(
          surface: DeskletSurface.terminal,
          font: DeskletFont.mono,
          accent: false,
          props: {
            'timeSize': 13.0,
            'command': 'date',
            'showDate': true,
          },
        ),
    };
  }

  static DeskletSkin _genericFor(ShellKind shell) => switch (shell) {
        ShellKind.gnome => const DeskletSkin(
            surface: DeskletSurface.bare,
            font: DeskletFont.display,
            accent: false,
          ),
        ShellKind.plasma => const DeskletSkin(
            surface: DeskletSurface.card,
            font: DeskletFont.display,
            accent: false,
          ),
        ShellKind.tiling => const DeskletSkin(
            surface: DeskletSurface.panel,
            font: DeskletFont.mono,
            accent: false,
          ),
        ShellKind.aqua => const DeskletSkin(
            surface: DeskletSurface.bare,
            font: DeskletFont.display,
            accent: false,
          ),
        ShellKind.tui => const DeskletSkin(
            surface: DeskletSurface.terminal,
            font: DeskletFont.mono,
            accent: false,
          ),
      };
}

/// A theme's whole `desklets` block.
class DeskletThemeBlock {
  const DeskletThemeBlock({
    this.offers = const [],
    this.starter = const [],
    this.skins = const {},
  });

  /// Kind ids this distro exposes in the picker, in picker order.
  ///
  /// Empty means "this theme has not authored a list", NOT "offer nothing".
  /// See [offersOr], which falls back to the shipping set so a theme that
  /// predates this block is not left with an empty picker.
  final List<String> offers;

  /// The desktop this distro lays out for you the first time you choose it.
  ///
  /// Authored placements, applied ONCE per theme and never again. This is why
  /// picking Arch gives you a waybar-ish desktop instead of an empty screen,
  /// and it is remote-safe: a starter desktop only ever touches a theme the
  /// user has not used yet, so it can never rearrange something they arranged.
  final List<StarterDesklet> starter;

  /// Per-kind overrides, merged over [DeskletSkin.defaultFor].
  final Map<String, DeskletSkin> skins;

  List<String> offersOr(List<String> fallback) =>
      offers.isEmpty ? fallback : offers;

  DeskletSkin skinFor(ShellKind shell, String kindId) =>
      DeskletSkin.defaultFor(shell, kindId).mergedWith(skins[kindId]);

  static DeskletThemeBlock fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DeskletThemeBlock();
    return DeskletThemeBlock(
      offers: ((j['offers'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      starter: ((j['starter'] as List?) ?? const [])
          .map((e) => StarterDesklet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      skins: {
        for (final e in ((j['skins'] as Map?) ?? const {}).entries)
          e.key.toString(): DeskletSkin.fromJson(
            (e.value as Map?)?.cast<String, dynamic>(),
          ),
      },
    );
  }
}

/// One authored placement in a starter desktop.
///
/// Deliberately NOT a `Desklet`: it has no id, because ids are minted when the
/// placement is applied. Reusing the stored type would mean a theme.json
/// carrying ids, and two users who both install the same pack would share them.
class StarterDesklet {
  const StarterDesklet({
    required this.kind,
    this.page = 0,
    this.col,
    this.row,
    this.spanX,
    this.spanY,
    this.config = const {},
  });

  final String kind;
  final int page;

  /// Null means "wherever it fits". An authored desktop usually wants an exact
  /// cell, but a theme that only cares about WHICH desklets appear can omit
  /// the position and let the packer place them.
  final int? col;
  final int? row;
  final int? spanX;
  final int? spanY;

  final Map<String, Object?> config;

  static StarterDesklet fromJson(Map<String, dynamic> j) => StarterDesklet(
        kind: j['kind'] as String,
        page: (j['page'] as num?)?.toInt() ?? 0,
        col: (j['col'] as num?)?.toInt(),
        row: (j['row'] as num?)?.toInt(),
        spanX: (j['spanX'] as num?)?.toInt(),
        spanY: (j['spanY'] as num?)?.toInt(),
        config: ((j['config'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v as Object?)),
      );
}
