/// The file verbs. Every one of them goes through [TermVfs], so each works in
/// `/apps` and in `~` or refuses in the words of the namespace it was aimed at.
library;

import '../term_command.dart';
import '../term_host.dart';
import '../term_output.dart';
import '../term_path.dart';
import '../term_vfs.dart';

List<TermLine> _errorLines(TermVfsError error) => <TermLine>[
      TermLine.of(error.message, TermInk.bad),
      if (error.hint != null) TermLine.of(error.hint!, TermInk.dim),
    ];

String _stamp(DateTime? when) {
  if (when == null) return '';
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final String day = when.day.toString().padLeft(2, ' ');
  final String hour = when.hour.toString().padLeft(2, '0');
  final String minute = when.minute.toString().padLeft(2, '0');
  return '${months[when.month - 1]} $day $hour:$minute';
}

class LsCommand extends TermCommand {
  const LsCommand();

  @override
  String get name => 'ls';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'list what you are standing in';
  @override
  String? get usage => 'ls [-a] [-l] [-r] [path]';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermPath path = inv.path();
    final TermListing listing = await inv.context.vfs.list(path);
    if (listing.failed) return TermResult.lines(_errorLines(listing.error!));

    List<TermEntry> entries = listing.entries;
    if (!inv.has('a')) {
      entries = entries
          .where((TermEntry e) => !e.name.startsWith('.'))
          .toList();
    }
    if (inv.has('r')) entries = entries.reversed.toList();
    if (entries.isEmpty) {
      return TermResult.line('empty', TermInk.dim);
    }

    // Every entry, in full. `ls` on a phone with 247 apps prints 247 lines and
    // you scroll, which is what a shell does and what makes `ls | grep` mean
    // what it says.
    return TermResult.lines(<TermLine>[
      for (final TermEntry e in entries) inv.has('l') ? _long(e) : _short(e),
    ]);
  }

  TermLine _short(TermEntry e) => TermLine(<TermSpan>[
        TermSpan(
          e.isDirectory ? '${e.name}/' : e.name,
          e.standsOut ? TermInk.key : TermInk.text,
        ),
      ]);

  TermLine _long(TermEntry e) {
    final String size = e.sizeBytes == null ? '' : humanBytes(e.sizeBytes!);
    return TermLine(<TermSpan>[
      TermSpan(size.padLeft(7), TermInk.dim),
      const TermSpan('  '),
      TermSpan(_stamp(e.modified).padRight(13), TermInk.dim),
      TermSpan(
        e.isDirectory ? '${e.name}/' : e.name,
        e.standsOut ? TermInk.key : TermInk.text,
      ),
      // The package name, which is the truthful identifier a slug is not.
      if (e.subtitle != null) TermSpan('  ${e.subtitle}', TermInk.dim),
    ]);
  }
}

class CdCommand extends TermCommand {
  const CdCommand();

  @override
  String get name => 'cd';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'change folder, .. and ~ work';
  @override
  String? get usage => 'cd [path]';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    // Bare `cd` goes to `~`, the way a shell does. `~` always means storage,
    // and `/apps` never gets a home shorthand, so the two never blur.
    final TermPath path =
        inv.target == null ? TermPath.filesRoot : inv.path();
    final TermVfsError? error = await inv.context.vfs.canEnter(path);
    if (error != null) return TermResult.lines(_errorLines(error));
    inv.context.cwd = path;
    return const TermResult.none();
  }
}

class PwdCommand extends TermCommand {
  const PwdCommand();

  @override
  String get name => 'pwd';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'where you are';

  @override
  Future<TermResult> run(TermInvocation inv) async =>
      TermResult.line(inv.context.cwd.display);
}

class TreeCommand extends TermCommand {
  const TreeCommand();

  static const int _maxLines = 60;

