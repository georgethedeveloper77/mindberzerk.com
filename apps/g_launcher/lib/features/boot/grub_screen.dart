import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/cdn/distro_packs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../engine/boot_spec.dart';
import '../../engine/effective_theme.dart';
import '../settings/settings_screen.dart';
import '../themes/theme_actions.dart';
import '../themes/theme_catalog.dart';
import '../themes/theme_detail_screen.dart';
import '../themes/theme_peek.dart';
import 'boot_controller.dart';
import 'boot_sequence.dart';
import 'grub_prefs.dart';

/// What the person picked at the GRUB menu.
///
/// Null from [showGrubMenu] means "boot the default", which is also what a
/// timeout, system back and the `Esc` key mean, exactly as on a PC.
sealed class GrubChoice {
  const GrubChoice();
}

/// Boot a distro already on the phone (bundled or installed).
class GrubBootDistro extends GrubChoice {
  const GrubBootDistro(this.themeId, {this.verbose});

  final String themeId;

  /// From "Advanced options": force the boot log on or off for this one boot.
  /// Null keeps the person's own Verbose boot setting.
  final bool? verbose;
}

/// A free distro not downloaded yet: the caller runs the normal card action,
/// which downloads and then applies it.
class GrubGetDistro extends GrubChoice {
  const GrubGetDistro(this.card);

  final ThemeCard card;
}

/// "UEFI Firmware Settings": G Launcher's own Settings, after the boot.
class GrubFirmwareSettings extends GrubChoice {
  const GrubFirmwareSettings();
}

/// Do what a [GrubChoice] means, from wherever the menu was opened.
///
/// A different distro is a theme switch, and the home screen plays that
/// distro's own boot when the id changes, so only the SAME distro needs a
/// boot played here.
Future<void> applyGrubChoice(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme t,
  GrubChoice? choice,
) async {
  final boot = ref.read(bootControllerProvider.notifier);
  switch (choice) {
    case GrubBootDistro(:final themeId) when themeId != t.spec.id:
      await ref.read(selectedThemeIdProvider.notifier).select(themeId);
      unawaited(ref.read(distroPacksProvider.notifier).ensure(themeId));
    case GrubBootDistro(:final verbose):
      boot.playFor(t, verbose: verbose);
    case GrubGetDistro(:final card):
      boot.playFor(t);
      if (context.mounted) await runThemeCardAction(context, ref, card);
    case GrubFirmwareSettings():
      boot.playFor(t);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SettingsScreen(theme: t)),
      );
    case null:
      boot.playFor(t);
  }
}

/// Push the menu. [currentId] is the distro that boots on timeout.
Future<GrubChoice?> showGrubMenu(
  BuildContext context, {
  required String currentId,
  required String currentName,
}) {
  return Navigator.of(context).push<GrubChoice>(
    PageRouteBuilder<GrubChoice>(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) =>
          GrubScreen(currentId: currentId, currentName: currentName),
    ),
  );
}

/// GNU GRUB, as a distro picker.
///
/// ─── IT LOOKS LIKE GRUB ON PURPOSE, NOT LIKE THE DISTRO ─────────────────────
///
/// GRUB runs before any desktop exists, so it wears no distro's palette: grey
/// on black, one boxed menu, an inverted bar for the selection, a countdown
/// under it. That plainness is the joke and the authenticity at once. Every
/// distro's own look starts after you pick it.
///
/// ─── WHAT EACH KIND OF ENTRY DOES ───────────────────────────────────────────
///
///   on the phone   boots it (a theme switch, which plays its boot or splash)
///   free, not yet  downloads then boots, through the storefront's own action
///   paid, locked   plays THAT distro's real boot log as a preview, then
///                  opens its store page: the purchase funnel dressed as the
///                  joke
///   Advanced       the current distro with the boot log forced on or off
///   UEFI           G Launcher Settings
class GrubScreen extends ConsumerStatefulWidget {
  const GrubScreen({
    super.key,
    required this.currentId,
    required this.currentName,
  });

  final String currentId;
  final String currentName;

  @override
  ConsumerState<GrubScreen> createState() => _GrubScreenState();
}

/// One row of the menu.
class _Entry {
  const _Entry(this.label, this.onSelect, {this.suffix});

  final String label;
  final String? suffix;
  final VoidCallback onSelect;
}

class _GrubScreenState extends ConsumerState<GrubScreen> {
  static const _bg = Color(0xFF000000); // theme-exempt: GRUB is pre-desktop
  static const _fg = Color(0xFFAAAAAA); // theme-exempt: GRUB console grey
  static const _hi = Color(0xFFFFFFFF); // theme-exempt: GRUB console white
  static const _mono = 'UbuntuMono';

