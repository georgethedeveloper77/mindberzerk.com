import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';
// NEEDS A PUBSPEC LINE: `url_launcher: ^6.3.1`.
//
// Not a Pigeon method, deliberately, though it was the obvious alternative.
// `openAndroidSettings` fires `Intent(action)` with no data, so it cannot carry
// a URL, and a second native method plus its Kotlin plus a regen is more moving
// parts than a plugin this app already has three siblings of (image_picker,
// battery_plus, device_info_plus).
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/charts.dart';
import '../../design/components/components.dart';
import '../../system/battery_history.dart';
import '../../system/stats_history.dart';
import '../../system/system_stats.dart';

/// The device-owned Settings categories. T1.
///
/// ─── WHY THESE EXIST, AND WHY THERE ARE ONLY THREE ──────────────────────────
///
/// A desktop settings app has Network, Bluetooth, Sound, Power, Displays,
/// Notifications and Privacy. A launcher owns none of them, and the codebase
/// rule is explicit that it never will:
///
///   WE DO NOT REIMPLEMENT ANDROID SETTINGS. Anything the OS owns is a deep
///   link out, never a reimplementation.
///
/// So the temptation is a page of link rows that reads like a desktop and does
/// nothing. That is a link farm wearing a settings screen's clothes.
///
/// The rule these pages follow instead: A CATEGORY EARNS A PAGE ONLY IF WE CAN
/// SHOW SOMETHING REAL ON IT. Something real means a number this device will
/// actually give us with no runtime permission, which is exactly the set
/// `DeviceStatsReader` already reads and `StatCapabilities` already probes.
///
/// Three categories clear that bar: Network (transport and live throughput),
/// Power (draw, temperature, thermal state) and Storage (used and free on the
/// data partition). Bluetooth, Notifications, Sound and Privacy do not clear
/// it , there is nothing permission-free to read for any of them , so they are
/// ABSENT rather than present-and-empty. Same rule as a nullable stat row.
///
/// ─── AND WHY THE HAND-OFF IS AT THE BOTTOM ──────────────────────────────────
///
/// Every page ends with a row into Android's own screen for that thing. At the
/// bottom, not the top: the data is the reason you opened the page, and a link
/// above it would say "the real settings are elsewhere" before you had read
/// anything.

/// Android's own screens, by action.
///
/// UNRESOLVED INTENTS THROW, and these do not all exist everywhere. The privacy
/// and storage screens in particular are missing on a number of Infinix and
/// Tecno builds, which are the target hardware. Native needs a
/// `canOpenAndroidSettings(String)` query before a row that cannot resolve is
/// allowed on screen; until then these three are the safest of the set, because
/// Wi-Fi, battery and storage screens are effectively universal.
class _AndroidSettings {
  const _AndroidSettings._();

  static const wifi = 'android.settings.WIFI_SETTINGS';
  static const battery = 'android.intent.action.POWER_USAGE_SUMMARY';
  static const storage = 'android.settings.INTERNAL_STORAGE_SETTINGS';

  /// ─── APPS, BECAUSE ANDROID HAS NO MEMORY SCREEN ────────────────────────
  ///
  /// The Memory page people remember lives inside Developer options on most
  /// builds, and there is no public action that opens it. Apps is the honest
  /// hand-off: it is where you go to stop the thing that is using the RAM, and
  /// it exists on every device rather than only on the ones with developer
  /// mode switched on.
  static const apps = 'android.settings.APPLICATION_SETTINGS';
}

/// Which device categories this phone can actually fill.
///
/// Derived from the SAME probe the desklets use, so a Galaxy that refuses a
/// reading hides the row in both places and cannot disagree with itself. Empty
/// while the probe is in flight, which is correct: showing a category and then
/// removing it a frame later is worse than showing it a frame late.
final deviceCategoriesProvider = Provider<List<DeviceCategory>>((ref) {
  final caps = ref.watch(statCapabilitiesProvider).asData?.value;
  if (caps == null) return const [];

  return [
    // Transport alone is enough: "Wi-Fi" with no throughput is still a fact
    // about this device, and throughput without transport never happens.
    if (caps.network || caps.networkTransport) DeviceCategory.network,
    if (caps.battery) DeviceCategory.power,
    if (caps.storage) DeviceCategory.storage,
    if (caps.memory) DeviceCategory.memory,
  ];
});

