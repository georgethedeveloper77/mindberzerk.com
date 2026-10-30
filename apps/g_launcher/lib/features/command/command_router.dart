import 'bangs.dart';
import 'calc.dart';
import 'search_engines.dart';
import 'units.dart';

/// One answer the command bar can give besides apps.
sealed class CommandHit {
  const CommandHit();
}

/// `=1250*3.5`, or a bare sum.
class CalcHit extends CommandHit {
  const CalcHit(this.expression, this.value);

  final String expression;
  final double value;

  String get display => Calc.format(value);
}

/// `:5 km in mi`, or a bare "5 km in mi".
class ConvertHit extends CommandHit {
  const ConvertHit(this.conversion);

  final Conversion conversion;
}

/// `!yt linux rice`.
class BangSearchHit extends CommandHit {
  const BangSearchHit(this.hit);

  final BangHit hit;
}

/// `!y` while the key is still being typed: the bangs it could become.
class BangHintHit extends CommandHit {
  const BangHintHit(this.bangs);

  final List<Bang> bangs;
}

/// What a query means, decided once for every search surface.
class CommandRoute {
  const CommandRoute({required this.hits, required this.searchApps});

  final List<CommandHit> hits;

  /// False for an explicit mode (`=`, `:`, `!`): the person asked for a sum
  /// or a site, and an app grid underneath would only push the answer away.
  /// True for plain text, including text that merely LOOKS like a sum, so
  /// "2048" the game is still found.
  final bool searchApps;

  static const empty = CommandRoute(hits: [], searchApps: true);
}

/// The mode router: rofi's `-modi`, KRunner's runners, in one function.
///
/// Pure Dart, no Flutter, so the GNOME search page, the drop-down sheet and
/// rofi all route identically and the rules are unit-tested in one place.
abstract final class CommandRouter {
  static CommandRoute route(String raw, {List<Bang> extraBangs = const []}) {
    final q = raw.trim();
    if (q.isEmpty) return CommandRoute.empty;

    switch (q[0]) {
      case '=':
        final expr = q.substring(1).trim();
        final v = Calc.tryEval(expr);
        return CommandRoute(
          hits: [if (v != null) CalcHit(expr, v)],
          searchApps: false,
        );
      case ':':
        final c = Units.tryConvert(q.substring(1));
        return CommandRoute(
          hits: [if (c != null) ConvertHit(c)],
          searchApps: false,
        );
      case '!':
        final hit = Bangs.resolve(q, extra: extraBangs);
        if (hit != null) {
          return CommandRoute(hits: [BangSearchHit(hit)], searchApps: false);
        }
        final hints = Bangs.suggest(q, extra: extraBangs);
        return CommandRoute(
          hits: [if (hints.isNotEmpty) BangHintHit(hints)],
          searchApps: false,
        );
    }

    // Implicit forms: answered alongside the apps, never instead of them.
    final hits = <CommandHit>[];
    final trailing = Bangs.resolve(q, extra: extraBangs);
    if (trailing != null) hits.add(BangSearchHit(trailing));
    if (Calc.looksLikeMath(q)) {
      hits.add(CalcHit(q, Calc.tryEval(q)!));
    } else if (Units.looksLikeConversion(q)) {
      hits.add(ConvertHit(Units.tryConvert(q)!));
    }
    return CommandRoute(hits: hits, searchApps: trailing == null);
  }

  /// The web fallback, for the "Search the web" row, on the chosen engine.
  static String webSearchUrl(
    String q, {
    SearchEngine engine = SearchEngine.google,
  }) =>
      engine.urlFor(q);

  /// The Play fallback, for the "Search Play Store" row.
  static String playSearchUrl(String q) =>
      'market://search?q=${Uri.encodeQueryComponent(q.trim())}&c=apps';
}
