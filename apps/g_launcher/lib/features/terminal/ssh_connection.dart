/// One SSH connection, from socket to shell.
///
/// ─── THE ORDER OF OPERATIONS IS THE SECURITY ────────────────────────────────
///
/// Socket, then HOST KEY, then password. The key check happens during the
/// transport handshake, before any authentication method runs, which is what
/// makes it worth anything: by the time a password is sent, the peer has
/// already proven it holds the key we pinned. Reverse those and the password is
/// gone before the check could have helped.
///
/// dartssh2 gives us that for free through `onVerifyHostKey`, and the handler is
/// `FutureOr<bool>`, so a confirmation sheet can be awaited inside it.
///
/// ─── disableHostkeyVerification IS NEVER SET ────────────────────────────────
///
/// It exists on `SSHClient` and it defaults to false. It is the single most
/// tempting line in this file the first time a connection refuses, and setting
/// it removes the only thing standing between a password and a machine in the
/// middle. `scripts/no_insecure_ssh.sh` fails the build if it ever appears.
///
/// ─── OUTPUT IS BYTES, NOT STRINGS ───────────────────────────────────────────
///
/// `stdout` is a `Stream<Uint8List>` and a chunk boundary can land in the middle
/// of a UTF-8 sequence, so decoding each chunk on its own mangles any character
/// unlucky enough to straddle one. A single `Utf8Decoder` with `allowMalformed`
/// runs for the life of the session and carries that state across chunks.
///
/// `AnsiParser` then does the same job one level up, holding escape-sequence
/// state across the same boundaries. Local command output already goes through
/// it, which is why it arrives here proven rather than untested.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_host.dart';

/// Where a connection has got to.
enum SshPhase {
  idle,
  connecting,
  verifying,
  authenticating,
  open,
  closed,

  /// Ended badly. [SshConnection.failure] says how, in words meant for a person.
  failed,
}

/// What the caller must answer while a connection is being made.
///
/// Both are async because both put something on screen. Returning null from
/// [onPassword] or false from [onHostKey] ABORTS, which is the correct reading
/// of a person dismissing a sheet: silence is not consent.
typedef SshPasswordPrompt = Future<String?> Function(SshHost host);

typedef SshHostKeyPrompt = Future<bool> Function(
  SshHost host,
  String keyType,
  String fingerprint,
  HostKeyVerdict verdict,
);

/// A live connection.
///
/// Deliberately not a Riverpod notifier. A session is owned by the screen that
/// opened it and dies with it; a provider would outlive the screen and keep a
/// socket open behind a closed terminal.
class SshConnection {
  SshConnection({
    required this.host,
    this.identity,
    required this.onData,
    required this.onPhase,
    required this.onPassword,
    required this.onHostKey,
    required this.lookupPinned,
    required this.pin,
    this.connectTimeout = const Duration(seconds: 15),
  });

  final SshHost host;

  /// The key to offer, or null for password only.
  ///
  /// dartssh2 tries PUBLIC KEY BEFORE PASSWORD when both are available, which
  /// is the order you want: a key that works means the password sheet never
  /// appears, and a key that fails falls through rather than blocking.
  ///
  /// Typed as the package's own interface rather than the keystore class, so a
  /// PEM-loaded identity would work here too without this file knowing.
  final SSHKeyPair? identity;

  /// Decoded output, ready for the parser.
  final void Function(String text) onData;

  final void Function(SshPhase phase) onPhase;

  final SshPasswordPrompt onPassword;
  final SshHostKeyPrompt onHostKey;

  /// The pinned key for this host and port, or null.
  final KnownHost? Function(String host, int port) lookupPinned;

  /// Remember a key the person confirmed. Only ever called after a true from
  /// [onHostKey]; there is no path that pins silently.
  final Future<void> Function(KnownHost key) pin;

  final Duration connectTimeout;

  SSHClient? _client;
  SSHSession? _session;
  StreamSubscription<Uint8List>? _out;
  StreamSubscription<Uint8List>? _err;

  /// One decoder for the whole session, so a multi-byte character split across
  /// two reads survives. `allowMalformed` because a remote program can emit
  /// genuinely invalid bytes and a terminal that throws on them is a terminal
  /// that dies mid-log.
  final _decoder = const Utf8Decoder(allowMalformed: true);

  SshPhase _phase = SshPhase.idle;
  SshPhase get phase => _phase;

  String? failure;

  bool get isOpen => _phase == SshPhase.open;

  void _setPhase(SshPhase p) {
    _phase = p;
    onPhase(p);
  }

