import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../background/background_checks.dart' show backgroundLastRunKey;
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../tools/tool_widgets.dart';
import 'alert_watcher.dart';
import 'alerts.dart';

(IconData, Color) alertLook(AlertKind k, Meridian m) => switch (k) {
      AlertKind.newDevice => (Icons.devices_other_rounded, m.good),
      AlertKind.openWifi => (Icons.wifi_rounded, m.bad),
      AlertKind.blocked => (Icons.block_rounded, m.violet),
      AlertKind.breach => (Icons.key_rounded, m.pink),
      AlertKind.report => (Icons.insert_chart_outlined_rounded, m.brand),
    };

String alertKindName(AlertKind k) => switch (k) {
      AlertKind.newDevice => t.alerts.kinds.newDevice,
      AlertKind.openWifi => t.alerts.kinds.openWifi,
      AlertKind.blocked => t.alerts.kinds.blocked,
      AlertKind.breach => t.alerts.kinds.breach,
      AlertKind.report => t.alerts.kinds.report,
    };

/// The button an alert offers, if any.
String? _actionFor(AlertKind k) => switch (k) {
      AlertKind.newDevice => t.alerts.look,
      AlertKind.breach => t.alerts.read,
      AlertKind.report => t.alerts.open,
      AlertKind.blocked => t.alerts.check,
      AlertKind.openWifi => null,
    };

/// "14:02" today, "Tue" this week, "12 Oct" before that.
String _when(BuildContext context, DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return TimeOfDay.fromDateTime(at).format(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  if (today.difference(day).inDays < 7) return DateFormat.E(locale).format(at);
  return MaterialLocalizations.of(context).formatShortMonthDay(at);
}

/// The inbox: newest first, grouped by day, filtered by kind. Settings live
/// on their own page, behind the gear.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertKind? _filter;

  @override
  void initState() {
    super.initState();
    // The background checks may have added some since the app last looked.
    ref.read(alertsProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final state = ref.watch(alertsProvider).value ?? const AlertsState();
    final items = state.items;
    final counts = {for (final k in AlertKind.values) k: items.where((a) => a.kind == k).length};
    final shown = _filter == null ? items : items.where((a) => a.kind == _filter).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <(String, List<Alert>)>[
      (t.alerts.today, shown.where((a) => !a.at.isBefore(today)).toList()),
      (t.alerts.thisWeek, shown.where((a) => a.at.isBefore(today) && today.difference(a.at).inDays < 7).toList()),
      (t.alerts.earlier, shown.where((a) => today.difference(a.at).inDays >= 7).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();

    return ToolPage(
      title: t.alerts.title,
      icon: Icons.notifications_none_rounded,
      color: m.brand,
      actions: [
        if (state.unread > 0)
          IconButton(
            tooltip: t.alerts.markAllRead,
            onPressed: () => ref.read(alertsProvider.notifier).markRead(),
            icon: Icon(Icons.done_all_rounded, color: m.text),
          ),
        IconButton(
          tooltip: t.alerts.settings,
          onPressed: () => AlertSettingsSheet.show(context),
          icon: Icon(Icons.settings_outlined, color: m.text),
        ),
      ],
      children: [
        if (items.isEmpty)
          const _Quiet()
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(label: '${t.alerts.all} ${items.length}', on: _filter == null, color: m.brand, onTap: () => setState(() => _filter = null)),
              for (final k in AlertKind.values)
                if (counts[k]! > 0)
                  _FilterChip(
                    label: '${alertKindName(k)} ${counts[k]}',
                    on: _filter == k,
                    color: alertLook(k, m).$2,
                    onTap: () => setState(() => _filter = k),
                  ),
            ]),
          ),
          for (final (title, list) in groups) ...[
            ToolHeading(title),
            MerCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, a) in list.indexed) ...[
                  if (i > 0) Divider(height: 1, color: m.line),
                  _AlertRow(alert: a),
                ],
              ]),
            ),
          ],
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.color, required this.onTap});

  final String label;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: .16),
        backgroundColor: m.surface,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: on ? color : m.text),
        shape: StadiumBorder(side: BorderSide(color: on ? color : m.line)),
      ),
    );
  }
}