  @override
  String get name => 'tree';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'this folder as a tree';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermPath root = inv.path();
    final List<TermLine> out = <TermLine>[TermLine.of(root.display, TermInk.key)];
    final bool truncated = await _walk(inv, root, '', out);
    if (truncated) {
      out.add(TermLine.of('stopped at $_maxLines lines', TermInk.dim));
    }
    return TermResult.lines(out);
  }

  Future<bool> _walk(
    TermInvocation inv,
    TermPath path,
    String prefix,
    List<TermLine> out,
  ) async {
    final TermListing listing = await inv.context.vfs.list(path);
    if (listing.failed) {
      out.addAll(_errorLines(listing.error!));
      return false;
    }
    final List<TermEntry> entries = listing.entries
        .where((TermEntry e) => !e.name.startsWith('.'))
        .toList();

    for (var i = 0; i < entries.length; i++) {
      if (out.length >= _maxLines) return true;
      final TermEntry e = entries[i];
      final bool last = i == entries.length - 1;
      out.add(TermLine(<TermSpan>[
        TermSpan('$prefix${last ? '└── ' : '├── '}', TermInk.dim),
        TermSpan(e.name, e.standsOut ? TermInk.key : TermInk.text),
      ]));
      // Apps are leaves, so a tree of /apps is one flat level and stays honest.
      if (e.kind == TermEntryKind.directory) {
        final bool stopped = await _walk(
          inv,
          path.child(e.name),
          '$prefix${last ? '    ' : '│   '}',
          out,
        );
        if (stopped) return true;
      }
    }
    return false;
  }
}

class CatCommand extends TermCommand {
  const CatCommand({this.headLines, this.tailLines, this.commandName = 'cat'});

  final int? headLines;
  final int? tailLines;
  final String commandName;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => switch (commandName) {
        'head' => 'the first lines of a file',
        'tail' => 'the last lines of a file',
        _ => 'read a text file, or an app entry',
      };
  @override
  String? get usage => '$commandName <path>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.target == null) return missing('a path');
    final TermPath path = inv.path();

    // `cat /apps/firefox` is the payoff for apps being files: the app's own
    // details, printed by the same verb that reads a text file.
    final TermApp? app = await inv.context.vfs.appAt(path);
    if (app != null) return TermResult.lines(_app(app));

    final TermEntry? entry = await inv.context.vfs.stat(path);
    if (entry == null) {
      return TermResult.error('$commandName: ${path.display}: no such file');
    }
    if (entry.isDirectory) {
      return TermResult.error('$commandName: ${path.display}: is a directory');
    }
    if (entry.isApp) {
      return TermResult.error('$commandName: ${path.display}: is an app');
    }

    final List<String>? lines = await inv.context.host.readLines(path);
    if (lines == null) {
      final String size =
          entry.sizeBytes == null ? '' : ', ${humanBytes(entry.sizeBytes!)}';
      return TermResult.lines(<TermLine>[
        TermLine.of('binary file$size', TermInk.dim),
        TermLine.of('open ${path.display} hands it to the app that owns it',
            TermInk.dim),
      ]);
    }

    List<String> body = lines;
    final int? head = headLines, tail = tailLines;
    if (head != null && body.length > head) body = body.sublist(0, head);
    if (tail != null && body.length > tail) {
      body = body.sublist(body.length - tail);
    }
    return TermResult.lines(body.map(TermLine.of).toList());
  }

  List<TermLine> _app(TermApp app) => <TermLine>[
        TermLine.pair('label', app.label),
        TermLine.pair('package', app.packageName),
        if (app.sizeBytes != null)
          TermLine.pair('size', humanBytes(app.sizeBytes!)),
        if (app.targetSdk != null)
          TermLine.pair('target', 'SDK ${app.targetSdk}'),
        if (app.system) TermLine.pair('system', 'preinstalled'),
        TermLine.of('open ${app.slug} launches it', TermInk.dim),
        TermLine.of('pm uninstall ${app.slug} opens the system prompt',
            TermInk.dim),
      ];
}

class StatCommand extends TermCommand {
  const StatCommand();

  @override
  String get name => 'stat';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'size, kind and modified date';
  @override
  String? get usage => 'stat <path>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.target == null) return missing('a path');
    final TermPath path = inv.path();
    final TermEntry? entry = await inv.context.vfs.stat(path);
    if (entry == null) {
      return TermResult.error('stat: ${path.display}: no such file');
    }
    final int? size = await inv.context.vfs.sizeOf(path);
    return TermResult.lines(<TermLine>[
      TermLine.pair('path', path.display),
      TermLine.pair('kind', switch (entry.kind) {
        TermEntryKind.app => 'app',
        TermEntryKind.directory => 'directory',
        TermEntryKind.file => 'file',
      }),
      // Absent, not zero, when nothing measured it.
      if (size != null) TermLine.pair('size', humanBytes(size)),
      if (entry.childCount != null)
        TermLine.pair('holds', '${entry.childCount} entries'),
      if (entry.modified != null)
        TermLine.pair('mtime', _stamp(entry.modified)),
      if (entry.subtitle != null) TermLine.pair('package', entry.subtitle!),
    ]);
  }
}

