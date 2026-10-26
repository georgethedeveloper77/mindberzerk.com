import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../tools/speed_screen.dart';
import '../tools/tool_widgets.dart';
import '../tools/tools_providers.dart';
import 'provider_api.dart';

// ── Brand ───────────────────────────────────────────────────────────────

Color? _hex(String? s) {
  if (s == null || s.length != 7 || !s.startsWith('#')) return null;
  final v = int.tryParse(s.substring(1), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// A provider's colour: its brand when set, else a steady accent of ours.
Color brandColor(IspProfile p, Meridian m) {
  final set = _hex(p.color);
  if (set != null) return set;
  final palette = [m.brand, m.teal, m.violet, m.pink, m.warn, m.good];
  return palette[p.org.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff) % palette.length];
}

/// Two letters from a provider's name: "Safaricom Home" -> "SH".
String _initials(String name) {
  final words = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// The provider's badge: its logo when the admin set one, else its
/// initials on its brand colour.
class IspBadge extends StatelessWidget {
  const IspBadge({super.key, required this.profile, this.size = 44});

  final IspProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = brandColor(profile, m);
    final letters = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .3)),
      child: Text(_initials(profile.name),
          style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w800, color: Colors.white)),
    );
    final logo = profile.logo;
    if (logo == null) return letters;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .3),
      child: Image.network(
        logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => letters,
      ),
    );
  }
}

/// Stars for [value] out of five, halves included.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.size = 14});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mer.warn;
    return Semantics(
      label: t.providers.starsOf(n: value.toStringAsFixed(1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              value >= i ? Icons.star_rounded : value >= i - .5 ? Icons.star_half_rounded : Icons.star_outline_rounded,
              size: size,
              color: c,
            ),
        ],
      ),
    );
  }
}

String tagName(String tag) => switch (tag) {
      'fast' => t.providers.tags.fast,
      'reliable' => t.providers.tags.reliable,
      'support' => t.providers.tags.support,
      'price' => t.providers.tags.price,
      'slowEvenings' => t.providers.tags.slowEvenings,
      'drops' => t.providers.tags.drops,
      'poorSupport' => t.providers.tags.poorSupport,
      _ => t.providers.tags.pricey,
    };

/// The last speed test without the VPN, if any.
SpeedResult? lastDirect(List<SpeedResult> history) => history.where((r) => !r.viaVpn).firstOrNull;

// ── Internet tab ────────────────────────────────────────────────────────

/// The hub's Internet tab: who provides this connection, what people
/// think of them, and how this phone's speed compares.
class InternetTab extends ConsumerWidget {
  const InternetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final me = ref.watch(myProviderProvider);
    return switch (me) {
      AsyncData(value: final p?) => _Profile(me: p),
      AsyncData() || AsyncError() => Padding(
          padding: const EdgeInsets.all(20),
          child: Text(t.providers.unavailable, style: TextStyle(fontSize: 14, color: m.muted)),
        ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.me});

