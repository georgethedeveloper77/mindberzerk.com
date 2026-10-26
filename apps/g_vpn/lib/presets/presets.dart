import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.g.dart';
import '../map/map_data.dart';
import '../rules/rules_store.dart';
import '../servers/community.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';

enum PresetIcon { bolt, unlock, play, shield, star, game, home }

enum PresetPlace { fastest, country }

/// A preset's colour, so presets are told apart at a glance.
enum PresetTone { blue, amber, green, violet, teal, pink }

enum PresetProtocol { auto, sstp, openvpn }

IconData presetIconData(PresetIcon icon) => switch (icon) {
      PresetIcon.bolt => Icons.bolt_rounded,
      PresetIcon.unlock => Icons.lock_open_rounded,
      PresetIcon.play => Icons.play_circle_outline_rounded,
      PresetIcon.shield => Icons.shield_outlined,
      PresetIcon.star => Icons.star_outline_rounded,
      PresetIcon.game => Icons.sports_esports_outlined,
      PresetIcon.home => Icons.home_outlined,
    };

/// A connection recipe: which free server to pick, how to connect, and
/// what Shield and Apps direct do for that connection.
@immutable
class Preset {
  const Preset({
    required this.id,
    this.name,
    this.icon = PresetIcon.star,
    this.tone = PresetTone.teal,
    this.place = PresetPlace.fastest,
    this.country,
    this.skipMyCountry = false,
    this.protocol = PresetProtocol.auto,
    this.tryNext = true,
    this.shield,
    this.allApps = false,
    this.builtIn = false,
  });

  final String id;

  /// Null on a built-in the user has not renamed: shown in their language.
  final String? name;
  final PresetIcon icon;
  final PresetTone tone;
  final PresetPlace place;

  /// ISO alpha-2, for [PresetPlace.country].
  final String? country;

  /// Leaves out servers in the user's own country.
  final bool skipMyCountry;
  final PresetProtocol protocol;

  /// On a failed connect, tries the next server (up to three).
  final bool tryNext;

  /// Null follows the Rules.
  final ShieldLevel? shield;

  /// Every app through the VPN, ignoring Apps direct.
  final bool allApps;
  final bool builtIn;

  String get label =>
      name ??
      switch (id) {
        'fastest' => t.presets.names.fastest,
        'unblock' => t.presets.names.unblock,
        'streaming' => t.presets.names.streaming,
        'privacy' => t.presets.names.privacy,
        _ => t.presets.namePlaceholder,
      };

  RulesOverride get override => RulesOverride(shield: shield, allApps: allApps);

  Preset copyWith({
    String? name,
    PresetIcon? icon,
    PresetTone? tone,
    PresetPlace? place,
    String? country,
    bool? skipMyCountry,
    PresetProtocol? protocol,
    bool? tryNext,
    ShieldLevel? Function()? shield,
    bool? allApps,
  }) =>
      Preset(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        tone: tone ?? this.tone,
        place: place ?? this.place,
        country: country ?? this.country,
        skipMyCountry: skipMyCountry ?? this.skipMyCountry,
        protocol: protocol ?? this.protocol,
        tryNext: tryNext ?? this.tryNext,
        shield: shield == null ? this.shield : shield(),
        allApps: allApps ?? this.allApps,
        builtIn: builtIn,
      );

  /// The same preset under [name]; null shows the built-in's own name.
  Preset named(String? name) => Preset(
        id: id,
        name: name,
        icon: icon,
        tone: tone,
        place: place,
        country: country,
        skipMyCountry: skipMyCountry,
        protocol: protocol,
        tryNext: tryNext,
        shield: shield,
        allApps: allApps,
        builtIn: builtIn,
      );

  Map<String, Object> toJson() => {
        'id': id,
        if (name != null) 'name': name!,
        'icon': icon.name,
        'tone': tone.name,
        'place': place.name,
        if (country != null) 'country': country!,
        'skipMyCountry': skipMyCountry,
        'protocol': protocol.name,
        'tryNext': tryNext,
        if (shield != null) 'shield': shield!.name,
        'allApps': allApps,
        'builtIn': builtIn,
      };

  static T? _enum<T extends Enum>(List<T> values, Object? name) => values.where((v) => v.name == name).firstOrNull;

  static Preset? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return Preset(
      id: j['id'] as String,
      name: j['name'] is String ? j['name'] as String : null,
      icon: _enum(PresetIcon.values, j['icon']) ?? PresetIcon.star,
      tone: _enum(PresetTone.values, j['tone']) ?? PresetTone.teal,
      place: _enum(PresetPlace.values, j['place']) ?? PresetPlace.fastest,
      country: j['country'] is String ? j['country'] as String : null,
      skipMyCountry: j['skipMyCountry'] == true,
      protocol: _enum(PresetProtocol.values, j['protocol']) ?? PresetProtocol.auto,
      tryNext: j['tryNext'] != false,
      shield: _enum(ShieldLevel.values, j['shield']),
      allApps: j['allApps'] == true,
      builtIn: j['builtIn'] == true,
    );
  }
}

