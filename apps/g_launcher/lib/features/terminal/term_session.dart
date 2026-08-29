/// The shell's state.
///
/// Scrollback lives HERE, not in the desklet surface. That is the change that
/// unlocked the rest: output is a list of blocks a view paints, so history
/// survives a rebuild, `clear` is a state change rather than a widget trick,
/// and the pane stays free for what it was for.
///
/// Plain Riverpod 3, no codegen. Mutating methods are named for what they do,
/// never `update`, because an `AsyncNotifier.update` on a persisted notifier is
/// how preferences got lost before.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'term_command.dart';
import 'term_host.dart';
import 'term_output.dart';
import 'term_path.dart';
import 'term_registry.dart';
import 'term_vfs.dart';

/// One entry in the scrollback: what was typed, and what came back.
class TermEntryBlock {
  const TermEntryBlock({
    required this.line,
    required this.cwd,
    required this.chunks,
  });

  final String line;

  /// The folder the command ran IN, so the echoed prompt stays truthful after
  /// a `cd`. Without this a chain would print its result under the folder it
  /// ended in, which is not where the user typed it.
  final TermPath cwd;

  final List<TermChunk> chunks;
}

class TermSessionState {
  const TermSessionState({
    this.cwd = TermPath.appsRoot,
    this.blocks = const <TermEntryBlock>[],
    this.history = const <String>[],
    this.aliases = const <String, String>{},
    this.runCount = 0,
    this.busy = false,
    this.unwired = const <String>{},
  });

  final TermPath cwd;
  final List<TermEntryBlock> blocks;
  final List<String> history;
  final Map<String, String> aliases;

  /// How many commands this user has ever run.
  ///
  /// The suggestion block under an empty prompt stops at [kTeachingRuns]. A
  /// shell that keeps teaching after the user has learned is a tutorial, not a
  /// tool, and the `?` key stays forever for the ones they have not met.
  final int runCount;

  final bool busy;

  /// Command names this build cannot perform. The `?` sheet and the match rows
  /// leave them out; typing one still resolves and explains itself.
  final Set<String> unwired;

  bool get showsSuggestions => runCount < kTeachingRuns;

  bool offers(String command) => !unwired.contains(command);

  TermSessionState copyWith({
    TermPath? cwd,
    List<TermEntryBlock>? blocks,
    List<String>? history,
    Map<String, String>? aliases,
    int? runCount,
    bool? busy,
    Set<String>? unwired,
  }) =>
      TermSessionState(
        cwd: cwd ?? this.cwd,
        blocks: blocks ?? this.blocks,
        history: history ?? this.history,
        aliases: aliases ?? this.aliases,
        runCount: runCount ?? this.runCount,
        busy: busy ?? this.busy,
        unwired: unwired ?? this.unwired,
      );
}

const int kTeachingRuns = 8;

/// How many blocks the scrollback keeps.
///
/// A phone terminal that never forgets is a memory leak with a prompt.
const int kScrollbackLimit = 120;

/// The host is provided by the app, not built here, so this file imports no
/// repository. Override it once at the root.
final Provider<TermHost> termHostProvider = Provider<TermHost>(
  (Ref ref) => throw UnimplementedError(
    'Override termHostProvider with the adapter that wires the app',
  ),
);

final NotifierProvider<TermSession, TermSessionState> termSessionProvider =
    NotifierProvider<TermSession, TermSessionState>(TermSession.new);

class TermSession extends Notifier<TermSessionState> {
  late final TermHost _host = ref.read(termHostProvider);
  late final TermVfs _vfs = TermVfs(_host);
  final TermEngine _engine = const TermEngine();

  @override
  TermSessionState build() {
    // Loaded after the first frame rather than awaited, so the prompt is live
    // immediately and the aliases arrive when they arrive.
    _ready = _restore();
    return TermSessionState(unwired: _host.unwired);
  }

