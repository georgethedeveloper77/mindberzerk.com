/// The lines a session keeps, and the cap on how many.
///
/// Separate from [AnsiParser] because they answer different questions. The
/// parser turns bytes into lines and has no opinion about history; the buffer
/// decides what history is worth keeping and what to drop when there is too
/// much of it. Folding them together would mean a parser that cannot be tested
/// without also testing eviction.
library;

import 'ansi.dart';

/// A bounded, append-only view of session output.
///
/// ─── WHY A LIST AND NOT A CIRCULAR BUFFER ───────────────────────────────────
///
/// A ring buffer is the textbook answer and it is the wrong one here. Every
/// read of this is a rebuild of a scrolling list that wants `lines[i]` in
/// display order, and a ring hands back an index that needs rotating on every
/// access. Removing from the front of a Dart List is O(n) in the number of
/// lines dropped, which at the eviction rate a phone terminal sees is a few
/// hundred pointer moves against a cap that starts at 5000.
///
/// The trade is measured against the workload rather than against the general
/// case: eviction is rare and reads are constant, so pay on eviction.
class TerminalBuffer {
  TerminalBuffer({required int maxLines})
      : _maxLines = maxLines < 1 ? 1 : maxLines;

  int _maxLines;

  final List<AnsiLine> _lines = [];

  /// Lines dropped since the buffer was created.
  ///
  /// Exposed so a UI can say history was truncated rather than silently
  /// pretending the session started where the buffer does. A terminal that
  /// quietly forgets is one nobody trusts with a long build log.
  int get droppedLines => _dropped;
  int _dropped = 0;

  int get maxLines => _maxLines;

  /// Every retained line, oldest first.
  List<AnsiLine> get lines => List.unmodifiable(_lines);

  int get length => _lines.length;

  bool get isEmpty => _lines.isEmpty;

  AnsiLine operator [](int i) => _lines[i];

  void add(AnsiLine line) {
    _lines.add(line);
    _evict();
  }

  void addAll(Iterable<AnsiLine> lines) {
    _lines.addAll(lines);
    _evict();
  }

  /// Drain a parser's finished lines into this buffer.
  ///
  /// The pairing every caller wants, kept here so no caller has to remember
  /// that reading `committed` without draining it appends the same lines twice.
  void drain(AnsiParser parser) => addAll(parser.takeCommitted());

  /// Change the cap, evicting immediately if it shrank.
  ///
  /// Applied at once rather than on the next write, because the setting exists
  /// for memory and a cap that takes effect eventually does not relieve
  /// anything now.
  void setMaxLines(int value) {
    _maxLines = value < 1 ? 1 : value;
    _evict();
  }

  /// Everything, unstyled. For copy, for share, for a test.
  String get text => _lines.map((l) => l.text).join('\n');

  void clear() {
    _lines.clear();
    // Dropped is NOT reset. It counts what was lost to the cap, and a clear is
    // the user choosing to discard rather than the buffer failing to keep up.
    // Conflating the two would make the truncation notice lie after a clear.
  }

  void _evict() {
    if (_lines.length <= _maxLines) return;
    final excess = _lines.length - _maxLines;
    _lines.removeRange(0, excess);
    _dropped += excess;
  }
}