  final MyProvider me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final p = me.profile;
    final r = me.rating;
    final comparison = ref.watch(ispComparisonProvider).value;
    final standing = comparison?.providers.where((s) => s.isp == p.org).firstOrNull;
    final direct = lastDirect(ref.watch(speedHistoryProvider).value ?? const []);
    final where = [me.city, me.country].whereType<String>().join(', ');
    final topTags = (r.tags.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(4).toList();

    String compare(double you, double avg) {
      final pct = ((you - avg) / avg * 100).round();
      if (pct.abs() < 10) return t.providers.aboutAverage;
      return pct > 0 ? t.providers.aboveAverage(pct: pct) : t.providers.belowAverage(pct: -pct);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (me.cached)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(t.providers.cached, style: TextStyle(fontSize: 12, color: m.muted)),
          ),
        Row(
          children: [
            IspBadge(profile: p, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.text)),
                  if (where.isNotEmpty)
                    Row(children: [
                      Icon(Icons.place_outlined, size: 14, color: m.muted),
                      const SizedBox(width: 4),
                      Text(where, style: TextStyle(fontSize: 13, color: m.muted)),
                    ]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!me.hidden)
          MerCard(
            child: Row(
              children: [
                Column(
                  children: [
                    Text(r.average?.toStringAsFixed(1) ?? '--', style: m.monoStyle(size: 40, color: m.text)),
                    const SizedBox(height: 4),
                    Stars(value: r.average ?? 0),
                    const SizedBox(height: 4),
                    Text(t.providers.ratings(n: r.count), style: TextStyle(fontSize: 11, color: m.muted)),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: r.average == null
                      ? Text(t.providers.notEnough, style: TextStyle(fontSize: 13, color: m.muted))
                      : Column(
                          children: [
                            for (var s = 5; s >= 1; s--)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Row(children: [
                                  SizedBox(width: 12, child: Text('$s', style: m.monoStyle(size: 11, color: m.muted))),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: r.count == 0 ? 0 : r.spread[s - 1] / r.count,
                                        minHeight: 8,
                                        color: m.warn,
                                        backgroundColor: m.surface2,
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        if (topTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in topTags)
                _Chip(text: tagName(e.key), color: badTags.contains(e.key) ? m.warn : m.good),
            ],
          ),
        ],
        if (me.myStars != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Text(t.providers.yourRating, style: TextStyle(fontSize: 13, color: m.muted)),
            const SizedBox(width: 8),
            Stars(value: me.myStars!.toDouble(), size: 14),
          ]),
        ],
        ToolHeading(t.providers.yourSpeed),
        if (direct == null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SpeedScreen())),
            icon: const Icon(Icons.speed_rounded),
            label: Text(t.providers.runTest),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          )
        else
          Row(
            children: [
              Expanded(
                child: _SpeedTile(
                  label: t.speed.download,
                  value: direct.down,
                  note: standing == null ? null : compare(direct.down, standing.down),
                  good: standing == null || direct.down >= standing.down * .9,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SpeedTile(
                  label: t.speed.upload,
                  value: direct.up,
                  note: standing == null ? null : compare(direct.up, standing.up),
                  good: standing == null || direct.up >= standing.up * .9,
                ),
              ),
            ],
          ),
        if (p.phone != null || p.website != null || p.outages != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, (label, icon, link)) in [
                if (p.phone != null) (t.providers.call, Icons.call_outlined, 'tel:${p.phone}'),
                if (p.website != null) (t.providers.website, Icons.public_rounded, p.website!),
                if (p.outages != null) (t.providers.outages, Icons.warning_amber_rounded, p.outages!),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                    icon: Icon(icon, size: 16),
                    label: Text(label, maxLines: 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: m.text,
                      side: BorderSide(color: m.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({required this.label, required this.value, required this.note, required this.good});

  final String label;
  final double value;
  final String? note;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: m.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: m.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5, color: m.muted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value.toStringAsFixed(value >= 100 ? 0 : 1), style: m.monoStyle(size: 22, color: m.text)),
              const SizedBox(width: 4),
              Text(t.speed.mbps, style: TextStyle(fontSize: 12, color: m.muted)),
            ],
          ),
          if (note != null)
            Text(note!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: good ? m.good : m.warn)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      );
}

/// The Internet tab's buttons: Rate and Compare.
class InternetActions extends ConsumerWidget {
  const InternetActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final me = ref.watch(myProviderProvider).value;
    final canRate = me != null && !me.cached && !me.hidden;
    return Row(
      children: [
        if (canRate) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showRateSheet(context, me),
              icon: const Icon(Icons.star_rounded),
              label: Text(me.myStars == null ? t.providers.rate : t.providers.changeRating),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: m.warn, foregroundColor: m.bg),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CompareScreen())),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: m.text,
              side: BorderSide(color: m.line),
            ),
            child: Text(t.providers.compare),
          ),
        ),
      ],
    );
  }
}

// ── Rating ──────────────────────────────────────────────────────────────

Future<void> showRateSheet(BuildContext context, MyProvider me) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.mer.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _RateSheet(me: me),
    );

class _RateSheet extends ConsumerStatefulWidget {
  const _RateSheet({required this.me});

  final MyProvider me;

  @override
  ConsumerState<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<_RateSheet> {
  late int _stars = widget.me.myStars ?? 0;
  late final Set<String> _tags = {...widget.me.myTags};
  bool _busy = false;
  String? _error;

  Future<void> _post() async {
    if (_stars == 0 || _busy) return;
    final direct = lastDirect(ref.read(speedHistoryProvider).value ?? const []);
    // A speed test from the last week counts as proof of using it.
    final recent = direct != null && DateTime.now().difference(direct.at).inDays < 7 ? direct.down : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await postRating(stars: _stars, tags: _tags.toList(), down: recent);
      ref.invalidate(myProviderProvider);
      ref.invalidate(nearbyProvidersProvider);
      if (mounted) Navigator.of(context).pop();
    } on RateException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.code == 'busy' ? t.providers.busy : t.providers.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final p = widget.me.profile;
    final direct = lastDirect(ref.watch(speedHistoryProvider).value ?? const []);
    final verified = direct != null && DateTime.now().difference(direct.at).inDays < 7;
    final words = [t.providers.words.bad, t.providers.words.poor, t.providers.words.okay, t.providers.words.good, t.providers.words.great];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IspBadge(profile: p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.providers.rateTitle(name: p.name), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: m.text)),
                Text(t.providers.oncePerMonth, style: TextStyle(fontSize: 12, color: m.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: words[i - 1],
                  onPressed: () => setState(() => _stars = i),
                  iconSize: 44,
                  icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: m.warn),
                ),
            ],
          ),
          Text(
            _stars == 0 ? t.providers.tapStars : words[_stars - 1],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _stars == 0 ? m.muted : m.warn),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in ratingTags)
                FilterChip(
                  label: Text(tagName(tag)),
                  selected: _tags.contains(tag),
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                  selectedColor: (badTags.contains(tag) ? m.warn : m.good).withValues(alpha: .16),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _tags.contains(tag) ? (badTags.contains(tag) ? m.warn : m.good) : m.text,
                  ),
                ),
            ],
          ),
          if (verified) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: m.good.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.speed_rounded, size: 18, color: m.good),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.providers.verified(mbps: direct.down.toStringAsFixed(1)),
                      style: TextStyle(fontSize: 13, color: m.text)),
                ),
              ]),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: m.bad, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _stars == 0 || _busy ? null : _post,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: m.warn, foregroundColor: m.bg),
            child: Text(t.providers.post),
          ),
        ],
      ),
    );
  }
}