enum DeviceCategory {
  network('Network', Icons.wifi),
  power('Power', Icons.battery_charging_full_outlined),
  storage('Storage', Icons.storage_outlined),
  memory('Memory', Icons.memory_outlined);

  const DeviceCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Extra words that should find this category in the Settings search.
  ///
  /// The label alone is not enough: nobody searching for their battery types
  /// "power", and nobody looking for free space types "storage" first. Kept
  /// beside the category rather than in the settings screen so a fourth
  /// category arrives with its own vocabulary instead of needing a second edit
  /// somewhere else.
  List<String> get keywords => switch (this) {
        DeviceCategory.network => const [
            'wifi',
            'wi-fi',
            'internet',
            'data',
            'speed',
            'mobile'
          ],
        DeviceCategory.power => const [
            'battery',
            'charge',
            'charging',
            'temperature',
            'thermal'
          ],
        // 'memory' LEFT THIS LIST. It was here because storage was the only
        // place a search for it could land, and that stopped being true the
        // moment there was a Memory page. A word that matches two categories
        // makes the search useless for both.
        DeviceCategory.storage => const [
            'space',
            'free',
            'disk',
            'full',
          ],
        DeviceCategory.memory => const [
            'ram',
            'memory',
            'slow',
            'apps',
            'usage',
          ],
      };

  /// The one figure worth putting on the landing row.
  ///
  /// ONE, not a summary. The row has room for a short string beside a chevron,
  /// and picking the single most-asked number per category is what makes the
  /// list informative at a glance: "Wi-Fi", "72%", "42G free" each answer the
  /// question that sends someone into that page.
  ///
  /// Null while the first sample is in flight, or on a device that will not
  /// answer. The row then shows a bare chevron, never a placeholder, which is
  /// the same rule every stat row in the app follows.
  String? valueFor(SystemStats? s) {
    if (s == null) return null;
    return switch (this) {
      DeviceCategory.network => switch (s.transport) {
          'wifi' => 'Wi-Fi',
          'cellular' => 'Mobile',
          'ethernet' => 'Ethernet',
          'vpn' => 'VPN',
          'none' => 'Offline',
          _ => null,
        },
      DeviceCategory.power =>
        s.batteryPercent == null ? null : '${s.batteryPercent}%',
      // FREE, not used. Same call the Storage page's headline makes, and the
      // two must agree: a landing row saying one thing and the page it opens
      // saying another is the sort of small disagreement that costs trust in
      // every other number on the screen.
      DeviceCategory.storage => s.hasStorage
          ? '${SystemStats.bytes(s.storageTotalBytes! - s.storageUsedBytes!)} free'
          : null,
      // USED of total, not free, which is the opposite of the choice storage
      // makes directly above and is deliberate. Free space is a budget you
      // spend; free RAM is not, because an operating system that leaves memory
      // unused is wasting it. "4.8/7G" is the figure every system monitor on
      // every desktop prints, and it is the one this app's own panel readout
      // already shows.
      DeviceCategory.memory => s.hasMemory ? s.memLabel : null,
    };
  }

  Widget get page => switch (this) {
        DeviceCategory.network => const NetworkPage(),
        DeviceCategory.power => const PowerPage(),
        DeviceCategory.storage => const StoragePage(),
        DeviceCategory.memory => const MemoryPage(),
      };
}

// ─── network ─────────────────────────────────────────────────────────────────

