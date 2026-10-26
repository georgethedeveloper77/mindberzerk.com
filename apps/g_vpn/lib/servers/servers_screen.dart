import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/appear.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../design/sheet.dart';
import '../gservers/gservers.dart';
import '../gservers/gservers_page.dart' show GServerRow, byLoad;
import '../i18n/strings.g.dart';
import '../map/server_map_view.dart';
import '../pro/billing.dart';
import '../ui/add_server_sheet.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'server_details.dart';
import 'community.dart';

enum _Filter { all, fastest, stable, popular, sstp }

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key, required this.openHome, required this.openPro});

  /// Tapping a server connects to it and shows the result on Home.
  final VoidCallback openHome;
  final VoidCallback openPro;

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

/// One row of tabs you swipe between: Free, G Servers (once any run) and
/// Yours. List or Map is a floating switch inside Free, not a second bar.
class _ServersScreenState extends ConsumerState<ServersScreen> with TickerProviderStateMixin {
  TabController? _tabs;
  List<String> _ids = const [];
  _Filter _filter = _Filter.all;
  bool _onMap = false;
  bool _searching = false;
  String _query = '';

  static String _label(String id) => switch (id) {
        'fast' => t.servers.fastTab,
        'free' => t.servers.tabs.free,
        'gservers' => t.servers.gTab,
        _ => t.servers.tabs.yours,
      };

