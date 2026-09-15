/// A module's name and glyph, for anything that has to talk ABOUT a module
/// rather than draw one.
///
/// ─── TWO CALLERS NOW, WHICH IS WHY IT LEFT THE SHELL ───────────────────────
///
/// The Add sheet needs a name for a module that is not on the panel, and the
/// undo strip needs a name for one that just left it. Both are panel surfaces
/// and neither is Plasma's, so a private switch in the KDE shell was one shell
/// owning the vocabulary the others also speak.
///
/// A switch rather than a map, so a new module cannot be added to the enum and
/// silently arrive with no name.
library;

import 'package:flutter/material.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../engine/theme_spec.dart' show PanelModule;

/// The label for a module in the Add sheet.
///
/// A switch rather than a map, so a new module cannot be added to the enum and
/// silently arrive in this sheet with no name.
String panelModuleLabel(BuildContext context, PanelModule m) => switch (m) {
      PanelModule.kickoff => context.t('shell.moduleKickoff'),
      PanelModule.tasks => context.t('shell.moduleTasks'),
      PanelModule.pager => context.t('shell.modulePager'),
      PanelModule.tray => context.t('shell.moduleTray'),
      PanelModule.clock => context.t('shell.moduleClock'),
      PanelModule.spacer => context.t('shell.moduleSpacer'),
      PanelModule.activities => context.t('shell.moduleActivities'),
      PanelModule.network => context.t('shell.moduleNetwork'),
      PanelModule.memory => context.t('shell.moduleMemory'),
      PanelModule.storage => context.t('shell.moduleStorage'),
      PanelModule.battery => context.t('shell.moduleBattery'),
      PanelModule.wifi => context.t('shell.moduleWifi'),
      PanelModule.volume => context.t('shell.moduleVolume'),
      PanelModule.app => context.t('shell.moduleApp'),
    };

IconData panelModuleIcon(PanelModule m) => switch (m) {
      PanelModule.kickoff => Icons.apps,
      PanelModule.tasks => Icons.view_agenda_outlined,
      PanelModule.pager => Icons.grid_view,
      PanelModule.tray => Icons.expand_less,
      PanelModule.battery => Icons.battery_std_outlined,
      PanelModule.wifi => Icons.wifi,
      PanelModule.volume => Icons.volume_up_outlined,
      PanelModule.app => Icons.widgets_outlined,
      PanelModule.clock => Icons.schedule,
      PanelModule.spacer => Icons.space_bar,
      PanelModule.activities => Icons.dashboard_outlined,
      PanelModule.network => Icons.swap_vert,
      PanelModule.memory => Icons.memory,
      PanelModule.storage => Icons.sd_storage_outlined,
    };

/// The i18n KEY for a module's one-line description.
///
/// A key rather than a string, because the row that shows it is built inside a
/// list and `context.t` belongs at the point of use. The sheet is the only
/// caller: a panel 44dp tall has no room for a sentence, which is most of why
/// the editing moved off it.
String panelModuleNote(PanelModule m) => switch (m) {
      PanelModule.kickoff => 'shell.noteKickoff',
      PanelModule.activities => 'shell.noteActivities',
      PanelModule.tasks => 'shell.noteTasks',
      PanelModule.pager => 'shell.notePager',
      PanelModule.tray => 'shell.noteTray',
      PanelModule.clock => 'shell.noteClock',
      PanelModule.battery => 'shell.noteBattery',
      PanelModule.wifi => 'shell.noteWifi',
      PanelModule.volume => 'shell.noteVolume',
      PanelModule.network => 'shell.noteNetwork',
      PanelModule.memory => 'shell.noteMemory',
      PanelModule.storage => 'shell.noteStorage',
      PanelModule.spacer => 'shell.noteSpacer',
      PanelModule.app => 'shell.noteApp',
    };