class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    final history = ref.watch(statsHistoryProvider);

    final down = history.series((x) => x.downBytesPerSec);
    final up = history.series((x) => x.upBytesPerSec);

    return _DevicePage(
      title: context.t('settings.network'),
      // The chart answers a question the rows cannot: the rows say 2.4 MB/s,
      // the chart says whether that is a download running or a spike as you
      // opened the page. Only once there are enough samples to have a shape.
      header: history.chartable && down.isNotEmpty
          ? _ChartHeader(
              legend: const {'Down': ChartColors.down, 'Up': ChartColors.up},
              child: TrendChart(
                series: down,
                secondSeries: up,
                // Cyan and pink, not accent and grey. Two series need two
                // HUES; two shades of the same one is a legend nobody reads.
                color: ChartColors.down,
                secondColor: ChartColors.up,
                // Rates start at zero. Letting a flat 4 MB/s fill the box would
                // draw an idle connection as a busy one.
                minY: 0,
                height: 116,
                labelFor: SystemStats.rate,
              ),
            )
          : null,
      action: _AndroidSettings.wifi,
      actionLabel: 'Wi-Fi and mobile data',
      rows: [
        if (s?.transport != null)
          _StatRow('Connection', _transportLabel(s!.transport!)),
        if (s?.netDownBytesPerSec != null)
          _StatRow('Download', SystemStats.rate(s!.netDownBytesPerSec)),
        if (s?.netUpBytesPerSec != null)
          _StatRow('Upload', SystemStats.rate(s!.netUpBytesPerSec)),
      ],
      // THE NETWORK NAME IS NOT HERE AND IS NOT COMING. Reading the SSID needs
      // location permission on Android 10+, and an ecosystem whose pitch is
      // that it does not take what it does not need cannot hold location to
      // print a word. "Wi-Fi, 2.4 MB/s down" reads just as well.
      note: 'The network name needs location permission, so it is not shown.',
    );
  }

  static String _transportLabel(String t) => switch (t) {
        'wifi' => 'Wi-Fi',
        'cellular' => 'Mobile data',
        'ethernet' => 'Ethernet',
        'vpn' => 'VPN',
        _ => 'Offline',
      };
}

// ─── power ───────────────────────────────────────────────────────────────────

/// Power, rebuilt to the shape of the system battery screen.
///
/// ─── WHAT CHANGED AND WHY ──────────────────────────────────────────────────
///
/// The page used to be a ring and a temperature trend, both drawn from
/// [StatsHistory], which is six minutes of memory. That answers "how is the
/// battery right now" and cannot answer "where did today go", which is the
/// only question anybody opens a battery screen to ask.
///
/// So the headline is the level and the draw, the chart under it is the day,
/// and the bars under that are the week, all from [BatteryHistory]. The ring
/// is gone: it said the same thing as the number beside it.
///
/// ─── STATEFUL, FOR ONE FIELD ───────────────────────────────────────────────
///
/// The selected day. A provider for it would outlive the page and put the user
/// back on Tuesday a week later; a settings page's own scroll position is not
/// app state and neither is this.
class PowerPage extends ConsumerStatefulWidget {
  const PowerPage({super.key});

  @override
  ConsumerState<PowerPage> createState() => _PowerPageState();
}

class _PowerPageState extends ConsumerState<PowerPage> {
  /// Midnight of the day being charted. Null means today, RE-EVALUATED on
  /// every build rather than captured in initState: a launcher sits open
  /// across midnight and a captured date would keep charting yesterday.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;

    // The page's own ticker is already running for the rows below, so every
    // sample it produces is offered to the history for free. The recorder in
    // `HomeScreen` covers the hours this page is closed.
    ref.listen(systemStatsProvider, (_, next) {
      if (!next.hasValue) return;
      ref.read(batteryHistoryProvider.notifier).offer(next.requireValue);
    });

    final history = ref.watch(batteryHistoryProvider);
    final notifier = ref.read(batteryHistoryProvider.notifier);

    final c = ChromeScope.of(context).colors;
    final pct = s?.batteryPercent;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = _selected ?? today;
    final week = history.hasValue ? notifier.dailyUsage() : const <BatteryDay>[];
    final samples =
        history.hasValue ? notifier.samplesOn(day) : const <BatterySample>[];
    final usedToday = week.isEmpty ? null : week.last.dischargePercent;

