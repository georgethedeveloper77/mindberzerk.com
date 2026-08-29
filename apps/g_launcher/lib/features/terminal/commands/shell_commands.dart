/// The shell's own vocabulary, and the pipe filters.
///
/// `help` is generated from the registry, so a command that exists is a command
/// `help` lists. There is no second list to forget to update, which is the
/// failure that keeps recurring in this codebase whenever a value has to be
/// named in two places.
library;

import '../term_command.dart';
import '../term_output.dart';
import '../term_parse.dart';
import '../term_registry.dart';
import 'file_commands.dart';

class HelpCommand extends TermCommand {
  const HelpCommand();

  @override
  String get name => 'help';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'every command, grouped';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final List<TermLine> lines = <TermLine>[];
    for (final TermGroup group in TermGroup.values) {
      final List<TermCommand> commands = TermRegistry.instance.inGroup(group);
      if (commands.isEmpty) continue;
      lines.add(TermLine(<TermSpan>[
        TermSpan(group.label.padRight(10), TermInk.key),
        TermSpan(commands.map((TermCommand c) => c.name).join(' ')),
      ]));
    }
    lines.add(TermLine.blank);
    lines.add(TermLine.of(
      'chain with && , filter with | grep , man <cmd> for one line',
      TermInk.dim,
    ));
    return TermResult.lines(lines);
  }
}

class ManCommand extends TermCommand {
  const ManCommand();

  @override
  String get name => 'man';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'what one command does';
  @override
  String? get usage => 'man <command>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final String? word = inv.target;
    if (word == null) return missing('a command name');
    final TermCommand? command = TermRegistry.instance.lookup(word);
    if (command == null) {
      final String? near = TermRegistry.instance.nearest(word);
      return TermResult.lines(<TermLine>[
        TermLine.of('man: no entry for $word', TermInk.bad),
        if (near != null) TermLine.of('did you mean $near', TermInk.dim),
      ]);
    }
    return TermResult.lines(<TermLine>[
      TermLine(<TermSpan>[
        TermSpan(command.name, TermInk.key),
        TermSpan('  ${command.help}'),
      ]),
      if (command.usage != null) TermLine.of(command.usage!, TermInk.dim),
    ]);
  }
}

class AliasCommand extends TermCommand {
  const AliasCommand();

  @override
  String get name => 'alias';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'list or set your own word for a command';
  @override
  String? get usage => "alias ll='ls -l'";

  @override
  Future<TermResult> run(TermInvocation inv) async {
    // The raw stage, not the tokenized positionals: an alias value keeps its
    // spaces and its quotes are already stripped by the tokenizer.
    final String raw = inv.stage.raw;
    final int space = raw.indexOf(' ');
    final String body = space < 0 ? '' : raw.substring(space + 1).trim();

    if (body.isEmpty) {
      final Map<String, String> aliases = inv.context.aliases;
      if (aliases.isEmpty) return TermResult.line('none set', TermInk.dim);
      return TermResult.lines(<TermLine>[
        for (final MapEntry<String, String> e in aliases.entries)
          TermLine(<TermSpan>[
            TermSpan(e.key.padRight(12), TermInk.key),
            TermSpan(e.value),
          ]),
      ]);
    }

    final int equals = body.indexOf('=');
    if (equals <= 0) {
      return TermResult.lines(<TermLine>[
        TermLine.of('alias: use alias name=command', TermInk.bad),
        TermLine.of("alias ll='ls -l'", TermInk.dim),
      ]);
    }
    final String key = body.substring(0, equals).trim();
    var value = body.substring(equals + 1).trim();
    if (value.length > 1 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')))) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isEmpty || value.isEmpty) return missing('a name and a command');

    inv.context.aliases[key] = value;
    return TermResult.line('$key is now $value', TermInk.dim);
  }
}

class UnaliasCommand extends TermCommand {
  const UnaliasCommand();

  @override
  String get name => 'unalias';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'drop one of your words';
  @override
  String? get usage => 'unalias <name>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final String? key = inv.target;
    if (key == null) return missing('a name');
    final String? removed = inv.context.aliases.remove(key);
    if (removed == null) return TermResult.error('unalias: $key is not set');
    return TermResult.line('dropped $key', TermInk.dim);
  }
}

class HistoryCommand extends TermCommand {
  const HistoryCommand();

