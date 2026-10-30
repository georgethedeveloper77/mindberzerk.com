/// A physical keyboard on the home screen: a Bluetooth keyboard on a phone or
/// tablet, a Chromebook's own, a DeX keyboard on the launcher's window.
///
/// ─── THE DESKTOP HABITS, MAPPED ─────────────────────────────────────────────
///
///   type anything      search opens with that letter in it (GNOME, KRunner)
///   Super, alone       search
///   Super+A            the app drawer (GNOME's Show Applications)
///   Super+D, Esc       back to a bare desktop
///   Ctrl+Alt+T         the Terminal (every Linux desktop since forever)
///   Super+N            Android's notification shade
///   Super+L            lock the screen
///   Alt+Tab            Android's recent apps
///   Super+/            this list, on screen
///
/// The shade, the lock and recents need the gesture accessibility service,
/// exactly as the same gestures do, and ask for it the same way the first time.
///
/// ─── DeX, HONESTLY ──────────────────────────────────────────────────────────
///
/// DeX draws its own Samsung desktop and does not hand the home role to a
/// third-party launcher, so G Launcher cannot BE the DeX desktop. What works is
/// everything above on the phone's own screen with a keyboard attached.
///
/// ─── A GLOBAL HANDLER, NOT A FOCUS NODE ─────────────────────────────────────
///
/// The home screen has nothing focused, so a Focus-based shortcut would never
/// see a key. `HardwareKeyboard.addHandler` sees every key, so this answers
/// only when the home route is on top and no text field holds focus; anything
/// else returns false and the key goes where it was going.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../drawer/drawer_state.dart';
import '../gestures/accessibility_disclosure.dart';
import '../gestures/gesture_actions.dart';
import '../home/quick_settings.dart';
import '../search/search_sheet.dart';
import '../terminal/terminal_screen.dart';

class LauncherKeys extends ConsumerStatefulWidget {
  const LauncherKeys({super.key, required this.theme, required this.child});

  final EffectiveTheme theme;
  final Widget child;

  @override
  ConsumerState<LauncherKeys> createState() => _LauncherKeysState();
}

class _LauncherKeysState extends ConsumerState<LauncherKeys> {
  /// Super went down and nothing else has been pressed with it yet.
  bool _superAlone = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool get _active {
    if (!mounted) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    // A focused text field owns its keys: typing in the drawer's own search
    // box must not open a second search on top of it.
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    return true;
  }

  static bool _isSuper(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.metaLeft ||
      k == LogicalKeyboardKey.metaRight ||
      k == LogicalKeyboardKey.meta;

  bool _onKey(KeyEvent e) {
    if (!_active) {
      _superAlone = false;
      return false;
    }

    final keys = HardwareKeyboard.instance;
    final k = e.logicalKey;

    if (_isSuper(k)) {
      if (e is KeyDownEvent) _superAlone = true;
      if (e is KeyUpEvent && _superAlone) {
        _superAlone = false;
        _search();
        return true;
      }
      return false;
    }

    if (e is! KeyDownEvent) return false;
    _superAlone = false;

    final superDown = keys.isMetaPressed;
    final ctrl = keys.isControlPressed;
    final alt = keys.isAltPressed;

    if (superDown) {
      if (k == LogicalKeyboardKey.keyA) return _do(_drawer);
      if (k == LogicalKeyboardKey.keyD) return _do(_desktop);
      if (k == LogicalKeyboardKey.keyN) {
        return _do(() => _system(GestureAction.notifications));
      }
      if (k == LogicalKeyboardKey.keyL) {
        return _do(() => _system(GestureAction.lockScreen));
      }
      if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.space) {
        return _do(_search);
      }
      if (k == LogicalKeyboardKey.slash) return _do(_help);
      return false;
    }

    if (ctrl && alt && k == LogicalKeyboardKey.keyT) {
      return _do(() => openTerminal(context, widget.theme));
    }
    if (alt && k == LogicalKeyboardKey.tab) {
      return _do(() => _system(GestureAction.recents));
    }
    if (k == LogicalKeyboardKey.escape) {
      final anyOpen =
          ref.read(activitiesOpenProvider) || ref.read(quickSettingsProvider);
      if (!anyOpen) return false;
      return _do(_desktop);
    }

    // ─── TYPE TO SEARCH ───────────────────────────────────────────────────
    //
    // A printable character with no modifier opens search already holding
    // it, so "tel" then Enter launches Telegram from a bare desktop.
    final ch = e.character;
    if (!ctrl && !alt && ch != null && ch.length == 1 && ch.trim().isNotEmpty) {
      final code = ch.codeUnitAt(0);
      if (code >= 0x20 && code != 0x7F) return _do(() => _search(ch));
    }
    return false;
  }

  bool _do(void Function() f) {
    f();
    return true;
  }

  void _search([String? initial]) {
    _desktop();
    showSearchSheet(context, widget.theme, initialQuery: initial);
  }

  void _drawer() {
    ref.read(quickSettingsProvider.notifier).close();
    ref.read(activitiesOpenProvider.notifier).state = true;
  }

  void _desktop() {
    ref.read(activitiesOpenProvider.notifier).state = false;
    ref.read(quickSettingsProvider.notifier).close();
  }

  Future<void> _system(GestureAction action) async {
    final ok = await runGesture(
      ref,
      GestureBinding.action(action),
      onActivities: _drawer,
      onShowDock: () {},
      onSearch: _search,
    );
    if (!ok && action.needsService && mounted) {
      await requestGestureService(context, ref);
    }
  }

  void _help() {
    const rows = <(String, String)>[
      ('keys.typeToSearch', 'A to Z'),
      ('keys.search', 'Super'),
      ('keys.drawer', 'Super+A'),
      ('keys.desktop', 'Super+D · Esc'),
      ('keys.terminal', 'Ctrl+Alt+T'),
      ('keys.notifications', 'Super+N'),
      ('keys.lock', 'Super+L'),
      ('keys.recents', 'Alt+Tab'),
    ];
    ThemedSheet.show<void>(
      context,
      title: context.t('keys.title'),
      builder: (sheet) {
        final d = ChromeScope.of(sheet);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, combo) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text(sheet.t(label), style: d.text.body)),
                      Text(
                        combo,
                        style: d.text.body.copyWith(
                          fontFamily: widget.theme.typography.mono,
                          color: d.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
