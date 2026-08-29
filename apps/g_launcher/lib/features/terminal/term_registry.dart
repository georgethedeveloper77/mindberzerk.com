/// The registry and the engine.
///
/// ONE list of commands. `help`, the `?` sheet, tab completion, the match rows
/// as you type, `which`, `man` and did you mean all read this same list, so a
/// command that exists is a command every surface knows about. The recurring
/// failure in this codebase is a value that has to be named in two places, and
/// this is the file that refuses to be the second place.
library;

import 'commands/app_commands.dart';
import 'commands/file_commands.dart';
import 'commands/shell_commands.dart';
import 'commands/system_commands.dart';
import 'term_command.dart';
import 'term_host.dart';
import 'term_output.dart';
import 'term_parse.dart';

class TermRegistry {
  TermRegistry(List<TermCommand> commands)
      : _byName = <String, TermCommand>{
          for (final TermCommand c in commands) c.name: c,
        },
        _ordered = List<TermCommand>.unmodifiable(commands);

  static final TermRegistry instance = TermRegistry(_builtins);

  final Map<String, TermCommand> _byName;
  final List<TermCommand> _ordered;

  static const List<TermCommand> _builtins = <TermCommand>[
    // files
    LsCommand(),
    CdCommand(),
    PwdCommand(),
    TreeCommand(),
    CatCommand(),
    HeadTailCommand.head(),
    HeadTailCommand.tail(),
    StatCommand(),
    DuCommand(),
    FindCommand(),
    MakeCommand.directory(),
    MakeCommand.file(),
    RemoveCommand(),
    TransferCommand.copy(),
    TransferCommand.move(),
    OpenCommand(),
    // apps
    AppsCommand(),
    PmCommand(),
    LaunchCommand(),
    LaunchCommand(commandName: 'am'),
    WhichCommand(),
    // system
    DfCommand(),
    FreeCommand(),
    TopCommand(),
    UptimeCommand(),
    DateCommand(),
    BatteryCommand(),
    NetCommand(),
    FetchCommand(),
    // device
    TorchCommand(),
    VolumeCommand(),
    PanelCommand.wifi(),
    PanelCommand.bluetooth(),
    PanelCommand.doNotDisturb(),
    // launcher
    LauncherPageCommand.settings(),
    LauncherPageCommand.themes(),
    LauncherPageCommand.wallpaper(),
    LauncherPageCommand.icons(),
    // shell
    HelpCommand(),
    ManCommand(),
    AliasCommand(),
    UnaliasCommand(),
    HistoryCommand(),
    ClearCommand(),
    EchoCommand(),
    GrepFilter(),
    WcFilter(),
  ];

  List<TermCommand> get all => _ordered;

  TermCommand? lookup(String name) => _byName[name];

  List<TermCommand> inGroup(TermGroup group) =>
      _ordered.where((TermCommand c) => c.group == group).toList();

  /// Names that start with [prefix], for tab completion and the match rows.
  List<String> startingWith(String prefix) {
    final String needle = prefix.toLowerCase();
    return _ordered
        .map((TermCommand c) => c.name)
        .where((String n) => n.startsWith(needle))
        .toList();
  }

  /// The nearest command to a word that missed.
  ///
  /// A miss is the moment a user is most willing to learn, so it costs one
  /// subsequence pass to turn "not found" into a suggestion. The 0.5 floor is
  /// what stops a wild guess: below it the shell says nothing rather than
  /// something wrong.
  String? nearest(String word) {
    final String needle = word.toLowerCase();
    String? best;
    var bestScore = 0.0;
    for (final TermCommand command in _ordered) {
      var matched = 0;
      for (final String ch in command.name.split('')) {
        if (matched < needle.length && ch == needle[matched]) matched++;
      }
      final int longest =
          command.name.length > needle.length ? command.name.length : needle.length;
      final double score = longest == 0 ? 0 : matched / longest;
      if (score > bestScore) {
        bestScore = score;
        best = command.name;
      }
    }
    return bestScore >= 0.5 ? best : null;
  }
}

/// Runs one typed line.
class TermEngine {
  const TermEngine({
    this.registry,
    this.parser = const TermParser(),
  });

  final TermRegistry? registry;
  final TermParser parser;

  TermRegistry get _registry => registry ?? TermRegistry.instance;

