/// The terminal's paint, resolved from the distro rather than from constants.
///
/// ─── WHY `Term` COULD NOT STAY ──────────────────────────────────────────────
///
/// `terminal_tokens.dart` holds `Term.bg`, `Term.green` and the rest as
/// compile-time constants, which the `const TextStyle(color: Term.green)` call
/// sites prove. Constants are the right shape for ONE terminal, and this shell
/// backs several: `tui_shell.dart`'s own comment says Kali is a terminal too.
/// While the paint is const, Kali's terminal and Ubuntu's terminal are the same
/// green on the same very dark green, and no amount of theme.json can move
/// them. That is the same class of thing as the hardcoded waybar module list.
///
/// So a role maps onto [ThemePalette] here, once, and every command file stays
/// unable to name a colour.
///
/// ─── WHAT IS DERIVED AND WHAT IS AUTHORED ───────────────────────────────────
///
/// Derived from the palette the distro already ships: background, foreground,
/// accent, and the four alpha steps between them. Nothing new to author, and
/// every existing distro gets a terminal in its own colours for free.
///
/// Authored, because a palette cannot carry it: the prompt shape, the logo, the
/// greeting and the hint line. Those are the fields that make Kali's
/// `┌──(george㉿kali)-[~]` different from Arch's `[george@arch ~]$`, and none of
/// them has a settings arm, so by the mechanical rule they are genuinely
/// exclusive rather than a preference wearing a distro's name.
library;

import 'package:flutter/widgets.dart';

import '../../../engine/effective_theme.dart';
import '../term_output.dart';

/// The per-distro block. Reads from `theme.json`, once [ThemeSpec] carries it.
///
/// Every field is nullable and every default reproduces WHAT THE TERMINAL LOOKS
/// LIKE TODAY, so a distro that authors nothing does not move. That is the same
/// contract the authored panel keeps in `tiling_shell.dart`, and the reason
/// shipping this is not a visual change for anyone.
@immutable
class TerminalSpec {
  const TerminalSpec({
    this.promptTop,
    this.prompt,
    this.logo,
    this.motd = const <String>[],
    this.hint,
    this.cursor = 'block',
  });

  /// The line ABOVE the input, for the two-line prompts. Null for one line.
  ///
  /// Tokens: `{user}`, `{host}`, `{cwd}`. Kali is
  /// `┌──({user}㉿{host})-[{cwd}]`, a starship prompt is
  /// `╭─ {user} ❯ {cwd}`.
  final String? promptTop;

  /// The line the caret sits on. Defaults to `{cwd} ❯`, which is exactly what
  /// the terminal prompts today.
  final String? prompt;

  /// ASCII art for the fetch header. Was a `static const _logo` inside
  /// `_FastfetchHeader`, which is why every distro had the same one.
  final String? logo;

  /// Up to a couple of lines, printed once per session above the first prompt.
  /// Where a distro gets to sound like itself.
  final List<String> motd;

  /// The rule line at the bottom. The ONLY discovery surface before the first
  /// keystroke, so a distro that says nothing here keeps the default rather
  /// than getting a blank rule.
  final String? hint;

  /// 'block' | 'bar' | 'underline'.
  final String cursor;

  static TerminalSpec fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TerminalSpec();
    final Object? motd = json['motd'];
    return TerminalSpec(
      promptTop: json['promptTop'] as String?,
      prompt: json['prompt'] as String?,
      logo: json['logo'] as String?,
      motd: motd is List
          ? <String>[for (final Object? line in motd) if (line is String) line]
          : const <String>[],
      hint: json['hint'] as String?,
      cursor: json['cursor'] as String? ?? 'block',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TerminalSpec &&
      other.promptTop == promptTop &&
      other.prompt == prompt &&
      other.logo == logo &&
      other.hint == hint &&
      other.cursor == cursor &&
      other.motd.length == motd.length;

  @override
  int get hashCode => Object.hash(promptTop, prompt, logo, hint, cursor, motd.length);
}

/// The default fetch logo.
///
/// Kept as the raw string, exactly as `_FastfetchHeader` kept it: an escaped
/// one is unreadable and someone will eventually "fix" the backslashes.
const String kDefaultTerminalLogo =
    '  .--.\n |o_o |\n |:_/ |\n//   \\ \\\n(|     | )\n/\'\\_   _/`\\\n\\___)=(___/';

/// The default hint. Six words, because nobody types a command they do not
/// know exists and `?` prints the rest.
const String kDefaultTerminalHint =
    'type to launch  \u00b7  enter opens the top match  \u00b7  ? for commands';

/// The one colour a palette does not carry.
///
/// A distro's palette has a background, a foreground and an accent. It has no
/// error colour, and deriving one from the accent gives a red distro a red
/// error indistinguishable from ordinary text. A single named token here is the
/// sanctioned place for that, the same way `terminal_tokens.dart` is for the
/// values it holds, and a distro can override it once `theme.json` carries the
/// block.
const Color kTerminalErrorInk = Color(0xFFE0685F);

/// Everything the view paints with.
@immutable
class TerminalSkin {
  const TerminalSkin({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.bar,
    required this.mono,
    required this.spec,
    required this.user,
    required this.host,
  });

