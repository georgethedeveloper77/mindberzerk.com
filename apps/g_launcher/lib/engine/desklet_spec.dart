/// The catalogue of desklet kinds. PHASE D2.
///
/// ─── THE THREE-LAYER BET, RESTATED ──────────────────────────────────────────
///
///   KIND      code. One builder each, exhaustive, never per distro.
///   OFFERS    theme.json. Which kinds this distro exposes in the picker.
///   SKIN      theme.json. How this distro draws that kind.
///
/// There is exactly ONE clock in the codebase. Ubuntu renders it as an Adwaita
/// card, Arch as a waybar module, the terminal as `date` output, Aqua as a
/// Dashboard flip-clock. Adding Kali costs zero Dart. That is the whole reason
/// this file holds sizes and defaults and nothing visual.
///
/// ─── WHAT EARNS A KIND ──────────────────────────────────────────────────────
///
/// A desklet earns its place only if Android does not already show it at a
/// glance. The status bar owns the clock, the battery percentage and the
/// connection state, which is exactly why the launcher's own top bar is
/// transparent. So [battery] is not a percentage — it is draw in mA, cell
/// temperature and time-to-empty. [network] is not "connected" — it is live
/// throughput. Anything that would duplicate the status bar does not ship.
class DeskletKind {
  const DeskletKind({
    required this.id,
    required this.label,
    required this.minSpanX,
    required this.minSpanY,
    required this.maxSpanX,
    required this.maxSpanY,
    required this.defaultSpanX,
    required this.defaultSpanY,
    this.paneOnly = false,
    this.defaults = const {},
  });

  /// The string stored on [Desklet.kind]. Never renamed once shipped: a rename
  /// orphans every placement already on a user's desktop.
  final String id;

  final String label;

  final int minSpanX;
  final int minSpanY;
  final int maxSpanX;
  final int maxSpanY;
  final int defaultSpanX;
  final int defaultSpanY;

  /// Only coherent on the pane surface (the terminal shell), where a desklet is
  /// persistent command output rather than a positioned card. `ls` on a GNOME
  /// desktop would be a file manager, not a desklet.
  final bool paneOnly;

  /// Config keys and their fallbacks. The kind owns these, in ONE place, so a
  /// clock's `format` default cannot drift between the picker, the renderer and
  /// the settings sheet.
  final Map<String, Object?> defaults;

  /// Read a config value with the kind's default as the floor.
  ///
  /// Absent key falls back; a key of the WRONG TYPE also falls back rather than
  /// throwing, because this reads content that may have come from a CDN pack or
  /// an admin panel. A desktop must not fail to draw because someone typed a
  /// string where a bool belonged.
  T read<T>(Map<String, Object?> config, String key, T fallback) {
    final v = config.containsKey(key) ? config[key] : defaults[key];
    return v is T ? v : fallback;
  }
}

/// Every kind this build knows. Order is the picker order.
///
/// The grid kinds below read from sources that need NO runtime permission.
/// Permissions only start at calendar events, Wi-Fi SSID, media controls and
/// weather, none of which are here.
class DeskletKinds {
  const DeskletKinds._();

  /// A hosted third-party Android AppWidget (RemoteViews from another app).
  ///
  /// NOT a kind you pick from the desklet menu — it is minted when you tap a
  /// provider in the picker's App widgets list, and its config carries the
  /// device-local `widgetId` the host allocated plus the provider's min size.
  /// Generous span limits; the initial span comes from the provider's own
  /// minimum footprint, not from [defaultSpanX]/[defaultSpanY].
  ///
  /// Deliberately absent from the picker's offer list (desklet_picker's
  /// fallback), so it never appears among the drawn-in-Dart desklets — it is
  /// only ever created through the hosting path.
  static const appWidget = DeskletKind(
    id: 'appwidget',
    label: 'App widget',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 2,
    defaultSpanY: 2,
  );

  /// The combined default desktop tile. Time + date, and stat rows that appear
  /// as it is resized taller: cpu/ram at spanY 2, network at 3, disk/temp at 4.
  ///
  /// This is what the first-install starter drops on the right side, and it is
  /// why a fresh desktop reads as furnished rather than empty. The tiering lives
  /// in the widget (it keys off [Desklet.spanY]); this entry only bounds the
  /// resize. Default spanY is 2, so the tile ships showing time, date, cpu and
  /// ram — cpu absent on the many devices that will not report it.
  static const glance = DeskletKind(
    id: 'glance',
    label: 'Glance',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 3,
    maxSpanY: 4,
    defaultSpanX: 2,
    defaultSpanY: 2,
  );

  /// Big, and the proof of the skin layer: it looks radically different on all
  /// five shells, which is what makes it the right first kind to build.
  static const clock = DeskletKind(
    id: 'clock',
    label: 'Clock',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 4,
    maxSpanY: 2,
    defaultSpanX: 2,
    defaultSpanY: 1,
    defaults: {
      'format': '24h', // '24h' | '12h'
      'showSeconds': false,
      'showDate': true,
    },
  );

