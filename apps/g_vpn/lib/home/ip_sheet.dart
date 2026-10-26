import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../map/lat_lon.dart';
import '../i18n/strings.g.dart';
import '../map/g_map.dart';
import '../map/map_data.dart';
import '../vpn/vpn_controller.dart';
import 'home_scan.dart';

/// Where an IP places someone, as people say it: "Nairobi, Kenya", or just
/// the country when the lookup has no city. Null when it has neither.
String? approximatePlace(String? city, String? country) {
  final name = country == null || country.isEmpty ? null : countryName(country, country);
  final parts = [city, name].whereType<String>().where((s) => s.trim().isNotEmpty);
  return parts.isEmpty ? null : parts.join(', ');
}

/// What sites see: the IP, provider and approximate place, on a small map.
/// [onHide] connects; it is offered only while exposed.
Future<void> showIpSheet(BuildContext context, {required Future<void> Function() onHide}) {
  final m = context.mer;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _IpSheet(onHide: onHide),
  );
}

class _IpSheet extends ConsumerWidget {
  const _IpSheet({required this.onHide});

  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final on = phase == VpnPhase.on;
    final identity = ref.watch(identityProvider);
    final id = identity.value;
    // City coordinates when the Worker sends them; else the country only.
    final place = id?.latitude != null && id?.longitude != null ? LatLon(id!.latitude!, id.longitude!) : null;
    final code = isoOf(id?.country);
    final spot = place ?? placeOf(country: code);
    final tone = on ? m.good : m.bad;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.home.ip.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.4, color: m.text),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: tone.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        on ? t.home.ip.vpn : t.home.ip.real,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tone),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(Meridian.rTile),
              child: Container(
                height: 168,
                decoration: BoxDecoration(
                  color: m.bg,
                  border: Border.all(color: m.line),
                  borderRadius: BorderRadius.circular(Meridian.rTile),
                ),
                child: spot == null
                    ? Center(child: Icon(Icons.public_rounded, size: 40, color: m.muted))
                    : GMap(
                        // Close in on a city; frame the whole country otherwise.
                        zoom: place == null ? null : 9.5,
                        scene: MapScene(
                          mood: on ? MapMood.protected : MapMood.exposed,
                          you: on ? null : spot,
                          youCountry: on ? null : code,
                          server: on ? spot : null,
                          serverCountry: on ? code : null,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            switch (identity) {
              AsyncData(:final value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (approximatePlace(value.city, value.country) case final estimate?) ...[
                      Text(
                        t.home.ip.near(place: estimate),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3, color: m.text),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.home.ip.address, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m.muted)),
                              const SizedBox(height: 2),
                              Text(value.ip, style: m.monoStyle(size: 20, color: m.text)),
                            ],
                          ),
                        ),
                        _CopyButton(text: value.ip),
                      ],
                    ),
                  ],
                ),
              AsyncError() => Text(t.home.ipFailed, style: TextStyle(fontSize: 15, color: m.warn)),
              _ => Text(t.home.ipChecking, style: TextStyle(fontSize: 15, color: m.muted)),
            },
            if (id != null && (id.org != null || place != null)) ...[
              const SizedBox(height: 10),
              MerCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: m.bg,
                child: Column(
                  children: [
                    if (id.org != null) MerRow(t.network.provider, id.org!),
                    if (place != null)
                      MerRow(
                        t.home.ip.coordinates,
                        '${place.lat.toStringAsFixed(4)}, ${place.lon.toStringAsFixed(4)}',
                        mono: true,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: m.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(t.home.ip.note, style: TextStyle(fontSize: 12, color: m.muted))),
              ],
            ),
            if (phase == VpnPhase.off) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(onHide());
                  },
                  icon: const Icon(Icons.lock_rounded, size: 20),
                  label: Text(t.home.ip.hide),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Copies [text]; the label confirms in place, since a snack bar would sit
/// behind the sheet.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _copy,
        icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
        label: Text(_copied ? t.details.copied : t.details.copy),
        style: OutlinedButton.styleFrom(
          foregroundColor: _copied ? m.good : m.text,
          side: BorderSide(color: m.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
