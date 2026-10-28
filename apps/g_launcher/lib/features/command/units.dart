import 'calc.dart';

/// The `:` mode: offline unit conversion.
///
/// "5 km in mi", ":30 c to f", ":2 gib mb". Every factor is to the dimension's
/// base unit, so a pair converts through one multiply and one divide, and a
/// unit cannot convert across dimensions by construction.
///
/// No currency here: rates go stale, and a launcher printing yesterday's
/// shilling rate as fact is worse than printing nothing. That arrives with a
/// signed daily rates file on the CDN.
class Conversion {
  const Conversion({
    required this.value,
    required this.from,
    required this.result,
    required this.to,
  });

  final double value;
  final String from;
  final double result;
  final String to;

  String get input => '${Calc.format(value)} $from';
  String get output => '${Calc.format(result)} $to';
}

abstract final class Units {
  /// "<number> <unit> [in|to|=] <unit>", spaces optional around the number.
  static final _pattern = RegExp(
    r'^\s*(-?[\d.,]+)\s*([a-zA-Z°/µ²]+)\s*(?:in|to|=|->|em|en|para)?\s*([a-zA-Z°/µ²]+)\s*$',
  );

  /// Whether [q] parses as a conversion without the `:` prefix. Needs the
  /// joining word, so an app called "5 Minute Crafts" is never a conversion.
  static bool looksLikeConversion(String q) =>
      RegExp(r'\s(in|to|em|en|para)\s', caseSensitive: false).hasMatch(q) &&
      tryConvert(q) != null;

  static Conversion? tryConvert(String q) {
    final m = _pattern.firstMatch(q);
    if (m == null) return null;
    final value = Calc.tryEval(m.group(1)!);
    if (value == null) return null;

    final from = _lookup(m.group(2)!);
    final to = _lookup(m.group(3)!);
    if (from == null || to == null || from.dim != to.dim || from == to) {
      return null;
    }

    final double result;
    if (from.dim == _Dim.temperature) {
      result = _fromKelvin(_toKelvin(value, from.symbol), to.symbol);
    } else {
      result = value * from.factor / to.factor;
    }
    return Conversion(
      value: value,
      from: from.symbol,
      result: result,
      to: to.symbol,
    );
  }

  static _Unit? _lookup(String raw) {
    // Case matters for exactly one family: b is a bit, B is a byte.
    final exact = _byAlias[raw];
    if (exact != null) return exact;
    return _byAlias[raw.toLowerCase()];
  }

  static double _toKelvin(double v, String sym) => switch (sym) {
        '°C' => v + 273.15,
        '°F' => (v - 32) * 5 / 9 + 273.15,
        _ => v,
      };

  static double _fromKelvin(double k, String sym) => switch (sym) {
        '°C' => k - 273.15,
        '°F' => (k - 273.15) * 9 / 5 + 32,
        _ => k,
      };

  static final Map<String, _Unit> _byAlias = _build();

