import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../checks/checks_screen.dart';
import '../design/countries.dart';
import '../design/flag.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../map/country_shapes.dart';
import '../tools/tool_widgets.dart';
import 'breach_map.dart';
import 'breaches.dart';

enum _Sort { newest, biggest, passwords }

/// The breach's logo from HIBP, or its initials while that loads or fails.
class BreachLogo extends StatelessWidget {
  const BreachLogo({super.key, required this.breach, this.size = 40});

  final Breach breach;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final letters = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: m.pink.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(size * .3)),
      child: Text(
        breach.title.isEmpty
            ? '?'
            : breach.title
                .substring(0, breach.title.length.clamp(1, 2))
                .toUpperCase(),
        style: TextStyle(
            fontSize: size * .34, fontWeight: FontWeight.w800, color: m.pink),
      ),
    );
    final logo = breach.logo;
    if (logo == null) return letters;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(size * .3)),
      child: Image.network(logo,
          fit: BoxFit.contain, errorBuilder: (_, __, ___) => letters),
    );
  }
}

String _month(BuildContext context, DateTime? d) =>
    d == null ? '' : MaterialLocalizations.of(context).formatMonthYear(d);

/// Tools › Data breaches: what was leaked lately, biggest first on top.
class BreachesScreen extends ConsumerStatefulWidget {
  const BreachesScreen({super.key});

  @override
  ConsumerState<BreachesScreen> createState() => _BreachesScreenState();
}

class _BreachesScreenState extends ConsumerState<BreachesScreen> {
  _Sort _sort = _Sort.newest;

  /// Null: everywhere. '': worldwide sites (.com and the like). Else a country.
  String? _place;
  String _query = '';

  void _open(Breach b) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => BreachScreen(breach: b)));

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final list = ref.watch(breachesProvider);
    return ToolPage(
      title: t.breaches.title,
      icon: Icons.key_rounded,
      color: m.pink,
      info: t.breaches.info,
      children: [
        switch (list) {
          AsyncData(:final value) when value.isNotEmpty => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Places(
                  breaches: value,
                  place: _place,
                  onPlace: (p) => setState(() => _place = p),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t.breaches.search,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: m.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: m.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: m.pink)),
                  ),
                ),
                const SizedBox(height: 14),
                Builder(builder: (_) {
                  final q = _query.trim().toLowerCase();
                  final shown = value
                      .where((b) =>
                          _place == null || (breachCountry(b) ?? '') == _place)
                      .where((b) =>
                          q.isEmpty ||
                          b.title.toLowerCase().contains(q) ||
                          b.domain.toLowerCase().contains(q) ||
                          b.dataClasses.any((d) => d.toLowerCase().contains(q)))
                      .toList();
                  return shown.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(t.breaches.noneHere,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: m.muted)),
                        )
                      : _Feed(
                          breaches: shown,
                          sort: _sort,
                          onSort: (s) => setState(() => _sort = s),
                          onOpen: _open);
                }),
              ],
            ),
          AsyncData() || AsyncError() => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(t.breaches.unavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: m.muted)),
            ),
          _ => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator())),
        },
      ],
    );
  }
}

/// The map, and the places under it: worldwide sites and each country.
class _Places extends StatelessWidget {
  const _Places(
      {required this.breaches, required this.place, required this.onPlace});

  final List<Breach> breaches;
  final String? place;
  final ValueChanged<String?> onPlace;

