// i18n_extract.dart
//
// Finds EVERY user-facing string in lib/, gives each a stable key, and merges
// those keys into assets/i18n/en.json. Uses the Dart analyzer's SYNTACTIC
// parser (parseString), so no build or package resolution is needed.
//
// Setup (once):
//   dart pub add --dev analyzer
//
// Run:
//   dart run tool/i18n_extract.dart                 # report + merge en.json
//   dart run tool/i18n_extract.dart --write         # ALSO rewrite lib/ sources
//   dart run tool/i18n_extract.dart --ref           # rewrite with ref.t (default context.t)
//   dart run tool/i18n_extract.dart --dir lib/features/setup   # limit scope
//
// SAFETY (hard guarantees, added after a rewrite once mangled import lines):
//   1. Strings inside ANY directive (import/export/part/library) are never
//      touched: they are code, and rewriting one breaks the file at line 1.
//   2. Strings that look like URIs or file references (package:, dart:, .dart)
//      are rejected by the heuristics as a second, independent layer.
//   3. After rewriting a file, the result is RE-PARSED. If the rewrite
//      introduced even one syntax error the file is NOT written and is
//      reported instead. A bug in this tool can now cost you a skipped file,
//      never a broken one.
//
// --write remains best effort in one honest way: it cannot know whether
// `context`/`ref` is in scope at a call site, or whether a literal sits inside
// a `const` widget (wrapping makes it non-const). Those surface as ANALYZER
// errors, not parse errors, so run --write on a branch and compile after.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// Calls whose string arguments are code, not copy. A string ANYWHERE beneath
// one of these is skipped.
const _ignoredCalls = {
  'debugPrint', 'print', 'log', 'jsonDecode', 'jsonEncode', 'DateFormat',
  'loadString', 'contains', 'startsWith', 'endsWith', 'split', 'replaceAll',
  'replaceFirst', 'matches', 'setUp', 'logEvent', 'setCustomKey', 'named',
};

// Constructors whose string arguments are code. Anything ending in Exception or
// Error is also skipped (handled below), so this is just the odd ones out.
const _ignoredCtors = {'RegExp', 'Uri', 'Duration', 'Key', 'ValueKey', 'Locale'};

// Named arguments that carry identifiers, not copy.
const _ignoredNamedArgs = {
  'fontFamily', 'package', 'key', 'restorationId', 'debugLabel', 'name',
};

class _Hit {
  _Hit(this.offset, this.length, this.value, this.line);
  final int offset;
  final int length;
  final String value;
  final int line;
  late String key;
}

void main(List<String> args) {
  final write = args.contains('--write');
  final useRef = args.contains('--ref');
  final dirs = _argValues(args, '--dir');
  final roots = dirs.isEmpty ? ['lib'] : dirs;

  const enPath = 'assets/i18n/en.json';
  final existing = _readJson(enPath);
  final valueToKey = <String, String>{};
  existing.forEach((k, v) => valueToKey.putIfAbsent(v, () => k));

  final pkg = _packageName();
  final usedKeys = existing.keys.toSet();
  final report = <String>[];
  final skipped = <String>[];
  var added = 0;
  var rewrittenFiles = 0;

  for (final root in roots) {
    for (final file in _dartFiles(root)) {
      final hits = _scan(file);
      if (hits.isEmpty) continue;

      for (final h in hits) {
        final reused = valueToKey[h.value];
        if (reused != null) {
          h.key = reused;
        } else {
          h.key = _uniqueKey(_makeKey(file.path, h.value), usedKeys);
          usedKeys.add(h.key);
          valueToKey[h.value] = h.key;
          existing[h.key] = h.value;
          added++;
        }
        final preview = h.value.length > 60 ? '${h.value.substring(0, 57)}...' : h.value;
        report.add('${file.path}:${h.line}  ${h.key}  ->  "$preview"');
      }

      if (write) {
        switch (_rewrite(file, hits, useRef: useRef, pkg: pkg)) {
          case _RewriteResult.written:
            rewrittenFiles++;
          case _RewriteResult.skippedBrokenParse:
            skipped.add(file.path);
        }
      }
    }
  }

  _writeJson(enPath, existing);

  stdout.writeln(report.isEmpty ? '(no new strings found)' : report.join('\n'));
  stdout.writeln('');
  stdout.writeln('Added $added new key(s) to $enPath (total ${existing.length}).');
  if (write) {
    stdout.writeln('Rewrote $rewrittenFiles file(s). Compile now: check every '
        '.t(...) has ${useRef ? "a WidgetRef" : "a BuildContext"} in scope and '
        'drop any `const` that now fails.');
    if (skipped.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('NOT written (rewrite would have broken the parse — file '
          'left untouched, wrap these by hand):');
      for (final p in skipped) {
        stdout.writeln('  $p');
      }
    }
  } else {
    stdout.writeln('Review the keys above, then re-run with --write to wrap them.');
  }
}