/// Nothing in the inbox: a calm shield, breathing.
class _Quiet extends StatefulWidget {
  const _Quiet();

  @override
  State<_Quiet> createState() => _QuietState();
}

class _QuietState extends State<_Quiet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(children: [
        SizedBox(
          width: 160,
          height: 160,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              Container(
                width: 88 + 60 * _pulse.value,
                height: 88 + 60 * _pulse.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: m.good.withValues(alpha: .25 * (1 - _pulse.value))),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.good.withValues(alpha: .14),
                  border: Border.all(color: m.good.withValues(alpha: .5), width: 2),
                ),
                child: Icon(Icons.shield_outlined, size: 40, color: m.good),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(t.alerts.quiet, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
        const SizedBox(height: 4),
        Text(t.alerts.quietSub, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: m.muted)),
      ]),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final (icon, tone) = alertLook(alert.kind, m);
    final action = alert.route == null ? null : _actionFor(alert.kind);
    void go() {
      ref.read(alertsProvider.notifier).markRead(alert.id);
      openAlertRoute(context, alert.route);
    }

    return InkWell(
      onTap: go,
      child: Container(
        color: alert.read ? null : tone.withValues(alpha: .05),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, size: 19, color: tone),
              ),
              if (!alert.read)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(color: tone, shape: BoxShape.circle, border: Border.all(color: m.surface, width: 2)),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(alert.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text))),
                    Text(_when(context, alert.at), style: TextStyle(fontSize: 11, color: m.muted)),
                  ]),
                  if (alert.body.isNotEmpty) Text(alert.body, style: TextStyle(fontSize: 12, color: m.muted)),
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: go,
                      style: TextButton.styleFrom(
                        foregroundColor: tone,
                        backgroundColor: tone.withValues(alpha: .14),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      child: Text(action),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alerts › settings, as a sheet: one switch per kind, with when it is
/// checked, and Clear all.
class AlertSettingsSheet extends ConsumerWidget {
  const AlertSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => const AlertSettingsSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final state = ref.watch(alertsProvider).value ?? const AlertsState();
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + MediaQuery.paddingOf(context).bottom),
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, prefs) {
          final last = prefs.data?.getInt(backgroundLastRunKey);
          final checked = last == null
              ? t.alerts.status.background
              : t.alerts.status.checked(time: TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(last)).format(context));
          String status(AlertKind k) => switch (k) {
                AlertKind.newDevice => checked,
                AlertKind.openWifi => t.alerts.status.wifi,
                AlertKind.blocked => t.alerts.status.blocked,
                AlertKind.breach => checked,
                AlertKind.report => t.alerts.status.report,
              };
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(t.alerts.settings, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
              ),
              for (final k in AlertKind.values)
                SwitchListTile(
                  value: state.enabled.contains(k),
                  onChanged: (v) => ref.read(alertsProvider.notifier).setEnabled(k, v),
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: alertLook(k, m).$2.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                    child: Icon(alertLook(k, m).$1, size: 18, color: alertLook(k, m).$2),
                  ),
                  title: Text(alertKindName(k), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                  subtitle: Text(status(k), style: TextStyle(fontSize: 12, color: m.muted)),
                ),
              if (state.items.isNotEmpty) ...[
                Divider(height: 16, color: m.line),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: m.bad),
                  title: Text(t.alerts.clearAll, style: TextStyle(fontWeight: FontWeight.w800, color: m.bad)),
                  onTap: () {
                    ref.read(alertsProvider.notifier).clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The bell in Home's header, with the unread count.
class AlertsBell extends ConsumerWidget {
  const AlertsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final unread = ref.watch(alertsProvider.select((s) => s.value?.unread ?? 0));
    return IconButton(
      tooltip: t.alerts.title,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsScreen())),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: m.bad,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(Icons.notifications_none_rounded, color: m.muted),
      ),
    );
  }
}
