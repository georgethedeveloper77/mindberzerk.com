/// A distro's terminal identity, expressed as data. [BootSpec]'s sibling.
///
/// ─── WHY THE SIX-COLOUR PALETTE IS NOT ENOUGH ───────────────────────────────
///
/// [ThemePalette] carries bgTop, bgBottom, bar, dock, accent and onDark. None of
/// them is an ANSI colour, and a terminal needs sixteen of those before it can
/// draw anything a shell emits. Deriving them from six is possible and it is the
/// wrong trade: what comes out is technically a palette and looks like nothing
/// any of these distros ships, which is the same argument `paletteLight` already
/// makes for not inverting six colours algorithmically.
///
/// So this block is ADDITIVE and OPTIONAL, exactly like `boot` and `splash`. A
/// theme.json that predates it keeps parsing, and the shell family default fills
/// in. Kali is `shell: gnome` and can therefore have a terminal without becoming
/// a terminal.
///
/// ─── ROLE COLOURS ARE DERIVED, NOT AUTHORED ─────────────────────────────────
///
/// An earlier draft had the author name ok, warn, err and dim beside the
/// sixteen. That is four more chances to disagree with the palette they sit
/// next to, for no expressive power: in every real terminal green IS success and
/// red IS failure, because that is what the program emitting the escape code
/// means. So [ok], [warn], [err] and [dim] read out of [ansi] and cannot drift
/// from it.
///
/// ─── ALIASES ARE BINDINGS, NEVER SHELL ──────────────────────────────────────
///
/// A pack that could ship executable commands would be remote code execution on
/// a home screen, arriving over the CDN. An alias names a [CommandAction] that
/// already exists in this build and nothing else. Unknown ids degrade to null
/// here, matching every other parse in the theme layer, and are a hard failure
/// in `validate_themes.sh`, which runs strictly and only over themes we wrote.
///
/// Hand-rolled fromJson, no codegen, same as ThemeSpec.
library;

import 'dart:ui';

import 'package:collection/collection.dart';

import 'theme_spec.dart' show ShellKind, parseColor;

/// One name bound to one action.
///
/// A DUMB CARRIER, deliberately. [actionId] is not screened here, for the same
/// reason `ThemeSpec.gestures` does not screen its action ids: the enum lives in
/// the feature layer, and the engine importing a feature to validate a string
/// would invert the dependency for no gain. The registry screens it beside the
/// enum when it binds, and `validate_themes.sh` screens it strictly over the
/// themes we wrote, which is where a typo should be caught anyway.
class TerminalAlias {
  const TerminalAlias({
    required this.name,
    required this.actionId,
    this.args = const {},
    this.summary,
  });

  /// What the user types. Lowercased on parse, since a terminal that is
  /// case-sensitive about `Tile` is a terminal that looks broken.
  final String name;

  /// The wire name of a `CommandAction`, for example `launcher.openThemes`.
  /// An id this build does not know resolves to nothing at bind time and the
  /// alias simply does not appear, which is the same degradation an unknown
  /// `BootLineKind` gets.
  final String actionId;

  /// Arguments bound at author time. Scalars only, because a nested structure
  /// here would be a small language, and a small language in a downloadable
  /// pack is how this stops being data.
  final Map<String, Object?> args;

  /// One line for the match list. Falls back to the bound command's own
  /// description at render time when absent.
  final String? summary;

  /// Null when the row is unusable: no name, or no action id at all.
  static TerminalAlias? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim().toLowerCase();
    if (name == null || name.isEmpty) return null;

    final actionId = (j['action'] as String?)?.trim();
    if (actionId == null || actionId.isEmpty) return null;