  static Map<String, _Unit> _build() {
    final out = <String, _Unit>{};
    void add(_Dim dim, String symbol, double factor, List<String> aliases) {
      final u = _Unit(dim, symbol, factor);
      for (final a in [symbol, ...aliases]) {
        out[a] = u;
      }
    }

    // Length, base metre.
    add(_Dim.length, 'mm', 0.001, ['millimeter', 'millimetre', 'millimeters']);
    add(_Dim.length, 'cm', 0.01, ['centimeter', 'centimetre', 'centimeters']);
    add(_Dim.length, 'm', 1, ['meter', 'metre', 'meters', 'metres']);
    add(_Dim.length, 'km', 1000, ['kilometer', 'kilometre', 'kilometers', 'kms']);
    add(_Dim.length, 'in', 0.0254, ['inch', 'inches', '"']);
    add(_Dim.length, 'ft', 0.3048, ['foot', 'feet']);
    add(_Dim.length, 'yd', 0.9144, ['yard', 'yards']);
    add(_Dim.length, 'mi', 1609.344, ['mile', 'miles']);

    // Mass, base kilogram.
    add(_Dim.mass, 'mg', 1e-6, ['milligram', 'milligrams']);
    add(_Dim.mass, 'g', 0.001, ['gram', 'grams', 'gr']);
    add(_Dim.mass, 'kg', 1, ['kilogram', 'kilograms', 'kilo', 'kilos', 'kgs']);
    add(_Dim.mass, 't', 1000, ['tonne', 'tonnes', 'ton']);
    add(_Dim.mass, 'oz', 0.028349523125, ['ounce', 'ounces']);
    add(_Dim.mass, 'lb', 0.45359237, ['lbs', 'pound', 'pounds']);
    add(_Dim.mass, 'st', 6.35029318, ['stone']);

    // Volume, base litre. US measures, which are what recipes online use.
    add(_Dim.volume, 'ml', 0.001, ['milliliter', 'millilitre', 'mL']);
    add(_Dim.volume, 'l', 1, ['L', 'liter', 'litre', 'liters', 'litres']);
    add(_Dim.volume, 'gal', 3.785411784, ['gallon', 'gallons']);
    add(_Dim.volume, 'qt', 0.946352946, ['quart', 'quarts']);
    add(_Dim.volume, 'pt', 0.473176473, ['pint', 'pints']);
    add(_Dim.volume, 'cup', 0.2365882365, ['cups']);
    add(_Dim.volume, 'floz', 0.0295735295625, ['fl.oz']);

    // Data, base byte. Bits first so 'b' resolves to the bit before the
    // lowercase fallback can turn it into anything else.
    add(_Dim.data, 'bit', 0.125, ['b', 'bits']);
    add(_Dim.data, 'B', 1, ['byte', 'bytes']);
    add(_Dim.data, 'KB', 1e3, ['kb', 'kilobyte', 'kilobytes']);
    add(_Dim.data, 'MB', 1e6, ['mb', 'megabyte', 'megabytes']);
    add(_Dim.data, 'GB', 1e9, ['gb', 'gigabyte', 'gigabytes']);
    add(_Dim.data, 'TB', 1e12, ['tb', 'terabyte', 'terabytes']);
    add(_Dim.data, 'KiB', 1024, ['kib']);
    add(_Dim.data, 'MiB', 1048576, ['mib']);
    add(_Dim.data, 'GiB', 1073741824, ['gib']);
    add(_Dim.data, 'Mbit', 125000, ['mbit', 'Mb', 'megabit', 'megabits']);

    // Speed, base metre per second.
    add(_Dim.speed, 'm/s', 1, ['mps']);
    add(_Dim.speed, 'km/h', 1 / 3.6, ['kmh', 'kph', 'kmph']);
    add(_Dim.speed, 'mph', 0.44704, []);
    add(_Dim.speed, 'kn', 0.514444, ['knot', 'knots']);

    // Time, base second.
    add(_Dim.time, 's', 1, ['sec', 'secs', 'second', 'seconds']);
    add(_Dim.time, 'min', 60, ['mins', 'minute', 'minutes']);
    add(_Dim.time, 'h', 3600, ['hr', 'hrs', 'hour', 'hours']);
    add(_Dim.time, 'd', 86400, ['day', 'days']);
    add(_Dim.time, 'wk', 604800, ['week', 'weeks']);

    // Temperature, converted through kelvin rather than by factor.
    add(_Dim.temperature, '°C', 1, ['c', 'C', 'celsius', '°c']);
    add(_Dim.temperature, '°F', 1, ['f', 'F', 'fahrenheit', '°f']);
    add(_Dim.temperature, 'K', 1, ['k', 'kelvin']);
    return out;
  }
}

enum _Dim { length, mass, volume, data, speed, time, temperature }

class _Unit {
  const _Unit(this.dim, this.symbol, this.factor);

  final _Dim dim;
  final String symbol;
  final double factor;
}
