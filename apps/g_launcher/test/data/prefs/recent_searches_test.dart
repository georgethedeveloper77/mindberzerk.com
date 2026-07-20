import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/prefs_repository.dart';
import 'package:g_launcher/data/prefs/recent_searches.dart';

void main() {
  late MemoryPrefsStore store;

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [prefsStoreProvider.overrideWithValue(store)],
      );

  setUp(() => store = MemoryPrefsStore());

  test('record prepends, de-dupes case-insensitively, and caps at 8', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(recentSearchesProvider.notifier);
    await c.read(recentSearchesProvider.future); // warm the async build

    await n.record('chrome');
    await n.record('Files');
    await n.record('CHROME'); // moves chrome to front, no duplicate
    expect(c.read(recentSearchesProvider).value, ['CHROME', 'Files']);

    for (var i = 0; i < 10; i++) {
      await n.record('app$i');
    }
    final list = c.read(recentSearchesProvider).value!;
    expect(list.length, 8);
    expect(list.first, 'app9'); // most recent wins
  });

  test('blank and whitespace queries are ignored', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(recentSearchesProvider.notifier);
    await c.read(recentSearchesProvider.future);

    await n.record('   ');
    await n.record('');
    expect(c.read(recentSearchesProvider).value, isEmpty);
  });

  test('remove drops one term; clear empties the list', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final n = c.read(recentSearchesProvider.notifier);
    await c.read(recentSearchesProvider.future);

    await n.record('a');
    await n.record('b');
    await n.remove('a');
    expect(c.read(recentSearchesProvider).value, ['b']);

    await n.clear();
    expect(c.read(recentSearchesProvider).value, isEmpty);
  });

  test('history persists across containers sharing the store', () async {
    final c1 = makeContainer();
    final n1 = c1.read(recentSearchesProvider.notifier);
    await c1.read(recentSearchesProvider.future);
    await n1.record('kept');
    c1.dispose();

    final c2 = makeContainer();
    addTearDown(c2.dispose);
    final restored = await c2.read(recentSearchesProvider.future);
    expect(restored, ['kept']);
  });
}
