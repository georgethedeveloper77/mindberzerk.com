/// Turning a theme's prompt template into the string on screen.
///
/// Separate from the widget because it is a pure string operation with rules
/// worth testing on their own, and because both the TUI shell and the Terminal
/// app will want it without wanting the same widget.
library;

/// Render [template], substituting the tokens a theme is allowed to use.
///
/// ─── AN UNKNOWN TOKEN RENDERS LITERALLY ─────────────────────────────────────
///
/// `{colour}` comes out as `{colour}`, not as nothing. Stripping it would leave
/// a prompt silently missing a segment, and the author would see a prompt that
/// looks almost right and have no idea which part failed. A brace left on
/// screen is a mistake anyone can see and fix in one edit.
///
/// This is the same choice the schema comment on `terminal.prompt` records, and
/// the reason it is written down in two places is that they are two different
/// audiences: the author reading the schema, and whoever changes this function.
String renderPrompt(
  String template, {
  String user = 'user',
  String? host,
  String cwd = '~',
  String distro = '',
  int exitCode = 0,
}) {
  // `{host}` with no host resolves to EMPTY, and the separator that would have
  // preceded it goes with it. There is no way to get a hostname on Android, so
  // `user@` with nothing after it is the common case, not the exceptional one,
  // and a prompt ending in a bare `@` looks broken rather than minimal.
  final resolvedHost = host?.trim() ?? '';

  var out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final ch = template[i];
    if (ch != '{') {
      out.write(ch);
      i++;
      continue;
    }

    final close = template.indexOf('}', i);
    if (close < 0) {
      // An unterminated brace is the rest of the template, verbatim.
      out.write(template.substring(i));
      break;
    }

    final token = template.substring(i + 1, close);
    final value = switch (token) {
      'user' => user,
      'host' => resolvedHost,
      'cwd' => cwd,
      'distro' => distro,
      'exit' => '$exitCode',
      _ => null,
    };

    if (value == null) {
      // Unknown. Keep the braces so the author can see what they typed.
      out.write(template.substring(i, close + 1));
    } else {
      out.write(value);
    }
    i = close + 1;
  }

  return _collapseEmptyHost(out.toString(), resolvedHost.isEmpty);
}

/// Drop a separator left dangling by an empty `{host}`.
///
/// Handles the two spellings that actually appear in the default prompts,
/// `user@host` and `[user@host cwd]`. Deliberately not a general grammar: a
/// prompt template is a small enough surface that guessing at every possible
/// separator would remove characters an author meant to keep.
String _collapseEmptyHost(String s, bool hostWasEmpty) {
  if (!hostWasEmpty) return s;
  return s.replaceAll('@:', ':').replaceAll('@ ', ' ').replaceAll('@]', ']');
}