  /// Rebuilds the controller when G Servers appear or go, keeping the tab
  /// the user was on.
  TabController _controllerFor(List<String> ids) {
    if (_tabs != null && listEquals(ids, _ids)) return _tabs!;
    final was = _tabs == null ? ids.first : _ids[_tabs!.index];
    // The old controller is still attached to this frame's TabBar.
    final old = _tabs;
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _ids = ids;
    final c = TabController(length: ids.length, vsync: this, initialIndex: ids.contains(was) ? ids.indexOf(was) : 0);
    c.addListener(() {
      if (!c.indexIsChanging) setState(() {});
    });
    return _tabs = c;
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Select, connect (switching if already connected elsewhere), show Home.
  Future<void> _pick(ServerChoice choice, Future<void> Function() select) async {
    await select();
    widget.openHome();
    final vpn = ref.read(vpnProvider.notifier);
    final current = ref.read(vpnProvider);
    if (current.phase == VpnPhase.on) {
      if (current.tunnelId == choice.id) return;
      await vpn.disconnect();
    }
    await vpn.connect(choice);
  }

  void _about() => showInfoSheet(
        context,
        icon: Icons.public_rounded,
        title: t.servers.sheet.title,
        subtitle: t.servers.sheet.subtitle,
        sections: [
          SheetSection(Icons.check_rounded, t.servers.tabs.free, t.servers.sheet.free, tone: context.mer.good),
          SheetSection(Icons.bolt_rounded, t.servers.tabs.pro, t.servers.sheet.pro),
          SheetSection(Icons.dns_outlined, t.servers.tabs.yours, t.servers.sheet.yours, tone: context.mer.muted),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final community = ref.watch(communityProvider);
    final g = ref.watch(gServersProvider).value ?? ref.watch(gServersCacheProvider).value;
    // Fast first (our own servers when they run, then the fastest free
    // ones), then every free server, then G Servers, then the user's own.
    final ids = ['fast', 'free', if (g != null && g.available) 'gservers', 'yours'];
    final tabs = _controllerFor(ids);
    final current = ids[tabs.index];
    final counts = {
      'free': community.value?.servers.length,
      'gservers': g?.servers.length,
      'yours': tunnels?.tunnels.length,
    };

    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.servers.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
                  ),
                  IconButton(
                    tooltip: t.servers.search,
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                      if (_searching && current != 'free') tabs.animateTo(ids.indexOf('free'));
                    }),
                    icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: m.text),
                  ),
                  InfoIcon(onPressed: _about),
                ],
              ),
            ),
            TabBar(
              controller: tabs,
              labelColor: m.text,
              unselectedLabelColor: m.muted,
              indicatorColor: current == 'gservers' ? m.warn : m.brand,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              dividerColor: m.line,
              labelStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w800),
              unselectedLabelStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w600),
              tabs: [
                for (final id in ids)
                  Tab(
                    height: 48,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (id == 'gservers') ...[Icon(Icons.workspace_premium_rounded, size: 15, color: m.warn), const SizedBox(width: 5)],
                      if (id == 'fast') ...[Icon(Icons.bolt_rounded, size: 16, color: m.brand), const SizedBox(width: 4)],
                      Text(_label(id)),
                      if (counts[id] != null) ...[
                        const SizedBox(width: 6),
                        Text('${counts[id]}', style: m.monoStyle(size: 12, color: m.muted)),
                      ],
                    ]),
                  ),
              ],
            ),
            if (_searching && current == 'free')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: t.servers.search,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: m.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: m.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: m.brand)),
                  ),
                ),
              ),
            Expanded(
              child: Stack(children: [
                TabBarView(
                  controller: tabs,
                  // The map pans with a finger, so swiping tabs stops there.
                  physics: current == 'free' && _onMap ? const NeverScrollableScrollPhysics() : null,
                  children: [
                    for (final id in ids)
                      switch (id) {
                        'free' when _onMap => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ServerMapView(onConnected: widget.openHome, openOnFastest: true),
                          ),
                        'free' => _FreeTab(
                            filter: _filter,
                            query: _query,
                            onFilter: (f) => setState(() => _filter = f),
                            pick: _pick,
                          ),
                        'gservers' => _GServersTab(info: g!),
                        'fast' => _FastTab(gservers: g != null && g.available ? g : null, pick: _pick),
                        _ => _YoursTab(pick: _pick),
                      },
                  ],
                ),
                // List or Map, floating over the Free tab.
                if (current == 'free')
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () => setState(() => _onMap = !_onMap),
                        icon: Icon(_onMap ? Icons.format_list_bulleted_rounded : Icons.map_outlined, size: 18),
                        label: Text(_onMap ? t.map.list : t.map.map),
                        style: FilledButton.styleFrom(
                          backgroundColor: m.text,
                          foregroundColor: m.bg,
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                          elevation: 6,
                          shadowColor: Colors.black54,
                          textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Pick = Future<void> Function(ServerChoice choice, Future<void> Function() select);

String _speed(double mbps) => mbps >= 10 ? mbps.round().toString() : mbps.toStringAsFixed(1);

// ── Free ──────────────────────────────────────────────────────────────────

/// Free servers grouped by country: one row per country with its best
/// figures, opening in place to show each server.
class _FreeTab extends ConsumerStatefulWidget {
  const _FreeTab({required this.filter, required this.query, required this.onFilter, required this.pick});

  final _Filter filter;
  final String query;
  final ValueChanged<_Filter> onFilter;
  final _Pick pick;

  @override
  ConsumerState<_FreeTab> createState() => _FreeTabState();
}

class _FreeTabState extends ConsumerState<_FreeTab> {
  /// Countries opened by the user; the top one opens by itself.
  final Set<String> _open = {};
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final community = ref.watch(communityProvider);
    final selectedId = ref.watch(tunnelsProvider).value?.choice?.id;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    void connect(CommunityServer s) =>
        widget.pick(CommunityChoice(s), () => ref.read(tunnelsProvider.notifier).selectCommunity(s));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(communityProvider.future),
      child: switch (community) {
        AsyncData(:final value) when value.servers.isNotEmpty => Builder(builder: (context) {
            final q = widget.query.trim().toLowerCase();
            final sorted = [
              for (final s in value.servers)
                if ((widget.filter != _Filter.sstp || s.sstpHost != null) &&
                    (q.isEmpty || countryName(s.countryCode, s.country).toLowerCase().contains(q)))
                  s,
            ];
            switch (widget.filter) {
              case _Filter.fastest:
                sorted.sort((a, b) => b.speedMbps.compareTo(a.speedMbps));
              case _Filter.stable:
                sorted.sort((a, b) => b.uptimeDays.compareTo(a.uptimeDays));
              case _Filter.popular:
                sorted.sort((a, b) => b.sessions.compareTo(a.sessions));
              case _Filter.all || _Filter.sstp:
                break; // the Worker's ranking
            }
            // Countries in the order their best server ranks.
            final groups = <String, List<CommunityServer>>{};
            for (final s in sorted) {
              groups.putIfAbsent(s.countryCode.toUpperCase(), () => []).add(s);
            }
            final codes = groups.keys.toList();
            final open = _touched ? _open : {if (codes.isNotEmpty) codes.first};
            final best = value.servers.first;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
              children: [
                if (q.isEmpty) ...[
                  Appear(index: 0, child: _BestCard(server: best, onConnect: busy ? null : () => connect(best))),
                  const SizedBox(height: 14),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (f, label) in [
                        (_Filter.all, t.servers.filters.all),
                        (_Filter.fastest, t.servers.filters.fastest),
                        (_Filter.stable, t.servers.filters.stable),
                        (_Filter.popular, t.servers.filters.popular),
                        (_Filter.sstp, 'SSTP'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: widget.filter == f,
                            onSelected: (_) => widget.onFilter(f),
                            showCheckmark: false,
                            selectedColor: m.text,
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: widget.filter == f ? m.bg : m.text),
                            shape: StadiumBorder(side: BorderSide(color: widget.filter == f ? m.text : m.line)),
                            backgroundColor: m.surface,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (codes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.servers.noMatch, textAlign: TextAlign.center, style: TextStyle(color: m.muted)),
                  )
                else
                  KeyedSubtree(
                    key: ValueKey('${widget.filter}$q'),
                    child: _Group(children: [
                      for (final (i, code) in codes.indexed)
                        Appear(
                          index: i + 1,
                          child: _CountryRow(
                            servers: groups[code]!,
                            open: open.contains(code),
                            selectedId: selectedId,
                            busy: busy,
                            onToggle: () => setState(() {
                              if (!_touched) {
                                _touched = true;
                                _open.addAll(open);
                              }
                              _open.contains(code) ? _open.remove(code) : _open.add(code);
                            }),
                            onConnect: connect,
                          ),
                        ),
                    ]),
                  ),
              ],
            );
          }),
        AsyncData() || AsyncError() => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Group(children: [
                ListTile(
                  title: Text(community.hasError ? t.servers.loadFailed : t.servers.noServers, style: TextStyle(fontWeight: FontWeight.w700, color: m.text)),
                  trailing: TextButton(onPressed: () => ref.invalidate(communityProvider), child: Text(t.common.retry)),
                ),
              ]),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Signal bars from the Worker's grade.
class _Bars extends StatelessWidget {
  const _Bars({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final n = switch (grade) { 'fast' => 4, 'good' => 3, _ => 2 };
    final c = grade == 'slow' ? m.warn : m.good;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 4,
            height: 6.0 + i * 3.4,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(color: i < n ? c : m.line, borderRadius: BorderRadius.circular(1)),
          ),
      ],
    );
  }
}

/// One country: its server count and best figures on two short lines, and
/// its servers when opened (three, then "Show all"). A country with one
/// server connects straight from the row.
class _CountryRow extends StatefulWidget {
  const _CountryRow({
    required this.servers,
    required this.open,
    required this.selectedId,
    required this.busy,
    required this.onToggle,
    required this.onConnect,
  });

  final List<CommunityServer> servers;
  final bool open;
  final String? selectedId;
  final bool busy;
  final VoidCallback onToggle;
  final ValueChanged<CommunityServer> onConnect;

  @override
  State<_CountryRow> createState() => _CountryRowState();
}

class _CountryRowState extends State<_CountryRow> {
  static const _first = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final servers = widget.servers;
    final top = servers.first;
    final single = servers.length == 1;
    final pings = servers.where((s) => s.pingMs > 0).map((s) => s.pingMs);
    final fastest = servers.map((s) => s.speedMbps).fold<double>(0, (a, b) => b > a ? b : a);
    final facts = [
      if (pings.isNotEmpty) '${pings.reduce((a, b) => a < b ? a : b)} ms',
      if (fastest > 0) '${_speed(fastest)} Mbps',
    ].join(' · ');
    final hasSelected = servers.any((s) => '$communityPrefix${s.id}' == widget.selectedId);
    final shown = _all ? servers : servers.take(_first).toList();

    return Container(
      color: widget.open || hasSelected ? m.brand.withValues(alpha: .06) : null,
      child: Column(children: [
        InkWell(
          onTap: single ? (widget.busy ? null : () => widget.onConnect(top)) : widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              CountryFlag(top.countryCode, width: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(countryName(top.countryCode, top.country),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                    ),
                    if (!single) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: m.surface2, borderRadius: BorderRadius.circular(999)),
                        child: Text('${servers.length}', style: m.monoStyle(size: 11, color: m.muted)),
                      ),
                    ],
                  ]),
                  if (facts.isNotEmpty)
                    Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: m.monoStyle(size: 12, color: m.muted)),
                ]),
              ),
              if (hasSelected && !widget.open) ...[Icon(Icons.check_rounded, color: m.brand, size: 20), const SizedBox(width: 6)],
              _Bars(grade: top.grade),
              const SizedBox(width: 4),
              if (single)
                IconButton(
                  tooltip: t.common.connect,
                  onPressed: widget.busy ? null : () => widget.onConnect(top),
                  icon: Icon(Icons.power_settings_new_rounded, color: m.brand),
                )
              else
                AnimatedRotation(
                  turns: widget.open ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.expand_more_rounded, color: m.muted),
                  ),
                ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !widget.open || single
              ? const SizedBox(width: double.infinity)
              : Column(children: [
                  for (final (i, s) in shown.indexed)
                    _ServerLine(
                      server: s,
                      rank: i + 1,
                      best: i == 0,
                      selected: '$communityPrefix${s.id}' == widget.selectedId,
                      onConnect: widget.busy ? null : () => widget.onConnect(s),
                    ),
                  if (servers.length > _first)
                    InkWell(
                      onTap: () => setState(() => _all = !_all),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
                        child: Text(
                          _all ? t.servers.showFewer : t.servers.showAll(n: servers.length),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: m.brand),
                        ),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }
}

