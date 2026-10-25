import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/meridian.dart';
import 'design/theme_mode.dart';
import 'i18n/strings.g.dart';
import 'shell.dart';

class GVpnApp extends ConsumerWidget {
  const GVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'G VPN',
        debugShowCheckedModeBanner: false,
        // The phone's language when a translation exists, else English.
        locale: TranslationProvider.of(context).flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: meridianTheme(Brightness.light),
        darkTheme: meridianTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        home: const Shell(),
      );
}