/// The presets every phone starts with.
const builtInPresets = [
  Preset(id: 'fastest', icon: PresetIcon.bolt, tone: PresetTone.blue, builtIn: true),
  Preset(
    id: 'unblock',
    icon: PresetIcon.unlock,
    tone: PresetTone.amber,
    skipMyCountry: true,
    protocol: PresetProtocol.sstp,
    builtIn: true,
  ),
  Preset(
    id: 'streaming',
    icon: PresetIcon.play,
    tone: PresetTone.violet,
    place: PresetPlace.country,
    country: 'US',
    builtIn: true,
  ),
  Preset(
    id: 'privacy',
    icon: PresetIcon.shield,
    tone: PresetTone.green,
    shield: ShieldLevel.malware,
    allApps: true,
    builtIn: true,
  ),
];

@immutable
class PresetsState {
  const PresetsState({required this.presets, this.applied});

  final List<Preset> presets;

  /// The preset behind the current connection; cleared on disconnect.
  final String? applied;
}

final presetsProvider = AsyncNotifierProvider<PresetsController, PresetsState>(PresetsController.new);

/// Built-ins (with the user's edits) followed by the user's own presets.
class PresetsController extends AsyncNotifier<PresetsState> {
  static const _key = 'gvpn.presets.v1';

  @override
  Future<PresetsState> build() async {
    ref.listen(vpnProvider.select((s) => s.phase), (_, phase) {
      final current = state.value;
      if (phase == VpnPhase.off && current?.applied != null) {
        state = AsyncData(PresetsState(presets: current!.presets));
      }
    });
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    final saved = <String, Preset>{};
    if (raw != null) {
      try {
        for (final p in (jsonDecode(raw) as List).map(Preset.fromJson).whereType<Preset>()) {
          saved[p.id] = p;
        }
      } on FormatException {
        saved.clear();
      }
    }
    return PresetsState(presets: [
      for (final b in builtInPresets) saved[b.id] ?? b,
      for (final p in saved.values) if (!p.builtIn) p,
    ]);
  }

  /// Adds or replaces [preset].
  Future<void> save(Preset preset) async {
    final current = await future;
    final exists = current.presets.any((p) => p.id == preset.id);
    await _persist(PresetsState(
      presets: exists ? [for (final p in current.presets) p.id == preset.id ? preset : p] : [...current.presets, preset],
      applied: current.applied,
    ));
  }

  /// Removes a user preset, or puts a built-in back as it shipped.
  Future<void> remove(String id) async {
    final current = await future;
    final shipped = builtInPresets.where((b) => b.id == id).firstOrNull;
    await _persist(PresetsState(
      presets: [
        for (final p in current.presets)
          if (p.id != id) p else if (shipped != null) shipped,
      ],
      applied: current.applied == id ? null : current.applied,
    ));
  }

  void markApplied(String id) {
    final current = state.value;
    if (current != null) state = AsyncData(PresetsState(presets: current.presets, applied: id));
  }

  Future<void> _persist(PresetsState next) async {
    state = AsyncData(next);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final p in next.presets) p.toJson()]));
  }
}

/// The free servers [preset] would try, best first.
List<CommunityServer> presetCandidates(Preset preset, List<CommunityServer> servers, String? myCountry) {
  final picked = servers.where((s) {
    final code = s.countryCode.toUpperCase();
    if (preset.place == PresetPlace.country && code != preset.country?.toUpperCase()) return false;
    if (preset.skipMyCountry && myCountry != null && code == myCountry.toUpperCase()) return false;
    if (preset.protocol == PresetProtocol.sstp && s.sstpHost == null) return false;
    return true;
  });
  return [
    for (final s in picked.take(preset.tryNext ? 3 : 1))
      // "OpenVPN" means OpenVPN even where the server also offers SSTP.
      preset.protocol == PresetProtocol.openvpn ? _withoutSstp(s) : s,
  ];
}

CommunityServer _withoutSstp(CommunityServer s) => CommunityServer(
      id: s.id,
      country: s.country,
      countryCode: s.countryCode,
      proto: s.proto,
      port: s.port,
      speedMbps: s.speedMbps,
      pingMs: s.pingMs,
      sessions: s.sessions,
      quality: s.quality,
      grade: s.grade,
      uptimeDays: s.uptimeDays,
      source: s.source,
    );

/// Connects with [preset]: the best fitting free server, then the next
/// ones if it fails, with the preset's Shield and Apps direct for this
/// connection. Returns false when no server fits.
///
/// Reads through [container], which outlives any screen, so the tries
/// carry on if the user leaves the page.
Future<bool> applyPreset(ProviderContainer container, Preset preset) async {
  final servers = container.read(communityProvider).value?.servers ?? const <CommunityServer>[];
  final myCountry = container.read(homePlaceProvider).country;
  final candidates = presetCandidates(preset, servers, myCountry);
  if (candidates.isEmpty) return false;

  final vpn = container.read(vpnProvider.notifier);
  final tunnels = container.read(tunnelsProvider.notifier);
  container.read(presetsProvider.notifier).markApplied(preset.id);
  if (container.read(vpnProvider).phase == VpnPhase.on) await vpn.disconnect();
  for (final server in candidates) {
    await tunnels.selectCommunity(server);
    await vpn.connect(CommunityChoice(server), override: preset.override);
    if (container.read(vpnProvider).phase == VpnPhase.on) {
      container.read(presetsProvider.notifier).markApplied(preset.id);
      return true;
    }
  }
  return true;
}