/// One server inside an open country: its rank, speed large, protocol and
/// ping small, and a round connect button. The whole row connects too.
class _ServerLine extends StatelessWidget {
  const _ServerLine({required this.server, required this.rank, required this.best, required this.selected, required this.onConnect});

  final CommunityServer server;
  final int rank;
  final bool best;
  final bool selected;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final s = server;
    final sub = [s.sstpHost != null ? 'SSTP' : s.proto.toUpperCase(), if (s.pingMs > 0) '${s.pingMs} ms'].join(' · ');
    return InkWell(
      onTap: selected ? null : onConnect,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? m.brand : m.surface2, shape: BoxShape.circle),
            child: selected
                ? Icon(Icons.check_rounded, size: 16, color: m.onBrand)
                : Text('$rank', style: m.monoStyle(size: 12, color: m.muted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.speedMbps > 0 ? '${_speed(s.speedMbps)} Mbps' : sub, style: m.monoStyle(size: 14, color: m.text)),
                if (best) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: m.good.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
                    child: Text(t.servers.bestTag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: m.good)),
                  ),
                ],
              ]),
              if (s.speedMbps > 0) Text(sub, style: m.monoStyle(size: 11, color: m.muted)),
            ]),
          ),
          _Bars(grade: s.grade),
          const SizedBox(width: 6),
          IconButton(
            tooltip: t.common.connect,
            onPressed: selected ? null : onConnect,
            style: IconButton.styleFrom(
              backgroundColor: m.brand.withValues(alpha: .14),
              foregroundColor: m.brand,
              disabledBackgroundColor: Colors.transparent,
            ),
            icon: const Icon(Icons.power_settings_new_rounded, size: 20),
          ),
        ]),
      ),
    );
  }
}