  void _openGlobe(BuildContext context, [String? country]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BreachGlobeScreen(
            breaches: breaches, onPlace: onPlace, country: country),
      ));

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final counts = breachesByCountry(breaches);
    final worldwide = breaches.where((b) => breachCountry(b) == null).length;
    Widget chip(String? value, Widget label) {
      final on = place == value;
      final country = value != null && value.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: label,
          selected: on,
          showCheckmark: false,
          onSelected: (_) =>
              country ? _openGlobe(context, value) : onPlace(on ? null : value),
          selectedColor: m.pink.withValues(alpha: .16),
          backgroundColor: m.surface,
          shape: StadiumBorder(side: BorderSide(color: on ? m.pink : m.line)),
          labelStyle: TextStyle(
              fontWeight: FontWeight.w700, color: on ? m.pink : m.text),
        ),
      );
    }

    return MerCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A small Earth, turning; a tap opens the full globe.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 300,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                    colors: [Color(0xFF121A3C), Color(0xFF05070F)], radius: .9),
              ),
              child: Stack(fit: StackFit.expand, children: [
                BreachGlobe(
                  counts: counts,
                  interactive: false,
                  onTapAnywhere: () => _openGlobe(context),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: IconButton(
                    tooltip: t.breaches.bigMap,
                    onPressed: () => _openGlobe(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xB30A0E1E),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x2EFFFFFF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              chip('', Text(t.breaches.worldwide(n: worldwide))),
              for (final e in counts.entries.take(8))
                chip(
                  e.key,
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CountryFlag(e.key, width: 18),
                    const SizedBox(width: 6),
                    Text('${countryName(e.key, e.key)} ${e.value}'),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed(
      {required this.breaches,
      required this.sort,
      required this.onSort,
      required this.onOpen});

  final List<Breach> breaches;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<Breach> onOpen;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final month = DateTime.now().subtract(const Duration(days: 31));
    final recent = breaches.where((b) => b.addedDate.isAfter(month)).toList();
    final biggest = (recent.isEmpty ? breaches.take(10) : recent)
        .reduce((a, b) => a.pwnCount >= b.pwnCount ? a : b);
    final shown = [
      for (final b in breaches)
        if (b != biggest && (sort != _Sort.passwords || b.hasPasswords)) b,
    ];
    if (sort == _Sort.biggest) {
      shown.sort((a, b) => b.pwnCount.compareTo(a.pwnCount));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The biggest of the last month, on top.
        Material(
          color: m.bad.withValues(alpha: .12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: m.bad.withValues(alpha: .45)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onOpen(biggest),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Tag(text: t.breaches.biggest, color: m.bad),
                  const SizedBox(height: 12),
                  Row(children: [
                    BreachLogo(breach: biggest, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(biggest.title,
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: m.text)),
                            Text(
                              '${t.breaches.accounts(n: biggest.pwnCount, count: compactCount(biggest.pwnCount))} · ${_month(context, biggest.breachDate ?? biggest.addedDate)}',
                              style: TextStyle(fontSize: 13, color: m.muted),
                            ),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _Classes(classes: biggest.dataClasses.take(5).toList()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          for (final (s, label) in [
            (_Sort.newest, t.breaches.newest),
            (_Sort.biggest, t.breaches.biggestSort),
            (_Sort.passwords, t.breaches.withPasswords),
          ])
            ChoiceChip(
              label: Text(label),
              selected: sort == s,
              showCheckmark: false,
              onSelected: (_) => onSort(s),
              selectedColor: m.pink.withValues(alpha: .16),
              labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sort == s ? m.pink : m.text),
            ),
        ]),
        const SizedBox(height: 10),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, b) in shown.take(60).indexed) ...[
              if (i > 0) Divider(height: 1, indent: 66, color: m.line),
              InkWell(
                onTap: () => onOpen(b),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                  child: Row(children: [
                    BreachLogo(breach: b),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: m.text)),
                            Text(
                              t.breaches.accounts(
                                  n: b.pwnCount,
                                  count: compactCount(b.pwnCount)),
                              style: m.monoStyle(size: 12, color: m.muted),
                            ),
                          ]),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_month(context, b.addedDate),
                              style: TextStyle(fontSize: 11, color: m.muted)),
                          if (b.hasPasswords)
                            Text(t.breaches.passwordsMark,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: m.bad)),
                        ]),
                    Icon(Icons.chevron_right_rounded, color: m.muted),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

/// What leaked, as chips: passwords and IDs red, contact details amber.
class _Classes extends StatelessWidget {
  const _Classes({required this.classes});

  final List<String> classes;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    Color tone(String c) {
      final l = c.toLowerCase();
      if (l.contains('password') ||
          l.contains('passport') ||
          l.contains('credit card') ||
          l.contains('bank')) {
        return m.bad;
      }
      if (l.contains('phone') || l.contains('address') || l.contains('birth')) {
        return m.warn;
      }
      return m.muted;
    }

    return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final c in classes) _Tag(text: c, color: tone(c))]);
  }
}

/// One breach: what happened, what leaked, what to do.
class BreachScreen extends StatelessWidget {
  const BreachScreen({super.key, required this.breach});

