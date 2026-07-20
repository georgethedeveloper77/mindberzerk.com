import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/effective_theme.dart';

/// Tone of a transient message. Maps to an accent colour, nothing else — the
/// card shape, the logo and the layout never change.
enum MessageTone { neutral, success, warning, danger }

/// Everything the branded message card needs in order to paint itself.
///
/// This type exists so `branded_message.dart` never imports `EffectiveTheme`
/// directly. There is exactly ONE place in the app that knows how to turn a
/// theme into a message skin, and it is [messageSkinProvider] below.
@immutable
class MessageSkin {
  const MessageSkin({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.uiFamily,
  });

  final Color background;
  final Color foreground;
  final Color accent;

  /// Family name as declared in pubspec.yaml — 'Ubuntu' for the GNOME shells,
  /// 'UbuntuMono' for the terminal shell. Null falls back to Roboto.
  final String? uiFamily;

  Color accentFor(MessageTone tone) => switch (tone) {
        MessageTone.neutral => accent,
        MessageTone.success => const Color(0xFF4CAF7D),
        MessageTone.warning => const Color(0xFFE8B84B),
        MessageTone.danger => const Color(0xFFE0553F),
      };

  // Value equality so `messageSkinProvider`'s `.select` only fires the overlay
  // rebuild when a colour or the font actually changes, not on every theme tick.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageSkin &&
          other.background == background &&
          other.foreground == foreground &&
          other.accent == accent &&
          other.uiFamily == uiFamily;

  @override
  int get hashCode => Object.hash(background, foreground, accent, uiFamily);

  /// Ubuntu 24.04 values. Used until the provider below is bound to the real
  /// theme, and as the fallback if the theme fails to resolve.
  static const fallback = MessageSkin(
    background: Color(0xFF2C2622),
    foreground: Color(0xFFF6F1EE),
    accent: Color(0xFFE95420), // Ubuntu orange
    uiFamily: 'Ubuntu',
  );
}

/// Bound to the live theme, so a toast wears the distro it belongs to: Ubuntu's
/// orange on aubergine chrome, Fedora's blue on Adwaita grey, the terminal's
/// accent on near-black. Whatever theme is active, its toast matches.
///
/// It reads EffectiveTheme (never ThemeSpec) so a user's palette override
/// reaches toasts too, per §6 of the handoff. The `.select` collapses the theme
/// to just the four fields the card paints, and MessageSkin's value equality
/// means an unrelated prefs tick (grid size, gestures) does not rebuild the
/// overlay. Falls back to Ubuntu while the theme is still resolving, or if it
/// fails to load.
///
/// Field mapping to the real ThemePalette / ThemeTypography:
///   background <- palette.bar     (the shell's chrome fill; a toast is chrome)
///   foreground <- palette.onDark  (the theme's on-dark text colour)
///   accent     <- palette.accent  (neutral tone only; semantic tones are fixed)
///   uiFamily   <- typography.display
final messageSkinProvider = Provider<MessageSkin>((ref) {
  return ref.watch(
    effectiveThemeProvider.select((async) {
      final theme = async.asData?.value;
      if (theme == null) return MessageSkin.fallback;
      return MessageSkin(
        background: theme.palette.bar,
        foreground: theme.palette.onDark,
        accent: theme.palette.accent,
        uiFamily: theme.typography.display,
      );
    }),
  );
});
