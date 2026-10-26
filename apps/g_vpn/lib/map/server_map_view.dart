import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/flag.dart';
import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import 'g_map.dart';
import 'map_data.dart';
import 'server_sheet.dart';

/// The interactive map of servers: one marker per country, a search that
/// flies to a country, and a bottom sheet of that country's servers for the
/// marker tapped. Used full screen from Home and as the Map view in Servers.
class ServerMapView extends ConsumerStatefulWidget {
  const ServerMapView({super.key, this.onConnected, this.leading, this.topInset = 0, this.openOnFastest = false});

  /// Runs once a connection starts from the sheet, to show Home.
  final VoidCallback? onConnected;

  /// Shown left of the search field, such as a back button.
  final Widget? leading;

  /// Space above the search field, for the status bar.
  final double topInset;

  /// Open on the fastest servers: G Servers' country when they run, else
  /// the country of the free server ranked first.
  final bool openOnFastest;

  @override
  ConsumerState<ServerMapView> createState() => _ServerMapViewState();
}

class _ServerMapViewState extends ConsumerState<ServerMapView> {
  final _map = GlobalKey<GMapState>();
  final _search = TextEditingController();
  final _focus = FocusNode();
  String? _selected;
  bool _flown = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Highlights [c] and opens its sheet; the highlight clears on close.
  Future<void> _open(CountryServers c) async {
    setState(() => _selected = c.code);
    await showServerSheet(context, country: c, onConnected: widget.onConnected);
    if (mounted) setState(() => _selected = null);
  }

  void _select(CountryServers c) {
    _search.clear();
    _focus.unfocus();
    _map.currentState?.focusOn(c.code, c.at);
    unawaited(_open(c));
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final countries = ref.watch(countryServersProvider);
    final scene = ref.watch(mapSceneProvider);
    if (widget.openOnFastest && !_flown && countries.isNotEmpty) {
      _flown = true;
      final fastest = countries.where((c) => c.gservers.isNotEmpty).firstOrNull ?? countries.first;
      // Once the map has drawn its style; a camera move before that is lost.
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _selected = fastest.code);
        _map.currentState?.focusOn(fastest.code, fastest.at);
      });
    }
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <CountryServers>[]
        : countries.where((c) => c.name.toLowerCase().contains(query) || c.code.toLowerCase() == query).take(5).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: GMap(
            key: _map,
            interactive: true,
            // Clear of the search bar above and the locate button below.
            padding: EdgeInsets.only(top: widget.topInset + 72, bottom: 80),
            scene: scene.withMarkers([for (final c in countries) c.marker], selected: _selected),
            onMarkerTap: (id) {
              final hit = countries.where((c) => c.code == id).firstOrNull;
              if (hit != null) unawaited(_open(hit));
            },
          ),
        ),
        Positioned(
          top: widget.topInset + 12,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Material(
                      color: m.surface,
                      shape: StadiumBorder(side: BorderSide(color: m.line)),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Icons.search_rounded, size: 20, color: m.muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _search,
                                focusNode: _focus,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) {
                                  if (matches.isNotEmpty) _select(matches.first);
                                },
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: m.text),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: t.map.searchCountries,
                                  hintStyle: TextStyle(fontSize: 15, color: m.muted),
                                ),
                              ),
                            ),
                            if (_search.text.isNotEmpty)
                              IconButton(
                                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                                onPressed: _search.clear,
                                icon: Icon(Icons.close_rounded, size: 18, color: m.muted),
                              )
                            else
                              const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 8),
                Material(
                  color: m.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Meridian.rTile),
                    side: BorderSide(color: m.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(t.map.noMatch, style: TextStyle(fontSize: 14, color: m.muted)),
                        )
                      : Column(
                          children: [
                            for (final c in matches)
                              ListTile(
                                leading: CountryFlag(c.code, width: 30),
                                title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: m.text)),
                                trailing: Text('${c.count}', style: m.monoStyle(size: 13, color: m.muted)),
                                onTap: () => _select(c),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: IconButton.filledTonal(
            tooltip: t.map.locate,
            onPressed: () => _map.currentState?.recenter(),
            style: IconButton.styleFrom(backgroundColor: m.surface, foregroundColor: m.text, fixedSize: const Size(48, 48)),
            icon: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}