// --- scanning ---------------------------------------------------------------

List<_Hit> _scan(File file) {
  final src = file.readAsStringSync();
  final result = parseString(content: src, throwIfDiagnostics: false);
  final visitor = _Collector(result.lineInfo);
  result.unit.accept(visitor);
  return visitor.hits;
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.lineInfo);
  final dynamic lineInfo; // LineInfo, kept dynamic to dodge analyzer API churn
  final hits = <_Hit>[];
  final _seen = <int>{};

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is! AdjacentStrings) _consider(node);
    super.visitSimpleStringLiteral(node);
  }

  // 'a long string that Dart '
  // 'joins across two lines'  ->  captured as ONE value, ONE key.
  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _consider(node);
    super.visitAdjacentStrings(node);
  }

  void _consider(StringLiteral node) {
    final value = node.stringValue; // null if any part interpolates (${...})
    if (value == null) return;
    if (!_shouldTranslate(value)) return;
    if (_inIgnoredContext(node)) return;
    if (!_seen.add(node.offset)) return;
    final loc = lineInfo.getLocation(node.offset);
    hits.add(_Hit(node.offset, node.length, value, loc.lineNumber as int));
  }

  bool _inIgnoredContext(AstNode node) {
    for (AstNode? a = node.parent; a != null; a = a.parent) {
      // THE GUARD THAT WAS MISSING: an import/export/part/library URI is a
      // string literal too, and rewriting one destroys the file at line 1.
      // Directives are never copy. Checked before anything else, and before
      // the FunctionBody early-exit (directives sit outside any function).
      if (a is Directive) return true;
      if (a is Configuration) return true; // `if (dart.library.io) 'uri'`
      if (a is MethodInvocation && _ignoredCalls.contains(a.methodName.name)) {
        return true;
      }
      if (a is InstanceCreationExpression) {
        final nm = a.constructorName.type.toSource().split('<').first.split('.').last;
        if (_ignoredCtors.contains(nm) || nm.endsWith('Exception') || nm.endsWith('Error')) {
          return true;
        }
      }
      if (a is AssertStatement || a is AssertInitializer) return true;
      if (a is ThrowExpression) return true;
      if (a is Annotation) return true;
      if (a is NamedExpression && _ignoredNamedArgs.contains(a.name.label.name)) {
        return true;
      }
      // Stop at the enclosing function so the walk stays cheap. Safe AFTER the
      // directive check above, which never sits inside a function body.
      if (a is FunctionBody) break;
    }
    return false;
  }
}

// --- heuristics -------------------------------------------------------------

final _identifierLike = RegExp(r'^[a-z0-9_.\-/]+$'); // no spaces, no caps
final _hasLetter = RegExp(r'[A-Za-z]');
final _bareUrl = RegExp(r'^https?://\S+$');

bool _shouldTranslate(String s) {
  final t = s.trim();
  if (t.length < 2) return false;
  if (!_hasLetter.hasMatch(t)) return false; // pure symbols / numbers
  if (_bareUrl.hasMatch(t)) return false; // a lone URL is not copy
  // SECOND LAYER for the directive bug: URI-shaped strings are never copy,
  // wherever they appear (imports are already excluded structurally above).
  if (t.startsWith('package:') || t.startsWith('dart:')) return false;
  if (t.startsWith('assets/')) return false; // asset paths
  if (t.startsWith('com.') || t.startsWith('android.')) return false; // ids
  for (final ext in const ['.dart', '.png', '.svg', '.json', '.txt', '.ttf', '.webp']) {
    if (t.endsWith(ext)) return false;
  }
  // A no-space, all-lowercase-ish token is a key/route/segment, not display
  // copy. "[Russia](https://...)" is NOT caught here (brackets, a capital and
  // a colon), so a markdown link survives.
  if (!t.contains(' ') && _identifierLike.hasMatch(t)) return false;
  return true;
}

// --- key generation ---------------------------------------------------------