  Future<TermResult> execute(String line, TermContext context) async {
    final TermParsed parsed =
        parser.parse(line, aliases: context.aliases);
    if (parsed.isEmpty) return const TermResult.none();

    // One line, one chance to ask for the folder. See TermVfs.beginLine.
    context.vfs.beginLine();

    final List<TermChunk> chunks = <TermChunk>[];
    var clear = false;

    for (final List<TermStage> stages in parsed.chunks) {
      final TermResult result = await _runPipeline(stages, context);
      if (result.clearScrollback) {
        clear = true;
        // `clear && ls` empties the screen and then prints the listing, so
        // anything already collected is dropped rather than resurrected.
        chunks.clear();
        continue;
      }
      chunks.addAll(result.chunks);
    }
    return TermResult(_cap(chunks), clearScrollback: clear);
  }

  /// The runaway guard, applied ONCE, at the very end.
  ///
  /// After every filter has run, so `apps | grep zoom` searched all 247 apps
  /// and this only ever trims what is about to be PAINTED. The old cap lived
  /// inside `ls` and `apps`, which meant grep received forty lines and answered
  /// for a list the user never asked about.
  ///
  /// A real listing never reaches this. It exists so a pathological output
  /// cannot lock the view.
  static List<TermChunk> _cap(List<TermChunk> chunks) {
    var printed = 0;
    var dropped = 0;
    final List<TermChunk> out = <TermChunk>[];

    for (final TermChunk chunk in chunks) {
      if (chunk is! TermTextChunk) {
        out.add(chunk);
        continue;
      }
      final int room = kOutputCeiling - printed;
      if (room <= 0) {
        dropped += chunk.lines.length;
        continue;
      }
      if (chunk.lines.length <= room) {
        out.add(chunk);
        printed += chunk.lines.length;
        continue;
      }
      out.add(TermTextChunk(chunk.lines.sublist(0, room)));
      printed = kOutputCeiling;
      dropped += chunk.lines.length - room;
    }

    if (dropped > 0) {
      // The count is real, so this states a fact rather than standing in for
      // one. Same rule as everywhere else here.
      out.add(TermTextChunk(<TermLine>[
        TermLine.of('$dropped more lines not shown', TermInk.dim),
      ]));
    }
    return out;
  }

  Future<TermResult> _runPipeline(
    List<TermStage> stages,
    TermContext context,
  ) async {
    TermResult result = await _runStage(stages.first, context);

    for (final TermStage stage in stages.skip(1)) {
      final TermCommand? command = _registry.lookup(stage.name);
      if (command == null) {
        return _notFound(stage.name);
      }
      if (!command.acceptsPipe) {
        return TermResult.lines(<TermLine>[
          TermLine.of('${stage.name}: cannot read a pipe', TermInk.bad),
          TermLine.of('grep, wc, head and tail can', TermInk.dim),
        ]);
      }
      final List<TermLine> filtered = command.filter(
        result.textLines,
        TermInvocation(stage, context),
      );
      result = TermResult.lines(filtered);
    }
    return result;
  }

  Future<TermResult> _runStage(TermStage stage, TermContext context) async {
    final TermCommand? command = _registry.lookup(stage.name);
    if (command != null) {
      return command.run(TermInvocation(stage, context));
    }

    // A bare word that names an app launches it. This is the terminal's whole
    // premise and it stays ahead of the not found path, but BEHIND the command
    // table, which is the ordering that makes `settings` open ours.
    final TermApp? app = await context.vfs.appNamed(stage.raw);
    if (app != null) {
      await context.host.launchApp(app);
      return TermResult.lines(<TermLine>[
        TermLine(<TermSpan>[
          const TermSpan('launching ', TermInk.dim),
          TermSpan(app.label),
        ]),
      ]);
    }
    return _notFound(stage.name);
  }

  TermResult _notFound(String word) {
    final String? near = _registry.nearest(word);
    return TermResult.lines(<TermLine>[
      TermLine.of('$word: command not found', TermInk.bad),
      if (near != null)
        TermLine(<TermSpan>[
          const TermSpan('did you mean ', TermInk.dim),
          TermSpan(near, TermInk.accent),
          TermSpan('  ${_registry.lookup(near)!.help}', TermInk.dim),
        ])
      else
        TermLine.of('? lists every command', TermInk.dim),
    ]);
  }
}
