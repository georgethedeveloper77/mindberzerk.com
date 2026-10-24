import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/meridian.dart';
import 'design/theme_mode.dart';
import 'shell.dart';

class GVpnApp extends ConsumerWidget {
  const GVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'G VPN',
        debugShowCheckedModeBanner: false,
        theme: meridianTheme(Brightness.light),
        darkTheme: meridianTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        home: const Shell(),
      );
}
