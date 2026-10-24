import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/list_ui.dart';
import '../design/meridian.dart';
import 'billing.dart';

/// G VPN Pro. Prices come live from Google Play; buying stays closed until
/// G Servers run (see [proSalesOpen]).
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
    final plans = ref.watch(proPlansProvider).value ?? const <ProPlan>[];
    final chosenId = _chosen ?? plans.where((p) => p.yearly).firstOrNull?.basePlanId ?? plans.firstOrNull?.basePlanId;
    final chosen = plans.where((p) => p.basePlanId == chosenId).firstOrNull;
    final monthly = plans.where((p) => !p.yearly).firstOrNull;

    Widget feature(IconData icon, String title, bool pro) => ListItem(
          leading: Icon(icon, color: pro ? m.brand : m.muted),
          title: title,
          trailing: Tag(pro ? 'PRO' : 'FREE', color: pro ? m.brand : m.good),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('G VPN Pro'),
        centerTitle: false,
        actions: const [
          InfoAction(
            title: 'G VPN Pro',
            body: 'G Servers are WireGuard servers run by Mindberzerk with no activity logs. Your key is made on '
                'your phone and never leaves it, and there is no account or email.\n\n'
                'Billed by Google Play. Cancel anytime in Play Store, Subscriptions. Everything free stays free.',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            billing.owned ? 'You have Pro' : 'Fast servers, run by us',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text),
          ),
          Text('WireGuard. No logs. No account.', style: TextStyle(fontSize: 14, color: m.muted)),
          const SectionTitle('Included'),
          ListGroup(children: [
            feature(Icons.bolt_rounded, 'G Servers', true),
            feature(Icons.public_rounded, 'Community servers', false),
            feature(Icons.dns_outlined, 'Your own servers', false),
            feature(Icons.shield_outlined, 'Shield', false),
            feature(Icons.handyman_outlined, 'Network tools', false),
          ]),
          if (!billing.owned && plans.isNotEmpty) ...[
            const SectionTitle('Plan'),
            ListGroup(children: [
              for (final p in plans)
                ListItem(
                  title: p.yearly ? 'Yearly' : 'Monthly',
                  subtitle: p.trialDays != null
                      ? '${p.trialDays} days free'
                      : p.yearly && monthly != null && monthly.priceMicros > 0
                          ? 'Save ${(100 - p.monthlyMicros / monthly.priceMicros * 100).round()}%'
                          : null,
                  selected: p.basePlanId == chosenId,
                  onTap: () => setState(() => _chosen = p.basePlanId),
                  trailing: Text(
                    '${p.price}${p.yearly ? '/yr' : '/mo'}',
                    style: m.monoStyle(size: 14, weight: FontWeight.w600),
                  ),
                ),
            ]),
          ],
          if (billing.error != null) ...[
            const SizedBox(height: 10),
            Text(billing.error!, style: TextStyle(color: m.bad, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          if (!billing.owned)
            FilledButton(
              onPressed: !proSalesOpen || billing.pending || chosen == null
                  ? null
                  : () => ref.read(billingProvider.notifier).buy(chosen),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(
                !proSalesOpen
                    ? 'Coming soon'
                    : billing.pending
                        ? 'Waiting for Google Play'
                        : chosen?.trialDays != null
                            ? 'Start free trial'
                            : 'Continue',
              ),
            ),
          Center(
            child: TextButton(
              onPressed: () => ref.read(billingProvider.notifier).restore(),
              child: const Text('Restore purchases'),
            ),
          ),
        ],
      ),
    );
  }
}