String _makeKey(String path, String value) {
  final unix = path.replaceAll('\\', '/');
  String area;
  final m = RegExp(r'lib/features/([^/]+)/').firstMatch(unix);
  if (m != null) {
    area = m.group(1)!;
  } else if (unix.contains('lib/shells/')) {
    area = 'shell';
  } else if (unix.contains('lib/design/')) {
    area = 'design';
  } else {
    area = unix.split('/').last.replaceAll('.dart', '');
  }
  return '$area.${_slug(value)}';
}

String _slug(String value) {
  // Strip URLs and markdown link targets so the key derives from the VISIBLE
  // words. "[Russia](https://long-url)" -> "russia".
  final cleaned = value
      .replaceAll(RegExp(r'\(https?://[^)]*\)'), ' ')
      .replaceAll(RegExp(r'https?://\S+'), ' ');
  final words = cleaned
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .take(4)
      .toList();
  if (words.isEmpty) return 'text';
  final buf = StringBuffer(words.first);
  for (final w in words.skip(1)) {
    buf.write(w[0].toUpperCase() + w.substring(1));
  }
  var s = buf.toString();
  if (RegExp(r'^[0-9]').hasMatch(s)) s = 't$s';
  return s;
}

String _uniqueKey(String base, Set<String> used) {
  if (!used.contains(base)) return base;
  var i = 2;
  while (used.contains('${base}_$i')) {
    i++;
  }
  return '${base}_$i';
}

// --- rewriting (--write) ----------------------------------------------------

enum _RewriteResult { written, skippedBrokenParse }

int _parseErrorCount(String src) =>
    parseString(content: src, throwIfDiagnostics: false).errors.length;

_RewriteResult _rewrite(File file, List<_Hit> hits,
    {required bool useRef, required String pkg}) {
  final original = file.readAsStringSync();
  var src = original;
  final sorted = [...hits]..sort((a, b) => b.offset.compareTo(a.offset));
  final call = useRef ? 'ref.t' : 'context.t';
  for (final h in sorted) {
    final replacement = "$call('${h.key}')";
    src = src.substring(0, h.offset) + replacement + src.substring(h.offset + h.length);
  }
  src = _ensureImport(src, pkg);

  // THE BACKSTOP: if the rewritten file parses worse than the original, the
  // rewrite is wrong somewhere, and the only safe move is to not write it.
  // (Compared against the original's count, not zero, so a file that already
  // had a pre-existing parse error can still be processed.)
  if (_parseErrorCount(src) > _parseErrorCount(original)) {
    return _RewriteResult.skippedBrokenParse;
  }

  file.writeAsStringSync(src);
  return _RewriteResult.written;
}

/// Adds `import 'package:<pkg>/i18n/i18n.dart';` after the last import if the
/// file does not already reference it.
String _ensureImport(String src, String pkg) {
  const marker = 'i18n/i18n.dart';
  if (src.contains(marker)) return src;
  final imports = RegExp(r'''^import\s+['"][^'"]+['"].*;$''', multiLine: true)
      .allMatches(src)
      .toList();
  final line = "import 'package:$pkg/i18n/i18n.dart';";
  if (imports.isEmpty) return '$line\n$src';
  final last = imports.last;
  return '${src.substring(0, last.end)}\n$line${src.substring(last.end)}';
}

// --- io helpers -------------------------------------------------------------

Iterable<File> _dartFiles(String root) sync* {
  final dir = Directory(root);
  if (!dir.existsSync()) return;
  for (final e in dir.listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final p = e.path.replaceAll('\\', '/');
    if (!p.endsWith('.dart')) continue;
    if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) continue;
    if (p.contains('/i18n/')) continue;
    if (p.contains('/generated/')) continue;
    yield e;
  }
}

Map<String, String> _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  final decoded = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((k, v) => MapEntry(k, '$v'));
}

void _writeJson(String path, Map<String, String> map) {
  final keys = map.keys.toList()..sort();
  final buf = StringBuffer('{\n');
  for (var i = 0; i < keys.length; i++) {
    final k = keys[i];
    final comma = i == keys.length - 1 ? '' : ',';
    buf.writeln('  ${json.encode(k)}: ${json.encode(map[k])}$comma');
  }
  buf.write('}\n');
  File(path).writeAsStringSync(buf.toString());
}

String _packageName() {
  final f = File('pubspec.yaml');
  if (!f.existsSync()) return 'g_launcher';
  final m = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(f.readAsStringSync());
  return m?.group(1) ?? 'g_launcher';
}

List<String> _argValues(List<String> args, String flag) {
  final out = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == flag) out.add(args[i + 1]);
  }
  return out;
}