/// The server Worker ranks first: one line, one button.
class _BestCard extends StatelessWidget {
  const _BestCard({required this.server, required this.onConnect});

  final CommunityServer server;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final facts = [
      if (server.pingMs > 0) '${server.pingMs} ms',
      if (server.speedMbps > 0) '${_speed(server.speedMbps)} Mbps',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        gradient: LinearGradient(colors: [m.brand.withValues(alpha: .22), m.brand.withValues(alpha: .08)]),
        border: Border.all(color: m.brand.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: m.brand.withValues(alpha: .2), borderRadius: BorderRadius.circular(13)),
          child: Icon(Icons.bolt_rounded, color: m.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.servers.best, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.brand)),
            const SizedBox(height: 2),
            Row(children: [
              CountryFlag(server.countryCode, width: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(countryName(server.countryCode, server.country),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
              ),
              if (facts.isNotEmpty) ...[const SizedBox(width: 8), Text(facts, style: m.monoStyle(size: 12, color: m.muted))],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onConnect,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(t.common.connect),
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Meridian.rCard), side: BorderSide(color: m.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: m.line),
            c,
          ],
        ],
      ),
    );
  }
}

// ── Fast ──────────────────────────────────────────────────────────────────

/// The quickest way to a fast connection: G Servers, least busy first, when
/// they run; then the free servers with the most speed.
class _FastTab extends ConsumerWidget {
  const _FastTab({required this.gservers, required this.pick});

