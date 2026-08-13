import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/accent.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../core/i18n/g_strings.dart';

/// Theme and accent, on their own screen.
///
/// It was an inline card in the middle of a list of rows, which made the page a
/// list interrupted by a widget. Moving it out costs one tap and buys room:
/// there is nowhere in an inline card to put a font size control or a per distro
/// accent, and both are coming.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const AppearancePage(),
  );

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

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
              title: context.s('Appearance'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const AppearanceCard(),
          ],
        ),
      ),
    );
  }
}

/// WHAT THIS APP DOES WITH WHAT IT READS.
///
/// The claim the whole product rests on, and until now it was a paragraph at the
/// bottom of a settings list that nobody scrolls to. An app that reads every
/// file a person owns should be able to state its position in one screen, and be
/// specific enough that the statement is checkable.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const PrivacyPage(),
  );

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

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
              title: context.s('Privacy'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            Text(
              context.s('Nothing leaves this phone'),
              style: GType.display.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.md),
            Text(
              context.s(
                'This app reads a great deal: every file in your storage, the '
                'contents of your trash, and, if you turn it on, the text of '
                'messages as they arrive. None of it is sent anywhere.',
              ),
              style: GType.bodySmall.copyWith(color: t.muted),
            ),

            const SizedBox(height: GSpace.lg),
            _Point(
              icon: Icons.cloud_off_rounded,
              tone: t.docs,
              title: context.s('No account, no server'),
              body:
                  'There is nothing to sign in to. Your files are never '
                  'uploaded, because there is nowhere for them to go.',
            ),
            _Point(
              icon: Icons.analytics_outlined,
              tone: t.docs,
              // Specific rather than a blanket denial. An app claiming zero
              // analytics while shipping Crashlytics would be lying, and a
              // reader who checks would stop believing the rest of the page.
              title: context.s('What is measured'),
              // Describes what SHIPS, not what was planned. Crashlytics is
              // not in the pubspec, so claiming crash reporting here would be
              // a false statement on the one page whose whole value is being
              // checkable.
              body:
                  'Which screens are opened, and nothing else. Never a file '
                  'name, a folder, a photo or a message. If the app is slow '
                  'while you look at your holiday pictures, we learn that the '
                  'photos screen was open and nothing about the photos.',
            ),
            _Point(
              icon: Icons.forum_outlined,
              tone: t.chat,
              title: context.s('Messages stay on the phone'),
              body:
                  'The archive is a file in this app\u0027s own storage. '
                  'Deleting the archive deletes it, and uninstalling the app '
                  'takes it with it.',
            ),
            _Point(
              icon: Icons.lock_outline_rounded,
              tone: t.audio,
              title: context.s('Why the permissions are so broad'),
              body:
                  'All files access is the only permission that reaches app '
                  'trash folders, which is where most recoverable files are. '
                  'There is no narrower one that would work.',
            ),
            _Point(
              icon: Icons.shopping_bag_outlined,
              tone: t.apps,
              title: context.s('No ads, ever'),
              body:
                  'Not a banner, not a sponsored row, not a partner offer. '
                  'This is a decision rather than a current state.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm + 1),
      child: GCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 19, color: tone),
            ),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: GType.heading.copyWith(color: t.text)),
                  const SizedBox(height: 3),
                  Text(body, style: GType.bodySmall.copyWith(color: t.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme mode and accent. This is the permanent home for both controls, and it
/// is the same controller the onboarding picker will drive in Phase 4.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final GThemeState theme = ref.watch(gThemeProvider);
    final GThemeController controller = ref.read(gThemeProvider.notifier);

    return GCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.s('Theme'),
            style: GType.heading.copyWith(color: t.text),
          ),
          const SizedBox(height: GSpace.md),
          Row(
            children: <Widget>[
              for (final ThemeMode mode in ThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: GSpace.sm),
                  child: GChip(
                    label: _modeLabel(mode),
                    selected: theme.mode == mode,
                    onTap: () => controller.setMode(mode),
                  ),
                ),
            ],
          ),
          const GCardDivider(),
          Text(
            context.s('Accent'),
            style: GType.heading.copyWith(color: t.text),
          ),
          const SizedBox(height: GSpace.md),
          Row(
            children: <Widget>[
              for (final GAccent accent in gAccentOrder)
                Expanded(
                  child: _AccentSwatch(
                    accent: accent,
                    selected: theme.accent == accent,
                    onTap: () {
                      controller.setAccent(accent);
                      GMessenger.show(
                        context,
                        GMessage.success('Accent set to ${accent.label}'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Auto';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final GAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Semantics(
      label: accent.label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: GMotion.fast,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.base,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.text : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18, color: t.onAccent)
                : null,
          ),
        ),
      ),
    );
  }
}
