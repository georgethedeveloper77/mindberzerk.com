import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/rice/rice_code.dart';

Map<String, dynamic> _prefs() => {
      'iconTreatment': 'squircle',
      'accentId': 'orange',
      'hiddenApps': ['secret/app'],
      'gestures': {'swipeUp': 'drawer'},
      'textScale': 1.3,
      'systemIconPack': 'com.some.pack',
      'wallpaperCurrent': '/storage/emulated/0/DCIM/me.jpg',
      'favourites': ['a/a', 'b/b'],
      'homeItems': <dynamic>[],
      'desklets': [
        {
          'id': '1',
          'kind': 'clock',
          'config': {'face': 'digital'}
        },
        {
          'id': '2',
          'kind': 'notes',
          'config': {'text': 'my bank pin'}
        },
        {
          'id': '3',
          'kind': 'appwidget',
          'config': {'appWidgetId': 42}
        },
      ],
    };

void main() {
  test('round trip through the code', () {
    final rice = RiceCode.fromPrefs(
      distroId: 'kali-2024',
      distroName: 'Kali Linux',
      prefsJson: _prefs(),
      includeApps: true,
    );
    final code = RiceCode.encode(rice);
    expect(code, startsWith('GRICE1.'));
    final back = RiceCode.decode('look at this: $code nice right?')!;
    expect(back.distroId, 'kali-2024');
    expect(back.look['iconTreatment'], 'squircle');
    expect(back.dockCount, 2);
  });

  test('private things never travel', () {
    final rice = RiceCode.fromPrefs(
      distroId: 'x',
      distroName: 'X',
      prefsJson: _prefs(),
      includeApps: true,
    );
    final all = rice.toJson().toString();
    expect(all, isNot(contains('secret/app')));
    expect(all, isNot(contains('swipeUp')));
    expect(all, isNot(contains('my bank pin')));
    expect(all, isNot(contains('appWidgetId')));
    expect(all, isNot(contains('DCIM')));
    expect(all, isNot(contains('com.some.pack')));
    expect(rice.deskletCount, 2);
  });

  test('apps stay home when the sharer says so, and are kept on apply', () {
    final rice = RiceCode.fromPrefs(
      distroId: 'x',
      distroName: 'X',
      prefsJson: _prefs(),
      includeApps: false,
    );
    expect(rice.layout.containsKey('favourites'), isFalse);
    final mine = {
      'favourites': ['mine/app'],
      'iconTreatment': 'circle'
    };
    final worn = RiceCode.applyTo(mine, rice);
    expect(worn['favourites'], ['mine/app']);
    expect(worn['iconTreatment'], 'squircle');
  });

  test('garbage and tampered codes decode to nothing', () {
    expect(RiceCode.decode('hello'), isNull);
    expect(RiceCode.decode('GRICE1.not-real-data'), isNull);
  });
}