  /// The conky. RAM, storage, network, thermal, uptime — and CPU only where the
  /// device allows it, which on most modern hardware it does not.
  static const monitor = DeskletKind(
    id: 'monitor',
    label: 'System monitor',
    minSpanX: 2,
    minSpanY: 2,
    maxSpanX: 4,
    maxSpanY: 5,
    defaultSpanX: 2,
    defaultSpanY: 3,
    defaults: {'graphs': true},
  );

  /// Logo plus spec table. Mostly static, so it costs nothing to keep on screen.
  static const fastfetch = DeskletKind(
    id: 'fastfetch',
    label: 'Fastfetch',
    minSpanX: 3,
    minSpanY: 2,
    maxSpanX: 5,
    maxSpanY: 4,
    defaultSpanX: 4,
    defaultSpanY: 2,
  );

  /// Live throughput and transport. Never the SSID: that needs location
  /// permission on Android 10+, which a privacy-positioned ecosystem does not
  /// ask for to draw a widget.
  static const network = DeskletKind(
    id: 'network',
    label: 'Network',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 4,
    maxSpanY: 3,
    defaultSpanX: 2,
    defaultSpanY: 1,
  );

  /// The same number Settings shows and the same one G Recovery will report.
  /// Those agreeing matters more than technical completeness.
  static const storage = DeskletKind(
    id: 'storage',
    label: 'Storage',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 4,
    maxSpanY: 3,
    defaultSpanX: 2,
    defaultSpanY: 2,
  );

  /// Draw, temperature, time-to-empty. NOT a percentage — Android's own status
  /// bar already shows that, and duplicating it would fail the rule above.
  static const battery = DeskletKind(
    id: 'battery',
    label: 'Battery detail',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 4,
    maxSpanY: 3,
    defaultSpanX: 2,
    defaultSpanY: 1,
  );

  static const notes = DeskletKind(
    id: 'notes',
    label: 'Note',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 2,
    defaultSpanY: 2,
    defaults: {'text': ''},
  );

  static const search = DeskletKind(
    id: 'search',
    label: 'Search',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 1,
    defaultSpanX: 4,
    defaultSpanY: 1,
  );

  // ── pane surface (terminal shell) ──────────────────────────────────────────
  // Added by TYPING the command, not by dragging from a picker. Spans are
  // carried so the record stays uniform, and ignored by the pane renderer.

  static const freeMem = DeskletKind(
    id: 'free',
    label: 'free -h',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 1,
    defaultSpanY: 1,
    paneOnly: true,
  );

  /// `ls`. The app list AS A DIRECTORY LISTING, which is the joke and also the
  /// correct metaphor: on a launcher, installed apps are what the filesystem
  /// has in it. There is no real filesystem to list — scoped storage sees to
  /// that — so listing the one thing we genuinely have is more honest than
  /// showing an empty `/`.
  static const appsList = DeskletKind(
    id: 'ls',
    label: 'ls',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 1,
    defaultSpanY: 1,
    paneOnly: true,
    defaults: {'limit': 12},
  );

  /// `uptime`. One line, and it is the only thing that command ever was.
  static const uptime = DeskletKind(
    id: 'uptime',
    label: 'uptime',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 1,
    defaultSpanY: 1,
    paneOnly: true,
  );

  static const diskFree = DeskletKind(
    id: 'df',
    label: 'df -h',
    minSpanX: 1,
    minSpanY: 1,
    maxSpanX: 5,
    maxSpanY: 5,
    defaultSpanX: 1,
    defaultSpanY: 1,
    paneOnly: true,
  );

  static const all = <DeskletKind>[
    glance,
    appWidget,
    clock,
    monitor,
    fastfetch,
    network,
    storage,
    battery,
    notes,
    search,
    freeMem,
    diskFree,
    appsList,
    uptime,
  ];

  static final Map<String, DeskletKind> _byId = {
    for (final k in all) k.id: k,
  };

  /// Null for a kind this build has never heard of.
  ///
  /// NULL IS NOT AN ERROR AND NOT A LICENCE TO DELETE. A CDN theme can offer a
  /// desklet a shipped APK does not know; the placement must round-trip
  /// untouched and simply not draw, so it reappears after an app update. Same
  /// contract as an unknown `BootLineKind` degrading to plain.
  static DeskletKind? byId(String id) => _byId[id];

  static bool isKnown(String id) => _byId.containsKey(id);

  /// The kinds a theme offers, resolved against what this build can draw.
  ///
  /// [offered] comes from `theme.json`. Unknown ids are dropped HERE, in the
  /// picker path only — never from stored placements.
  static List<DeskletKind> resolveOffers(List<String> offered) =>
      offered.map(byId).whereType<DeskletKind>().toList();
}
