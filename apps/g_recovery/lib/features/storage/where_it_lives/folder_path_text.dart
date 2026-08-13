library;

import 'package:flutter/material.dart';

/// A file path rendered so it wraps instead of being cut off.
///
/// Flutter finds no break opportunity inside a path, because a path has no
/// whitespace, so a long one truncates on the first line even when there is
/// room underneath. Inserting a zero width space after each separator gives the
/// line breaker somewhere to break, and the character itself renders as nothing.
///
/// Ellipsis stays as the last resort for paths that are absurd even wrapped.
class FolderPathText extends StatelessWidget {
  const FolderPathText(
    this.path, {
    super.key,
    this.maxLines = 2,
    this.style,
    this.rootLabel = 'Internal storage',
  });

  final String path;
  final int maxLines;
  final TextStyle? style;

  /// Shown when the path resolves to the volume root, which has no name.
  final String rootLabel;

  static const String _breakHint = '\u200B';

  /// Exposed so the same treatment can be applied inside other text runs.
  static String wrappable(String value) =>
      value.replaceAll('/', '/$_breakHint');

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();
    final text = trimmed.isEmpty ? rootLabel : wrappable(trimmed);

    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style:
          style ??
          const TextStyle(fontSize: 12, color: Color(0xFF6B7878), height: 1.45),
    );
  }
}
