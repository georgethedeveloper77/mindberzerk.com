/// The engines the "Search the web" row can use.
///
/// Pure Dart, like the router, so the default and every template are covered
/// by the same unit tests. Ids are stored in prefs: never rename one, only
/// add new engines at the end.
class SearchEngine {
  const SearchEngine(this.id, this.label, this.host, this.template);

  /// Stored in prefs.
  final String id;

  /// Shown on the settings page and in the fallback row.
  final String label;

  /// The second line on the settings page.
  final String host;

  /// URL with `%s` where the encoded terms go.
  final String template;

  String urlFor(String terms) =>
      template.replaceAll('%s', Uri.encodeQueryComponent(terms.trim()));

  static const google = SearchEngine(
    'google',
    'Google',
    'google.com',
    'https://www.google.com/search?q=%s',
  );

  static const all = <SearchEngine>[
    google,
    SearchEngine(
      'duckduckgo',
      'DuckDuckGo',
      'duckduckgo.com',
      'https://duckduckgo.com/?q=%s',
    ),
    SearchEngine(
      'brave',
      'Brave Search',
      'search.brave.com',
      'https://search.brave.com/search?q=%s',
    ),
    SearchEngine(
      'bing',
      'Bing',
      'bing.com',
      'https://www.bing.com/search?q=%s',
    ),
    SearchEngine(
      'startpage',
      'Startpage',
      'startpage.com',
      'https://www.startpage.com/do/search?q=%s',
    ),
    SearchEngine(
      'ecosia',
      'Ecosia',
      'ecosia.org',
      'https://www.ecosia.org/search?q=%s',
    ),
  ];

  /// The engine for a stored id. An unknown id (a newer build's engine read
  /// by an older one) falls back to Google rather than to nothing.
  static SearchEngine byId(String? id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return google;
  }
}
