// Guards the two rules that decide what a panel draws on a phone: the status
// row belongs to Android while its bar shows, and an upright phone leaves the
// readouts and the pager off the bar.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/engine/theme_spec.dart';
import 'package:g_launcher/features/panel/panel_modules.dart';

List<PanelModule> _kinds(List<PanelItem> items) =>
    [for (final i in items) i.kind];

void main() {
  final kali = PanelItem.parseAll(
    const ['kickoff', 'tasks', 'pager', 'spacer', 'network', 'tray', 'clock'],
    side: TopBarSide.bottom,
  );

  test('upright with the status bar: menu, apps and one tray button', () {
    expect(
      _kinds(panelItemsShown(kali, systemStatusBar: true, narrow: true)),
      [PanelModule.kickoff, PanelModule.tasks, PanelModule.spacer,
        PanelModule.tray],
    );
  });

  test('wide keeps the pager and readouts', () {
    final k = _kinds(panelItemsShown(kali, systemStatusBar: true));
    expect(k, contains(PanelModule.pager));
    expect(k, contains(PanelModule.network));
    expect(k, isNot(contains(PanelModule.clock)));
  });

  test('upright with status icons on keeps them, drops only the wide ones',
      () {
    final k = _kinds(panelItemsShown(kali, systemStatusBar: false, narrow: true));
    expect(k, containsAll([PanelModule.wifi, PanelModule.clock]));
    expect(k, isNot(contains(PanelModule.pager)));
    expect(k, isNot(contains(PanelModule.network)));
  });
}