  @override
  String get name => 'history';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'what you have run';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final List<String> history = inv.context.history;
    if (history.isEmpty) return TermResult.line('nothing yet', TermInk.dim);
    // The one listing that keeps a window, and it keeps the RECENT end. A
    // shell's `history` is read for what you just did, and the numbers stay
    // absolute so `history | grep alias` still points at the right line.
    const int window = 40;
    final int start =
        history.length > window ? history.length - window : 0;
    return TermResult.lines(<TermLine>[
      for (var i = start; i < history.length; i++)
        TermLine(<TermSpan>[
          TermSpan('${i + 1}'.padLeft(4).padRight(6), TermInk.dim),
          TermSpan(history[i]),
        ]),
    ]);
  }
}

class ClearCommand extends TermCommand {
  const ClearCommand();

  @override
  String get name => 'clear';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'empty the scrollback';

  @override
  Future<TermResult> run(TermInvocation inv) async =>
      const TermResult(<TermChunk>[], clearScrollback: true);
}

class EchoCommand extends TermCommand {
  const EchoCommand();

  @override
  String get name => 'echo';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'print the argument';

  @override
  Future<TermResult> run(TermInvocation inv) async =>
      TermResult.line(inv.positionals.join(' '));
}

/// `apps | grep sig`
class GrepFilter extends TermFilter {
  const GrepFilter();

  @override
  String get name => 'grep';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'keep the lines that contain a word';
  @override
  String? get usage => 'apps | grep <word>';

  @override
  List<TermLine> filter(List<TermLine> input, TermInvocation invocation) {
    final String needle = (invocation.target ?? '').toLowerCase();
    if (needle.isEmpty) return input;
    // Matched against the PLAIN text, so a match can never depend on how a
    // line happens to be painted.
    final List<TermLine> kept = input
        .where((TermLine l) => l.plain.toLowerCase().contains(needle))
        .toList();
    if (kept.isEmpty) return <TermLine>[TermLine.of('no match', TermInk.dim)];
    return kept;
  }
}

class WcFilter extends TermFilter {
  const WcFilter();

  @override
  String get name => 'wc';
  @override
  TermGroup get group => TermGroup.shell;
  @override
  String get help => 'count the lines';
  @override
  String? get usage => 'apps | wc -l';

  @override
  List<TermLine> filter(List<TermLine> input, TermInvocation invocation) =>
      <TermLine>[TermLine.of('${input.length}')];
}

/// `head` and `tail` read a FILE when they start a line and a PIPE when they
/// follow one, which is exactly how they behave in a real shell. One registry
/// entry, one name, two positions.
class HeadTailCommand extends TermCommand {
  const HeadTailCommand.head()
      : commandName = 'head',
        fromEnd = false;
  const HeadTailCommand.tail()
      : commandName = 'tail',
        fromEnd = true;

  final String commandName;
  final bool fromEnd;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help =>
      fromEnd ? 'the last lines of a file or a pipe' : 'the first lines of a file or a pipe';
  @override
  String? get usage => '$commandName [-n] <file>   or   apps | $commandName 10';

  @override
  bool get acceptsPipe => true;

  /// `head -2 notes.txt`, `head 2`, `head -n 2`.
  ///
  /// `-2` reaches here as a POSITIONAL, because the parser refuses to read a
  /// negative number as a bundle of flags. Stripping the sign here rather than
  /// there is what keeps `int.tryParse` from handing back a negative count and
  /// a `sublist` that throws.
  static bool _isCount(String word) {
    final String body = word.startsWith('-') ? word.substring(1) : word;
    return body.isNotEmpty && int.tryParse(body) != null;
  }

  int _count(TermInvocation inv) {
    for (final String word in inv.positionals) {
      if (_isCount(word)) {
        return int.parse(word.startsWith('-') ? word.substring(1) : word);
      }
    }
    for (final String flag in inv.flags) {
      final int? parsed = int.tryParse(flag);
      if (parsed != null) return parsed;
    }
    return 10;
  }

  @override
  List<TermLine> filter(List<TermLine> input, TermInvocation invocation) {
    final int count = _count(invocation);
    if (input.length <= count) return input;
    return fromEnd
        ? input.sublist(input.length - count)
        : input.sublist(0, count);
  }

  @override
  Future<TermResult> run(TermInvocation inv) {
    final int count = _count(inv);
    final CatCommand reader = CatCommand(
      commandName: commandName,
      headLines: fromEnd ? null : count,
      tailLines: fromEnd ? count : null,
    );
    // The count is not a path. Without stripping it, `head -2 notes.txt`
    // resolves `-2` as the target and reports that it does not exist.
    final TermStage stripped = TermStage(
      inv.stage.name,
      inv.positionals.where((String w) => !_isCount(w)).toList(),
      inv.flags,
      inv.stage.raw,
    );
    return reader.run(TermInvocation(stripped, inv.context));
  }
}
