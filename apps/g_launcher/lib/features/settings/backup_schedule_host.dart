import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/backup_schedule.dart';

/// Runs the automatic backup check when the launcher comes back to the front.
///
/// ─── WHY A WRAPPER AND NOT A CALL IN THE HOME SHELL ─────────────────────────
///
/// The check has to fire whether the user landed on the home screen, the
/// drawer, or a settings page, and it has to keep firing after a restore has
/// rebuilt half the provider graph. A widget above all of that observes the
/// engine's lifecycle directly and survives every rebuild beneath it.
///
/// It renders [child] untouched and adds no layout, so wrapping costs one
/// element in the tree.
///
/// Wire it once, in `app.dart`, around whatever the router builds:
///
///   home: const BackupScheduleHost(child: BootGate()),
///
/// ─── THE FIRST CHECK IS POST-FRAME ──────────────────────────────────────────
///
/// A cold start does not produce a `resumed` event, so without the post-frame
/// call a phone that is restarted daily and never backgrounded would never back
/// up. It runs after the first frame rather than in `initState` so the boot
/// sequence paints before anything touches prefs.
class BackupScheduleHost extends ConsumerStatefulWidget {
  const BackupScheduleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackupScheduleHost> createState() => _BackupScheduleHostState();
}

class _BackupScheduleHostState extends ConsumerState<BackupScheduleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  /// Deliberately not awaited. The lifecycle callback must return immediately,
  /// and `runIfDue` never throws and reports nothing to the user: an automatic
  /// backup that announced itself would interrupt whatever the person came to
  /// the home screen to do.
  void _check() {
    if (!mounted) return;
    ref.read(backupScheduleProvider.notifier).runIfDue();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
