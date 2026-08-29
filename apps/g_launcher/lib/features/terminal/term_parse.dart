/// Turning a typed line into something runnable.
///
/// Grammar, deliberately small and deliberately complete:
///
///   line   := chunk ( '&&' chunk )*
///   chunk  := stage ( '|' stage )*
///   stage  := word+          quoted with ' or "
///   word   := flags starting with '-' are lifted out of the positionals
///
/// No subshells, no globs, no redirect. Each of those would need a filesystem
/// guarantee that a folder grant does not give, and a shell that half supports
/// `>` is worse than one that does not.
///
/// Pure Dart, fully covered by `test/terminal/term_parse_test.dart`.
library;

/// One command with its arguments, after quoting and flag lifting.
class TermStage {
  const TermStage(this.name, this.positionals, this.flags, this.raw);

  /// The command word. Empty when the stage was blank.
  final String name;

  /// Arguments that are not flags, in order.
  final List<String> positionals;

  /// Short flags exploded to single letters, plus long flags whole.
  ///
  /// `-la` gives {l, a}. `--human` gives {human}. So a command asks
  /// `flags.contains('l')` and never parses a string itself.
  final Set<String> flags;

  /// The stage exactly as typed, for `echo` and for the scrollback echo.
  final String raw;

  bool get isEmpty => name.isEmpty;

  /// The first positional, or null. The overwhelmingly common shape.
  String? get target => positionals.isEmpty ? null : positionals.first;

  @override
  String toString() => raw;
}

class TermParsed {
  const TermParsed(this.chunks);

  /// Each entry is one `&&` chunk, itself a list of pipe stages.
  final List<List<TermStage>> chunks;

  bool get isEmpty => chunks.isEmpty;
}

class TermParser {
  const TermParser();

  /// Split, expand aliases, tokenize.
  ///
  /// [aliases] expands only the HEAD word of a stage, once, and never
  /// recursively. An alias that names itself is therefore a no-op instead of a
  /// hang, which matters because the alias table is user data.
  TermParsed parse(String line, {Map<String, String> aliases = const <String, String>{}}) {
    final List<List<TermStage>> chunks = <List<TermStage>>[];
    for (final String chunk in _split(line, '&&')) {
      final List<TermStage> stages = <TermStage>[];
      for (final String stage in _split(chunk, '|')) {
        final TermStage parsed = _stage(stage, aliases);
        if (!parsed.isEmpty) stages.add(parsed);
      }
      if (stages.isNotEmpty) chunks.add(stages);
    }
    return TermParsed(chunks);
  }

  /// Split on a separator that is not inside quotes.
  List<String> _split(String line, String separator) {
    final List<String> out = <String>[];
    final StringBuffer buffer = StringBuffer();
    String? quote;
    var i = 0;
    while (i < line.length) {
      final String ch = line[i];
      if (quote != null) {
        buffer.write(ch);
        if (ch == quote) quote = null;
        i++;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        buffer.write(ch);
        i++;
        continue;
      }
      if (line.startsWith(separator, i)) {
        out.add(buffer.toString());
        buffer.clear();
        i += separator.length;
        continue;
      }
      buffer.write(ch);
      i++;
    }
    out.add(buffer.toString());
    return out.map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
  }

  TermStage _stage(String raw, Map<String, String> aliases) {
    List<String> words = tokenize(raw);
    if (words.isEmpty) return const TermStage('', <String>[], <String>{}, '');

    // Expanded ONCE, never recursively, so `alias ls='ls -l'` is the useful
    // thing a user expects and not a hang. The alias table is user data, so it
    // has to be safe to write anything into it.
    final String? expansion = aliases[words.first];
    if (expansion != null) {
      final List<String> head = tokenize(expansion);
      if (head.isNotEmpty) words = <String>[...head, ...words.skip(1)];
    }

    final String name = words.first;
    final List<String> positionals = <String>[];
    final Set<String> flags = <String>{};

    for (final String word in words.skip(1)) {
      if (word.startsWith('--') && word.length > 2) {
        flags.add(word.substring(2));
      } else if (word.startsWith('-') && word.length > 1 && !_looksNumeric(word)) {
        flags.addAll(word.substring(1).split(''));
      } else {
        positionals.add(word);
      }
    }
    return TermStage(name, positionals, flags, raw.trim());
  }

  /// `-5` is an argument to `head`, not five flags.
  bool _looksNumeric(String word) =>
      int.tryParse(word.substring(1)) != null;

  /// Split on whitespace, honouring quotes and stripping them.
  static List<String> tokenize(String raw) {
    final List<String> out = <String>[];
    final StringBuffer buffer = StringBuffer();
    String? quote;
    var pending = false;

    for (var i = 0; i < raw.length; i++) {
      final String ch = raw[i];
      if (quote != null) {
        if (ch == quote) {
          quote = null;
        } else {
          buffer.write(ch);
        }
        pending = true;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        pending = true;
        continue;
      }
      if (ch == ' ' || ch == '\t') {
        if (pending) {
          out.add(buffer.toString());
          buffer.clear();
          pending = false;
        }
        continue;
      }
      buffer.write(ch);
      pending = true;
    }
    if (pending) out.add(buffer.toString());
    return out;
  }
}
