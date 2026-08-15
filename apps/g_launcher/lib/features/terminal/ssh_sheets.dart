/// The two things a connection has to ask a person.
///
/// Both painted from the TERMINAL palette rather than `ChromeData`, like the
/// rest of this screen: a settings-coloured sheet rising over a green canvas
/// reads as two apps stacked.
///
/// ─── DISMISSAL IS A NO ──────────────────────────────────────────────────────
///
/// Both return the refusing answer when the sheet is dismissed by a back
/// gesture or a tap outside. Silence is not consent, and the alternative for
/// the host key sheet is a client that trusts a key because someone swiped in
/// the wrong direction.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/terminal_spec.dart';
import 'ssh_host.dart';

/// Ask for a password. Null when cancelled.
///
/// Held only for the life of the connection and never written anywhere. The
/// only honest place for a stored credential is behind the keystore with a
/// biometric, and that arrives with the key manager.
Future<String?> askSshPassword(
  BuildContext context,
  SshHost host,
  TerminalPalette palette, {
  String? fontFamily,
}) async {
  final controller = TextEditingController();

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.bg,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Rides above the keyboard. A password field the keyboard covers is a
        // password field nobody can see they typed into.
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            host.target,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12.5,
              color: palette.dim,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(fontFamily: fontFamily, color: palette.fg),
            cursorColor: palette.cursor,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.fg.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.dim),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.dim),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.ansi[4]),
              ),
            ),
            onSubmitted: (v) => Navigator.of(sheetContext).pop(v),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text('Cancel', style: TextStyle(color: palette.dim)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.ansi[4],
                  foregroundColor: palette.bg,
                ),
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text),
                child: const Text('Connect'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}

/// Ask whether to trust a host key. False when dismissed.
///
/// ─── THE FINGERPRINT IS THE WHOLE POINT ─────────────────────────────────────
///
/// This sheet is only meaningful if the person can compare what it shows with
/// what their server reports, so it prints the exact `SHA256:` string that
/// `ssh-keygen -lf` prints and tells them the command to run. A dialog that
/// says "an unknown host wants to connect, OK?" trains people to tap OK.
///
/// [HostKeyVerdict.mismatch] never reaches here: that refuses in
/// `SshConnection` without asking, because at that moment a prompt is a button
/// someone taps to make an error go away.
Future<bool> confirmSshHostKey(
  BuildContext context,
  SshHost host, {
  required String keyType,
  required String fingerprint,
  required HostKeyVerdict verdict,
  required TerminalPalette palette,
  String? fontFamily,
}) async {
  final isNewAlgorithm = verdict == HostKeyVerdict.newAlgorithm;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.bg,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key, size: 18, color: palette.warn),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isNewAlgorithm
                      ? 'New key type for ${host.host}'
                      : 'First connection to ${host.host}',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isNewAlgorithm
                ? 'This server is offering a key of a type you have not '
                    'accepted before. That is normal, and it is also what an '
                    'impersonation would look like.'
                : 'This server has not been seen before. Check the '
                    'fingerprint matches, or anything between you and it '
                    'could read what you type.',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 12.5,
              height: 1.5,
              color: palette.dim,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.fg.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyType,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11.5,
                    color: palette.dim,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  fingerprint,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 12.5,
                    height: 1.4,
                    color: palette.fg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'On the server:  ssh-keygen -lf /etc/ssh/ssh_host_${_keyFile(keyType)}_key.pub',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              height: 1.5,
              color: palette.dim,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text('Cancel', style: TextStyle(color: palette.dim)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.warn,
                  foregroundColor: palette.bg,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop(true);
                },
                child: const Text('Trust this key'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // Dismissed by a back gesture or a tap outside. Not consent.
  return ok ?? false;
}

/// The filename OpenSSH gives a host key of this type, so the command printed
/// above is one someone can paste rather than adapt.
String _keyFile(String keyType) => switch (keyType) {
      'ssh-ed25519' => 'ed25519',
      'ssh-rsa' || 'rsa-sha2-256' || 'rsa-sha2-512' => 'rsa',
      _ when keyType.startsWith('ecdsa-') => 'ecdsa',
      // Unknown type: name the placeholder rather than printing a wrong path
      // that would fail with "no such file" and look like the server is broken.
      _ => '<type>',
    };
