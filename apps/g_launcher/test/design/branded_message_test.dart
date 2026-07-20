import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/design/branded_message.dart';

/// The gesture layer calls showMessage() from places with no Scaffold anywhere
/// above them — the case that would have broken a ScaffoldMessenger
/// implementation, so it's the case that gets tested.
///
/// v2 of these tests exists because v1 caught a real bug and then failed
/// messily: the messenger is a process-wide singleton, and its cached
/// OverlayEntry outlived each test's tree. Two rules keep this suite honest:
///   1. tearDown calls debugResetBrandedMessenger() — no timer or entry
///      survives into the next test (or trips the pending-timers assert).
///   2. Each test drains its own message (pump past the duration + exit
///      animation) before ending, mirroring what a real tree does.
Widget _host(void Function(BuildContext) onReady, {Key? key}) {
  return ProviderScope(
    key: key,
    child: MaterialApp(
      home: Builder(
        builder: (context) => GestureDetector(
          onTap: () => onReady(context),
          child: const SizedBox.expand(child: ColoredBox(color: Colors.black)),
        ),
      ),
    ),
  );
}

/// Duration + exit animation + slack.
const _drain = Duration(milliseconds: 3400);

void main() {
  tearDown(debugResetBrandedMessenger);

  testWidgets('shows a message from a context with no Scaffold', (tester) async {
    await tester.pumpWidget(_host((c) => c.showMessage('Wallpaper set')));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper set'), findsOneWidget);

    await tester.pump(_drain);
    await tester.pumpAndSettle();
  });

  testWidgets('survives its tree being disposed — the singleton lifecycle bug',
      (tester) async {
    // Show a message in tree #1...
    await tester.pumpWidget(
      _host((c) => c.showMessage('first tree'), key: const ValueKey('tree-1')),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('first tree'), findsOneWidget);

    // ...replace the entire tree. The DISTINCT key forces Flutter to dispose
    // tree #1 and mount a fresh one — an identical tree would be reused and the
    // Overlay never recreated, so the disposal this test is about would never
    // happen. This is what a hot restart / root rebuild does in production.
    await tester.pumpWidget(
      _host((c) => c.showMessage('second tree'), key: const ValueKey('tree-2')),
    );
    await tester.pumpAndSettle();

    // ...and the messenger must attach cleanly to the NEW overlay. v1 threw
    // "already present in a different Overlay" here.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('second tree'), findsOneWidget);

    await tester.pump(_drain);
    await tester.pumpAndSettle();
  });

  testWidgets('auto-dismisses after its duration', (tester) async {
    // The duration must clear pumpAndSettle's settle window for the enter
    // animation (~300ms), or the dismiss timer fires WHILE settling and the
    // message is gone before the first assertion even runs. 1500ms is clear.
    await tester.pumpWidget(_host(
      (c) => c.showMessage('gone soon',
          duration: const Duration(milliseconds: 1500)),
    ));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('gone soon'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('gone soon'), findsNothing);
  });

  testWidgets('queues rather than stacking', (tester) async {
    // 1500ms for the same reason as the auto-dismiss test: keep each message's
    // dismiss timer out of the enter-animation settle window.
    await tester.pumpWidget(_host((c) {
      c.showMessage('first', duration: const Duration(milliseconds: 1500));
      c.showMessage('second', duration: const Duration(milliseconds: 1500));
    }));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    // Exactly one on screen — never two cards fighting for the same slot.
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets('the action fires and dismisses', (tester) async {
    var retried = false;

    await tester.pumpWidget(_host(
      (c) => c.showMessage(
        'Backup failed',
        tone: MessageTone.danger,
        actionLabel: 'Retry',
        onAction: () => retried = true,
      ),
    ));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
    expect(find.text('Backup failed'), findsNothing);
  });

  testWidgets('tap dismisses', (tester) async {
    await tester.pumpWidget(_host((c) => c.showMessage('tap me away')));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('tap me away'));
    await tester.pumpAndSettle();

    expect(find.text('tap me away'), findsNothing);
  });
}
