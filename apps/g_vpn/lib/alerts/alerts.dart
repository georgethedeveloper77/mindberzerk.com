import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.g.dart';

/// What an alert is about. The order is the order of the settings.
enum AlertKind { newDevice, openWifi, blocked, breach, report }

/// One alert in the inbox.
@immutable
class Alert {
  const Alert({required this.id, required this.kind, required this.title, required this.body, required this.at, this.read = false, this.route});

  final int id;
  final AlertKind kind;
  final String title;
  final String body;
  final DateTime at;
  final bool read;

  /// Where tapping it goes ("/report", "/hub").
  final String? route;

  Alert copyWith({bool? read}) => Alert(id: id, kind: kind, title: title, body: body, at: at, read: read ?? this.read, route: route);

  Map<String, Object> toJson() => {
        'id': id,
        'k': kind.name,
        't': title,
        'b': body,
        'at': at.millisecondsSinceEpoch,
        'r': read,
        if (route != null) 'go': route!,
      };

  static Alert? fromJson(Object? j) {
    if (j is! Map || j['id'] is! int || j['at'] is! int) return null;
    final kind = AlertKind.values.where((k) => k.name == j['k']).firstOrNull;
    if (kind == null) return null;
    return Alert(
      id: j['id'] as int,
      kind: kind,
      title: '${j['t']}',
      body: '${j['b']}',
      at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      read: j['r'] == true,
      route: j['go'] as String?,
    );
  }
}

/// The phone's own notifications, through the native alerts channel.
abstract final class AlertsBridge {
  static const _channel = MethodChannel('com.mindberzerk.gvpn/alerts');

  static Future<void> notify(Alert a) async {
    try {
      await _channel.invokeMethod<bool>('notify', {
        'id': a.id & 0x7fffffff,
        'title': a.title,
        'body': a.body,
        'route': a.route,
        'channel': t.alerts.channel,
      });
    } on PlatformException {
      // A missed notification still sits in the inbox.
    }
  }

  /// The route of the notification that opened the app, once.
  static Future<String?> launchRoute() async {
    try {
      return await _channel.invokeMethod<String>('launchRoute');
    } on PlatformException {
      return null;
    }
  }
}

/// The inbox on disk. Plain functions, so the background checks (which run
/// without the app's providers) write to the same place the app reads.
abstract final class AlertsStore {
  static const itemsKey = 'gvpn.alerts.items.v1';
  static const offKey = 'gvpn.alerts.off.v1';
  static const keep = 50;

  static Future<AlertsState> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final off = prefs.getStringList(offKey) ?? const [];
    var items = const <Alert>[];
    final raw = prefs.getString(itemsKey);
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List).map(Alert.fromJson).whereType<Alert>().toList();
      } on FormatException {
        items = const [];
      }
    }
    return AlertsState(items: items, enabled: {for (final k in AlertKind.values) if (!off.contains(k.name)) k});
  }

  static Future<void> saveItems(List<Alert> items) async =>
      (await SharedPreferences.getInstance()).setString(itemsKey, jsonEncode([for (final a in items) a.toJson()]));

  /// Adds an alert unless its kind is off or [once] fired within [onceFor].
  /// Returns the alert, or null when nothing was added.
  static Future<Alert?> add(
    AlertKind kind, {
    required String title,
    required String body,
    String? route,
    String? once,
    Duration onceFor = const Duration(days: 1),
  }) async {
    final current = await load();
    if (!current.enabled.contains(kind)) return null;
    final prefs = await SharedPreferences.getInstance();
    if (once != null) {
      final key = 'gvpn.alerts.once.$once';
      final last = prefs.getInt(key);
      if (last != null && DateTime.now().millisecondsSinceEpoch - last < onceFor.inMilliseconds) return null;
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    }
    final alert = Alert(
      id: DateTime.now().millisecondsSinceEpoch,
      kind: kind,
      title: title,
      body: body,
      at: DateTime.now(),
      route: route,
    );
    await saveItems([alert, ...current.items].take(keep).toList());
    return alert;
  }
}

@immutable
class AlertsState {
  const AlertsState({this.items = const [], this.enabled = const {}});

  /// Newest first.
  final List<Alert> items;
  final Set<AlertKind> enabled;

  int get unread => items.where((a) => !a.read).length;
}

final alertsProvider = AsyncNotifierProvider<AlertsController, AlertsState>(AlertsController.new);

/// The inbox and which kinds the user wants, kept on this phone.
class AlertsController extends AsyncNotifier<AlertsState> {
  @override
  Future<AlertsState> build() => AlertsStore.load();

  /// Re-reads the inbox (after the background checks added to it).
  Future<void> reload() async => state = AsyncData(await AlertsStore.load());

  /// Adds an alert unless its kind is off. [notify] also posts a system
  /// notification; [once] skips it if an alert with that key came within
  /// [onceFor] (one per network a day, and so on).
  Future<void> add(
    AlertKind kind, {
    required String title,
    required String body,
    String? route,
    bool notify = false,
    String? once,
    Duration onceFor = const Duration(days: 1),
  }) async {
    final alert = await AlertsStore.add(kind, title: title, body: body, route: route, once: once, onceFor: onceFor);
    if (alert == null) return;
    await reload();
    if (notify) await AlertsBridge.notify(alert);
  }

  Future<void> markRead([int? id]) async {
    final current = await future;
    await _save(AlertsState(
      items: [for (final a in current.items) id == null || a.id == id ? a.copyWith(read: true) : a],
      enabled: current.enabled,
    ));
  }

  Future<void> clear() async {
    final current = await future;
    await _save(AlertsState(enabled: current.enabled));
  }

  Future<void> setEnabled(AlertKind kind, bool on) async {
    final current = await future;
    final enabled = {...current.enabled};
    on ? enabled.add(kind) : enabled.remove(kind);
    state = AsyncData(AlertsState(items: current.items, enabled: enabled));
    await (await SharedPreferences.getInstance())
        .setStringList(AlertsStore.offKey, [for (final k in AlertKind.values) if (!enabled.contains(k)) k.name]);
  }

  Future<void> _save(AlertsState s) async {
    state = AsyncData(s);
    await AlertsStore.saveItems(s.items);
  }
}
