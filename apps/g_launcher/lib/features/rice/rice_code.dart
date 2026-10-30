/// Share your rice: a whole setup as one pasteable code.
///
/// ─── NO SERVER, ON PURPOSE ──────────────────────────────────────────────────
///
/// The code IS the rice: gzip, then base64url, behind a `GRICE1.` tag. No
/// upload, no database, no bill, nothing to moderate, and it works between
/// two phones with no internet at all. The cost is length (around a kilobyte
/// to two for a busy desktop), which a chat app carries without complaint.
///
/// ─── WHAT TRAVELS, AND WHAT NEVER DOES ──────────────────────────────────────
///
/// An ALLOW-LIST, never a deny-list, so a field added to LauncherPrefs next
/// month stays on this phone until someone decides it should travel:
///
///   travels   the distro, its look (icons, fonts, accent, panels, opacity,
///             drawer style), the arrangement when the sharer allows it, and
///             desklets with anything personal emptied
///   never     hidden apps, the sharer's own photos, gestures, text size,
///             the system icon pack APK, app widgets (their ids belong to the
///             sharer's phone), and the text of a notes desklet
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import '../../data/prefs/layout_snapshots.dart';

class RicePayload {
  const RicePayload({
    required this.distroId,
    required this.distroName,
    required this.look,
    required this.layout,
    this.includesApps = true,
  });

  final String distroId;
  final String distroName;

  /// LauncherPrefs JSON fields from [RiceCode.lookKeys] only.
  final Map<String, dynamic> look;

  /// LauncherPrefs JSON fields from [LayoutSnapshots.layoutKeys] only.
  final Map<String, dynamic> layout;

  /// False when the sharer chose not to include their apps: the layout then
  /// carries desklets and grid size, and no app placements.
  final bool includesApps;

  int get deskletCount => (layout['desklets'] as List?)?.length ?? 0;
  int get dockCount => (layout['favourites'] as List?)?.length ?? 0;
  String? get iconPack => look['iconPackId'] as String?;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'distro': distroId,
        'name': distroName,
        'apps': includesApps,
        'look': look,
        'layout': layout,
      };

  static RicePayload? fromJson(Map<String, dynamic> j) {
    if (j['v'] != 1) return null;
    final distro = j['distro'];
    final look = j['look'];
    final layout = j['layout'];
    if (distro is! String || look is! Map || layout is! Map) return null;
    // Filtered AGAIN on the way in: a code is untrusted input, and only the
    // allow-listed fields may reach LauncherPrefs.fromJson.
    return RicePayload(
      distroId: distro,
      distroName: (j['name'] as String?) ?? distro,
      includesApps: j['apps'] != false,
      look: {
        for (final k in RiceCode.lookKeys)
          if (look.containsKey(k)) k: look[k],
      },
      layout: {
        for (final k in LayoutSnapshots.layoutKeys)
          if (layout.containsKey(k)) k: layout[k],
      },
    );
  }
}

abstract final class RiceCode {
  static const tag = 'GRICE1.';

  /// The look half: everything about how the distro is dressed.
  static const lookKeys = <String>[
    'dockSide',
    'dockGridButton',
    'dockHover',
    'dockPress',
    'dockEntrance',
    'dockLayout',
    'topBar',
    'topBarSide',
    'topBarStats',
    'statusBar',
    'desktopIcons',
    'panelModules',
    'panelHeight',
    'panelSide',
    'drawerCols',
    'drawerScrollStyle',
    'drawerGrouping',
    'drawerIndexRail',
    'drawerListStyle',
    'drawerRowExpand',
    'drawerSortMode',
    'drawerSlotCols',
    'drawerSlotRows',
    'drawerPageCount',
    'drawerSearchPosition',
    'themeMode',
    'accentId',
    'layoutPreset',
    'surfaceOpacity',
    'dockOpacity',
    'drawerOpacity',
    'barOpacity',
    'panelOpacity',
    'panelBlur',
    'panelTint',
    'panelRadius',
    'badgeStyle',
    'workspaceCount',
    'iconSizeDp',
    'iconTreatment',
    'iconPackId',
    'iconBrandPackId',
    'cornerRadius',
    'labelLines',
    'menuActionLabels',
    'displayFont',
    'monoFont',
    'folderCols',
    'folderRows',
    'folderShape',
    'folderOrderCustom',
    'wallpaperFit',
    'wallpaperCurrent',
  ];

