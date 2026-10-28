import 'dart:math' as math;

/// The `=` mode: a small, safe arithmetic evaluator.
///
/// Recursive descent over + - * / ^ %, parentheses and unary minus. No
/// `eval`, no variables, no functions: a launcher calculator answers
/// "what is 1250 times 3.5", and every feature past that is a way for a typed
/// app name to be mistaken for a sum.
///
/// `%` is POSTFIX percent ("200*15%" is 30), the way phone calculators read
/// it, not modulo.
abstract final class Calc {
  /// Characters a query may contain to be treated as arithmetic without the
  /// `=` prefix. Letters anywhere (except the x multiply sign between numbers)
  /// mean it is an app name, so "7-Zip" never turns into a sum.
  static final _mathish = RegExp(r'^[\d\s.,+\-*/×x÷^%()]+$');
  static final _hasOperator = RegExp(r'\d\s*[+\-*/×x÷^%]');

  /// Whether [q] reads as a sum even without the `=` prefix.
  static bool looksLikeMath(String q) {
    final t = q.trim();
    if (t.length < 3 || !_mathish.hasMatch(t)) return false;
    if (!_hasOperator.hasMatch(t)) return false;
    // A bare "x" between letters cannot reach here (letters fail _mathish),
    // but "x" alone or at an edge is not a multiplication.
    return RegExp(r'\d').hasMatch(t) && tryEval(t) != null;
  }

  /// The value of [expr], or null for anything that is not a complete,
  /// finite sum.
  static double? tryEval(String expr) {
    final src = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(RegExp(r'(?<=\d)\s*x\s*(?=[\d(])'), '*')
        // Thousands commas ("1,250") only; a lone comma is a decimal mark in
        // much of Latin America and Europe, where the buyers are.
        .replaceAll(RegExp(r'(?<=\d),(?=\d{3}(\D|$))'), '')
        .replaceAll(',', '.');
    try {
      final p = _Parser(src);
      final v = p.parseExpression();
      p.skipSpace();
      if (!p.atEnd || v.isNaN || v.isInfinite) return null;
      return v;
    } on FormatException {
      return null;
    }
  }

  /// [v] for display: up to 10 significant digits, grouped, no trailing
  /// zeros, scientific only past a trillion or below a millionth.
  static String format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return _group(v.toInt().toString());
    }
    final a = v.abs();
    if (a >= 1e12 || a < 1e-6) {
      return v.toStringAsExponential(6).replaceFirst(RegExp(r'\.?0+e'), 'e');
    }
    var s = v.toStringAsPrecision(10);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    final dot = s.indexOf('.');
    return dot < 0 ? _group(s) : _group(s.substring(0, dot)) + s.substring(dot);
  }

  static String _group(String digits) {
    final neg = digits.startsWith('-');
    final d = neg ? digits.substring(1) : digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) b.write(',');
      b.write(d[i]);
    }
    return neg ? '-$b' : '$b';
  }
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  bool get atEnd => i >= s.length;

  void skipSpace() {
    while (!atEnd && s.codeUnitAt(i) == 0x20) {
      i++;
    }
  }

  bool _eat(String ch) {
    skipSpace();
    if (!atEnd && s[i] == ch) {
      i++;
      return true;
    }
    return false;
  }

  // expression := term (('+' | '-') term)*
  double parseExpression() {
    var v = _term();
    while (true) {
      if (_eat('+')) {
        v += _term();
      } else if (_eat('-')) {
        v -= _term();
      } else {
        return v;
      }
    }
  }

  // term := power (('*' | '/') power)*
  double _term() {
    var v = _power();
    while (true) {
      if (_eat('*')) {
        v *= _power();
      } else if (_eat('/')) {
        v /= _power();
      } else {
        return v;
      }
    }
  }

  // power := unary ('^' power)?   right-associative, so 2^3^2 is 512
  double _power() {
    final base = _unary();
    if (_eat('^')) return _pow(base, _power());
    return base;
  }

  // unary := ('-' | '+') unary | postfix
  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _postfix();
  }

  // postfix := primary '%'*
  double _postfix() {
    var v = _primary();
    while (_eat('%')) {
      v /= 100;
    }
    return v;
  }

  double _primary() {
    if (_eat('(')) {
      final v = parseExpression();
      if (!_eat(')')) throw const FormatException('unclosed');
      return v;
    }
    skipSpace();
    final start = i;
    while (!atEnd && (_isDigit(s.codeUnitAt(i)) || s[i] == '.')) {
      i++;
    }
    if (start == i) throw const FormatException('number expected');
    final v = double.tryParse(s.substring(start, i));
    if (v == null) throw const FormatException('bad number');
    return v;
  }

  static bool _isDigit(int u) => u >= 0x30 && u <= 0x39;

  static double _pow(double b, double e) => math.pow(b, e).toDouble();
}
