// A paywall check is worth testing without Play, a container or a network,
// which is why the rule is a pure function and this file exists at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/terminal_entitlement.dart';

void main() {
  group('isTerminalPro', () {
    test('true only when the product is owned', () {
      expect(isTerminalPro({kTerminalProSku}), isTrue);
    });

    test('false for an empty set, which is the cold-start state', () {
      // Play has not answered yet. Failing CLOSED is the correct direction: a
      // paid user sees a lock for a moment, and the alternative is trusting a
      // cached flag, which is how an app ends up on a modding forum.
      expect(isTerminalPro(const {}), isFalse);
    });

    test('owning every distro does not make you Pro', () {
      // The bundle that granted everything was considered and rejected. This
      // asserts the decision rather than leaving it in a commit message.
      expect(
        isTerminalPro({
          'distro_kali',
          'distro_pop_cosmic',
          'distro_garuda_dragonized',
          'bundle_all_distros',
        }),
        isFalse,
      );
    });

    test('a near-miss sku does not unlock', () {
      // Play product IDs are matched exactly. A typo in the console presents as
      // the user not having bought it, which is the failure this asserts is
      // possible rather than one it prevents.
      for (final near in const [
        'terminal-pro',
        'Terminal_Pro',
        'terminalpro',
        'terminal_pro_v2',
        ' terminal_pro',
      ]) {
        expect(isTerminalPro({near}), isFalse, reason: near);
      }
    });

    test('unrelated ownership is ignored', () {
      expect(isTerminalPro({'icons_kali', 'distro_terminal'}), isFalse);
    });

    test('owning the distro named terminal is not owning Pro', () {
      // `distro_terminal` sells an identity and a home screen. Pro sells SSH at
      // scale. Conflating them would give every buyer of the Terminal distro a
      // key manager they did not pay for.
      expect(isTerminalPro({'distro_terminal'}), isFalse);
    });
  });

  group('the sku itself', () {
    test('satisfies Play product ID rules', () {
      // Mirrors CdnIndex.isSafeSku, which enforces the same thing on the pack
      // side: lowercase alphanumeric and underscore, starting with a letter or
      // digit. Enforced here because nothing else checks a feature sku.
      expect(kTerminalProSku, isNotEmpty);
      expect(kTerminalProSku.length, lessThanOrEqualTo(64));
      expect(RegExp(r'^[a-z0-9][a-z0-9_]*$').hasMatch(kTerminalProSku), isTrue);
    });
  });
}
