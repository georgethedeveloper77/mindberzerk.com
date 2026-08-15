/// The paywall, reached only from a locked command.
///
/// ─── NEVER ON LAUNCH, NEVER ON A TIMER ──────────────────────────────────────
///
/// This opens when someone runs a Pro command and not before. They typed it, so
/// they know what it is and they wanted it a second ago, which is the only
/// moment a price is worth showing. A sheet that appears because the app opened
/// is an advertisement.
///
/// The command that led here is named at the top, so the sheet answers the
/// question that was just asked rather than pitching a feature list.
///
/// Painted from the TERMINAL palette like the rest of this screen. A
/// chrome-coloured store sheet rising over a green canvas reads as a different
/// app arriving to ask for money.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/terminal_spec.dart';
import 'terminal_entitlement.dart';

/// Show it. Returns true when a purchase was STARTED, which is not the same as
/// completed: Play's flow can take minutes on the cash and carrier-billing
/// methods this market actually uses, and the entitlement arrives on its own
/// stream when it does.
Future<bool> showTerminalProSheet(
  BuildContext context,
  WidgetRef ref, {
  required String command,
  required TerminalPalette palette,
  String? fontFamily,
}) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: palette.bg,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ProSheet(
      command: command,
      palette: palette,
      fontFamily: fontFamily,
    ),
  );
  return started ?? false;
}

class _ProSheet extends ConsumerWidget {
  const _ProSheet({
    required this.command,
    required this.palette,
    this.fontFamily,
  });

  final String command;
  final TerminalPalette palette;
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final price = ref.watch(terminalProPriceProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: p.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$command needs Terminal Pro',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _Line(
              palette: p,
              fontFamily: fontFamily,
              text: 'Keys held in this phone\'s secure chip, unlocked with '
                  'your fingerprint. The key itself can never leave the device.',
            ),
            _Line(
              palette: p,
              fontFamily: fontFamily,
              text: 'As many saved servers as you like.',
            ),
            _Line(
              palette: p,
              fontFamily: fontFamily,
              text: 'One payment. Not a subscription.',
            ),

            const SizedBox(height: 16),
            Text(
              // What stays free is stated, because a paywall that implies the
              // free tier is crippled is one people resent. Everything they
              // already use keeps working.
              'Every command stays free, and so does one saved server with a '
              'password.',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 11.5,
                height: 1.5,
                color: p.dim,
              ),
            ),

            const SizedBox(height: 18),
            if (price == null)
              // NOT a free unlock, and not a spinner forever. Play has not
              // answered, which on a de-Googled ROM it never will, and saying so
              // beats a button that does nothing when tapped.
              Text(
                'Not available to buy on this device right now.',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12.5,
                  color: p.warn,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.warn,
                    foregroundColor: p.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final ok = await ref.read(buyTerminalProProvider)();
                    if (context.mounted) Navigator.of(context).pop(ok);
                  },
                  child: Text(
                    'Unlock for $price',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: TextStyle(fontFamily: fontFamily, color: p.dim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.palette,
    this.fontFamily,
  });

  final String text;
  final TerminalPalette palette;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 15, color: palette.ok),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 12.5,
                height: 1.5,
                color: palette.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
