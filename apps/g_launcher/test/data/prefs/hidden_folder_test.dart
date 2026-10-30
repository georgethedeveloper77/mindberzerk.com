import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/hidden_folder.dart';
import 'package:g_launcher/data/prefs/prefs_backup.dart';

void main() {
  group('HiddenFolderSettings', () {
    test('off by default, with the translated name', () {
      const s = HiddenFolderSettings();
      expect(s.enabled, isFalse);
      expect(s.name, isNull);
    });

    test('names are trimmed, bounded, and empty means the default', () {
      expect(HiddenFolderSettings.cleanName('  Utilities '), 'Utilities');
      expect(HiddenFolderSettings.cleanName('   '), isNull);
      expect(HiddenFolderSettings.cleanName(null), isNull);
      expect(
        HiddenFolderSettings.cleanName('x' * 40)!.length,
        HiddenFolderSettings.maxNameLength,
      );
    });

    test('survives JSON, and tolerates junk', () {
      const s = HiddenFolderSettings(enabled: true, name: 'Utilities');
      expect(HiddenFolderSettings.fromJson(s.toJson()), s);
      expect(
        HiddenFolderSettings.fromJson({'enabled': 'yes', 'name': '  '}),
        const HiddenFolderSettings(),
      );
    });

    test('rename keeps the switch, toggle keeps the name', () {
      const s = HiddenFolderSettings(enabled: true);
      expect(s.withName('Tools'),
          const HiddenFolderSettings(enabled: true, name: 'Tools'));
      expect(s.withName('Tools').copyWith(enabled: false).name, 'Tools');
    });

    test('carried by backups', () {
      expect(PrefsBackup.extraKeys, contains(HiddenFolderNotifier.storageKey));
    });
  });
}
