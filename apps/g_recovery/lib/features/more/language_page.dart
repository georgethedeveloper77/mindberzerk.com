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
/// is the exact situation this screen exists to fix.
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

            GCard(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < GLanguage.all.length; i++)
                    _Row(
                      language: GLanguage.all[i],
                      selected: GLanguage.all[i].code == current,
                      last: i == GLanguage.all.length - 1,
                      onTap: () => ref
                          .read(gLocaleProvider.notifier)
                          .select(GLanguage.all[i].code),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        language.nativeName,
                        style: GType.body.copyWith(color: t.text),
                      ),
                      // The English name underneath, so someone who picked the
                      // wrong one can find their way back.
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