// ── Providers near you ──────────────────────────────────────────────────

/// Home providers rated near the phone, with their typical speed from
/// G VPN tests. Never a paid placement: the order is the users' own.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  bool _bySpeed = false;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final nearby = ref.watch(nearbyProvidersProvider);
    final speeds = {for (final s in ref.watch(ispComparisonProvider).value?.providers ?? const <IspStanding>[]) s.isp: s};
    final me = ref.watch(myProviderProvider).value;
    final direct = lastDirect(ref.watch(speedHistoryProvider).value ?? const []);
    final mine = me == null ? null : speeds[me.profile.org];
    final slow = direct != null && mine != null && direct.down < mine.down * .6;

    return ToolPage(
      title: t.providers.nearTitle,
      icon: Icons.compare_arrows_rounded,
      color: m.warn,
      children: [
        if (slow)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: m.warn.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(Meridian.rTile),
              border: Border.all(color: m.warn.withValues(alpha: .4)),
            ),
            child: Row(children: [
              Icon(Icons.speed_rounded, size: 18, color: m.warn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.providers.slower(pct: ((1 - direct.down / mine.down) * 100).round()),
                  style: TextStyle(fontSize: 13, height: 1.4, color: m.text),
                ),
              ),
            ]),
          ),
        switch (nearby) {
          AsyncData(value: final n?) when n.providers.isNotEmpty => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  (n.scope == 'city' ? t.providers.inPlace(place: n.city ?? '') : t.providers.inPlace(place: n.country ?? ''))
                      .toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: Text(t.providers.byRating),
                    selected: !_bySpeed,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _bySpeed = false),
                  ),
                  ChoiceChip(
                    label: Text(t.providers.bySpeed),
                    selected: _bySpeed,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _bySpeed = true),
                  ),
                ]),
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  final list = [...n.providers];
                  if (_bySpeed) {
                    list.sort((a, b) => (speeds[b.profile.org]?.down ?? -1).compareTo(speeds[a.profile.org]?.down ?? -1));
                  }
                  final top = n.providers.first.profile.asn;
                  final fastest = speeds.values.fold<double>(1, (mx, s) => s.down > mx ? s.down : mx);
                  return MerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, p) in list.indexed) ...[
                          if (i > 0) Divider(height: 1, color: m.line),
                          _NearbyRow(
                            p: p,
                            you: p.profile.asn == n.you,
                            top: p.profile.asn == top,
                            speed: speeds[p.profile.org],
                            fastest: fastest,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Text(t.providers.footnote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: m.muted)),
              ],
            ),
          AsyncData() || AsyncError() => Text(t.providers.noneNearby, style: TextStyle(fontSize: 14, color: m.muted)),
          _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        },
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.p, required this.you, required this.top, required this.speed, required this.fastest});

  final NearbyProvider p;
  final bool you;
  final bool top;
  final IspStanding? speed;
  final double fastest;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final s = speed;
    return Container(
      color: you ? m.brand.withValues(alpha: .06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IspBadge(profile: p.profile, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(p.profile.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text)),
                  if (you) _Chip(text: t.providers.you, color: m.brand),
                  if (top) _Chip(text: t.providers.topRated, color: m.good),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Stars(value: p.average, size: 12),
                  const SizedBox(width: 6),
                  Text('${p.average.toStringAsFixed(1)} · ${t.providers.ratings(n: p.count)}',
                      style: m.monoStyle(size: 11, color: m.muted)),
                ]),
                if (s != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (s.down / fastest).clamp(0.02, 1.0),
                      minHeight: 5,
                      color: brandColor(p.profile, m),
                      backgroundColor: m.surface2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (s != null) ...[
            const SizedBox(width: 10),
            Text('${s.down.round()} ${t.speed.mbps}', style: m.monoStyle(size: 13, color: m.text)),
          ],
        ],
      ),
    );
  }
}
