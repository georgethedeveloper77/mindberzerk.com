import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// NEEDS A PUBSPEC LINE: `url_launcher: ^6.3.1`.
//
// Not a Pigeon method, deliberately, though it was the obvious alternative.
// `openAndroidSettings` fires `Intent(action)` with no data, so it cannot carry
// a URL, and a second native method plus its Kotlin plus a regen is more moving
// parts than a plugin this app already has three siblings of (image_picker,
// battery_plus, device_info_plus).
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/components/components.dart';
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
  ];
});

enum DeviceCategory {
  network('Network', Icons.wifi),
  power('Power', Icons.battery_charging_full_outlined),
  storage('Storage', Icons.storage_outlined);

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
        DeviceCategory.network =>
          const ['wifi', 'wi-fi', 'internet', 'data', 'speed', 'mobile'],
        DeviceCategory.power =>
          const ['battery', 'charge', 'charging', 'temperature', 'thermal'],
        DeviceCategory.storage =>
          const ['space', 'free', 'disk', 'memory', 'full'],
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
    };
  }

  Widget get page => switch (this) {
        DeviceCategory.network => const NetworkPage(),
        DeviceCategory.power => const PowerPage(),
        DeviceCategory.storage => const StoragePage(),
      };
}

// ─── network ─────────────────────────────────────────────────────────────────

class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;

    return _DevicePage(
      title: 'Network',
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

class PowerPage extends ConsumerWidget {
  const PowerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(systemStatsProvider).asData?.value;

    return _DevicePage(
      title: 'Power',
      action: _AndroidSettings.battery,
      actionLabel: 'Battery usage',
      rows: [
        if (s?.batteryPercent != null) _StatRow('Charge', '${s!.batteryPercent}%'),
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
    final s = ref.watch(systemStatsProvider).asData?.value;
    final has = s?.hasStorage ?? false;

    final used = has ? s!.storageUsedBytes! : 0;
    final total = has ? s!.storageTotalBytes! : 0;
    final free = total - used;

    return _DevicePage(
      title: 'Storage',
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
        const ThemedSectionHeader('Free up space'),
        ThemedListRow(
          icon: Icons.cleaning_services_outlined,
          title: 'G Recovery',
          // Says what it does, not "our other app". The ecosystem cross-link
          // earns its place by being useful on the page it sits on: this screen
          // tells you how full the phone is and cannot do anything about it.
          subtitle: 'Find large files, duplicates and unused apps',
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

/// Used against free, as one bar.
///
/// A BAR, NOT A DONUT. A donut is the prettier chart and the wrong one here:
/// it needs a legend to say which arc is which, and this page has exactly two
/// quantities that sum to a known total. A bar reads left to right with no
/// legend at all, and it is the shape every OS storage screen already uses, so
/// nobody has to learn it.
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
                '$percent% used',
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
              'Under 10% free. Android starts refusing updates and photos around here.',
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
        children: [
          if (header != null) header!,

          if (rows.isEmpty)
            // Reachable only between the capability probe saying yes
            // and the first stats sample landing, which is under three seconds.
            // Saying so beats an empty page that looks like a dead screen.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Reading…', style: TextStyle(color: c.textMuted)),
            )
          else ...[
            const ThemedSectionHeader('Right now'),
            ...rows,
          ],

          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                note!,
                style: TextStyle(color: c.textFaint, fontSize: 12),
              ),
            ),

          const ThemedSectionHeader('Android'),

          ThemedListRow(
            icon: Icons.open_in_new,
            title: actionLabel,
            subtitle: 'Opens Android settings',
            onTap: () => api.openAndroidSettings(action),
          ),

          ...?extra,
        ],
      ),
    );
  }
}