  /// Completes when the aliases and the run count have been read.
  ///
  /// ─── A GATE, NOT A MERGE ─────────────────────────────────────────────────
  ///
  /// [build] returns immediately and reads from disk in a microtask, which is
  /// right: the prompt has to be live before a prefs read finishes. But the
  /// read then assigned over `state`, so a user who typed
  /// `alias ll='ls -l'` inside that window had it replaced by whatever was on
  /// disk, and the next save wrote the stale map back.
  ///
  /// My first fix merged the two maps. Writing the test for it showed the merge
  /// is not enough: `run` captures the alias map at its START, so a read landing
  /// mid-command still loses whatever the read brought. Waiting is correct and
  /// simpler. The prompt stays live throughout, and only the first command
  /// waits, on a read that has usually already finished.
  Future<void>? _ready;

  Future<void> _restore() async {
    final Map<String, String> aliases = await _host.loadAliases();
    final int runs = await _host.loadRunCount();
    state = state.copyWith(aliases: aliases, runCount: runs);
  }

  /// Run one typed line.
  Future<void> run(String line) async {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return;

    // See [_ready]. Nothing may read or write the alias map before the disk
    // has been read once.
    await _ready;

    final TermPath ranIn = state.cwd;
    final Map<String, String> aliases = Map<String, String>.of(state.aliases);
    final List<String> history = <String>[...state.history, trimmed];

    final TermContext context = TermContext(
      cwd: ranIn,
      vfs: _vfs,
      host: _host,
      aliases: aliases,
      history: history,
    );

    state = state.copyWith(busy: true);

    // Snapshotted BEFORE the command, so the save below can tell whether the
    // line actually changed anything.
    final Map<String, String> before = Map<String, String>.of(state.aliases);
    final TermResult result = await _engine.execute(trimmed, context);

    final List<TermEntryBlock> blocks = result.clearScrollback
        ? <TermEntryBlock>[]
        : <TermEntryBlock>[...state.blocks];

    if (result.chunks.isNotEmpty || !result.clearScrollback) {
      blocks.add(TermEntryBlock(
        line: trimmed,
        cwd: ranIn,
        chunks: result.chunks,
      ));
    }
    if (blocks.length > kScrollbackLimit) {
      blocks.removeRange(0, blocks.length - kScrollbackLimit);
    }

    final int runs = state.runCount + 1;
    state = state.copyWith(
      // Read back from the context: a chain can cd more than once and only the
      // last one is the answer.
      cwd: context.cwd,
      blocks: blocks,
      history: history,
      aliases: aliases,
      runCount: runs,
      busy: false,
    );

    // ── WRITE ONLY WHAT CHANGED ────────────────────────────────────────
    //
    // This used to write both keys on EVERY command. Two shared_preferences
    // writes per `ls` is a disk write per keystroke-command on exactly the
    // budget devices this app targets, and neither value had usually changed.
    if (!_sameAliases(before, aliases)) await _host.saveAliases(aliases);

    // The run count has ONE consumer: the suggestion block, which stops at
    // kTeachingRuns. Past that the number is never read again, so persisting it
    // forever is a write for nobody. The boundary value itself is written, so a
    // cold start resolves the suggestions the same way this session did.
    if (runs <= kTeachingRuns) await _host.saveRunCount(runs);
  }

  static bool _sameAliases(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, String> e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  /// The six commands offered under an empty prompt.
  ///
  /// `torch` used to be on this list, and on a build that cannot run it that is
  /// a suggestion to type a word that fails. Filtered against [state.unwired],
  /// so the seed list can name a command optimistically and the shell still
  /// only ever offers what works.
  List<TermCommand> suggestions() {
    const List<String> seeds = <String>[
      'ls',
      'du',
      'df',
      'apps',
      'battery',
      'torch',
      'help',
    ];
    final List<TermCommand> out = <TermCommand>[];
    for (final String seed in seeds) {
      if (out.length == 6) break;
      if (!state.offers(seed)) continue;
      final TermCommand? command = TermRegistry.instance.lookup(seed);
      if (command != null) out.add(command);
    }
    return out;
  }

  void clearScrollback() {
    state = state.copyWith(blocks: const <TermEntryBlock>[]);
  }

  /// Walk history for the up and down keys. Returns null at either end.
  String? recall(int index) {
    if (index < 0 || index >= state.history.length) return null;
    return state.history[index];
  }
}