    return _DevicePage(
      title: context.t('settings.power'),
      header: pct == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── THE HEADLINE, AS ONE LINE ───────────────────────
                  //
                  // Charge, state and draw read together or not at all: 78%
                  // means something different at plus 1200 mA than at minus
                  // 300, and three separate rows made the reader assemble it.
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: (pct <= 15 && s?.batteryCharging != true)
                          ? c.danger
                          : c.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _headline(context, s),
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _DayStrip(
                    days: [for (var i = 6; i >= 0; i--)
                      today.subtract(Duration(days: i))],
                    selected: day,
                    onSelect: (d) => setState(() => _selected = d),
                  ),
                  const SizedBox(height: 8),
                  if (samples.isEmpty)
                    // Absent, not a flat line at zero. Nothing was measured,
                    // and a chart that draws that as empty battery is a lie
                    // the same size as a placeholder string.
                    Text(
                      context.t('settings.batteryNoReadings'),
                      style: TextStyle(color: c.textFaint, fontSize: 12),
                    )
                  else ...[
                    BatteryDayChart(
                      day: day,
                      points: [
                        for (final x in samples)
                          (at: x.at, percent: x.percent, charging: x.charging),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ChartLegend(entries: {
                      context.t('settings.batteryLevel'): c.textMuted,
                      context.t('settings.batteryCharging'): ChartColors.good,
                    }),
                  ],
                  if (usedToday != null && usedToday > 0) ...[
                    const SizedBox(height: 18),
                    Text(
                      context.t('settings.dailyUsage', {'pct': '$usedToday'}),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BarsChart(
                      height: 110,
                      bars: [
                        for (final d in week)
                          (
                            label: _weekdayLetter(d.date),
                            value: d.dischargePercent.toDouble(),
                            color: d.date == day ? c.accent : ChartColors.cool,
                          ),
                      ],
                      labelFor: (v) => v <= 0 ? '' : '${v.toStringAsFixed(0)}%',
                    ),
                  ],
                ],
              ),
            ),
      // The honesty line, in the place every device page puts its caveat.
      note: context.t('settings.batteryRecordedNote'),
      action: _AndroidSettings.battery,
      actionLabel: 'Battery usage',
      rows: [
        if (s?.batteryCharging != null)
          _StatRow('State', s!.batteryCharging! ? 'Charging' : 'Discharging'),
        // Direction from the CHARGING FLAG, never the platform's sign, which is
        // negative-while-discharging on most OEMs and positive on several
        // Samsung and Xiaomi builds. batteryCurrentMa is a magnitude.
        if (s?.batteryCurrentMa != null)
          _StatRow(
            'Draw',
            '${s!.batteryCharging == true ? '+' : '-'}${s.batteryCurrentMa} mA',
          ),
        if (s?.batteryTempC != null)
          _StatRow('Temperature', '${s!.batteryTempC!.toStringAsFixed(1)} C'),
        if (thermalLabel(s?.thermalStatus) != null)
          _StatRow('Thermal state', thermalLabel(s!.thermalStatus)!),
        if (s?.uptime != null) _StatRow('Uptime', formatUptime(s!.uptime)),
      ],
    );
  }

  /// State, draw and temperature on one line, each part dropped when the
  /// device will not answer for it rather than printed as a dash.
  String _headline(BuildContext context, SystemStats? s) {
    final parts = <String>[
      if (s?.batteryCharging != null)
        s!.batteryCharging! ? 'Charging' : 'Discharging',
      if (s?.batteryCurrentMa != null)
        '${s!.batteryCharging == true ? '+' : '-'}${s.batteryCurrentMa} mA',
      if (s?.batteryTempC != null) '${s!.batteryTempC!.toStringAsFixed(1)} C',
    ];
    return parts.join(' \u00B7 ');
  }
}

String _weekdayLetter(DateTime d) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];