class DuCommand extends TermCommand {
  const DuCommand();

  @override
  String get name => 'du';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'what is holding the space here, biggest first';
  @override
  String? get usage => 'du [path]';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final TermPath path = inv.path();
    final TermListing listing = await inv.context.vfs.list(path);
    if (listing.failed) return TermResult.lines(_errorLines(listing.error!));

    final List<_Sized> sized = <_Sized>[];
    var unmeasured = 0;
    for (final TermEntry e in listing.entries) {
      final int? size = e.sizeBytes ??
          await inv.context.vfs.sizeOf(path.child(e.name));
      if (size == null) {
        unmeasured++;
        continue;
      }
      sized.add(_Sized(e, size));
    }
    if (sized.isEmpty) {
      return TermResult.line('nothing measurable here', TermInk.dim);
    }
    sized.sort((_Sized a, _Sized b) => b.size.compareTo(a.size));

    final int total = sized.fold<int>(0, (int a, _Sized s) => a + s.size);

    return TermResult.lines(<TermLine>[
      for (final _Sized s in sized)
        TermLine(<TermSpan>[
          TermSpan(humanBytes(s.size).padLeft(7), TermInk.dim),
          const TermSpan('  '),
          TermSpan(
            s.entry.isDirectory ? '${s.entry.name}/' : s.entry.name,
            s.entry.standsOut ? TermInk.key : TermInk.text,
          ),
        ]),
      TermLine.of('─' * 24, TermInk.dim),
      TermLine(<TermSpan>[
        TermSpan(humanBytes(total).padLeft(7), TermInk.accent),
        TermSpan('  total in ${path.display}', TermInk.dim),
      ]),
      if (unmeasured > 0)
        TermLine.of('$unmeasured entries had no readable size', TermInk.dim),
    ]);
  }
}

class _Sized {
  const _Sized(this.entry, this.size);
  final TermEntry entry;
  final int size;
}

class FindCommand extends TermCommand {
  const FindCommand();

  static const int _maxHits = 20;

  @override
  String get name => 'find';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'search by name below here';
  @override
  String? get usage => 'find <name>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final String query = (inv.target ?? '').toLowerCase();
    if (query.isEmpty) return missing('a name fragment');

    final List<TermPath> hits = <TermPath>[];
    await _walk(inv, inv.context.cwd, query, hits, 0);
    if (hits.isEmpty) return TermResult.line('no match', TermInk.dim);
    return TermResult.lines(
      hits.map((TermPath p) => TermLine.of(p.display)).toList(),
    );
  }

  Future<void> _walk(
    TermInvocation inv,
    TermPath path,
    String query,
    List<TermPath> hits,
    int depth,
  ) async {
    if (hits.length >= _maxHits || depth > 6) return;
    final TermListing listing = await inv.context.vfs.list(path);
    if (listing.failed) return;
    for (final TermEntry e in listing.entries) {
      if (hits.length >= _maxHits) return;
      final TermPath child = path.child(e.name);
      if (e.name.toLowerCase().contains(query)) hits.add(child);
      if (e.kind == TermEntryKind.directory) {
        await _walk(inv, child, query, hits, depth + 1);
      }
    }
  }
}

/// mkdir, touch, rm, cp, mv. All of them ask [TermVfs.guardWrite] first, which
/// is what makes the wrong namespace a sentence rather than a silent nothing.
class MakeCommand extends TermCommand {
  const MakeCommand.directory() : commandName = 'mkdir';
  const MakeCommand.file() : commandName = 'touch';

  final String commandName;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help =>
      commandName == 'mkdir' ? 'make a folder' : 'make an empty file';
  @override
  String? get usage => '$commandName <name>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.target == null) return missing('a name');
    final TermPath path = inv.path();
    final TermVfsError? guard =
        await inv.context.vfs.guardWrite(path, commandName);
    if (guard != null) return TermResult.lines(_errorLines(guard));

