import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/term_path.dart';

void main() {
  group('display', () {
    test('slash, apps and files each print their own way', () {
      expect(TermPath.slash.display, '/');
      expect(TermPath.appsRoot.display, '/apps');
      expect(TermPath.filesRoot.display, '~');
      expect(const TermPath(<String>['sdcard', 'Download']).display, '~/Download');
      expect(const TermPath(<String>['apps', 'firefox']).display, '/apps/firefox');
    });
  });

  group('roots', () {
    test('the first segment names the namespace', () {
      expect(TermPath.appsRoot.root, TermRoot.apps);
      expect(TermPath.filesRoot.root, TermRoot.files);
      expect(TermPath.slash.root, isNull);
    });

    test('an unknown first segment has no root, so it fails as not found', () {
      expect(const TermPath(<String>['etc']).root, isNull);
    });
  });

  group('resolve', () {
    test('relative appends to the current folder', () {
      final TermPath result =
          TermPath.resolve('Download', TermPath.filesRoot);
      expect(result, const TermPath(<String>['sdcard', 'Download']));
    });

    test('tilde always means storage, from anywhere', () {
      expect(TermPath.resolve('~', TermPath.appsRoot), TermPath.filesRoot);
      expect(
        TermPath.resolve('~/DCIM', TermPath.appsRoot),
        const TermPath(<String>['sdcard', 'DCIM']),
      );
    });

    test('absolute ignores the current folder', () {
      expect(
        TermPath.resolve('/apps/firefox', TermPath.filesRoot),
        const TermPath(<String>['apps', 'firefox']),
      );
    });

    test('dot dot walks up and stops at slash rather than underflowing', () {
      const TermPath deep = TermPath(<String>['sdcard', 'DCIM', 'Camera']);
      expect(TermPath.resolve('..', deep),
          const TermPath(<String>['sdcard', 'DCIM']));
      expect(TermPath.resolve('../..', deep), TermPath.filesRoot);
      expect(TermPath.resolve('../../../../..', deep), TermPath.slash);
    });

    test('dot dot crosses out of a namespace into slash', () {
      expect(TermPath.resolve('..', TermPath.appsRoot), TermPath.slash);
    });

    test('empty and dot stay put', () {
      expect(TermPath.resolve(null, TermPath.appsRoot), TermPath.appsRoot);
      expect(TermPath.resolve('', TermPath.appsRoot), TermPath.appsRoot);
      expect(TermPath.resolve('.', TermPath.appsRoot), TermPath.appsRoot);
    });

    test('doubled and trailing slashes collapse', () {
      expect(
        TermPath.resolve('DCIM//Camera/', TermPath.filesRoot),
        const TermPath(<String>['sdcard', 'DCIM', 'Camera']),
      );
    });

    test('a path can cross namespaces in one step', () {
      expect(
        TermPath.resolve('../apps', TermPath.filesRoot),
        TermPath.appsRoot,
      );
    });
  });

  test('parent and child are inverses', () {
    const TermPath base = TermPath(<String>['sdcard', 'Download']);
    expect(base.child('notes.txt').parent, base);
    expect(TermPath.slash.parent, TermPath.slash);
  });

  test('equality is by value, so a resolved path matches a literal one', () {
    expect(
      TermPath.resolve('/sdcard/Download', TermPath.slash),
      const TermPath(<String>['sdcard', 'Download']),
    );
    expect(
      TermPath.resolve('/sdcard/Download', TermPath.slash).hashCode,
      const TermPath(<String>['sdcard', 'Download']).hashCode,
    );
  });
}
