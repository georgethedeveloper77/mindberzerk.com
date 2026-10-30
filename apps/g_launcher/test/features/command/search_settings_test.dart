import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/prefs_backup.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/features/command/bangs.dart';
import 'package:g_launcher/features/command/command_router.dart';
import 'package:g_launcher/features/command/search_engines.dart';
import 'package:g_launcher/features/command/search_settings.dart';

const _npm = Bang('npm', 'npm', 'https://www.npmjs.com/search?q=%s');

void main() {
  group('BangRules', () {
    test('keys are normalised and checked', () {
      expect(BangRules.normalizeKey('  !NPM '), 'npm');
      expect(BangRules.keyError('npm'), isNull);
      expect(BangRules.keyError('a.b-c_1'), isNull);
      expect(BangRules.keyError(''), isNotNull);
      expect(BangRules.keyError('two words'), isNotNull);
      expect(BangRules.keyError('x' * 17), isNotNull);
    });

    test('templates need %s and a web scheme', () {
      expect(BangRules.templateError(_npm.template), isNull);
      expect(BangRules.templateError('http://x.org/?q=%s'), isNull);
      expect(
        BangRules.templateError('https://x.org/'),
        'searchSettings.errPlaceholder',
      );
      for (final bad in [
        'javascript:alert(%s)',
        'intent://x#Intent;q=%s;end',
        'file:///sdcard/%s',
        'market://search?q=%s',
        'https://%s',
      ]) {
        expect(
          BangRules.templateError(bad),
          'searchSettings.errUrl',
          reason: bad,
        );
      }
    });

    test('names are required and bounded', () {
      expect(BangRules.labelError('npm'), isNull);
      expect(BangRules.labelError('   '), isNotNull);
      expect(BangRules.labelError('n' * 41), isNotNull);
    });
  });

  group('SearchSettings', () {
    test('adds, edits in place, renames and removes', () {
      var s = const SearchSettings().withBang(_npm);
      s = s.withBang(const Bang('pp', 'PyPI', 'https://pypi.org/search/?q=%s'));
      expect([for (final b in s.bangs) b.key], ['npm', 'pp']);

      // Renamed: the old key goes, the position stays.
      s = s.withBang(
        const Bang('np', 'npm', 'https://www.npmjs.com/search?q=%s'),
        replacing: 'npm',
      );
      expect([for (final b in s.bangs) b.key], ['np', 'pp']);

      // Renamed onto another bang's key: the edit wins, no duplicate.
      s = s.withBang(
        const Bang('pp', 'npm', 'https://www.npmjs.com/search?q=%s'),
        replacing: 'np',
      );
      expect([for (final b in s.bangs) b.key], ['pp']);
      expect(s.bangs.single.label, 'npm');

      expect(s.withoutBang('pp').bangs, isEmpty);
    });

    test('JSON drops invalid and duplicate bangs and unknown engines', () {
      final s = SearchSettings.fromJson({
        'engine': 'altavista',
        'bangs': [
          _npm.toJson(),
          {'key': 'npm', 'label': 'dup', 'template': 'https://a.b/?q=%s'},
          {'key': 'evil', 'label': 'x', 'template': 'javascript:%s'},
          'not a map',
        ],
      });
      expect(s.engineId, 'google');
      expect(s.bangs, [_npm]);

      final round = SearchSettings.fromJson(
        jsonDecode(jsonEncode(
          const SearchSettings(engineId: 'brave', bangs: [_npm]).toJson(),
        )) as Map<String, dynamic>,
      );
      expect(round.engineId, 'brave');
      expect(round.bangs, [_npm]);
    });

    test('the list is capped', () {
      final s = SearchSettings.fromJson({
        'bangs': [
          for (var i = 0; i < 60; i++)
            {'key': 'k$i', 'label': 'K', 'template': 'https://a.b/?q=%s'},
        ],
      });
      expect(s.bangs.length, BangRules.maxCustom);
      expect(s.canAdd, isFalse);
    });
  });

  group('router and engine', () {
    test('a custom bang overrides a built-in key', () {
      const scholar =
          Bang('g', 'Scholar', 'https://scholar.google.com/scholar?q=%s');
      final route = CommandRouter.route('!g rice', extraBangs: [scholar]);
      final hit = route.hits.single as BangSearchHit;
      expect(hit.hit.url, 'https://scholar.google.com/scholar?q=rice');
    });

    test('custom bangs appear in the hint chips', () {
      final route = CommandRouter.route('!np', extraBangs: [_npm]);
      final hint = route.hits.single as BangHintHit;
      expect(hint.bangs.first.key, 'npm');
    });

    test('the web row follows the chosen engine, Google by default', () {
      expect(
        CommandRouter.webSearchUrl(' linux rice '),
        'https://www.google.com/search?q=linux+rice',
      );
      expect(
        CommandRouter.webSearchUrl(
          'linux rice',
          engine: SearchEngine.byId('duckduckgo'),
        ),
        'https://duckduckgo.com/?q=linux+rice',
      );
      expect(SearchEngine.byId(null), SearchEngine.google);
      expect({for (final e in SearchEngine.all) e.id}.length,
          SearchEngine.all.length);
    });
  });

  group('backups', () {
    test('the settings key is carried and restored', () async {
      expect(
        PrefsBackup.extraKeys,
        contains(SearchSettingsNotifier.storageKey),
      );

      final from = MemoryPrefsStore();
      const settings = SearchSettings(engineId: 'ecosia', bangs: [_npm]);
      await from.write(
        SearchSettingsNotifier.storageKey,
        jsonEncode(settings.toJson()),
      );
      final data = await PrefsBackup.collect(
        store: from,
        repo: PrefsRepository(from),
        collections: const [],
      );
      expect(
        (data['extras'] as Map)[SearchSettingsNotifier.storageKey],
        settings.toJson(),
      );
    });
  });
}