  /// App placements, dropped when the sharer keeps their apps private.
  static const appKeys = <String>[
    'favourites',
    'dockExcluded',
    'homeItems',
    'folders',
    'drawerFolders',
    'drawerSlots',
  ];

  /// Desklet kinds that do not travel: an app widget's id names a binding on
  /// the sharer's phone that this phone has never heard of.
  static const _deviceBoundKinds = {'appwidget'};

  /// Kinds whose config is the person's own words.
  static const _privateConfigKinds = {'notes'};

  /// Build a payload from a distro's merged prefs JSON.
  static RicePayload fromPrefs({
    required String distroId,
    required String distroName,
    required Map<String, dynamic> prefsJson,
    required bool includeApps,
  }) {
    final look = <String, dynamic>{
      for (final k in lookKeys)
        if (prefsJson.containsKey(k)) k: prefsJson[k],
    };
    // The sharer's own photo is a path on their phone. Only a distro's own
    // wallpaper (a name inside the pack) can be worn by someone else.
    final wall = look['wallpaperCurrent'];
    if (wall is String && (wall.startsWith('/') || wall.contains('://'))) {
      look.remove('wallpaperCurrent');
    }

    final layout = LayoutSnapshots.extract(prefsJson);
    if (!includeApps) {
      for (final k in appKeys) {
        layout.remove(k);
      }
    }
    final desklets = layout['desklets'];
    if (desklets is List) {
      layout['desklets'] = [
        for (final d in desklets)
          if (d is Map && !_deviceBoundKinds.contains(d['kind']))
            _privateConfigKinds.contains(d['kind'])
                ? {...d, 'config': const <String, dynamic>{}}
                : d,
      ];
    }

    return RicePayload(
      distroId: distroId,
      distroName: distroName,
      look: look,
      layout: layout,
      includesApps: includeApps,
    );
  }

  /// [prefsJson] dressed in [rice]: look fields replaced, layout replaced
  /// (app placements only when the rice carries them), everything else kept.
  static Map<String, dynamic> applyTo(
    Map<String, dynamic> prefsJson,
    RicePayload rice,
  ) {
    final replace = {
      ...lookKeys,
      for (final k in LayoutSnapshots.layoutKeys)
        if (rice.includesApps || !appKeys.contains(k)) k,
    };
    return {
      for (final e in prefsJson.entries)
        if (!replace.contains(e.key)) e.key: e.value,
      ...rice.look,
      for (final e in rice.layout.entries)
        if (replace.contains(e.key)) e.key: e.value,
    };
  }

  static String encode(RicePayload p) {
    final bytes = GZipEncoder().encode(utf8.encode(jsonEncode(p.toJson())))!;
    return tag + base64Url.encode(bytes).replaceAll('=', '');
  }

  /// The rice in [text], wherever it sits: a bare code, or a whole chat
  /// message with the code somewhere inside it. Null for anything else.
  static RicePayload? decode(String text) {
    final m = RegExp(r'GRICE1\.([A-Za-z0-9_-]+)').firstMatch(text);
    if (m == null) return null;
    try {
      var b64 = m.group(1)!;
      b64 = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
      final json =
          utf8.decode(GZipDecoder().decodeBytes(base64Url.decode(b64)));
      final j = jsonDecode(json);
      return j is Map<String, dynamic> ? RicePayload.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }
}
