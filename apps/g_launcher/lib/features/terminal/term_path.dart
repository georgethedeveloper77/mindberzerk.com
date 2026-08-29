/// The shell's path model.
///
/// Two roots under `/`, and that is the whole design:
///
///   /apps      every launchable app, one entry each
///   /sdcard    the granted folder, displayed as `~`
///
/// Apps are the phone's `/proc`: not files, rendered as files, so that `ls`,
/// `cat`, `stat`, `du`, `find` and `open` all do double duty without a single
/// extra command. The namespace a path lands in is decided HERE and nowhere
/// else, which is what stops a verb from half working in the wrong one.
///
/// Pure Dart on purpose. No Flutter, no Riverpod, no host. Every rule in this
/// file is covered by `test/terminal/term_path_test.dart`.
library;

enum TermRoot {
  /// `/apps`
  apps,

  /// `/sdcard`, shown as `~`
  files,
}

/// An absolute path, normalised, as a list of segments below `/`.
///
/// `parts` is empty for `/` itself. `parts.first` names the root, and a first
/// segment that is neither `apps` nor `sdcard` gives a null [root], which is
/// how `/etc` fails as "no such directory" rather than as a crash.
class TermPath {
  const TermPath(this.parts);

  /// `/`
  static const TermPath slash = TermPath(<String>[]);

  /// `/apps`, where the shell starts.
  ///
  /// Not `~`: on a fresh install there is no folder grant yet, so a shell that
  /// opened in `~` would answer the user's first `ls` with an error. Starting
  /// here means the first keystroke shows their apps, and `cd ~` is what asks
  /// for the grant, at the moment they actually wanted files.
  static const TermPath appsRoot = TermPath(<String>['apps']);

  /// `~`
  static const TermPath filesRoot = TermPath(<String>['sdcard']);

  final List<String> parts;

  TermRoot? get root {
    if (parts.isEmpty) return null;
    return switch (parts.first) {
      'apps' => TermRoot.apps,
      'sdcard' => TermRoot.files,
      _ => null,
    };
  }

  /// Segments below the root. Empty at `/apps` and at `~`.
  List<String> get rest => parts.isEmpty ? const <String>[] : parts.sublist(1);

  bool get isSlash => parts.isEmpty;
  bool get isRootOfNamespace => parts.length == 1 && root != null;

  /// The last segment, or null at `/`.
  String? get name => parts.isEmpty ? null : parts.last;

  TermPath get parent =>
      parts.isEmpty ? slash : TermPath(parts.sublist(0, parts.length - 1));

  TermPath child(String segment) => TermPath(<String>[...parts, segment]);

  /// What the prompt and every error message print.
  ///
  /// `~` rather than `/sdcard`, because that is what a shell shows and what the
  /// user typed. `/apps` stays literal: there is no home shorthand for it and
  /// inventing one would be a second name for one place.
  String get display {
    if (parts.isEmpty) return '/';
    if (root == TermRoot.files) {
      return rest.isEmpty ? '~' : '~/${rest.join('/')}';
    }
    return '/${parts.join('/')}';
  }

  /// Resolve [arg] against [cwd].
  ///
  /// Handles `~`, `~/x`, absolute, relative, `.`, `..`, doubled and trailing
  /// slashes. A `..` above `/` stays at `/` rather than underflowing.
  static TermPath resolve(String? arg, TermPath cwd) {
    final raw = (arg ?? '').trim();
    if (raw.isEmpty) return cwd;

    List<String> base;
    String tail;

    if (raw == '~') {
      return filesRoot;
    } else if (raw.startsWith('~/')) {
      base = <String>['sdcard'];
      tail = raw.substring(2);
    } else if (raw.startsWith('/')) {
      base = <String>[];
      tail = raw.substring(1);
    } else {
      base = List<String>.of(cwd.parts);
      tail = raw;
    }

    final out = List<String>.of(base);
    for (final segment in tail.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(segment);
    }
    return TermPath(out);
  }

  @override
  bool operator ==(Object other) =>
      other is TermPath &&
      other.parts.length == parts.length &&
      _sameParts(other.parts);

  bool _sameParts(List<String> other) {
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => display;
}
