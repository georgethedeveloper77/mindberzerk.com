import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/components.dart';
import '../../i18n/i18n.dart';
import '../setup/setup_chrome.dart';

/// The language picker reached from Settings.
///
/// Reuses [SetupRow] so it reads exactly like the installer's language step,
/// and adds a "System default" row at the top (which setup omits, because a
/// first run wants a concrete choice). Selecting applies immediately and pops:
/// there is no Save button because there is nothing to commit later, the same
/// way the distro switch in Settings takes effect on tap.
///
/// This is the interim home for language while Settings is mid-redesign. It is
/// deliberately thin, and everything visible here is already translated through
/// ref.t, so it will follow the redesign without rework.
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(i18nProvider);
    final langs = localesForDisplay();

    void choose(AppLocale? l) {
      ref.read(i18nProvider.notifier).select(l);
      Navigator.of(context).maybePop();
    }

    return ThemedScaffold(
      title: ref.t('settings.language.title'),
      body: ListView(
        // The 28 is the list's own breathing room; the inset clears the
        // navigation bar on top of it. No longer const: the inset is runtime.
        padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + context.bottomInset),
        children: [
          SetupRow(
            title: ref.t('settings.language.system'),
            selected: i18n.selectedCode == null,
            marker: SetupMarker.check,
            onTap: () => choose(null),
          ),
          const SizedBox(height: 6),
          for (final l in langs)
            SetupRow(
              title: l.nativeName,
              // The English name as the quiet second line, so someone who has
              // landed on the wrong language by accident can still recognise
              // the row that gets them back.
              subtitle: l.englishName == l.nativeName ? null : l.englishName,
              selected: i18n.selectedLocale == l,
              marker: SetupMarker.check,
              onTap: () => choose(l),
            ),
        ],
      ),
    );
  }
}
