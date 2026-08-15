/// The keys a phone keyboard does not have.
///
/// ─── WHY THIS EXISTS AT ALL ─────────────────────────────────────────────────
///
/// A software keyboard has no escape, no tab, no control and no arrows, and it
/// buries the pipe and the tilde two layers deep. Every one of those is
/// load-bearing in a shell. Without this row the terminal is a text field that
/// happens to be green, and the first thing anyone tries, tab completion, is
/// impossible.
///
/// ─── STATELESS ON PURPOSE ───────────────────────────────────────────────────
///
/// Control is a STICKY MODIFIER: press it, then press `c`, and what the session
/// receives is 0x03. That state belongs to the session, not to a row of
/// buttons, because the session is what has to clear it after the next key and
/// what has to know whether a physical keyboard is also attached. So this
/// widget is handed [ctrlActive] and reports intent; it decides nothing.
///
/// Painted from the TERMINAL palette rather than the chrome one. It is an
/// extension of the keyboard into the terminal, sitting on the terminal's own
/// background, and chrome colours here would put a settings-coloured strip
/// across the bottom of the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/terminal_spec.dart';

/// What a key press means.
///
/// A sealed pair rather than a raw string, because the two cases are handled
/// differently by every caller: text goes into the input buffer, a control
/// sequence goes straight to the session and never appears in the field.
sealed class TerminalKeyEvent {
  const TerminalKeyEvent();
}

/// Insert this text at the cursor.
class TerminalKeyText extends TerminalKeyEvent {
  const TerminalKeyText(this.text);
  final String text;
}

/// A named key with no printable form.
class TerminalKeySpecial extends TerminalKeyEvent {
  const TerminalKeySpecial(this.key);
  final TerminalSpecialKey key;
}

/// Toggle the sticky control modifier.
class TerminalKeyCtrl extends TerminalKeyEvent {
  const TerminalKeyCtrl();
}

enum TerminalSpecialKey { escape, tab, up, down, left, right, home, end }

class TerminalKeyRow extends StatelessWidget {
  const TerminalKeyRow({
    super.key,
    required this.palette,
    required this.onKey,
    this.ctrlActive = false,
    this.fontFamily,
  });

  final TerminalPalette palette;
  final ValueChanged<TerminalKeyEvent> onKey;

  /// Whether the sticky control modifier is armed. Owned by the session.
  final bool ctrlActive;

  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(top: BorderSide(color: palette.dim, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _key(context, label: 'esc',
                event: const TerminalKeySpecial(TerminalSpecialKey.escape)),
            _key(context, label: 'tab',
                event: const TerminalKeySpecial(TerminalSpecialKey.tab)),
            _key(context, label: 'ctrl',
                event: const TerminalKeyCtrl(), active: ctrlActive),
            _key(context, label: '|', event: const TerminalKeyText('|')),
            _key(context, label: '/', event: const TerminalKeyText('/')),
            _key(context, label: '-', event: const TerminalKeyText('-')),
            _key(context, label: '~', event: const TerminalKeyText('~')),
            // Kept together and last, where a thumb reaching from the bottom of
            // the screen finds them without scrolling the row.
            _key(context,
                icon: Icons.keyboard_arrow_up,
                event: const TerminalKeySpecial(TerminalSpecialKey.up)),
            _key(context,
                icon: Icons.keyboard_arrow_down,
                event: const TerminalKeySpecial(TerminalSpecialKey.down)),
            _key(context,
                icon: Icons.keyboard_arrow_left,
                event: const TerminalKeySpecial(TerminalSpecialKey.left)),
            _key(context,
                icon: Icons.keyboard_arrow_right,
                event: const TerminalKeySpecial(TerminalSpecialKey.right)),
          ],
        ),
      ),
    );
  }

  Widget _key(
    BuildContext context, {
    String? label,
    IconData? icon,
    required TerminalKeyEvent event,
    bool active = false,
  }) {
    // The armed modifier is filled rather than outlined, so its state is
    // readable in the half second before the next key rather than requiring the
    // user to remember whether they pressed it.
    final fg = active ? palette.bg : palette.fg;
    final bg = active ? palette.ansi[3] : palette.fg.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(event);
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 36),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 6 : 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: palette.fg.withValues(alpha: 0.10)),
          ),
          child: icon != null
              ? Icon(icon, size: 17, color: fg)
              : Text(
                  label!,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 12.5,
                    color: fg,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The bytes a special key sends.
///
/// Kept beside the widget because they are the other half of what a key press
/// means, and separating an enum from its wire encoding is how the two end up
/// disagreeing.
String bytesForSpecial(TerminalSpecialKey key) => switch (key) {
      TerminalSpecialKey.escape => '\x1b',
      TerminalSpecialKey.tab => '\t',
      // The CSI forms, which is what a shell in its default mode expects. The
      // SS3 spelling (`ESC O A`) is what an application-mode program asks for,
      // and switching between them needs the mode tracking a full emulator has.
      TerminalSpecialKey.up => '\x1b[A',
      TerminalSpecialKey.down => '\x1b[B',
      TerminalSpecialKey.right => '\x1b[C',
      TerminalSpecialKey.left => '\x1b[D',
      TerminalSpecialKey.home => '\x1b[H',
      TerminalSpecialKey.end => '\x1b[F',
    };

/// The byte a control chord sends, or null when the pairing is meaningless.
///
/// Control maps the letters onto 0x01 to 0x1a, which is why ctrl-c is 0x03 and
/// ctrl-d is 0x04. Anything outside that and the handful of punctuation chords
/// returns null, and the caller should send the plain character rather than
/// inventing a byte: a terminal that turns ctrl-9 into something is a terminal
/// that will one day send the wrong thing to a production host.
String? ctrlChord(String char) {
  if (char.isEmpty) return null;
  final c = char.toLowerCase().codeUnitAt(0);

  if (c >= 0x61 && c <= 0x7a) return String.fromCharCode(c - 0x60);

  return switch (char) {
    '@' => '\x00',
    '[' => '\x1b',
    '\\' => '\x1c',
    ']' => '\x1d',
    '^' => '\x1e',
    '_' => '\x1f',
    ' ' => '\x00',
    _ => null,
  };
}
