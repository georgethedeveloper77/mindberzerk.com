import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import 'state/pro_providers.dart';

/// THE WHOLE OFFER, ON ONE SCREEN.
///
/// ─── PRO SELLS LABOUR, NOT CAPABILITY ────────────────────────────────────────
///
/// The rule is already written into the server schema, on the `scheduled`
/// field: connecting, copying and reclaiming all work free, by hand. What is
/// sold is the app doing work while nobody is watching.
///
/// Everything on the paid list below is the same kind of thing. A list that
/// mixed unattended work with unlocked buttons would be the version nobody can
/// summarise, and a person who cannot summarise what they are buying does not
/// buy it.
///
/// ─── THE FREE LIST IS LONGER, AND SITS ABOVE THE BUTTON ──────────────────────
///
/// Not generosity. It is the accurate description of this app, and it is what
/// makes the section under it believable: a promise never to add ads reads very
/// differently after a list of everything that already costs nothing.
///
/// ─── NO COUNTDOWN, NO DISCOUNT, NO BADGE ANYWHERE ELSE ───────────────────────
///
/// The price is stated once, here, and at the one toggle it applies to. An app
/// that reminds you it has a paid tier on every screen is an app whose paid
/// tier is not worth mentioning once.
class ProPage extends ConsumerWidget {
  const ProPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ProPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final bool unlocked = ref.watch(proUnlockedProvider);

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: 'Pro',
              subtitle: 'One payment, no subscription',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (unlocked)
              const _Unlocked()
            else
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.lg),
                child: Column(
                  children: <Widget>[
                    Text(
                      'KSh 349',
                      style: GType.display.copyWith(color: t.text),
                    ),
                    const SizedBox(height: GSpace.xs),
                    Text(
                      'once, on this account, forever',
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),

            const _Item(
              icon: Icons.play_arrow_rounded,
              title: 'Video compression',
              detail:
                  'Long encodes that keep running in the background while you '
                  'use the phone for something else.',
            ),
            const _Item(
              icon: Icons.schedule_rounded,
              title: 'Backups that run overnight',
              detail:
                  'About once a day, while charging and on Wi-Fi, without you '
                  'opening the app.',
            ),
            const _Item(
              icon: Icons.dns_outlined,
              title: 'More than one server',
              detail: 'A drive at home and one somewhere else, kept separately.',
            ),

            const SizedBox(height: GSpace.lg),
            _Panel(
              title: 'What stays free, permanently',
              tone: t.accent,
              body:
                  'Recovery. Scanning. The storage breakdown. Duplicate and '
                  'blurry photo review, including trashing many at once. '
                  'Device monitors and hardware tests. The message archive. '
                  'Screenshot and photo compression. Backing up and reclaiming '
                  'by hand.',
            ),

            const SizedBox(height: GSpace.sm + 1),
            _Panel(
              title: 'What we will never do',
              tone: t.muted,
              body:
                  'No ads, not even a disabled one. No subscription. No cloud '
                  'storage of ours to rent. Nothing you have already made '
                  'smaller or already copied stops working if you never pay.',
            ),

            if (!unlocked) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              // ─── NOT A PURCHASE BUTTON YET, AND IT SAYS SO ─────────────────
              //
              // There is no Play Billing in this app. A button reading "Unlock
              // Pro" that silently sets a local flag would be the one piece of
              // dishonesty in a product built on refusing to overclaim, and it
              // would be indistinguishable from the finished thing at a glance,
              // which is exactly how it would survive into a release.
              GButton(
                label: 'Unlock Pro without paying, for testing',
                icon: Icons.construction_rounded,
                onPressed: () =>
                    ref.read(proProvider.notifier).set(unlocked: true),
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                'Payment is not connected yet. This button only sets a flag on '
                'this phone.',
                textAlign: TextAlign.center,
                style: GType.micro.copyWith(color: t.dim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Unlocked extends ConsumerWidget {
  const _Unlocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.lg),
      child: Column(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.success.withValues(alpha: 0.10),
              border: Border.all(color: t.success.withValues(alpha: 0.32)),
              borderRadius: GRadius.all(GRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(GSpace.md + 1),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_rounded, size: 19, color: t.success),
                  const SizedBox(width: GSpace.md - 2),
                  Expanded(
                    child: Text(
                      'Pro is on. Everything below is available.',
                      style: GType.bodySmall.copyWith(color: t.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GSpace.sm),
          GButton(
            label: 'Turn it off again, for testing',
            kind: GButtonKind.ghost,
            onPressed: () => ref.read(proProvider.notifier).set(unlocked: false),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm + 1),
      child: GCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 19, color: t.accent),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: GType.heading.copyWith(color: t.text)),
                  const SizedBox(height: 3),
                  Text(detail, style: GType.micro.copyWith(color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.tone, required this.body});

  final String title;
  final Color tone;
  final String body;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: GType.overline.copyWith(color: tone),
          ),
          const SizedBox(height: GSpace.sm),
          Text(
            body,
            style: GType.micro.copyWith(color: t.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}
