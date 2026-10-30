/// The commands a Linux user types first to see whether a terminal is real.
///
/// cowsay, sl, fortune, cmatrix, yes, and the two jokes every shell owes its
/// users. Pure functions from arguments to ANSI lines, so the Terminal app
/// prints them and tests pin them, and nothing here can touch the launcher.
///
/// Every piece of art and every fortune here is original to G Launcher.
library;

import 'dart:math' as math;

abstract final class FunCommands {
  static const _dim = '\x1b[90m';
  static const _green = '\x1b[32m';
  static const _bold = '\x1b[1m';
  static const _reset = '\x1b[0m';

  /// `cowsay` and `cowthink`. Wraps at 38 columns, which is what fits a
  /// phone's terminal in portrait at the default size.
  static List<String> cowsay(String message, {bool think = false}) {
    final text = message.trim().isEmpty ? 'moo' : message.trim();
    final lines = _wrap(text, 38);
    final w = lines.fold<int>(0, (m, l) => math.max(m, l.length));
    final out = <String>[' ${'_' * (w + 2)}'];

    if (lines.length == 1) {
      out.add(think ? '( ${lines.first} )' : '< ${lines.first} >');
    } else {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].padRight(w);
        final (a, b) = think
            ? ('(', ')')
            : i == 0
                ? ('/', '\\')
                : i == lines.length - 1
                    ? ('\\', '/')
                    : ('|', '|');
        out.add('$a $l $b');
      }
    }
    out.add(' ${'-' * (w + 2)}');

    // An original cow, drawn for G Launcher rather than lifted from cowsay.
    final tail = think ? 'o' : '\\';
    out.addAll([
      '      $tail    (__)',
      '       $tail   (\u00b0\u00b0)______',
      '            (..)      )~',
      '              |=====|',
      '              ||   ||',
    ]);
    return out;
  }

  /// `sl`: the train for people who meant `ls`. Static, because scrollback is
  /// append-only, and a train that redraws itself would scroll the whole
  /// history away.
  static List<String> sl() => const [
        '        ( ) ( )  o O',
        '     __[]__[]__ _____  ____________  ____________',
        '    |  G  |  |  |    | |  []  []  | |  []  []  |',
        '   [|_____|__|__|____|=|__________|=|__________|',
        '    (o)--(o)  (o)--(o)   (o)  (o)     (o)  (o)',
        '  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
        '',
        '${_dim}you typed sl. you meant ls.$_reset',
      ];

  /// `fortune`. Original lines, so nothing here is anyone else's quote.
  static List<String> fortune([math.Random? rng]) {
    final r = rng ?? math.Random();
    return [_fortunes[r.nextInt(_fortunes.length)]];
  }

  static const _fortunes = <String>[
    'There are two kinds of backups: the ones you have, and the ones you wish you had.',
    'Your phone is a Linux box with a very strict landlord.',
    'Every distro is the best distro until you need to print something.',
    'The fastest app is the one you uninstalled.',
    'Rice your launcher. Post it. Accept compliments gracefully.',
    'A clean dock is a clear mind. Five apps, no more.',
    'It is never DNS. Except when it is DNS.',
    'Today is a good day to read the man page.',
    'Battery is a renewable resource. Patience is not.',
    'You will hide an app today and forget its full name tomorrow.',
    'The terminal remembers what the drawer forgets.',
    'Distro hopping is cheaper on a phone. No USB stick required.',
  ];

  /// `cmatrix`, as one screenful rather than an animation, for the same
  /// append-only reason as [sl].
  static List<String> cmatrix([math.Random? rng]) {
    final r = rng ?? math.Random();
    const glyphs = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄ0123456789:.=*+-<>';
    return [
      for (var row = 0; row < 14; row++)
        '$_green${String.fromCharCodes([
              for (var col = 0; col < 34; col++)
                r.nextInt(4) == 0
                    ? 0x20
                    : glyphs.codeUnitAt(r.nextInt(glyphs.length)),
            ])}$_reset',
      '${_dim}wake up. the launcher has you.$_reset',
    ];
  }

  /// `yes`: bounded, because an unbounded `yes` in scrollback is a hang.
  static List<String> yes(String word) {
    final w = word.trim().isEmpty ? 'y' : word.trim();
    return [
      for (var i = 0; i < 24; i++) w,
      '$_dim^C  (stopped after 24, this is a phone)$_reset',
    ];
  }

  /// `make`. Only one target is buildable on a launcher.
  static List<String> make(String args, {required bool sudo}) {
    final a = args.trim().toLowerCase();
    if (a == 'me a sandwich') {
      return [sudo ? '${_bold}Okay.$_reset' : 'What? Make it yourself.'];
    }
    if (a.isEmpty) {
      return ['make: *** No targets specified and no makefile found.  Stop.'];
    }
    return ["make: *** No rule to make target '${args.trim()}'.  Stop."];
  }

  /// `rm`. There is nothing here to remove, and `-rf /` gets the answer it
  /// deserves.
  static List<String> rm(String args) {
    final a = args.trim();
    if (RegExp(r'(^|\s)-[a-z]*r[a-z]*f?[a-z]*\s+/\*?$|--no-preserve-root')
        .hasMatch(a)) {
      return [
        "rm: it is dangerous to operate recursively on '/'",
        '${_dim}nice try. your launcher has nothing to give.$_reset',
      ];
    }
    return [
      '${_dim}rm: this shell lists apps, it does not delete things.',
      'to remove an app: apt remove <app>$_reset',
    ];
  }

  static List<String> _wrap(String text, int width) {
    final words = text.split(RegExp(r'\s+'));
    final out = <String>[];
    var line = '';
    for (final w in words) {
      var word = w;
      while (word.length > width) {
        if (line.isNotEmpty) {
          out.add(line);
          line = '';
        }
        out.add(word.substring(0, width));
        word = word.substring(width);
      }
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= width) {
        line = '$line $word';
      } else {
        out.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) out.add(line);
    return out;
  }
}