  final GServersInfo? gservers;
  final _Pick pick;

  static const _freeShown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final community = ref.watch(communityProvider);
    final selectedId = ref.watch(tunnelsProvider).value?.choice?.id;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final g = gservers;
    final free = [...?community.value?.servers]..sort((a, b) => b.speedMbps.compareTo(a.speedMbps));
    Widget heading(String text, Color color) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: color)),
        );

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(gServersProvider);
        return ref.refresh(communityProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (g != null) ...[
            heading(t.gs.servers, m.warn),
            _Group(children: [for (final s in byLoad(g.servers)) GServerRow(server: s)]),
          ],
          heading(t.servers.fastestFree, m.brand),
          switch (community) {
            AsyncData() when free.isNotEmpty => _Group(children: [
                for (final (i, s) in free.take(_freeShown).indexed)
                  Appear(
                    index: i,
                    child: _FastRow(
                      server: s,
                      selected: '$communityPrefix${s.id}' == selectedId,
                      onConnect: busy ? null : () => pick(CommunityChoice(s), () => ref.read(tunnelsProvider.notifier).selectCommunity(s)),
                    ),
                  ),
              ]),
            AsyncData() || AsyncError() => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(community.hasError ? t.servers.loadFailed : t.servers.noServers, style: TextStyle(color: m.muted)),
              ),
            _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

/// A fast free server: country, speed large, protocol and ping small.
class _FastRow extends StatelessWidget {
  const _FastRow({required this.server, required this.selected, required this.onConnect});

  final CommunityServer server;
  final bool selected;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final s = server;
    final sub = [
      countryName(s.countryCode, s.country),
      s.sstpHost != null ? 'SSTP' : s.proto.toUpperCase(),
      if (s.pingMs > 0) '${s.pingMs} ms',
    ].join(' · ');
    return InkWell(
      onTap: selected ? null : onConnect,
      child: Container(
        color: selected ? m.brand.withValues(alpha: .06) : null,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          CountryFlag(s.countryCode, width: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_speed(s.speedMbps)} Mbps', style: m.monoStyle(size: 15, color: m.text)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: m.muted)),
            ]),
          ),
          _Bars(grade: s.grade),
          const SizedBox(width: 6),
          if (selected)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.check_rounded, color: m.brand))
          else
            IconButton(
              tooltip: t.common.connect,
              onPressed: onConnect,
              style: IconButton.styleFrom(backgroundColor: m.brand.withValues(alpha: .14), foregroundColor: m.brand),
              icon: const Icon(Icons.power_settings_new_rounded, size: 20),
            ),
        ]),
      ),
    );
  }
}

// ── G Servers ─────────────────────────────────────────────────────────────

class _GServersTab extends ConsumerWidget {
  const _GServersTab({required this.info});