  Timer? _timer;
  int? _remaining;
  int _selected = 0;
  bool _advanced = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await ref.read(grubPrefsProvider.future);
      if (!mounted || prefs.timeoutSec <= 0) return;
      setState(() => _remaining = prefs.timeoutSec);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        final left = (_remaining ?? 0) - 1;
        if (left <= 0) {
          t.cancel();
          _bootDefault();
        } else {
          setState(() => _remaining = left);
        }
      });
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// Any touch or key stops the countdown, as any key does on a PC.
  void _hold() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    setState(() => _remaining = null);
  }

  void _bootDefault() {
    if (mounted) Navigator.of(context).pop();
  }

  void _pop(GrubChoice c) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(c);
  }

  /// A paid distro: its real boot log, then its store page.
  Future<void> _preview(ThemeCard card) async {
    _hold();
    final peek = await ref.read(
      peekedThemeProvider(
        (packId: card.packIdOrSpec, version: card.remoteVersion),
      ).future,
    );
    if (!mounted) return;
    final spec = peek?.spec;
    final boot = spec == null
        ? null
        : (spec.boot ?? BootSpec.defaultForShell(spec.shell));
    if (boot != null && spec != null) {
      final s = spec;
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: Duration.zero,
          pageBuilder: (ctx, __, ___) => BootSequence(
            spec: boot,
            colors: BootColors.fromPalette(
              accent: s.palette.accent,
              background: s.palette.bgBottom,
            ),
            monoFontFamily: s.typography.mono ?? _mono,
            onComplete: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ThemeDetailScreen(packId: card.packIdOrSpec),
      ),
    );
  }

  List<_Entry> _entries(BuildContext context, List<ThemeCard> cards) {
    if (_advanced) {
      return [
        _Entry(
          context.t('grub.withLog', {'name': widget.currentName}),
          () => _pop(GrubBootDistro(widget.currentId, verbose: true)),
        ),
        _Entry(
          context.t('grub.quiet', {'name': widget.currentName}),
          () => _pop(GrubBootDistro(widget.currentId, verbose: false)),
        ),
        _Entry(
            context.t('grub.back'),
            () => setState(() {
                  _advanced = false;
                  _selected = 0;
                })),
      ];
    }

    // The default first, as GRUB lists it, marked with the classic `*`.
    final current = cards.where((c) => c.specId == widget.currentId);
    final others = cards.where(
      (c) =>
          c.specId != widget.currentId &&
          c.status != CardStatus.requiresAppUpdate,
    );

    _Entry entryFor(ThemeCard c) => switch (c.status) {
          CardStatus.locked => _Entry(
              c.name,
              () => _preview(c),
              suffix: context.t('grub.locked'),
            ),
          CardStatus.available => _Entry(
              c.name,
              () => _pop(GrubGetDistro(c)),
              suffix: context.t('grub.notInstalled'),
            ),
          _ => _Entry(c.name, () {
              if (c.specId != null) _pop(GrubBootDistro(c.specId!));
            }),
        };

    return [
      if (current.isEmpty)
        _Entry(widget.currentName, _bootDefault)
      else
        _Entry(current.first.name, _bootDefault),
      for (final c in others) entryFor(c),
      _Entry(
        context.t('grub.advanced', {'name': widget.currentName}),
        () => setState(() {
          _advanced = true;
          _selected = 0;
        }),
      ),
      _Entry(
        context.t('grub.firmware'),
        () => _pop(const GrubFirmwareSettings()),
      ),
    ];
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e, List<_Entry> entries) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    _hold();
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1) % entries.length);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      setState(
          () => _selected = (_selected - 1 + entries.length) % entries.length);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      entries[_selected].onSelect();
    } else if (k == LogicalKeyboardKey.escape) {
      if (_advanced) {
        setState(() {
          _advanced = false;
          _selected = 0;
        });
      } else {
        _bootDefault();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(themeCatalogProvider).value ?? const <ThemeCard>[];
    final entries = _entries(context, cards);
    if (_selected >= entries.length) _selected = 0;

    const text = TextStyle(fontFamily: _mono, fontSize: 14, color: _fg);
    final scale = MediaQuery.textScalerOf(context);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (n, e) => _onKey(n, e, entries),
      child: Listener(
        onPointerDown: (_) => _hold(),
        child: ColoredBox(
          color: _bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'GNU GRUB  version 2.12',
                    textAlign: TextAlign.center,
                    style: text,
                    textScaler: scale,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _fg),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          final on = i == _selected;
                          final star = i == 0 && !_advanced ? '*' : ' ';
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => setState(() => _selected = i),
                            onTap: e.onSelect,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              alignment: Alignment.centerLeft,
                              color: on ? _fg : _bg,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$star${e.label}'
                                '${e.suffix == null ? '' : '  [${e.suffix}]'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.copyWith(color: on ? _bg : _fg),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t('grub.help'),
                    style: text.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _remaining == null
                        ? ''
                        : context.t('grub.countdown', {
                            'seconds': '$_remaining',
                          }),
                    style: text.copyWith(color: _hi, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