    final TermOutcome outcome = commandName == 'mkdir'
        ? await inv.context.host.makeDirectory(path)
        : await inv.context.host.createFile(path);
    return _report(outcome, 'created ${path.display}');
  }
}

class RemoveCommand extends TermCommand {
  const RemoveCommand();

  @override
  String get name => 'rm';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'delete, -r for a folder';
  @override
  String? get usage => 'rm [-r] <path>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.target == null) return missing('a path');
    final TermPath path = inv.path();
    final TermVfsError? guard = await inv.context.vfs.guardWrite(path, 'rm');
    if (guard != null) return TermResult.lines(_errorLines(guard));

    final TermEntry? entry = await inv.context.vfs.stat(path);
    if (entry == null) {
      return TermResult.error('rm: ${path.display}: no such file');
    }
    if (entry.isDirectory && !inv.has('r')) {
      return TermResult.lines(<TermLine>[
        TermLine.of('rm: ${path.display}: is a directory', TermInk.bad),
        TermLine.of('rm -r removes it and everything under it', TermInk.dim),
      ]);
    }

    // Measured BEFORE the delete, because afterwards there is nothing to
    // measure and a reclaimed figure would have to be invented.
    final int? freed = await inv.context.vfs.sizeOf(path);
    final TermOutcome outcome =
        await inv.context.host.delete(path, recursive: inv.has('r'));
    final String reclaimed =
        freed == null ? '' : ', ${humanBytes(freed)} reclaimed';
    return _report(outcome, 'removed ${path.display}$reclaimed');
  }
}

class TransferCommand extends TermCommand {
  const TransferCommand.copy() : commandName = 'cp';
  const TransferCommand.move() : commandName = 'mv';

  final String commandName;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help =>
      commandName == 'cp' ? 'copy a file or folder' : 'move or rename';
  @override
  String? get usage => '$commandName <source> <destination>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.positionals.length < 2) {
      return missing('a source and a destination');
    }
    final TermPath from = inv.path(0);
    final TermPath to = inv.path(1);

    // Both ends are guarded. A source in /apps is the case this exists for:
    // `cp /apps/firefox ~/Download` is a reasonable thing to type and a
    // meaningless thing to do.
    final TermVfsError? guardTo =
        await inv.context.vfs.guardWrite(to, commandName);
    if (guardTo != null) return TermResult.lines(_errorLines(guardTo));
    if (from.root == TermRoot.apps) {
      return TermResult.lines(<TermLine>[
        TermLine.of('$commandName: an app is not a file you can move',
            TermInk.bad),
        TermLine.of('open ${from.name} launches it', TermInk.dim),
      ]);
    }

    final TermOutcome outcome = commandName == 'cp'
        ? await inv.context.host.copy(from, to)
        : await inv.context.host.move(from, to);
    final String verb = commandName == 'cp' ? 'copied' : 'moved';
    return _report(outcome, '$verb ${from.display} to ${to.display}');
  }
}

class OpenCommand extends TermCommand {
  const OpenCommand();

  @override
  String get name => 'open';
  @override
  TermGroup get group => TermGroup.files;
  @override
  String get help => 'hand a file to its app, or launch an app';
  @override
  String? get usage => 'open <path>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    if (inv.target == null) return missing('a path');
    final TermPath path = inv.path();

    final TermApp? app = await inv.context.vfs.appAt(path);
    if (app != null) {
      await inv.context.host.launchApp(app);
      return TermResult.lines(<TermLine>[
        TermLine(<TermSpan>[
          const TermSpan('launching ', TermInk.dim),
          TermSpan(app.label),
        ]),
      ]);
    }

    final TermEntry? entry = await inv.context.vfs.stat(path);
    if (entry == null) {
      return TermResult.error('open: ${path.display}: no such file');
    }
    final TermOutcome outcome = await inv.context.host.openFile(path);
    return _report(outcome, 'opening ${path.display}');
  }
}

TermResult _report(TermOutcome outcome, String success) {
  if (outcome.failed) {
    return TermResult.error(outcome.message ?? 'failed');
  }
  return TermResult.line(outcome.message ?? success, TermInk.dim);
}