  final GServersInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final owned = ref.watch(billingProvider).owned;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(gServersProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: m.warn.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(Meridian.rCard),
              border: Border.all(color: m.warn.withValues(alpha: .35)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: m.warn.withValues(alpha: .18), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.workspace_premium_rounded, color: m.warn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.servers.ownHero, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
                  Text(t.servers.ownHeroSub, style: TextStyle(fontSize: 12, color: m.muted)),
                ]),
              ),
              if (owned) Tag(t.gs.active, color: m.good),
            ]),
          ),
          const SizedBox(height: 12),
          _Group(children: [for (final s in byLoad(info.servers)) GServerRow(server: s)]),
        ],
      ),
    );
  }
}

// ── Yours ─────────────────────────────────────────────────────────────────

class _YoursTab extends ConsumerWidget {
  const _YoursTab({required this.pick});

  final _Pick pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final tunnels = ref.watch(tunnelsProvider).value;
    final selectedId = tunnels?.choice?.id;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;
    final list = tunnels?.tunnels ?? const <SavedTunnel>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final (i, tunnel) in list.indexed) ...[
          Appear(
            key: ValueKey(tunnel.id),
            index: i,
            child: _OwnCard(
              tunnel: tunnel,
              selected: tunnel.id == selectedId,
              connected: phase == VpnPhase.on && tunnel.id == selectedId,
              onConnect: busy ? null : () => pick(OwnServer(tunnel), () => ref.read(tunnelsProvider.notifier).select(tunnel.id)),
              onRemove: () => ref.read(tunnelsProvider.notifier).remove(tunnel.id),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
          child: Text(t.servers.addHeading, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .6, color: m.muted)),
        ),
        Row(
          children: [
            Expanded(child: _AddButton(icon: Icons.qr_code_scanner_rounded, label: t.servers.scanQr, onTap: () => _scanChoice(context, ref))),
            const SizedBox(width: 10),
            Expanded(child: _AddButton(icon: Icons.file_open_outlined, label: t.servers.importFile, onTap: () => _importFile(context, ref))),
            const SizedBox(width: 10),
            Expanded(child: _AddButton(icon: Icons.content_paste_rounded, label: t.servers.paste, onTap: () => AddServerSheet.show(context))),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: m.line, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showInfoSheet(
              context,
              icon: Icons.terminal_rounded,
              title: t.servers.own.title,
              subtitle: t.servers.own.subtitle,
              sections: [
                SheetSection(Icons.router_outlined, t.servers.own.router, t.servers.own.routerBody),
                SheetSection(Icons.cloud_outlined, t.servers.own.vps, t.servers.own.vpsBody),
                SheetSection(Icons.home_outlined, t.servers.own.home, t.servers.own.homeBody),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: m.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.isEmpty ? t.servers.own.noneYet : t.servers.own.addAnother, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.text)),
                        Text(t.servers.own.hint, style: TextStyle(fontSize: 13, color: m.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: m.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnCard extends ConsumerWidget {
  const _OwnCard({
    required this.tunnel,
    required this.selected,
    required this.connected,
    required this.onConnect,
    required this.onRemove,
  });

  final SavedTunnel tunnel;
  final bool selected;
  final bool connected;
  final VoidCallback? onConnect;
  final VoidCallback onRemove;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await _RenameSheet.show(context, tunnel.name);
    if (name != null) await ref.read(tunnelsProvider.notifier).rename(tunnel.id, name);
  }

  void _openDetails(BuildContext context, WidgetRef ref) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServerDetailsScreen(
            tunnelId: tunnel.id,
            onConnect: () => onConnect?.call(),
            onRename: () => _rename(context, ref),
            onRemove: () async {
              if (!await confirmRemoveServer(context)) return false;
              onRemove();
              return true;
            },
          ),
        ),
      );

  Future<void> _actions(BuildContext context, WidgetRef ref, String endpoint) async {
    final choice = await _ServerActionsSheet.show(context, tunnel.name, endpoint, canRemove: !connected);
    if (!context.mounted) return;
    switch (choice) {
      case _ServerAction.rename:
        await _rename(context, ref);
      case _ServerAction.remove:
        onRemove();
      case null:
        break;
    }
  }

  static String _bytes(int b) {
    if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(b / 1024).toStringAsFixed(0)} KB';
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return t.servers.justNow;
    if (d.inHours < 1) return t.servers.minutesAgo(n: d.inMinutes);
    if (d.inDays < 1) return t.servers.hoursAgo(n: d.inHours);
    return t.servers.daysAgo(n: d.inDays);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final vpn = ref.watch(vpnProvider);
    final busy = vpn.phase == VpnPhase.connecting || vpn.phase == VpnPhase.disconnecting;
    String endpoint;
    try {
      endpoint = tunnel.summary.endpoint;
    } on Exception {
      endpoint = t.servers.configBroken;
    }
    final detail = connected
        ? '↓ ${_bytes(vpn.rxBytes)}  ↑ ${_bytes(vpn.txBytes)}'
        : tunnel.lastUsed == null
            ? t.servers.neverUsed
            : t.servers.lastUsed(when: _ago(tunnel.lastUsed!));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 16),
      decoration: BoxDecoration(
        color: connected ? Color.alphaBlend(m.brand.withValues(alpha: .06), m.surface) : m.surface,
        borderRadius: BorderRadius.circular(Meridian.rCard),
        border: Border.all(color: selected ? m.brand : m.line, width: selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: connected ? m.good.withValues(alpha: .16) : m.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.dns_outlined, color: connected ? m.good : m.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openDetails(context, ref),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          tunnel.name,
                          key: ValueKey(tunnel.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: m.text),
                        ),
                      ),
                      Text(endpoint, maxLines: 1, overflow: TextOverflow.ellipsis, style: m.monoStyle(size: 12, color: m.muted)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          detail,
                          key: ValueKey(connected),
                          style: m.monoStyle(size: 12, color: connected ? m.good : m.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: t.servers.more,
                onPressed: () => _actions(context, ref, endpoint),
                icon: Icon(Icons.more_vert_rounded, color: m.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              // Connect and Disconnect cross-fade and settle into place.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: child),
                ),
                child: connected
                    ? OutlinedButton.icon(
                        key: const ValueKey('disconnect'),
                        onPressed: busy ? null : () => ref.read(vpnProvider.notifier).disconnect(),
                        icon: Icon(Icons.power_settings_new_rounded, color: m.bad),
                        label: Text(t.servers.disconnect, style: TextStyle(color: m.bad, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: m.bad.withValues(alpha: .5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : FilledButton(
                        key: const ValueKey('connect'),
                        onPressed: onConnect,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t.common.connect),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ServerAction { rename, remove }

/// Bottom sheet: what can be done with one of the user's servers. Removing
/// asks once more, inside the same sheet.
class _ServerActionsSheet extends StatefulWidget {
  const _ServerActionsSheet({required this.name, required this.endpoint, required this.canRemove});

  final String name;
  final String endpoint;
  final bool canRemove;

  static Future<_ServerAction?> show(BuildContext context, String name, String endpoint, {required bool canRemove}) =>
      showModalBottomSheet<_ServerAction>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _ServerActionsSheet(name: name, endpoint: endpoint, canRemove: canRemove),
      );

  @override
  State<_ServerActionsSheet> createState() => _ServerActionsSheetState();
}

class _ServerActionsSheetState extends State<_ServerActionsSheet> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
            Text(widget.endpoint, style: m.monoStyle(size: 12, color: m.muted)),
            const SizedBox(height: 16),
            if (!_confirming)
              ListGroup(children: [
                ListItem(
                  leading: Icon(Icons.edit_outlined, color: m.brand),
                  title: t.servers.rename,
                  onTap: () => Navigator.pop(context, _ServerAction.rename),
                ),
                ListItem(
                  leading: Icon(Icons.delete_outline_rounded, color: widget.canRemove ? m.bad : m.muted),
                  title: t.common.remove,
                  subtitle: widget.canRemove ? null : t.servers.disconnectFirst,
                  onTap: widget.canRemove ? () => setState(() => _confirming = true) : null,
                ),
              ])
            else ...[
              Text(t.servers.removeConfirm, style: TextStyle(fontSize: 15, height: 1.4, color: m.text)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _confirming = false),
                      child: Text(t.common.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: m.bad),
                      onPressed: () => Navigator.pop(context, _ServerAction.remove),
                      child: Text(t.common.remove),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with a name field. Owns its text controller, so nothing is
/// disposed while the sheet is still animating closed.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  static Future<String?> show(BuildContext context, String initial) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _RenameSheet(initial: initial),
      );

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final v = _name.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Padding(
      // Rises with the keyboard.
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.servers.renameTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(hintText: t.servers.nameHint),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(t.servers.save, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Material(
      color: m.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: m.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: m.brand),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: m.text)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _scan(BuildContext context, WidgetRef ref) async {
  try {
    final text = await ref.read(vpnApiProvider).scanQr();
    if (text == null || !context.mounted) return;
    await AddServerSheet.show(context, name: suggestServerName(text) ?? t.servers.scannedServer, config: text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, t.servers.scanFailedTitle, e.message ?? t.servers.scanFailedBody);
  }
}

Future<void> _importFile(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ref.read(vpnApiProvider).pickConfigFile();
    if (picked == null || !context.mounted) return;
    final backup = parseBackup(picked.text);
    if (backup != null) {
      final store = ref.read(tunnelsProvider.notifier);
      final have = {for (final s in (await ref.read(tunnelsProvider.future)).tunnels) s.configText.trim()};
      var added = 0;
      for (final s in backup) {
        if (have.contains(s.config.trim())) continue;
        if (await store.add(name: s.name, configText: s.config) == null) added++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(added == 0 ? t.backup.nothingNew : t.backup.restored(n: added))),
        );
      }
      return;
    }
    await AddServerSheet.show(context, name: suggestServerName(picked.text) ?? picked.name, config: picked.text);
  } on PlatformException catch (e) {
    if (context.mounted) await _problem(context, t.servers.importFailedTitle, e.message ?? t.servers.importFailedBody);
  }
}

Future<void> _problem(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t.common.ok))],
      ),
    );


/// Scan QR: with the camera, or from an image already on the phone.
Future<void> _scanChoice(BuildContext context, WidgetRef ref) async {
  final m = context.mer;
  final fromImage = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.add.title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 4),
          Text(t.add.subtitle, style: TextStyle(fontSize: 14, height: 1.45, color: m.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: t.add.camera,
                  subtitle: t.add.cameraSub,
                  primary: true,
                  onTap: () => Navigator.pop(c, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.image_outlined,
                  title: t.add.image,
                  subtitle: t.add.imageSub,
                  onTap: () => Navigator.pop(c, true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: m.brandSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: m.brand),
                const SizedBox(width: 10),
                Expanded(child: Text(t.add.tip, style: TextStyle(fontSize: 13, height: 1.45, color: m.text))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (fromImage == null || !context.mounted) return;
  if (!fromImage) return _scan(context, ref);
  try {
    final text = await ref.read(vpnApiProvider).scanQrFromImage();
    if (text == null || !context.mounted) return;
    await AddServerSheet.show(context, name: suggestServerName(text) ?? t.servers.scannedServer, config: text);
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code == 'no_qr' ? t.add.noQr : (e.message ?? t.add.noQr))),
      );
    }
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final fg = primary ? Colors.white : m.text;
    return Material(
      color: primary ? m.brand : m.brandSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(16),
          decoration: primary
              ? null
              : BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: m.brand, width: 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: primary ? Colors.white : m.brand),
              const SizedBox(height: 18),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: primary ? Colors.white.withValues(alpha: .85) : m.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks once before a server's settings are deleted from this phone.
Future<bool> confirmRemoveServer(BuildContext context) async {
  final m = context.mer;
  final yes = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.servers.removeConfirm, style: TextStyle(fontSize: 15, height: 1.45, color: m.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(t.common.cancel))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: m.bad),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t.common.remove),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return yes ?? false;
}