  /// Connect, verify, authenticate, open a shell.
  ///
  /// Returns true when a shell is live. Every failure path sets [failure] to
  /// something a person can act on rather than a stack trace: the difference
  /// between "connection refused" and "wrong password" is the difference
  /// between checking the server and checking your typing.
  Future<bool> open({required int columns, required int rows}) async {
    _setPhase(SshPhase.connecting);

    SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        host.host,
        host.port,
        timeout: connectTimeout,
      );
    } catch (e) {
      return _fail(_connectMessage(e));
    }

    var aborted = false;

    try {
      final client = SSHClient(
        socket,
        username: host.user,
        identities: identity == null ? null : [identity!],
        // NOTE: disableHostkeyVerification is deliberately absent. See the
        // library doc, and scripts/no_insecure_ssh.sh, which enforces it.
        onVerifyHostKey: (type, fingerprintBytes) async {
          _setPhase(SshPhase.verifying);

          // The library has already formatted this as `SHA256:<base64>` with
          // the padding stripped, which is what OpenSSH prints, so it is
          // comparable with what a person sees on their own server.
          final fingerprint = utf8.decode(fingerprintBytes);

          final verdict = verdictFor(
            lookupPinned(host.host, host.port),
            keyType: type,
            fingerprint: fingerprint,
          );

          if (verdict == HostKeyVerdict.trusted) return true;

          if (verdict == HostKeyVerdict.mismatch) {
            // NOT a prompt. The server may have been rebuilt or something may
            // be impersonating it, and from here those are indistinguishable.
            // A dialog at this moment is a button someone taps to make the
            // error go away, which is exactly the wrong outcome.
            aborted = true;
            failure = 'Host key for ${host.host} has CHANGED.\n'
                'Someone could be impersonating the server, or it was '
                'rebuilt.\n'
                'Nothing was sent. Remove the saved key to connect anyway.';
            return false;
          }

          final accepted =
              await onHostKey(host, type, fingerprint, verdict);
          if (!accepted) {
            aborted = true;
            failure = 'Host key not accepted. Nothing was sent.';
            return false;
          }

          await pin(KnownHost(
            host: host.host,
            port: host.port,
            keyType: type,
            fingerprint: fingerprint,
            acceptedAt: DateTime.now().toUtc(),
          ));
          return true;
        },
        onPasswordRequest: () async {
          _setPhase(SshPhase.authenticating);
          final password = await onPassword(host);
          if (password == null) {
            aborted = true;
            failure = 'Cancelled.';
          }
          return password;
        },
      );

      _client = client;

      // A PTY with the REAL size, not the 80x24 default. Without it `htop` and
      // `less` draw for a terminal twice as wide as the phone and every line
      // wraps, which reads as the app being broken rather than the size being
      // wrong.
      final session = await client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: columns,
          height: rows,
        ),
      );
      _session = session;

      _out = session.stdout.listen(
        (chunk) => onData(_decoder.convert(chunk)),
        onDone: _handleClosed,
      );
      // stderr is merged into the same stream rather than separated. A terminal
      // interleaves them, and a program that writes progress to stderr would
      // otherwise print out of order or not at all.
      _err = session.stderr.listen((chunk) => onData(_decoder.convert(chunk)));

      _setPhase(SshPhase.open);
      return true;
    } catch (e) {
      if (aborted) {
        _setPhase(SshPhase.failed);
        return false;
      }
      return _fail(_authMessage(e));
    }
  }

  /// Send input to the remote shell.
  ///
  /// Silently ignored when no shell is open, because the caller is a keyboard
  /// and a keystroke arriving a frame after a disconnect is not an error worth
  /// telling anyone about.
  void write(String text) {
    if (!isOpen) return;
    _session?.write(Uint8List.fromList(utf8.encode(text)));
  }

  /// Tell the remote the window changed.
  ///
  /// Called on rotation and when the keyboard opens. A remote full-screen
  /// program only redraws correctly if it is told, and this is the difference
  /// between rotating into a usable screen and rotating into a smeared one.
  void resize({required int columns, required int rows}) {
    if (!isOpen) return;
    _session?.resizeTerminal(columns, rows);
  }

  Future<void> close() async {
    await _out?.cancel();
    await _err?.cancel();
    _out = null;
    _err = null;
    _session?.close();
    _session = null;
    _client?.close();
    _client = null;
    if (_phase != SshPhase.failed) _setPhase(SshPhase.closed);
  }

  void _handleClosed() {
    if (_phase == SshPhase.open) _setPhase(SshPhase.closed);
  }

  bool _fail(String message) {
    failure = message;
    _setPhase(SshPhase.failed);
    return false;
  }

  /// Socket-level failures, in words that point at the right thing.
  String _connectMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('timed out') || s.contains('timeout')) {
      return 'No answer from ${host.host}:${host.port} after '
          '${connectTimeout.inSeconds}s. The server may be down, or a '
          'firewall may be dropping the connection.';
    }
    if (s.contains('refused')) {
      return 'Connection refused by ${host.host}:${host.port}. Nothing is '
          'listening on that port.';
    }
    if (s.contains('failed host lookup') || s.contains('nodename')) {
      return 'Cannot resolve ${host.host}. Check the name, or your network.';
    }
    if (s.contains('network is unreachable') || s.contains('no route')) {
      return 'Network unreachable. Check the phone is online.';
    }
    return 'Could not connect to ${host.host}:${host.port}.';
  }

  /// Post-handshake failures. Password and username are the overwhelmingly
  /// common causes, so they are named rather than left to a generic message.
  String _authMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('auth')) {
      return host.user.isEmpty
          ? 'Authentication failed. This host has no username saved.'
          : 'Authentication failed for ${host.user}. Wrong password, or the '
              'server does not allow password login.';
    }
    if (s.contains('closed') || s.contains('reset')) {
      return 'The server closed the connection during the handshake.';
    }
    return 'SSH failed: $e';
  }
}