  final Breach breach;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final b = breach;
    final loc = MaterialLocalizations.of(context);
    final steps = [
      if (b.hasPasswords) t.breaches.stepPassword,
      if (b.hasPasswords) t.breaches.stepReuse,
      t.breaches.stepTwoStep,
      if (b.hasPhones) t.breaches.stepScams,
    ];
    return ToolPage(
      title: t.breaches.one,
      icon: Icons.key_rounded,
      color: m.pink,
      action: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChecksScreen())),
        icon: const Icon(Icons.lock_outline_rounded),
        label: Text(t.breaches.checkPassword),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      children: [
        const SizedBox(height: 4),
        Center(child: BreachLogo(breach: b, size: 72)),
        const SizedBox(height: 10),
        Text(b.title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
          if (b.verified) _Tag(text: t.breaches.verified, color: m.good),
          if (b.hasPasswords) _Tag(text: t.breaches.hasPasswords, color: m.bad),
        ]),
        const SizedBox(height: 16),
        MerCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            MerRow(t.breaches.accountsLabel, loc.formatDecimal(b.pwnCount),
                mono: true),
            if (b.breachDate != null)
              MerRow(t.breaches.happened, loc.formatMediumDate(b.breachDate!)),
            MerRow(t.breaches.published, loc.formatMediumDate(b.addedDate)),
            if (b.domain.isNotEmpty) MerRow(t.breaches.website, b.domain),
          ]),
        ),
        ToolHeading(t.breaches.leaked),
        _Classes(classes: b.dataClasses),
        if (b.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(b.description,
              style: TextStyle(fontSize: 13, height: 1.5, color: m.muted)),
        ],
        ToolHeading(t.breaches.ifUsed),
        MerCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, s) in steps.indexed) ...[
              if (i > 0) Divider(height: 1, color: m.line),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: m.pink.withValues(alpha: .16),
                        shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: m.monoStyle(size: 12, color: m.pink)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(s,
                          style: TextStyle(fontSize: 13.5, color: m.text))),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// A country's breaches in a sheet: how many, how many accounts, each one
/// to open, and a button to show only these in the list.
Future<void> showCountrySheet(BuildContext context, String code,
    List<Breach> all, ValueChanged<String?> onPlace,
    {bool fromBigMap = false}) {
  final m = context.mer;
  final list = all.where((b) => breachCountry(b) == code).toList()
    ..sort((a, b) => b.pwnCount.compareTo(a.pwnCount));
  final accounts = list.fold<int>(0, (n, b) => n + b.pwnCount);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: m.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              CountryFlag(code, width: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(countryName(code, code),
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: m.text)),
                      Text(
                        list.isEmpty
                            ? t.breaches.noneHere
                            : '${t.breaches.count(n: list.length)} · ${t.breaches.accounts(n: accounts, count: compactCount(accounts))}',
                        style: TextStyle(fontSize: 13, color: m.muted),
                      ),
                    ]),
              ),
            ]),
          ),
          if (list.isNotEmpty)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 64, color: m.line),
                itemBuilder: (_, i) {
                  final b = list[i];
                  return ListTile(
                    leading: BreachLogo(breach: b),
                    title: Text(b.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: m.text)),
                    subtitle: Text(
                      [
                        t.breaches.accounts(
                            n: b.pwnCount, count: compactCount(b.pwnCount)),
                        if (b.hasPasswords) t.breaches.passwordsMark
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: m.muted),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: m.muted),
                    onTap: () => Navigator.of(c).push(MaterialPageRoute<void>(
                        builder: (_) => BreachScreen(breach: b))),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(c).pop(),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: m.text,
                      side: BorderSide(color: m.line)),
                  child: Text(t.common.close),
                ),
              ),
              if (list.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      onPlace(code);
                      Navigator.of(c).pop();
                      // From the big map, go back to the list it now filters.
                      if (fromBigMap) Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: m.pink,
                        foregroundColor: m.bg),
                    child: Text(t.breaches.showInList,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    ),
  );
}

/// The globe, full screen: drag to spin, pinch or double tap to zoom, tap
/// a country to fly to it, or find one by name.
class BreachGlobeScreen extends StatefulWidget {
  const BreachGlobeScreen(
      {super.key, required this.breaches, required this.onPlace, this.country});

  final List<Breach> breaches;
  final ValueChanged<String?> onPlace;

  /// Fly to this country on opening.
  final String? country;

  @override
  State<BreachGlobeScreen> createState() => _BreachGlobeScreenState();
}

class _BreachGlobeScreenState extends State<BreachGlobeScreen> {
  final _globe = GlobeController();
  late final Map<String, int> _counts = breachesByCountry(widget.breaches);
  String? _picked;

