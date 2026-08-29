/// What a command IS.
///
/// A class with a name, a group, one line of help and a `run`. The help line is
/// not documentation: it is the text the match row prints beside the command as
/// the user types, and the text the `?` sheet lists. There is no separate
/// manual to fall out of date, because there is no separate manual.
library;

import 'term_host.dart';
import 'term_output.dart';
import 'term_parse.dart';
import 'term_path.dart';
import 'term_vfs.dart';

/// The grouping the `?` sheet and `help` both print. Ordered as declared.
enum TermGroup { files, apps, system, device, launcher, shell }

extension TermGroupLabel on TermGroup {
  String get label => switch (this) {
        TermGroup.files => 'files',
        TermGroup.apps => 'apps',
        TermGroup.system => 'system',
        TermGroup.device => 'device',
        TermGroup.launcher => 'launcher',
        TermGroup.shell => 'shell',
      };
}

/// Mutable across one typed line, so `cd .. && ls` sees the new folder.
///
/// The session reads [cwd] back after execution rather than a command
/// returning it, because a chain can change directory more than once and only
/// the last one is the answer.
class TermContext {
  TermContext({
    required this.cwd,
    required this.vfs,
    required this.host,
    required this.aliases,
    required this.history,
  });

  TermPath cwd;
  final TermVfs vfs;
  final TermHost host;

  /// Live maps, not copies. `alias` writes here and the session persists it.
  final Map<String, String> aliases;
  final List<String> history;

  TermPath resolve(String? arg) => TermPath.resolve(arg, cwd);
}

class TermInvocation {
  const TermInvocation(this.stage, this.context);

  final TermStage stage;
  final TermContext context;

  List<String> get positionals => stage.positionals;
  Set<String> get flags => stage.flags;
  String? get target => stage.target;

  bool has(String flag) => stage.flags.contains(flag);

  TermPath path([int index = 0]) => context.resolve(
        index < stage.positionals.length ? stage.positionals[index] : null,
      );
}

abstract class TermCommand {
  const TermCommand();

  String get name;
  TermGroup get group;

  /// One line, lower case, no full stop. It sits inside a match row.
  String get help;

  /// The argument shape, for the `?` sheet. Null when the command takes none.
  String? get usage => null;

  /// Whether this command can read the previous stage's lines.
  ///
  /// A CAPABILITY, not a separate kind of command, because `head` is both: a
  /// file reader when it starts a line and a filter when it follows a pipe,
  /// exactly as it behaves in a real shell. Two registry entries under one name
  /// would have been the usual failure, where the second silently wins.
  bool get acceptsPipe => false;

  /// Called only when this stage followed a pipe. Ignored otherwise.
  List<TermLine> filter(List<TermLine> input, TermInvocation invocation) =>
      input;

  Future<TermResult> run(TermInvocation invocation);

  /// Shared refusal, so every command spells a missing argument the same way.
  TermResult missing(String what) =>
      TermResult.error('$name: give $what');
}

/// A command that ONLY reads a pipe.
///
/// It exists as a command rather than as a case inside the engine so that `?`
/// lists it and `man grep` answers. Run without a pipe it says what it needs.
abstract class TermFilter extends TermCommand {
  const TermFilter();

  @override
  bool get acceptsPipe => true;

  @override
  Future<TermResult> run(TermInvocation invocation) async => TermResult.lines(
        <TermLine>[
          TermLine.of('$name reads a pipe', TermInk.dim),
          TermLine.of('try  apps | $name', TermInk.dim),
        ],
      );
}
