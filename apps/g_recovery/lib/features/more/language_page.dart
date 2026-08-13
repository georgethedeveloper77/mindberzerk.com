import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/i18n/g_strings.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';

/// CHOOSING A LANGUAGE.
///
/// ─── EACH ONE IS WRITTEN IN ITSELF ───────────────────────────────────────────
///
/// "Kiswahili", not "Swahili". A person who cannot read the language the app is
/// currently in cannot find their own in a list written in that language, which
/// is the exact situation this screen exists to fix. The English name sits
/// underneath in a quieter weight so that someone who picked the wrong one can
/// find their way back.
///
/// ─── THE PHONE ALREADY KNOWS ─────────────────────────────────────────────────
///
/// Twenty five rows is more than a screen. The system locale list is the best
/// guess anyone has about which of them a person wants, so the matches are
/// lifted to the top. It is a shortcut, not a filter: the full list is right
/// underneath, in the same order, every time.
///
/// ─── FLAGS ARE ORNAMENT ──────────────────────────────────────────────────────
///
/// Bundled images rather than emoji, because the emoji flag glyphs are missing
/// from the system font on a lot of the devices this app is built for and
/// render as boxed letters. And a flag is a country while a language is not, so
/// three rows here share India and the name is what actually identifies the
/// row. The flag is there to give the eye something to land on while scrolling.
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const LanguagePage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final String current = ref.watch(gLocaleProvider);
    final GStrings strings =
        ref.watch(gStringsProvider).value ?? const GStrings.english();

    final List<GLanguage> suggested = GLanguage.suggested(
      View.of(context).platformDispatcher.locales,
    );

    void select(GLanguage language) =>
        ref.read(gLocaleProvider.notifier).select(language.code);

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
              title: context.s('Language'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (suggested.isNotEmpty) ...<Widget>[
              _Header(label: context.s('From your phone settings')),
              GCard(
                padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < suggested.length; i++)
                      _Row(
                        language: suggested[i],
                        selected: suggested[i].code == current,
                        last: i == suggested.length - 1,
                        onTap: () => select(suggested[i]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: GSpace.md),
              _Header(label: context.s('All languages')),
            ],

            GCard(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < GLanguage.all.length; i++)
                    _Row(
                      language: GLanguage.all[i],
                      selected: GLanguage.all[i].code == current,
                      last: i == GLanguage.all.length - 1,
                      onTap: () => select(GLanguage.all[i]),
                    ),
                ],
              ),
            ),

            if (!strings.isEnglish) ...<Widget>[
              const SizedBox(height: GSpace.md),
              Text(
                // Says the truth about a partial translation rather than
                // leaving someone to wonder why half a screen changed. An app
                // that silently mixes languages looks broken; one that says it
                // will looks honest.
                context.s('Anything not yet translated stays in English.'),
                style: GType.micro.copyWith(color: t.dim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, GSpace.md, 2, 8),
      child: Text(label, style: GType.micro.copyWith(color: t.dim)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.language,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final GLanguage language;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
            child: Row(
              children: <Widget>[
                _Flag(language: language),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        language.nativeName,
                        style: GType.body.copyWith(color: t.text),
                      ),
                      // The English name underneath, so someone who picked the
                      // wrong one can find their way back. Hidden where the two
                      // are the same word, since repeating Filipino twice tells
                      // nobody anything.
                      if (language.nativeName != language.englishName)
                        Text(
                          language.englishName,
                          style: GType.micro.copyWith(color: t.muted),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 19, color: t.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The flag, or its absence handled quietly.
///
/// A hairline sits over the image because several flags have a white or very
/// pale edge that would otherwise bleed into the card and leave the shape
/// looking cropped. If the asset is missing the row keeps its rhythm with the
/// language code in its place, rather than collapsing and shifting every name
/// left by 36 pixels.
class _Flag extends StatelessWidget {
  const _Flag({required this.language});

  final GLanguage language;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return SizedBox(
      width: 24,
      height: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              language.flag,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      ColoredBox(
                        color: t.line,
                        child: Center(
                          child: Text(
                            language.code.toUpperCase(),
                            style: GType.micro.copyWith(
                              color: t.muted,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: t.line, width: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
