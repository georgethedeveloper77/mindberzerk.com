import 'package:flutter_riverpod/legacy.dart';
//import 'package:flutter_riverpod/legacy.dart'; // StateProvider moved here in v3

/// Is the Activities drawer open?
///
/// **Also used to live in `gnome_shell.dart`.** Same problem as `shellApps`: the
/// gesture layer reads it, the top bar writes it, the dock writes it, and none
/// of them should have to import a shell to find out whether a drawer is open.
///
/// It stays a `StateProvider` because that is exactly what it is — one bool, no
/// logic. Riverpod 3 moved `StateProvider` to `legacy.dart`; that is a rename,
/// not a deprecation with teeth. A `Notifier<bool>` here would be ceremony.
final activitiesOpenProvider = StateProvider<bool>((ref) => false);
