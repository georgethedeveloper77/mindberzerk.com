import 'package:flutter_test/flutter_test.dart';
import 'package:g_vpn/design/country_shapes.dart';

void main() {
  final shapes = CountryShapes.instance;

  test('decodes the whole bundle', () {
    expect(shapes.all.length, greaterThan(230));
    for (final country in shapes.all) {
      expect(country.code, matches(RegExp(r'^[A-Z]{2}$')));
      expect(country.rings, isNotEmpty);
      for (final ring in country.rings) {
        expect(ring.length, greaterThanOrEqualTo(6));
        expect(ring.length.isEven, isTrue);
      }
    }
  });

  test('lookup is case insensitive and null safe', () {
    expect(shapes['ke']?.code, 'KE');
    expect(shapes[null], isNull);
    expect(shapes['ZZ'], isNull);
  });

  test('Kenya frames Nairobi', () {
    final kenya = shapes['KE']!;
    expect(kenya.focus.contains(36.82, -1.29), isTrue);
    expect(kenya.bounds.contains(36.82, -1.29), isTrue);
  });

  test('focus skips overseas territories', () {
    final us = shapes['US']!;
    expect(us.bounds.west, lessThan(-170));
    expect(us.focus.west, greaterThan(-130));

    final france = shapes['FR']!;
    expect(france.focus.contains(2.35, 48.86), isTrue);
    expect(france.focus.contains(-53.0, 4.0), isFalse);
  });

  test('folded territories close the outline', () {
    expect(shapes['SO']!.bounds.contains(44.06, 9.56), isTrue);
  });

  test('within returns only countries near the view', () {
    const eastAfrica = GeoBounds(30, -5, 42, 5);
    final codes = shapes.within(eastAfrica).map((c) => c.code).toSet();
    expect(codes, containsAll(<String>['KE', 'UG', 'TZ', 'SO']));
    expect(codes, isNot(contains('JP')));
  });
}
