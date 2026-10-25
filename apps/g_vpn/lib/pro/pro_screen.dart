import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import '../gservers/gservers.dart';
import '../gservers/gservers_page.dart';
import '../i18n/strings.g.dart';
import '../legal.dart';
import 'billing.dart';

/// G VPN Pro, in the same light and dark Meridian surfaces as every other
/// tab. One column: what Pro is, what it includes, the plans stacked so
/// prices read top to bottom, one button, and the subscription terms Play
/// expects beside any purchase (renewal, cancelling, links to the terms and
/// privacy policy).
///
/// Prices are Google Play's own, in the buyer's currency. Buying stays off
/// (PRO_SALES_OPEN) until G Servers run.
class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});

  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final billing = ref.watch(billingProvider);
    // G Servers switched on (admin, Sources): the tab is them, for everyone
    // or for subscribers, as the admin chose.
    final g = ref.watch(gServersProvider).value;
    if (g != null && g.available && (!g.proOnly || billing.owned)) return GServersPage(info: g);
    // Nothing to sell: say plainly that everything is free, rather than show
    // prices beside a button that cannot work.
    if (!proSalesOpen && !billing.owned) return const _FreeForEveryone();
    final plansAsync = ref.watch(proPlansProvider);
    final plans = plansAsync.value ?? const <ProPlan>[];
    final yearly = plans.where((p) => p.yearly).firstOrNull;
    final monthly = plans.where((p) => !p.yearly).firstOrNull;
    final chosenId = _chosen ?? yearly?.basePlanId ?? monthly?.basePlanId;
    final chosen = plans.where((p) => p.basePlanId == chosenId).firstOrNull;
    final saving = yearly != null && monthly != null && monthly.priceMicros > 0
        ? (100 - yearly.monthlyMicros / monthly.priceMicros * 100).round()
        : null;

    final cta = billing.owned
        ? t.pro.owned
        : billing.pending
                ? t.pro.waitingPlay
                : chosen?.trialDays != null
                    ? t.pro.startTrial(days: chosen!.trialDays!)
                    : t.common.continueLabel;

    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      tooltip: t.common.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  Expanded(
                    child: Text(t.pro.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
                  ),
                  TextButton(
                    onPressed: () => ref.read(billingProvider.notifier).restore(),
                    child: Text(t.pro.restore),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── What Pro is ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: m.brand, borderRadius: BorderRadius.circular(Meridian.rCard)),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: m.onBrand.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.bolt_rounded, size: 30, color: m.onBrand),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                billing.owned ? t.pro.owned : t.pro.heroTitleOneLine,
                                style: TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w800, color: m.onBrand),
                              ),
                              const SizedBox(height: 2),
                              Text(t.pro.heroSubtitle, style: TextStyle(fontSize: 13, color: m.onBrand.withValues(alpha: .85))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── What it includes ──
                  SectionTitle(t.pro.includes),
                  ListGroup(children: [
                    ListItem(
                      leading: Icon(Icons.speed_rounded, color: m.brand),
                      title: t.pro.benefitSpeed,
                    ),
                    ListItem(
                      leading: Icon(Icons.key_rounded, color: m.brand),
                      title: t.pro.benefitKey,
                    ),
                    ListItem(
                      leading: Icon(Icons.visibility_off_outlined, color: m.brand),
                      title: t.pro.benefitLogs,
                    ),
                    ListItem(
                      leading: Icon(Icons.check_rounded, color: m.good),
                      title: t.pro.benefitFree,
                    ),
                  ]),

                  // ── Plans, one column ──
                  if (!billing.owned) ...[
                    SectionTitle(t.pro.plan),
                    switch (plansAsync) {
                      AsyncError(:final error) => Text('$error', style: TextStyle(color: m.muted)),
                      _ when plans.isEmpty => const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      _ => Column(
                          children: [
                            for (final p in [if (yearly != null) yearly, if (monthly != null) monthly]) ...[
                              _PlanRow(
                                plan: p,
                                selected: p.basePlanId == chosenId,
                                badge: p.yearly && saving != null && saving > 0 ? t.pro.save(pct: saving) : null,
                                onTap: () => setState(() => _chosen = p.basePlanId),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                    },
                  ],
                  if (billing.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(billing.error!, style: TextStyle(color: m.bad, fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: billing.owned || !proSalesOpen || billing.pending || chosen == null
                          ? null
                          : () => ref.read(billingProvider.notifier).buy(chosen),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text(cta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),

                  // ── Subscription terms, as Play expects beside a purchase ──
                  const SizedBox(height: 14),
                  Text(
                    chosen == null
                        ? t.pro.renewGeneric
                        : chosen.trialDays != null
                            ? t.pro.renewTrial(days: chosen.trialDays!, price: chosen.price, period: chosen.yearly ? t.pro.year : t.pro.month)
                            : t.pro.renew(price: chosen.price, period: chosen.yearly ? t.pro.year : t.pro.month),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.5, color: m.muted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(onPressed: () => Legal.open(Legal.terms), child: Text(t.legal.terms)),
                      TextButton(onPressed: () => Legal.open(Legal.privacy), child: Text(t.legal.privacy)),
                      TextButton(onPressed: () => Legal.open(Legal.subscriptions), child: Text(t.pro.manage)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One plan, full width: name and saving on the left, price on the right.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.selected, required this.badge, required this.onTap});

  final ProPlan plan;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final perMonth = plan.yearly
        ? t.pro.perMonth(price: '${plan.details.currencySymbol}${(plan.monthlyMicros / 1e6).toStringAsFixed(0)}')
        : t.pro.billedMonthly;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? m.brandSoft : m.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Meridian.rCard),
          side: BorderSide(color: selected ? m.brand : m.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Meridian.rCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? m.brand : m.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.yearly ? t.pro.yearly : t.pro.monthly,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Tag(badge!, color: m.good),
                          ],
                        ],
                      ),
                      Text(
                        plan.trialDays != null ? '${t.pro.daysFree(days: plan.trialDays!)} · $perMonth' : perMonth,
                        style: TextStyle(fontSize: 13, color: m.muted),
                      ),
                    ],
                  ),
                ),
                Text(plan.price, style: m.monoStyle(size: 17, weight: FontWeight.w600, color: m.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Pro tab until there is something to buy: what every user already
/// has, in full, and an honest line on what Pro will add.
class _FreeForEveryone extends StatelessWidget {
  const _FreeForEveryone();

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final included = [
      (Icons.public_rounded, t.pro.free.servers, t.pro.free.serversSub),
      (Icons.dns_outlined, t.pro.free.own, t.pro.free.ownSub),
      (Icons.shield_outlined, t.pro.free.shield, t.pro.free.shieldSub),
      (Icons.sync_rounded, t.pro.free.auto, t.pro.free.autoSub),
      (Icons.pause_circle_outline_rounded, t.pro.free.pause, t.pro.free.pauseSub),
      (Icons.speed_rounded, t.pro.free.tools, t.pro.free.toolsSub),
    ];
    return Scaffold(
      backgroundColor: m.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(t.pro.free.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: m.good.withValues(alpha: .12), borderRadius: BorderRadius.circular(Meridian.rCard)),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: m.good, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.check_rounded, size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.pro.free.headline, style: TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w800, color: m.text)),
                        const SizedBox(height: 2),
                        Text(t.pro.free.body, style: TextStyle(fontSize: 13, height: 1.4, color: m.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle(t.pro.free.included),
            ListGroup(children: [
              for (final (icon, title, sub) in included)
                ListItem(
                  leading: Icon(icon, color: m.brand),
                  title: title,
                  subtitle: sub,
                  trailing: Icon(Icons.check_circle_rounded, color: m.good, size: 20),
                ),
            ]),
            const SizedBox(height: 18),
            Text(
              t.pro.free.later,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: m.muted),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(onPressed: () => Legal.open(Legal.terms), child: Text(t.legal.terms)),
                TextButton(onPressed: () => Legal.open(Legal.privacy), child: Text(t.legal.privacy)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
