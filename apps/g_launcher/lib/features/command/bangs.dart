/// The `!` mode: DuckDuckGo-style bangs.
///
/// `!yt linux rice` opens YouTube's search for "linux rice". The built-in list
/// is short on purpose (sites people actually search from a phone, plus the
/// two a Linux launcher's users will reach for). User-defined bangs come from
/// the Search settings page and are merged over these by key.
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

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'template': template,
      };

  /// Null for an entry that fails [BangRules], so a hand-edited or corrupt
  /// backup cannot smuggle in a bang the editor would have refused.
  static Bang? fromJson(Map<String, dynamic> j) {
    final key = BangRules.normalizeKey('${j['key'] ?? ''}');
    final label = '${j['label'] ?? ''}'.trim();
    final template = '${j['template'] ?? ''}'.trim();
    if (BangRules.keyError(key) != null ||
        BangRules.labelError(label) != null ||
        BangRules.templateError(template) != null) {
      return null;
    }
    return Bang(key, label, template);
  }

  @override
  bool operator ==(Object other) =>
      other is Bang &&
      other.key == key &&
      other.label == label &&
      other.template == template;

  @override
  int get hashCode => Object.hash(key, label, template);
}

/// What a user-defined bang has to satisfy.
///
/// Every check returns an i18n key naming the problem, or null when that
/// field is fine, so the editor can mark each field on its own.
///
/// ─── HTTP AND HTTPS ONLY ──────────────────────────────────────────────────
///
/// A bang is opened as an Android VIEW intent. Built-in bangs may use
/// `market:` and `geo:` because they ship reviewed; a typed one is held to
/// the web schemes, so a pasted `javascript:`, `intent:` or `file:` template
/// is refused instead of being handed to whatever app claims it.
abstract final class BangRules {
  static const maxCustom = 50;
  static const maxKeyLength = 16;
  static const maxLabelLength = 40;
  static const placeholder = '%s';

  static final _key = RegExp(r'^[a-z0-9._-]+$');

  /// Lowercased, trimmed, and without a leading `!` someone typed by habit.
  static String normalizeKey(String raw) =>
      raw.trim().replaceFirst(RegExp(r'^!+'), '').toLowerCase();

  static String? keyError(String key) {
    if (key.isEmpty || key.length > maxKeyLength || !_key.hasMatch(key)) {
      return 'searchSettings.errKey';
    }
    return null;
  }

  static String? labelError(String label) {
    final l = label.trim();
    if (l.isEmpty || l.length > maxLabelLength) {
      return 'searchSettings.errName';
    }
    return null;
  }

  static String? templateError(String template) {
    final t = template.trim();
    if (!t.contains(placeholder)) return 'searchSettings.errPlaceholder';
    // Parsed with the placeholder filled, since `%s` alone is not a valid
    // percent escape and would make an otherwise good URL fail to parse.
    // The filler must not land in the host: then the typed words would pick
    // the site, not the search.
    const filler = 'gbangterms';
    final uri = Uri.tryParse(t.replaceAll(placeholder, filler));
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.host.contains(filler)) {
      return 'searchSettings.errUrl';
    }
    return null;
  }
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
    Bang('tr', 'Google Translate',
        'https://translate.google.com/?sl=auto&text=%s'),
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