  @override
  void initState() {
    super.initState();
    final c = widget.country;
    if (c != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(c));
    }
  }

  @override
  void dispose() {
    _globe.dispose();
    super.dispose();
  }

  void _pick(String? code) {
    setState(() => _picked = code);
    if (code != null) {
      _globe.flyToCountry(code, zoom: math.max(_globe.view.zoom, 1.8));
    }
  }

  /// Every country by name, those with breaches first.
  Future<void> _find() async {
    final m = context.mer;
    final codes = countryNames.keys
        .where((c) => CountryShapes.instance[c] != null)
        .toList()
      ..sort((a, b) {
        final byCount = (_counts[b] ?? 0).compareTo(_counts[a] ?? 0);
        return byCount != 0
            ? byCount
            : countryName(a, a).compareTo(countryName(b, b));
      });
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: m.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => _CountryFinder(codes: codes, counts: _counts),
    );
    if (code != null) _pick(code);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final picked = _picked;
    final list = picked == null
        ? const <Breach>[]
        : widget.breaches.where((b) => breachCountry(b) == picked).toList();
    final accounts = list.fold<int>(0, (n, b) => n + b.pwnCount);
    Widget round(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xB80A0E1E),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x29FFFFFF)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(icon),
        );

    return Scaffold(
      backgroundColor: const Color(0xFF03040A),
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                  colors: [Color(0xFF10183A), Color(0xFF03040A)], radius: .8),
            ),
            child: BreachGlobe(
                counts: _counts,
                selected: _picked,
                onSelect: _pick,
                controller: _globe),
          ),
        ),
        // Back and find.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                round(
                    Icons.arrow_back_rounded,
                    MaterialLocalizations.of(context).backButtonTooltip,
                    () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: const Color(0x990A0E1E),
                    shape: const StadiumBorder(
                        side: BorderSide(color: Color(0x1FFFFFFF))),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _find,
                      child: SizedBox(
                        height: 48,
                        child: Row(children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search_rounded,
                              color: Color(0xB3FFFFFF), size: 20),
                          const SizedBox(width: 10),
                          Text(t.breaches.findCountry,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xB3FFFFFF))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // Zoom.
        Positioned(
          right: 14,
          bottom: (picked == null ? 32 : 150) +
              MediaQuery.paddingOf(context).bottom,
          child: Column(children: [
            round(
                Icons.add_rounded, t.breaches.zoomIn, () => _globe.zoomBy(1.6)),
            const SizedBox(height: 8),
            round(Icons.remove_rounded, t.breaches.zoomOut,
                () => _globe.zoomBy(1 / 1.6)),
            const SizedBox(height: 8),
            round(Icons.public_rounded, t.breaches.wholeWorld, () {
              setState(() => _picked = null);
              _globe.reset();
            }),
          ]),
        ),
        // The picked country, peeking from the bottom.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: picked == null ? -160 : 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                18, 14, 18, 18 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: m.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: m.line)),
            ),
            child: picked == null
                ? const SizedBox(height: 60)
                : Row(children: [
                    CountryFlag(picked, width: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(countryName(picked, picked),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: m.text)),
                            Text(
                              list.isEmpty
                                  ? t.breaches.noneHere
                                  : '${t.breaches.count(n: list.length)} · ${t.breaches.accounts(n: accounts, count: compactCount(accounts))}',
                              style: TextStyle(fontSize: 13, color: m.muted),
                            ),
                          ]),
                    ),
                    if (list.isNotEmpty)
                      FilledButton(
                        onPressed: () => showCountrySheet(
                            context, picked, widget.breaches, widget.onPlace,
                            fromBigMap: true),
                        style: FilledButton.styleFrom(
                            backgroundColor: m.pink,
                            foregroundColor: m.bg,
                            minimumSize: const Size(0, 44)),
                        child: Text(t.breaches.seeAll,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _CountryFinder extends StatefulWidget {
  const _CountryFinder({required this.codes, required this.counts});

  final List<String> codes;
  final Map<String, int> counts;

  @override
  State<_CountryFinder> createState() => _CountryFinderState();
}

class _CountryFinderState extends State<_CountryFinder> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.codes
        : widget.codes
            .where((c) => countryName(c, c).toLowerCase().contains(q))
            .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: t.breaches.findCountry,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: m.surface2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final c = shown[i];
              final n = widget.counts[c] ?? 0;
              return ListTile(
                leading: CountryFlag(c, width: 30),
                title: Text(countryName(c, c),
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: m.text)),
                trailing: n == 0
                    ? null
                    : Text('$n', style: m.monoStyle(size: 13, color: m.pink)),
                onTap: () => Navigator.of(context).pop(c),
              );
            },
          ),
        ),
      ]),
    );
  }
}