/// The seven day chips above the chart.
///
/// Day of the month, not the weekday letter: the bars below already carry the
/// letters, and two rows of the same seven labels reads as one control drawn
/// twice.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(d),
              child: Container(
                // 44dp, so a chip in a row of seven is still a tap target on a
                // 360dp screen.
                height: 44,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: d == selected ? c.surfaceAlt : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    color: d == selected ? c.text : c.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// `PowerManager.THERMAL_STATUS_*`, named. Null below API 29 and on a device
/// that will not answer, in which case the row is absent.
///
/// Duplicated from stat_desklets deliberately rather than imported: a settings
/// page importing a desklet would make the desklet layer a dependency of the
/// chrome layer. If a third caller appears, lift it into system_stats.
String? thermalLabel(int? v) => switch (v) {
      0 => 'Nominal',
      1 => 'Light',
      2 => 'Moderate',
      3 => 'Severe',
      4 => 'Critical',
      5 => 'Emergency',
      6 => 'Shutdown',
      _ => null,
    };

// ─── storage ─────────────────────────────────────────────────────────────────

class StoragePage extends ConsumerWidget {
  const StoragePage({super.key});

  /// G Recovery on Play.
  ///
  /// An `https://play.google.com/...` URL rather than `market://`: the https
  /// form is caught by the Play app when it is installed and falls back to the
  /// browser when it is not, whereas `market://` throws on a device with no
  /// Play Store at all. Plenty of the target hardware ships without it.
  static const recoveryUrl =
      'https://play.google.com/store/apps/details?id=com.mindhunter.g_recovery';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    final has = s?.hasStorage ?? false;

    final used = has ? s!.storageUsedBytes! : 0;
    final total = has ? s!.storageTotalBytes! : 0;
    final free = total - used;

    return _DevicePage(
      title: context.t('settings.storage'),
      action: _AndroidSettings.storage,
      actionLabel: 'Manage storage',
      // The headline is FREE space, not used.
      //
      // "42G free" answers the question people actually open this page with.
      // "76G used" answers a different one, and every OEM storage screen leads
      // with used because it is the number that justifies their cleaner app.
      header: has ? _StorageChart(used: used, total: total) : null,
      rows: [
        if (has) ...[
          _StatRow('Free', SystemStats.bytes(free)),
          _StatRow('Used', SystemStats.bytes(used)),
          _StatRow('Total', SystemStats.bytes(total)),
        ],
      ],
      // The DATA partition, which is the number Settings shows and the number G
      // Recovery reports. Those three agreeing matters more than technical
      // completeness: a storage figure that disagrees with the OS is one nobody
      // trusts, and G Recovery's entire pitch is telling the truth about space.
      note: 'Internal storage, matching what Android reports.',
      extra: [
        ThemedSectionHeader(context.t('settings.freeUpSpace')),
        ThemedListRow(
          icon: Icons.cleaning_services_outlined,
          title: context.t('settings.gRecovery'),
          // Says what it does, not "our other app". The ecosystem cross-link
          // earns its place by being useful on the page it sits on: this screen
          // tells you how full the phone is and cannot do anything about it.
          subtitle: context.t('settings.findLargeFilesDuplicates'),
          onTap: () => launchUrl(
            Uri.parse(recoveryUrl),
            // externalApplication, so it opens the Play app rather than an
            // in-app webview that would look like a paywall.
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

// ─── memory ──────────────────────────────────────────────────────────────────

/// RAM: how much is in use, and whether that has been climbing.
///
/// ─── THE PAGE THE DEVICE SECTION WAS MISSING ───────────────────────────────
///
/// `caps.memory` has been answered by the same probe as the other three since
/// the desklets shipped, and the panel already draws the readout. Memory was
/// simply the one category with no page behind it, which meant the figure
/// people check when a phone feels slow was the one figure with nowhere to go.
class MemoryPage extends ConsumerWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    final history = ref.watch(statsHistoryProvider);

    final has = s?.hasMemory ?? false;
    final used = has ? s!.memUsedGb! : 0.0;
    final total = has ? s!.memTotalGb! : 0.0;
    final series = history.series((x) => x.memUsedGb);

    return _DevicePage(
      title: context.t('settings.memory'),
      header: !has
          ? null
          : _ChartHeader(
              legend: series.length >= 2 ? {'Used': ChartColors.cool} : null,
              centre: RingGauge(
                fraction: total == 0 ? 0 : used / total,
                label: s!.memLabel,
                // ─── NO WARNING COLOUR, AT ANY LEVEL ─────────────────────
                //
                // Power turns its ring red under 15% because a flat battery
                // stops the phone. A phone at 95% memory is a phone using the
                // memory it has, and Android will reclaim what it needs. Every
                // cleaner app on the store makes its living by colouring that
                // number red, and doing the same here would be the same lie in
                // a nicer typeface.
                color: ChartColors.cool,
              ),
              // The trend is the reason this page exists rather than a row on
              // the landing screen. 4.8 of 7G says nothing on its own; 4.8
              // after an hour at 3.1 says something.
              child: series.length >= 2
                  ? TrendChart(
                      series: series,
                      color: ChartColors.cool,
                      height: 84,
                      // Memory never starts at zero on a running phone, so the
                      // chart is left to frame its own range. Pinning minY to 0
                      // would flatten every interesting movement into the top
                      // third of the box.
                      labelFor: (v) => '${v.toStringAsFixed(1)}G',
                    )
                  : null,
            ),
      action: _AndroidSettings.apps,
      actionLabel: 'Apps',
      rows: [
        if (has) ...[
          _StatRow('In use', '${used.toStringAsFixed(1)}G'),
          _StatRow('Free', '${(total - used).toStringAsFixed(1)}G'),
          _StatRow('Total', '${total.round()}G'),
        ],
      ],
      // Said plainly, because the alternative is somebody reading a high number
      // as a fault and going looking for a cleaner.
      note: 'Android reclaims memory as apps need it, so a high figure on its '
          'own is not a problem.',
    );
  }
}

/// The chart block above a device page's rows.
///
/// One wrapper so the three pages cannot drift on padding, legend placement or
/// the gap to the first row. Every part is optional, because the pages differ:
/// network is a chart alone, power is a ring with a small trend beneath it, and
/// a page with nothing worth charting passes no header at all and looks exactly
/// as it did before charts existed.
class _ChartHeader extends StatelessWidget {
  const _ChartHeader({this.child, this.centre, this.legend});

  final Widget? child;
  final Widget? centre;
  final Map<String, Color>? legend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (centre != null) Center(child: centre!),
          if (centre != null && child != null) const SizedBox(height: 12),
          if (child != null) child!,
          if (legend != null) ...[
            const SizedBox(height: 8),
            ChartLegend(entries: legend!),
          ],
        ],
      ),
    );
  }
}

