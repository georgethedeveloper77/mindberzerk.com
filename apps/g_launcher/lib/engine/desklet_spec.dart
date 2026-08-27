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
/// ─── THE SPANS HERE ARE IN THE FINE GRID ────────────────────────────────────
///
/// Every number below was multiplied when the desklet grid was split off from
/// the icon grid: X by [DeskletLayout.colFactor], Y by
/// [DeskletLayout.rowFactor]. A kind whose maximum stayed at the old figure
/// would have been silently confined to a fraction of the screen, which is the
/// kind of change that looks like the resize handle broke.
///
/// If those factors ever change again, these change with them, and stored
/// placements need a migration. That is the whole reason
/// [LauncherPrefs.deskletGridVersion] exists.
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
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 4,
    defaultSpanY: 3,
  );

  /// Several widgets sharing one footprint, swiped between.
  ///
  /// ─── WHERE A STACK'S MEMBERS LIVE ───────────────────────────────────────
  ///
  /// `config['members']` is an ordered list of DESKLET IDS, and each member is
  /// a perfectly ordinary [Desklet] still sitting in `prefs.desklets` on page
  /// [DeskletLayout.stackedPage].
  ///
  /// That was the whole design decision, and the alternative was worse. Nesting
  /// members INSIDE the config as maps would mean `byId` cannot find them,
  /// `remove` cannot remove them, a hosted widget's `widgetId` would be buried
  /// where the release path never looks, and every existing query would need a
  /// recursive twin. Parking them on a page nothing renders costs nothing:
  /// `renderable` already filters by page, so they are invisible by the rule
  /// that was there before stacks existed.
  ///
  /// Spans are the stack's own; a member is drawn into whatever rectangle the
  /// stack occupies, which is why adding one never has to refuse for space.
  static const stack = DeskletKind(
    id: 'stack',
    label: 'Stack',
    minSpanX: 3,
    minSpanY: 2,
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 4,
    defaultSpanY: 4,
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
    minSpanX: 3,
    minSpanY: 2,
    maxSpanX: 8,
    maxSpanY: 12,
    defaultSpanX: 4,
    defaultSpanY: 3,
  );

  /// The distro's own first-run card: a title and a short list of links.
  ///
  /// ─── IT IS DISMISSIBLE, AND THAT IS WHY IT IS WORTH SHIPPING ────────────
  ///
  /// A greeting stops being useful the moment you know which distro you are
  /// on, which is roughly day two. The obvious conclusion is not to build one.
  /// The distro that this is for reached the opposite one: EndeavourOS's
  /// Welcome app has a "do not show on startup" checkbox and stays in the menu
  /// forever after you tick it.
  ///
  /// That is exactly the shape here. It ships on workspace one via `starter`,
  /// its long press removes it like any other desklet, and it stays in the
  /// picker so it can come back. What the distro is selling is that it GREETS
  /// you, not that you are stuck with it.
  ///
  /// ─── AND THE ROWS ARE AUTHORED, NOT HARDCODED ───────────────────────────
  ///
  /// `config['rows']` is a list of `{label, url}` maps, read from the starter
  /// placement in theme.json, so Manjaro and Garuda can ship their own without
  /// a line of Dart. The defaults below are neutral rather than EndeavourOS's,
  /// because a kind that ships one distro's copy as its floor is a kind the
  /// next distro has to fight.
  ///
  /// A row with no `url` draws and does nothing, which is deliberate: a distro
  /// listing a step it cannot link to would otherwise have to omit the step.
  static const welcome = DeskletKind(
    id: 'welcome',
    label: 'Welcome',
    minSpanX: 3,
    minSpanY: 2,
    maxSpanX: 8,
    maxSpanY: 8,
    // SIX BY FOUR when picked from the menu, not four by three.
    //
    // These are FINE-GRID units: `EffectiveTheme.deskletCols` is the icon
    // grid times `DeskletLayout.colFactor`, so on a four-column desktop the
    // desklet grid is eight wide. Four by three is therefore HALF the width
    // and a fifth of the height, and a card holding a title plus four link
    // rows at that size is a card whose rows are one word each.
    //
    // A kind carrying text has to default larger than a kind carrying a
    // number. The clock gets away with four by two because its content scales;
    // rows do not.
    defaultSpanX: 6,
    defaultSpanY: 4,
    defaults: {
      'title': '',
      'rows': <Object?>[],
    },
  );

  /// Big, and the proof of the skin layer: it looks radically different on all
  /// five shells, which is what makes it the right first kind to build.
  static const clock = DeskletKind(
    id: 'clock',
    label: 'Clock',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 8,
    maxSpanY: 6,
    defaultSpanX: 4,
    defaultSpanY: 2,
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
    minSpanX: 3,
    minSpanY: 2,
    maxSpanX: 8,
    maxSpanY: 12,
    defaultSpanX: 4,
    defaultSpanY: 3,
    defaults: {'graphs': true},
  );

  /// Logo plus spec table. Mostly static, so it costs nothing to keep on screen.
  static const fastfetch = DeskletKind(
    id: 'fastfetch',
    label: 'Fastfetch',
    minSpanX: 4,
    minSpanY: 2,
    maxSpanX: 10,
    maxSpanY: 9,
    defaultSpanX: 5,
    defaultSpanY: 3,
  );

  /// Live throughput and transport. Never the SSID: that needs location
  /// permission on Android 10+, which a privacy-positioned ecosystem does not
  /// ask for to draw a widget.
  static const network = DeskletKind(
    id: 'network',
    label: 'Network',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 8,
    maxSpanY: 6,
    defaultSpanX: 4,
    defaultSpanY: 2,
  );

  /// The same number Settings shows and the same one G Recovery will report.
  /// Those agreeing matters more than technical completeness.
  static const storage = DeskletKind(
    id: 'storage',
    label: 'Storage',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 8,
    maxSpanY: 6,
    defaultSpanX: 4,
    defaultSpanY: 2,
  );

  /// Draw, temperature, time-to-empty. NOT a percentage — Android's own status
  /// bar already shows that, and duplicating it would fail the rule above.
  static const battery = DeskletKind(
    id: 'battery',
    label: 'Battery detail',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 8,
    maxSpanY: 6,
    defaultSpanX: 4,
    defaultSpanY: 3,
  );

  static const notes = DeskletKind(
    id: 'notes',
    label: 'Note',
    minSpanX: 2,
    minSpanY: 1,
    maxSpanX: 10,
    maxSpanY: 12,
    defaultSpanX: 4,
    defaultSpanY: 2,
    defaults: {'text': ''},
  );

  static const search = DeskletKind(
    id: 'search',
    label: 'Search',
    minSpanX: 4,
    minSpanY: 1,
    maxSpanX: 10,
    maxSpanY: 2,
    defaultSpanX: 8,
    defaultSpanY: 1,
  );

  // ── pane surface (terminal shell) ──────────────────────────────────────────
  // Added by TYPING the command, not by dragging from a picker. Spans are
  // carried so the record stays uniform, and ignored by the pane renderer.

  static const freeMem = DeskletKind(
    id: 'free',
    label: 'free -h',
    minSpanX: 2,
    minSpanY: 3,
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 2,
    defaultSpanY: 3,
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
    minSpanX: 2,
    minSpanY: 3,
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 2,
    defaultSpanY: 3,
    paneOnly: true,
    defaults: {'limit': 12},
  );

  /// `uptime`. One line, and it is the only thing that command ever was.
  static const uptime = DeskletKind(
    id: 'uptime',
    label: 'uptime',
    minSpanX: 2,
    minSpanY: 3,
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 2,
    defaultSpanY: 3,
    paneOnly: true,
  );

  static const diskFree = DeskletKind(
    id: 'df',
    label: 'df -h',
    minSpanX: 2,
    minSpanY: 3,
    maxSpanX: 10,
    maxSpanY: 15,
    defaultSpanX: 2,
    defaultSpanY: 3,
    paneOnly: true,
  );

  static const all = <DeskletKind>[
    glance,
    appWidget,
    stack,
    welcome,
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
