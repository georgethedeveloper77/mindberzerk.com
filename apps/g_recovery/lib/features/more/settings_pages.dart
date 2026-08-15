import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/accent.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typeface.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_chip.dart';
import '../../ui/g_stat.dart';
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
/// The claim the whole product rests on, and the one page in the app whose
/// value is that a suspicious reader can check it.
///
/// ─── IT WAS AN ESSAY, AND IT HAD GONE OUT OF DATE ────────────────────────────
///
/// Five cards of paragraph, each the same weight, so the claim that matters had
/// no more prominence than the one about ads. Worse, it was written when the
/// app made one outbound request and now makes four: coverage packs, a typeface
/// file, the Play update check, and screen analytics. A reader who put the app
/// behind a proxy would have caught the page short, and having caught one line
/// they would have stopped believing the other four.
///
/// So it is a ledger now. Everything that goes out, named, then everything that
/// does not. The headline still says nothing leaves this phone because that is
/// true of the user's own data, and the line directly under it reconciles the
/// two before a reader can find the gap themselves.
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
                'Four things go out, and none of them is yours. All four are '
                'below.',
              ),
              style: GType.bodySmall.copyWith(color: t.muted),
            ),

            const SizedBox(height: GSpace.xl),
            GOverline('What goes out'),
            const SizedBox(height: GSpace.sm + 1),
            _Ledger(
              rows: <Widget>[
                _OutRow(
                  icon: Icons.cloud_download_outlined,
                  tone: t.docs,
                  title: context.s('Recovery coverage'),
                  body: context.s(
                    'Downloads a list of where phones hide deleted files. '
                    'Nothing about your phone is sent to ask for it.',
                  ),
                ),
                // The one row a reader can act on, so it is the one row that
                // goes somewhere. Telling someone a font is fetched and then
                // making them hunt for the setting that stops it is a worse
                // answer than not mentioning it.
                _OutRow(
                  icon: Icons.text_fields_rounded,
                  tone: t.video,
                  title: context.s('Typeface'),
                  body: context.s(
                    'Fetched once from Google, and only if you pick one. Set '
                    'the typeface back to System and this stops.',
                  ),
                  onTap: () =>
                      Navigator.of(context).push(AppearancePage.route()),
                ),
                _OutRow(
                  icon: Icons.system_update_alt_rounded,
                  tone: t.apps,
                  title: context.s('Update check'),
                  body: context.s(
                    'Asks the Play Store whether a newer build exists. Play '
                    'already knows this app is installed.',
                  ),
                ),
                _OutRow(
                  icon: Icons.analytics_outlined,
                  tone: t.chat,
                  title: context.s('Which screens you open'),
                  body: context.s(
                    'Never a file name, a folder, a photo or a message. The '
                    'screen, not what was on it.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: GSpace.lg),
            GOverline('What never does'),
            const SizedBox(height: GSpace.sm + 1),
            _Ledger(
              rows: <Widget>[
                _KeptRow(
                  icon: Icons.insert_drive_file_outlined,
                  label: context.s('Your files, and every scan of them'),
                ),
                _KeptRow(
                  icon: Icons.forum_outlined,
                  label: context.s('The message archive'),
                ),
                _KeptRow(
                  icon: Icons.dns_outlined,
                  label: context.s('Your home server address and password'),
                ),
                _KeptRow(
                  icon: Icons.person_outline_rounded,
                  label: context.s('There is no account to attach it to'),
                ),
              ],
            ),

            const SizedBox(height: GSpace.lg),
            _Note(
              title: context.s('Why the permissions are so broad'),
              body: context.s(
                'All files access is the only permission that reaches app '
                'trash folders, which is where most recoverable files are. '
                'There is no narrower one that would work.',
              ),
            ),
            _Note(
              title: context.s('No ads, ever'),
              body: context.s(
                'Not a banner, not a sponsored row, not a partner offer. This '
                'is a decision rather than a current state.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card of rows with a hairline between them.
///
/// Same shape as the groups on More, so the two pages read as one product. The
/// divider is drawn per row rather than interleaved as separate widgets,
/// because an interleaved list makes the last separator a special case that
/// somebody eventually forgets to remove.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

/// One outbound connection: what it is, and what it carries.
class _OutRow extends StatelessWidget {
  const _OutRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  /// Only on a row the reader can do something about.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: GSpace.md - 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GType.body.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(body, style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: GSpace.sm),
            Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    // GCard paints an opaque panel over the Scaffold's Material, so ink from a
    // bare InkWell would splash behind it and never be seen.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// One thing that stays. No body text: a line that needs explaining is not a
/// thing the reader can hold on to.
class _KeptRow extends StatelessWidget {
  const _KeptRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: t.success),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Text(label, style: GType.body.copyWith(color: t.text)),
          ),
        ],
      ),
    );
  }
}

/// The two entries that are genuinely explanations rather than ledger lines,
/// kept as prose because shortening either one would remove the reason.
class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm + 1),
      child: GCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: GType.heading.copyWith(color: t.text)),
            const SizedBox(height: 3),
            Text(body, style: GType.bodySmall.copyWith(color: t.muted)),
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
          const GCardDivider(),
          Text(
            context.s('Typeface'),
            style: GType.heading.copyWith(color: t.text),
          ),
          const SizedBox(height: 3),
          Text(
            context.s(
              'System uses the font already on your phone and downloads '
              'nothing. The rest are fetched once and kept.',
            ),
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
          const SizedBox(height: GSpace.md),
          for (final GTypeface face in GTypeface.values)
            _TypefaceRow(
              face: face,
              selected: theme.typeface == face,
              onTap: () {
                controller.setTypeface(face);
                GMessenger.show(
                  context,
                  GMessage.success('Typeface set to ${face.label}'),
                );
              },
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

/// One typeface, drawn in itself.
///
/// The name is set in the face it names and the figure beside it is set in that
/// face's monospace half, because those two things are what the choice actually
/// changes. A list of names in a single font tells a user nothing they could
/// not have guessed, and the digits are the half that matters most in an app
/// whose every screen is a measurement.
///
/// The sample is a fixed string rather than a real figure from the device. A
/// number here would be the only one in the app that was not measured, and the
/// rule is the rule even in a preview.
class _TypefaceRow extends StatelessWidget {
  const _TypefaceRow({
    required this.face,
    required this.selected,
    required this.onTap,
  });

  final GTypeface face;
  final bool selected;
  final VoidCallback onTap;

  static const String _sample = '1,024 GB';

  /// Cuts the row loose from the ambient DefaultTextStyle.
  ///
  /// The System face resolves to a null fontFamily, which is correct once it is
  /// installed and wrong in this picker: a null family is filled in by whatever
  /// DefaultTextStyle is above it, so the System row was previewing the face
  /// the user already has rather than the one they would get. With inherit
  /// false there is nothing to fill it in from, and the platform decides, which
  /// is exactly what choosing System means.
  ///
  /// It also restores the monospace sample. The mono styles carry a fallback
  /// stack and no family, so an inherited proportional family was winning
  /// outright and the System row's figure was the only one in the list not
  /// drawn in a monospace face.
  ///
  /// Only the System row needs this. Every other face names a real family, and
  /// a named family is never overwritten by inheritance.
  TextStyle _preview(TextStyle style) =>
      face.isSystem ? style.copyWith(inherit: false) : style;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    // Resolving the unselected faces is what puts their files in flight, so by
    // the time a row is tapped the download is usually already done.
    final GTypeSet set = GType.preview(face);

    return Semantics(
      label: face.label,
      selected: selected,
      button: true,
      // GCard paints an opaque background over the Scaffold's Material, and ink
      // draws on the nearest Material behind that, so a bare InkWell here
      // splashes underneath the card and is never seen. This one is its own
      // surface.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: GRadius.all(GRadius.tile),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: GSpace.sm + 2,
              horizontal: GSpace.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? t.accentText : t.dim,
                ),
                const SizedBox(width: GSpace.md),
                Expanded(
                  child: Text(
                    face.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _preview(
                      set.title.copyWith(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GSpace.sm),
                Text(
                  _sample,
                  maxLines: 1,
                  style: _preview(set.monoNumber.copyWith(color: t.dim)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
