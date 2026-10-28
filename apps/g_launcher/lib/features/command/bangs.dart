/// The `!` mode: DuckDuckGo-style bangs.
///
/// `!yt linux rice` opens YouTube's search for "linux rice". The built-in list
/// is short on purpose (sites people actually search from a phone, plus the
/// two a Linux launcher's users will reach for); user-defined bangs arrive
/// with their own settings page and are merged over these by key.
class Bang {
  const Bang(this.key, this.label, this.template);

  /// What follows the `!`, lowercase.
  final String key;

  /// Shown on the result row: "Search YouTube".
  final String label;

  /// URL with `%s` where the encoded terms go.
  final String template;

  String urlFor(String terms) =>
      template.replaceAll('%s', Uri.encodeQueryComponent(terms));
}

/// A typed bang, resolved.
class BangHit {
  const BangHit(this.bang, this.terms);

  final Bang bang;
  final String terms;

  String get url => bang.urlFor(terms);
}

abstract final class Bangs {
  static const builtIn = <Bang>[
    Bang('g', 'Google', 'https://www.google.com/search?q=%s'),
    Bang('ddg', 'DuckDuckGo', 'https://duckduckgo.com/?q=%s'),
    Bang('yt', 'YouTube', 'https://www.youtube.com/results?search_query=%s'),
    Bang('w', 'Wikipedia', 'https://en.wikipedia.org/w/index.php?search=%s'),
    Bang('aw', 'Arch Wiki', 'https://wiki.archlinux.org/index.php?search=%s'),
    Bang('gh', 'GitHub', 'https://github.com/search?q=%s'),
    Bang('so', 'Stack Overflow', 'https://stackoverflow.com/search?q=%s'),
    Bang('r', 'Reddit', 'https://www.reddit.com/search/?q=%s'),
    Bang('play', 'Play Store', 'market://search?q=%s&c=apps'),
    Bang('maps', 'Maps', 'geo:0,0?q=%s'),
    Bang('x', 'X', 'https://x.com/search?q=%s'),
    Bang('tr', 'Google Translate', 'https://translate.google.com/?sl=auto&text=%s'),
  ];

  /// `!key terms` or `terms !key`, the two orders DuckDuckGo accepts.
  /// Null for a bare `!key` with no terms, or an unknown key.
  static BangHit? resolve(String raw, {List<Bang> extra = const []}) {
    final q = raw.trim();
    final lead = RegExp(r'^!(\S+)\s+(.+)$').firstMatch(q);
    final trail = RegExp(r'^(.+?)\s+!(\S+)$').firstMatch(q);

    final String key;
    final String terms;
    if (lead != null) {
      key = lead.group(1)!;
      terms = lead.group(2)!;
    } else if (trail != null) {
      key = trail.group(2)!;
      terms = trail.group(1)!;
    } else {
      return null;
    }
    final bang = find(key, extra: extra);
    return bang == null ? null : BangHit(bang, terms.trim());
  }

  static Bang? find(String key, {List<Bang> extra = const []}) {
    final k = key.toLowerCase();
    for (final b in extra) {
      if (b.key == k) return b;
    }
    for (final b in builtIn) {
      if (b.key == k) return b;
    }
    return null;
  }

  /// Bangs whose key starts with what follows a lone `!`, for the hint chips
  /// shown while the key is still being typed.
  static List<Bang> suggest(String raw, {List<Bang> extra = const []}) {
    final m = RegExp(r'^!(\S*)$').firstMatch(raw.trim());
    if (m == null) return const [];
    final p = m.group(1)!.toLowerCase();
    return [
      for (final b in [...extra, ...builtIn])
        if (b.key.startsWith(p)) b,
    ];
  }
}