/// Used against free: a ring with the free figure inside it, over the bar.
///
/// ─── THE OLD COMMENT ARGUED AGAINST A DONUT AND WAS RIGHT ABOUT ONE ─────────
///
/// It said a donut needs a legend to say which arc is which, and that a bar
/// reads left to right without one. Both true. A RING WITH THE NUMBER IN THE
/// MIDDLE is a different object: there is no legend because there is nothing to
/// cross-reference, the headline and the chart are the same thing, and the free
/// figure stays the headline exactly as the old design insisted it should.
///
/// The bar survives underneath. It is still the clearest read of a proportion,
/// and the two together give the glance answer and the precise one without
/// either having to do both jobs.
///
/// Everything is drawn from the palette. `no_constants.sh` covers settings, and
/// a storage bar in a fixed blue would be the one place the whole screen forgot
/// which distro it was.
class _StorageChart extends StatelessWidget {
  const _StorageChart({required this.used, required this.total});

  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    final fraction = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();

    // Over 90% is where a phone starts refusing updates and camera writes, so
    // it is the one threshold worth colouring differently. Below it the bar
    // stays the distro accent rather than shouting at someone with 40% free.
    final full = fraction >= 0.9;
    final barColor = full ? c.warn : c.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── A BAR, NOT A THIRD RING ────────────────────────────────
          //
          // Network has a line and power has a ring, and a third page answering
          // "how much of the whole" with the same shape as the second would
          // make the set read as decoration. Used against free is a COMPARISON,
          // which is what a bar is for, and it puts the two numbers side by
          // side at their real relative heights rather than as one arc.
          BarsChart(
            bars: [
              (
                label: context.t('settings.used'),
                value: used / (1024 * 1024 * 1024),
                color: full ? ChartColors.warm : ChartColors.cool,
              ),
              (
                label: context.t('settings.free'),
                value: (total - used) / (1024 * 1024 * 1024),
                color: ChartColors.good,
              ),
            ],
            height: 116,
            // Both rods measured against the WHOLE disk rather than against
            // each other, with a faint track showing it. Without that, 42GB
            // used beside 86GB free is just a short rod and a tall one, and
            // nothing on screen says what full looks like.
            track: total / (1024 * 1024 * 1024),
            labelFor: (gb) => '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                SystemStats.bytes(total - used),
                style: TextStyle(
                  color: c.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 8),
              Text('free', style: TextStyle(color: c.textMuted, fontSize: 15)),
              const Spacer(),
              Text(
                context
                    .t('settings.percentUsed', {'percent': percent.toString()}),
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.surfaceAlt)),
                  // FractionallySizedBox rather than a computed width: no
                  // LayoutBuilder, and it stays correct through a rotation or a
                  // split-screen resize without being told.
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: ColoredBox(color: barColor),
                  ),
                ],
              ),
            ),
          ),
          if (full) ...[
            const SizedBox(height: 10),
            Text(
              context.t('settings.under10FreeAndroid'),
              style: TextStyle(color: c.warn, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── shared chrome ───────────────────────────────────────────────────────────

/// One label and one value. A value is never absent: the ROW is.
class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return ThemedListRow(
      title: label,
      trailing: Text(
        value,
        style: TextStyle(color: c.textMuted, fontSize: 13),
      ),
    );
  }
}

/// The caveat under a page's readings, FOLDED AWAY until asked for.
///
/// ─── WHY IT IS NOT A PARAGRAPH ANY MORE ────────────────────────────────────
///
/// Every one of these pages carried two or three lines of small print
/// permanently on screen: where the number comes from, what it excludes, why a
/// figure looks high. All of it true, all of it read once, and after that it is
/// a block of grey text between the data and the hand-off that the eye has to
/// step over every single visit.
///
/// A disclosure keeps the sentence available to the person who wants it and
/// gives the page back to the numbers. The glyph and the label are the
/// affordance; the text appears under them and folds away again.
class _PageNote extends StatefulWidget {
  const _PageNote(this.text);

  final String text;

  @override
  State<_PageNote> createState() => _PageNoteState();
}

class _PageNoteState extends State<_PageNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            // 48dp of height including the padding, so a 16dp glyph is still a
            // real tap target.
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: c.textFaint),
                const SizedBox(width: 8),
                Text(
                  context.t('settings.aboutThisReading'),
                  style: TextStyle(color: c.textFaint, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: c.textFaint,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              widget.text,
              style: TextStyle(color: c.textFaint, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// The shape every device page shares: live rows, then the hand-off.
class _DevicePage extends ConsumerWidget {
  const _DevicePage({
    required this.title,
    required this.action,
    required this.actionLabel,
    required this.rows,
    this.note,
    this.header,
    this.extra,
  });

  final String title;
  final String action;
  final String actionLabel;
  final List<Widget> rows;
  final String? note;

  /// Drawn above the rows, full width, outside any section. The storage chart
  /// is the only one so far; a page with nothing worth charting passes null and
  /// looks exactly as it did.
  final Widget? header;

  /// Appended AFTER the Android hand-off. Storage puts the G Recovery link
  /// here, below Android's own screen rather than above it: we are the ones
  /// suggesting another app, and putting that ahead of the OS's own tool would
  /// read as an advert rather than as a suggestion.
  final List<Widget>? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);
    final c = ChromeScope.of(context).colors;

    return ThemedScaffold(
      title: title,
      body: ListView(
        // Clears the navigation bar. Trailing padding rather than a SafeArea,
        // so the list still scrolls behind a transparent bar.
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          if (header != null) header!,
          if (rows.isEmpty)
            // Reachable only between the capability probe saying yes
            // and the first stats sample landing, which is under three seconds.
            // Saying so beats an empty page that looks like a dead screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(context.t('settings.reading'),
                  style: TextStyle(color: c.textMuted)),
            )
          else ...[
            ThemedSectionHeader(context.t('settings.rightNow')),
            ...rows,
          ],
          if (note != null) _PageNote(note!),
          ThemedSectionHeader(context.t('settings.android')),
          ThemedListRow(
            icon: Icons.open_in_new,
            title: actionLabel,
            subtitle: context.t('settings.opensAndroidSettings'),
            onTap: () => api.openAndroidSettings(action),
          ),
          ...?extra,
        ],
      ),
    );
  }
}