  /// Resolve from the distro.
  ///
  /// [authored] is null today and stays null until `ThemeSpec` carries a
  /// `terminal` block. Passing it as a parameter rather than reading it off the
  /// spec is what lets this ship before that field exists without pretending
  /// the field is already there.
  factory TerminalSkin.from(
    EffectiveTheme theme, {
    TerminalSpec? authored,
    String? user,
    String? host,
  }) {
    final palette = theme.palette;
    return TerminalSkin(
      background: palette.bgTop,
      foreground: palette.onDark,
      accent: palette.accent,
      bar: palette.bar,
      mono: theme.typography.mono,
      spec: authored ?? const TerminalSpec(),
      user: user ?? 'user',
      host: host,
    );
  }

  final Color background;
  final Color foreground;
  final Color accent;
  final Color bar;

  /// The distro's mono family, already resolved through the user's override and
  /// through `FontRegistry`. Passed to every `TextStyle` rather than read from a
  /// constant, so a terminal distro with its own typeface is a data change.
  final String? mono;

  final TerminalSpec spec;
  final String user;
  final String? host;

  /// A ROLE to a colour. The only place in the shell where that mapping exists.
  Color ink(TermInk role) => switch (role) {
        TermInk.text => foreground,
        TermInk.key => accent,
        // Four alpha steps off the foreground rather than four authored greys.
        // A distro that ships one foreground gets a readable hierarchy without
        // authoring anything, and a light palette gets the same hierarchy the
        // other way up for free.
        TermInk.dim => foreground.withValues(alpha: 0.45),
        TermInk.accent => accent,
        TermInk.warn => accent,
        TermInk.bad => kTerminalErrorInk,
      };

  /// The selected-row wash and the hint rule, both off the foreground at the
  /// alphas `terminal_tokens.dart` arrived at.
  Color get selection => foreground.withValues(alpha: 0.13);
  Color get rule => foreground.withValues(alpha: 0.14);
  Color get muted => foreground.withValues(alpha: 0.62);

  double get fontSize => 13.5;
  double get lineHeight => 1.6;

  TextStyle style({
    TermInk role = TermInk.text,
    double? size,
    FontWeight? weight,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size ?? fontSize,
        height: lineHeight,
        fontWeight: weight,
        color: ink(role),
      );

  /// Fill `{user}`, `{host}` and `{cwd}` in a prompt template.
  String render(String template, String cwd) => template
      .replaceAll('{user}', user)
      .replaceAll('{host}', host ?? 'phone')
      .replaceAll('{cwd}', cwd);

  String get promptLine => spec.prompt ?? '{cwd} \u276F';
  String? get promptTopLine => spec.promptTop;
  String get logo => spec.logo ?? kDefaultTerminalLogo;
  String get hint => spec.hint ?? kDefaultTerminalHint;

  double get cursorWidth => spec.cursor == 'bar' ? 2 : 8;

  @override
  bool operator ==(Object other) =>
      other is TerminalSkin &&
      other.background == background &&
      other.foreground == foreground &&
      other.accent == accent &&
      other.bar == bar &&
      other.mono == mono &&
      other.spec == spec &&
      other.user == user &&
      other.host == host;

  @override
  int get hashCode =>
      Object.hash(background, foreground, accent, bar, mono, spec, user, host);
}