    final rawArgs = j['args'];
    return TerminalAlias(
      name: name,
      actionId: actionId,
      args: rawArgs is Map
          ? {
              for (final e in rawArgs.entries)
                if (e.key is String &&
                    (e.value is String || e.value is num || e.value is bool))
                  e.key as String: e.value,
            }
          : const {},
      summary: j['summary'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalAlias &&
          other.name == name &&
          other.actionId == actionId &&
          other.summary == summary &&
          const MapEquality<String, Object?>().equals(other.args, args);

  @override
  int get hashCode => Object.hash(
        name,
        actionId,
        summary,
        const MapEquality<String, Object?>().hash(args),
      );
}

/// The sixteen, plus the four surfaces a terminal paints that are not text.
class TerminalPalette {
  /// SIXTEEN COLOURS IN [ansi]. That is not assertable here and the attempt is
  /// worth recording: `assert(ansi.length == 16)` compiles and then fails const
  /// evaluation, because Dart cannot read `.length` off a List in a constant
  /// expression, so every `const TerminalPalette` in [TerminalSpec.defaultForShell]
  /// stops compiling.
  ///
  /// It is enforced in the two places a palette can actually come from instead:
  /// [fromJson] refuses anything that is not exactly sixteen, and a test walks
  /// every shell default. [_slot] is the belt to that braces, so a palette built
  /// by hand with a short list degrades to the foreground rather than throwing a
  /// range error mid-paint.
  const TerminalPalette({
    required this.bg,
    required this.fg,
    required this.ansi,
    Color? cursor,
    Color? selection,
  })  : _cursor = cursor,
        _selection = selection;

  final Color bg;
  final Color fg;

  /// Standard order: black, red, green, yellow, blue, magenta, cyan, white,
  /// then the eight bright variants. Index IS the SGR code offset, which is why
  /// the order is not a style choice.
  final List<Color> ansi;

  final Color? _cursor;
  final Color? _selection;

  /// Read one ANSI slot, falling back to the foreground when the list is short.
  ///
  /// A short list cannot come from [fromJson], which refuses it outright. This
  /// covers a palette constructed in code, where the alternative is a range
  /// error thrown out of a paint callback.
  Color _slot(int i) => i < ansi.length ? ansi[i] : fg;

  /// Falls back to bright green, the colour a block cursor has had since VT100.
  Color get cursor => _cursor ?? _slot(10);

  /// Falls back to the foreground at low alpha, which is what a terminal that
  /// ships no selection colour actually does.
  Color get selection => _selection ?? fg.withValues(alpha: 0.20);

  /// Semantic reads. DERIVED, never authored: see the class doc.
  Color get ok => _slot(2);
  Color get warn => _slot(3);
  Color get err => _slot(1);
  Color get dim => _slot(8);

  /// Null when the block is absent or does not carry sixteen colours.
  ///
  /// A short or malformed `ansi` array is NOT padded. Padding produces a
  /// terminal where some escape codes land on a colour nobody chose, which
  /// looks like a rendering bug rather than an authoring one. Falling back to
  /// the whole shell default is louder and easier to trace.
  static TerminalPalette? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;

    final raw = j['ansi'];
    if (raw is! List || raw.length != 16) return null;

    final ansi = <Color>[];
    for (final e in raw) {
      final c = parseColor(e is String ? e : null);
      if (c == null) return null;
      ansi.add(c);
    }

    final bg = parseColor(j['bg'] as String?);
    final fg = parseColor(j['fg'] as String?);
    if (bg == null || fg == null) return null;

    return TerminalPalette(
      bg: bg,
      fg: fg,
      ansi: ansi,
      cursor: parseColor(j['cursor'] as String?),
      selection: parseColor(j['selection'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalPalette &&
          other.bg == bg &&
          other.fg == fg &&
          other._cursor == _cursor &&
          other._selection == _selection &&
          const ListEquality<Color>().equals(other.ansi, ansi);

  @override
  int get hashCode => Object.hash(
        bg,
        fg,
        _cursor,
        _selection,
        const ListEquality<Color>().hash(ansi),
      );
}

/// The terminal block for one theme.
class TerminalSpec {
  const TerminalSpec({
    required this.appLabel,
    required this.palette,
    this.prompt = defaultPrompt,
    this.aliases = const [],
    int scrollbackLines = defaultScrollback,
  }) : scrollbackLines = scrollbackLines < minScrollback
            ? minScrollback
            : (scrollbackLines > maxScrollback
                ? maxScrollback
                : scrollbackLines);

  /// Enforced rather than documented, the same way [SplashSpec] clamps its
  /// duration: a CDN theme cannot decide your phone holds fifty thousand lines
  /// of scrollback in memory.
  static const int minScrollback = 500;
  static const int defaultScrollback = 5000;
  static const int maxScrollback = 50000;

  static const String defaultPrompt = '{user}@{host}:{cwd}\$ ';

  /// The drawer entry's label.
  ///
  /// SHORT, because the drawer renders it in list, grid, cube and horizontal
  /// layouts and the narrowest of those gives it one line under an icon.
  /// "Dr460nized Terminal" already tests that; anything longer ellipsises.
  final String appLabel;

  final TerminalPalette palette;

  /// Prompt template. Tokens: `{user}` `{host}` `{cwd}` `{distro}` `{exit}`.
  ///
  /// An unknown token renders LITERALLY rather than being stripped. A prompt
  /// reading `{colour}` is an authoring mistake someone can see and fix; a
  /// prompt silently missing a segment is one they cannot.
  final String prompt;

  final List<TerminalAlias> aliases;

  final int scrollbackLines;

  /// Forward-compatible parse. Absent or malformed yields null and the caller
  /// falls back to [defaultForShell].
  ///
  /// The PALETTE is what makes or breaks the block: without sixteen usable
  /// colours there is no terminal to draw, so a bad palette fails the whole
  /// block rather than leaving a half-built one. A bad ALIAS drops only itself,
  /// because the other nine are still perfectly good.
  static TerminalSpec? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;

    final palette = TerminalPalette.fromJson(
      (j['palette'] as Map?)?.cast<String, dynamic>(),
    );
    if (palette == null) return null;

    final label = (j['appLabel'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;

    final rawAliases = (j['aliases'] as List?) ?? const [];
    final aliases = <TerminalAlias>[];
    final seen = <String>{};
    for (final entry in rawAliases) {
      if (entry is! Map) continue;
      final a = TerminalAlias.fromJson(entry.cast<String, dynamic>());
      if (a == null) continue;
      // First declaration wins, so a pack cannot redefine its own alias halfway
      // down the list and leave which one applies depending on parse order.
      if (!seen.add(a.name)) continue;
      aliases.add(a);
    }

    final prompt = (j['prompt'] as String?);
    return TerminalSpec(
      appLabel: label,
      palette: palette,
      prompt: prompt == null || prompt.isEmpty ? defaultPrompt : prompt,
      aliases: aliases,
      scrollbackLines:
          (j['scrollbackLines'] as num?)?.toInt() ?? defaultScrollback,
    );
  }

  /// Built-in terminals keyed by SHELL, not by distro id.
  ///
  /// Same rule [BootSpec.defaultForShell] and [SplashSpec.defaultForShell]
  /// follow, and for the same reason: switching on `theme.id == 'kali-2024'` is
  /// the trap ThemeSpec exists to avoid. Per-distro flavour is the `terminal`
  /// block's job; this is the family default a theme gets for free.
  ///
  /// Every one of these is a real, recognisable scheme rather than a tint of
  /// the distro accent, because a terminal palette that was generated reads as
  /// generated to exactly the people who install a Linux launcher.
  static TerminalSpec defaultForShell(ShellKind shell) => switch (shell) {
        // Tango, which is what gnome-terminal has shipped for twenty years.
        ShellKind.gnome => const TerminalSpec(
            appLabel: 'Terminal',
            palette: TerminalPalette(
              bg: Color(0xFF2C0A21),
              fg: Color(0xFFEEEEEC),
              ansi: [
                Color(0xFF2E3436), Color(0xFFCC0000), Color(0xFF4E9A06),
                Color(0xFFC4A000), Color(0xFF3465A4), Color(0xFF75507B),
                Color(0xFF06989A), Color(0xFFD3D7CF), Color(0xFF555753),
                Color(0xFFEF2929), Color(0xFF8AE234), Color(0xFFFCE94F),
                Color(0xFF729FCF), Color(0xFFAD7FA8), Color(0xFF34E2E2),
                Color(0xFFEEEEEC),
              ],
            ),
          ),

        // Breeze, Konsole's default.
        ShellKind.plasma => const TerminalSpec(
            appLabel: 'Konsole',
            palette: TerminalPalette(
              bg: Color(0xFF232629),
              fg: Color(0xFFFCFCFC),
              ansi: [
                Color(0xFF232629), Color(0xFFED1515), Color(0xFF11D116),
                Color(0xFFF67400), Color(0xFF1D99F3), Color(0xFF9B59B6),
                Color(0xFF1ABC9C), Color(0xFFFCFCFC), Color(0xFF7F8C8D),
                Color(0xFFC0392B), Color(0xFF1CDC9A), Color(0xFFFDBC4B),
                Color(0xFF3DAEE9), Color(0xFF8E44AD), Color(0xFF16A085),
                Color(0xFFFFFFFF),
              ],
            ),
          ),

        // A tiling WM user picked their own scheme and it is usually this one.
        ShellKind.tiling => const TerminalSpec(
            appLabel: 'Terminal',
            palette: TerminalPalette(
              bg: Color(0xFF1D1F21),
              fg: Color(0xFFC5C8C6),
              ansi: [
                Color(0xFF1D1F21), Color(0xFFCC6666), Color(0xFFB5BD68),
                Color(0xFFF0C674), Color(0xFF81A2BE), Color(0xFFB294BB),
                Color(0xFF8ABEB7), Color(0xFFC5C8C6), Color(0xFF969896),
                Color(0xFFCC6666), Color(0xFFB5BD68), Color(0xFFF0C674),
                Color(0xFF81A2BE), Color(0xFFB294BB), Color(0xFF8ABEB7),
                Color(0xFFFFFFFF),
              ],
            ),
          ),

        // The TUI shell's own greens, from terminal_tokens. The background is
        // NOT black: it is a very dark desaturated green, and that five-point
        // shift is most of why the screen reads as a terminal rather than as a
        // dark-mode app.
        ShellKind.tui => const TerminalSpec(
            appLabel: 'Terminal',
            prompt: '~ \u276f ',
            palette: TerminalPalette(
              bg: Color(0xFF080D08),
              fg: Color(0xFF52F088),
              cursor: Color(0xFF52F088),
              selection: Color(0x2152F088),
              ansi: [
                Color(0xFF0A140A), Color(0xFFE85C5C), Color(0xFF52F088),
                Color(0xFFE8B84B), Color(0xFF5C9CE8), Color(0xFFA98CE8),
                Color(0xFF4BD6C0), Color(0xFFC8D8C8), Color(0xFF2E7A48),
                Color(0xFFFF7A7A), Color(0xFF7DF5A8), Color(0xFFFFD166),
                Color(0xFF82B8F5), Color(0xFFC6AEF5), Color(0xFF7FE8DC),
                Color(0xFFEAF5EA),
              ],
            ),
          ),

        // Terminal.app's Basic scheme: black on white, and the one default in
        // this list that is not a dark theme. Inverting it to match the others
        // would be the same lie as a graphical splash in front of the TUI.
        ShellKind.aqua => const TerminalSpec(
            appLabel: 'Terminal',
            palette: TerminalPalette(
              bg: Color(0xFFFFFFFF),
              fg: Color(0xFF000000),
              cursor: Color(0xFF000000),
              ansi: [
                Color(0xFF000000), Color(0xFFC23621), Color(0xFF25BC24),
                Color(0xFFADAD27), Color(0xFF492EE1), Color(0xFFD338D3),
                Color(0xFF33BBC8), Color(0xFFCBCCCD), Color(0xFF818383),
                Color(0xFFFC391F), Color(0xFF31E722), Color(0xFFEAEC23),
                Color(0xFF5833FF), Color(0xFFF935F8), Color(0xFF14F0F0),
                Color(0xFFE9EBEB),
              ],
            ),
          ),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalSpec &&
          other.appLabel == appLabel &&
          other.prompt == prompt &&
          other.scrollbackLines == scrollbackLines &&
          other.palette == palette &&
          const ListEquality<TerminalAlias>().equals(other.aliases, aliases);

  @override
  int get hashCode => Object.hash(
        appLabel,
        prompt,
        scrollbackLines,
        palette,
        const ListEquality<TerminalAlias>().hash(aliases),
      );
}
