import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/server_api.g.dart';
import '../../bridge/server_bridge.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_sheet.dart';

/// SETTING UP A MACHINE THE USER OWNS.
///
/// ─── IT TESTS BEFORE IT SAVES ────────────────────────────────────────────────
///
/// A saved server that has never been reached is worse than no server: it
/// reports itself as configured and then fails at 2am. Save is only offered
/// after a probe that both signed in AND wrote a file, because a share that
/// authenticates and refuses writes is the commonest misconfiguration there is.
///
/// ─── THE PASSWORD IS NEVER READ BACK ─────────────────────────────────────────
///
/// Editing a saved server leaves the field empty, and an empty field means keep
/// the stored one. Nothing in Dart can retrieve a password, so no screen can
/// show one and no log can print one.
///
/// ─── TWO FORMS, ONE PAGE, AND ALMOST NO SHARED FIELDS ────────────────────────
///
/// SMB wants a host, a share and a port. WebDAV wants a URL. Only the user
/// name, password and folder are common to both, which is why the protocol is
/// chosen before this screen opens rather than toggled inside it: a single form
/// with a switch would be mostly empty whichever way it was set.
class ServerSetupPage extends ConsumerStatefulWidget {
  const ServerSetupPage({super.key, this.existing, this.protocol = 'smb'});

  final ServerConfig? existing;

  /// Only consulted when [existing] is null. A saved server keeps its own.
  final String protocol;

  static Route<void> route({ServerConfig? existing, String protocol = 'smb'}) =>
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ServerSetupPage(existing: existing, protocol: protocol),
      );

  @override
  ConsumerState<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends ConsumerState<ServerSetupPage> {
  late final TextEditingController _host;
  late final TextEditingController _share;
  late final TextEditingController _port;
  late final TextEditingController _address;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _path;

  bool _encrypt = false;
  bool _busy = false;
  ServerProbe? _probe;

  /// What the address field currently means. Null while it is unusable.
  DavAddress? _parsed;

  /// Set only when the user has looked at a fingerprint and accepted it.
  String? _certPin;

  String get _protocol => widget.existing?.protocol ?? widget.protocol;

  bool get _isDav => _protocol == 'webdav';

  @override
  void initState() {
    super.initState();
    final ServerConfig? existing = widget.existing;

    _host = TextEditingController(text: existing?.host ?? '');
    _share = TextEditingController(text: existing?.share ?? '');
    _port = TextEditingController(text: '${existing?.port ?? 445}');
    _user = TextEditingController(text: existing?.username ?? '');
    // Empty on purpose, even when editing. See the class note.
    _password = TextEditingController();
    _path = TextEditingController(
      text: existing?.remotePath ?? (_isDav ? 'Backups/Phone' : '/GRecovery'),
    );
    _encrypt = existing?.encrypt ?? false;
    _certPin = existing?.certPin;

    // Rebuilt from the pieces rather than stored whole, so what the user sees
    // when editing is the address the app will actually use, not the text they
    // once typed.
    final String rebuilt = existing == null || existing.protocol != 'webdav'
        ? ''
        : DavAddress(
            host: existing.host,
            port: existing.port,
            basePath: existing.basePath ?? '',
            secure: existing.secure ?? true,
          ).text;
    _address = TextEditingController(text: rebuilt);
    _parsed = DavAddress.parse(rebuilt);
  }

  @override
  void dispose() {
    _host.dispose();
    _share.dispose();
    _port.dispose();
    _address.dispose();
    _user.dispose();
    _password.dispose();
    _path.dispose();
    super.dispose();
  }

  ServerConfig get _config {
    final ServerConfig? existing = widget.existing;
    final String folder = _path.text.trim();

    if (_isDav) {
      final DavAddress? parsed = _parsed;
      return ServerConfig(
        id: existing?.id ?? 'server',
        protocol: 'webdav',
        label: parsed?.host ?? '',
        host: parsed?.host ?? '',
        port: parsed?.port ?? 443,
        // WebDAV has no share. Null rather than empty, so nothing downstream
        // has to decide whether a blank string meant anything.
        share: null,
        username: _user.text.trim(),
        remotePath: folder.isEmpty ? 'Backups/Phone' : folder,
        encrypt: _encrypt,
        wifiOnly: existing?.wifiOnly ?? true,
        whileCharging: existing?.whileCharging ?? true,
        scheduled: existing?.scheduled ?? false,
        secure: parsed?.secure ?? true,
        basePath: parsed?.basePath,
        certPin: _certPin,
      );
    }

    return ServerConfig(
      id: existing?.id ?? 'server',
      protocol: 'smb',
      label: _host.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 445,
      share: _share.text.trim().isEmpty ? null : _share.text.trim(),
      username: _user.text.trim(),
      remotePath: folder.isEmpty ? '/GRecovery' : folder,
      encrypt: _encrypt,
      wifiOnly: existing?.wifiOnly ?? true,
      whileCharging: existing?.whileCharging ?? true,
      scheduled: existing?.scheduled ?? false,
    );
  }

  /// Enough typed in to be worth asking the server about.
  bool get _fillable => _isDav ? _parsed != null : _host.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final ServerProbe? probe = _probe;
    final bool ready = probe != null && probe.reachable && probe.writable;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: _isDav ? 'WebDAV server' : 'Network drive',
              subtitle: _isDav
                  ? 'Nextcloud, ownCloud, Synology'
                  : 'SMB2 and SMB3',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            if (_isDav) ..._davFields(t) else ..._smbFields(),

            _Field(label: 'Username', controller: _user, hint: 'karani'),
            _Field(
              label: widget.existing == null
                  ? 'Password'
                  : 'Password, leave empty to keep the saved one',
              controller: _password,
              hint: '',
              secret: true,
            ),
            if (_isDav)
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.md),
                child: Text(
                  // The single most valuable sentence on this screen. An
                  // account with two-step sign in will refuse the real password
                  // every time, and without saying so it reads as a broken app
                  // rather than a server rule.
                  'If your account uses two-step sign in, your normal password '
                  'will be refused. Create an app password on the server and '
                  'paste that instead.',
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ),

            _Field(
              label: 'Folder on the server',
              controller: _path,
              hint: _isDav ? 'Backups/Phone' : '/GRecovery',
            ),

            if (probe != null) ...<Widget>[
              const SizedBox(height: GSpace.sm),
              _Result(
                probe: probe,
                onTrust: probe.certFingerprint == null ? null : _trust,
              ),
            ],

            const SizedBox(height: GSpace.md),
            GButton(
              label: ready ? 'Save' : 'Test connection',
              icon: ready ? Icons.check_rounded : Icons.wifi_tethering_rounded,
              onPressed: _busy || !_fillable
                  ? null
                  : () => ready ? _save() : _test(),
            ),

            const SizedBox(height: GSpace.lg),
            GCard(
              onTap: () => _explainSecurity(context),
              child: Row(
                children: <Widget>[
                  Icon(Icons.lock_outline_rounded, size: 19, color: t.docs),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Where the password goes',
                          style: GType.heading.copyWith(color: t.text),
                        ),
                        Text(
                          'Encrypted on this phone, sent only to your server',
                          style: GType.micro.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
                ],
              ),
            ),

            const SizedBox(height: GSpace.sm + 1),
            GCard(
              onTap: () => setState(() => _encrypt = !_encrypt),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Encrypt the files',
                          style: GType.heading.copyWith(color: t.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          // The trade-off, stated on the switch rather than
                          // buried. Off by default because the point of a home
                          // server is that the files stay yours and openable.
                          _encrypt
                              ? 'Only this app will be able to open them. Right '
                                    'for a server you do not fully control.'
                              : 'Files stay readable on your server, so any '
                                    'app on your computer can open them.',
                          style: GType.micro.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: GSpace.md),
                  _Switch(on: _encrypt),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // The two forms
  // ───────────────────────────────────────────────────────────────────────────

  List<Widget> _smbFields() => <Widget>[
    _Field(label: 'Address', controller: _host, hint: '192.168.1.40'),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Field(
            label: 'Share',
            controller: _share,
            hint: 'phone-backup',
          ),
        ),
        const SizedBox(width: GSpace.sm + 1),
        SizedBox(
          width: 92,
          child: _Field(
            label: 'Port',
            controller: _port,
            hint: '445',
            numeric: true,
          ),
        ),
      ],
    ),
  ];

  /// One address field, and what the app made of it shown underneath.
  ///
  /// ─── ONE FIELD, NOT THREE ────────────────────────────────────────────────
  ///
  /// Nextcloud, ownCloud and Synology all hand the user a complete WebDAV
  /// address to copy. Asking for host, port and path separately would mean the
  /// user parsing their own URL by eye and retyping it in pieces, which is work
  /// a machine does perfectly and a person does wrong at least once.
  ///
  /// The parse is shown rather than trusted silently, because a mistyped DAV
  /// root would otherwise surface as an unexplained network error at the end of
  /// a connection test instead of as a visibly wrong path before it starts.
  List<Widget> _davFields(GTokens t) {
    final DavAddress? parsed = _parsed;
    final bool typed = _address.text.trim().isNotEmpty;

    return <Widget>[
      _Field(
        label: 'Server address',
        controller: _address,
        hint: 'https://cloud.example.com/remote.php/dav/files/you/',
        onChanged: (String value) => setState(() {
          _parsed = DavAddress.parse(value);
          _probe = null;
          // A pin belongs to one certificate on one host. Carrying it across an
          // edit of the address is how a fingerprint checked against one server
          // ends up silently trusted for another.
          _certPin = null;
        }),
      ),

      if (parsed == null)
        Padding(
          padding: const EdgeInsets.only(bottom: GSpace.md),
          child: Text(
            typed
                ? 'That does not look like a web address yet.'
                : 'Copy this from the WebDAV section of your server settings. '
                      'It usually ends with your user name.',
            style: GType.micro.copyWith(color: typed ? t.warning : t.dim),
          ),
        )
      else ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: GSpace.md),
          child: GCard(
            padding: const EdgeInsets.symmetric(
              horizontal: GSpace.md,
              vertical: GSpace.sm,
            ),
            child: Column(
              children: <Widget>[
                _Parsed(label: 'Host', value: parsed.host),
                _Parsed(label: 'Port', value: '${parsed.port}'),
                _Parsed(
                  label: 'Path',
                  value: parsed.basePath.isEmpty ? '/' : parsed.basePath,
                ),
                _Parsed(
                  label: 'Connection',
                  value: parsed.secure ? 'Encrypted' : 'Not encrypted',
                  tone: parsed.secure ? null : t.warning,
                  last: true,
                ),
              ],
            ),
          ),
        ),
        if (!parsed.secure)
          Padding(
            padding: const EdgeInsets.only(bottom: GSpace.md),
            child: Text(
              // Said plainly rather than blocked. Plain HTTP to a box on the
              // same desk is a defensible choice; not knowing it is happening
              // is not.
              'This address is plain http, so your password and your files '
              'cross the network unprotected. Use https unless the server is '
              'on your own network.',
              style: GType.micro.copyWith(color: t.warning),
            ),
          ),
        if (_certPin != null)
          Padding(
            padding: const EdgeInsets.only(bottom: GSpace.md),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_user_outlined, size: 15, color: t.success),
                const SizedBox(width: GSpace.sm),
                Expanded(
                  child: Text(
                    'You have trusted this server\u0027s own certificate.',
                    style: GType.micro.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    ];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _probe = null;
    });
    final ServerProbe? probe = await ref
        .read(serverBridgeProvider)
        .test(_config, password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _probe = probe;
    });
  }

  /// Accepts one certificate, by fingerprint, and immediately tries again.
  ///
  /// The retry is the point. Pinning without reconnecting would leave the user
  /// looking at the same failure card wondering whether the button did
  /// anything.
  Future<void> _trust() async {
    final String? fingerprint = _probe?.certFingerprint;
    if (fingerprint == null) return;
    setState(() => _certPin = fingerprint);
    await _test();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref
        .read(serverBridgeProvider)
        .save(_config, password: _password.text);
    ref.invalidate(serverConfigProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _explainSecurity(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: 'Where the password goes',
      children: <Widget>[
        GSheetPoint(
          icon: Icons.phone_android_rounded,
          tone: t.docs,
          text:
              'It is encrypted by this phone\u0027s own hardware keystore and '
              'kept on the device. No other app can read it, and neither can we.',
        ),
        GSheetPoint(
          icon: Icons.send_rounded,
          tone: t.docs,
          text:
              'It is sent to one place only: the address you typed above. '
              'There is no account and no server of ours in between.',
        ),
        GSheetPoint(
          icon: Icons.key_off_rounded,
          text:
              'Changing your screen lock can destroy the key that protects '
              'it. If that happens the app asks you to type it again rather '
              'than failing quietly every night.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The address
// ─────────────────────────────────────────────────────────────────────────────

/// A WebDAV address, broken into the pieces the native layer needs.
///
/// Parsed in Dart rather than in Kotlin so the result can be shown on screen
/// while it is being typed. A parse that only happened on the other side of the
/// bridge would mean the user learning their path was wrong from a failed
/// connection rather than from looking at it.
@immutable
class DavAddress {
  const DavAddress({
    required this.host,
    required this.port,
    required this.basePath,
    required this.secure,
  });

  /// Null when there is not enough here to be an address.
  ///
  /// Lenient about the scheme, because someone copying from a browser bar gets
  /// one and someone typing from memory does not, and https is the right
  /// assumption for the missing case.
  static DavAddress? parse(String input) {
    final String raw = input.trim();
    if (raw.isEmpty) return null;

    final String withScheme = raw.contains('://') ? raw : 'https://$raw';

    final Uri? uri = Uri.tryParse(withScheme);
    if (uri == null) return null;
    if (uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final bool secure = uri.scheme == 'https';

    return DavAddress(
      host: uri.host,
      // Uri.port returns the scheme default when none was given, which is
      // exactly what is wanted here and is worth not second guessing.
      port: uri.hasPort ? uri.port : (secure ? 443 : 80),
      basePath: _tidy(uri.path),
      secure: secure,
    );
  }

  final String host;
  final int port;

  /// The DAV root, with no leading or trailing slash. Empty is legitimate: some
  /// servers put WebDAV at the domain root.
  final String basePath;

  final bool secure;

  /// The address written back out, for a field the user is editing.
  String get text {
    final String scheme = secure ? 'https' : 'http';
    final bool defaultPort = (secure && port == 443) || (!secure && port == 80);
    final String authority = defaultPort ? host : '$host:$port';
    return basePath.isEmpty
        ? '$scheme://$authority/'
        : '$scheme://$authority/$basePath/';
  }

  static String _tidy(String path) {
    final String trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    return trimmed.split('/').where((String s) => s.isNotEmpty).join('/');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The result
// ─────────────────────────────────────────────────────────────────────────────

/// Which outcome a probe describes.
///
/// Read from [ServerProbe.code] rather than from the wording of
/// [ServerProbe.detail], because one of these needs a button and matching on
/// English would break the day these strings are translated.
enum _Outcome { connected, auth, cert, notDav, path, network }

_Outcome _outcomeOf(ServerProbe probe) {
  if (probe.reachable && probe.writable) return _Outcome.connected;
  switch (probe.code) {
    case 'auth':
      return _Outcome.auth;
    case 'cert':
      return _Outcome.cert;
    case 'not_dav':
      return _Outcome.notDav;
    case 'path':
      return _Outcome.path;
    case 'network':
      return _Outcome.network;
    default:
      // An unrecognised code, or none at all from the SMB path. Both fall back
      // to showing detail, which is a sentence either way.
      return probe.reachable ? _Outcome.path : _Outcome.network;
  }
}

/// The probe result, in words rather than a code.
class _Result extends StatelessWidget {
  const _Result({required this.probe, this.onTrust});

  final ServerProbe probe;

  /// Offered only for an untrusted certificate, the one failure on this screen
  /// the user can resolve without leaving it.
  final VoidCallback? onTrust;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final _Outcome outcome = _outcomeOf(probe);

    final Color hue;
    final IconData glyph;
    final String title;
    switch (outcome) {
      case _Outcome.connected:
        hue = t.success;
        glyph = Icons.check_circle_outline_rounded;
        title = 'Ready to back up';
      case _Outcome.auth:
        hue = t.danger;
        glyph = Icons.person_off_outlined;
        title = 'Sign in failed';
      case _Outcome.cert:
        hue = t.warning;
        glyph = Icons.gpp_maybe_outlined;
        title = 'No one vouches for this server';
      case _Outcome.notDav:
        hue = t.danger;
        glyph = Icons.wrong_location_outlined;
        title = 'That address is not WebDAV';
      case _Outcome.path:
        hue = t.warning;
        glyph = Icons.folder_off_outlined;
        title = 'The folder would not take a file';
      case _Outcome.network:
        hue = t.danger;
        glyph = Icons.cloud_off_outlined;
        title = 'Could not reach the server';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.13),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(glyph, size: 19, color: hue),
                const SizedBox(width: GSpace.md - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: GType.heading.copyWith(color: hue)),
                      const SizedBox(height: 2),
                      Text(
                        outcome == _Outcome.connected
                            ? 'Signed in, and the folder accepts files.'
                            : probe.detail,
                        style: GType.bodySmall.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (outcome == _Outcome.connected) ...<Widget>[
              // Nullable stats render as absent rows, never as a dash. A server
              // that reports no quota has not told us zero.
              if (probe.freeBytes != null)
                _Detail(
                  label: 'Free on server',
                  value: GFormat.bytes(probe.freeBytes!),
                ),
              if (probe.serverName != null)
                _Detail(label: 'Server', value: probe.serverName!),
            ],

            if (outcome == _Outcome.cert &&
                probe.certFingerprint != null) ...<Widget>[
              const SizedBox(height: GSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.md,
                  vertical: GSpace.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: t.ink,
                  borderRadius: GRadius.all(GRadius.tile),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SHA-256',
                      style: GType.overline.copyWith(color: t.dim),
                    ),
                    const SizedBox(height: GSpace.xs + 1),
                    Text(
                      _grouped(probe.certFingerprint!),
                      style: GType.monoSmall.copyWith(
                        color: t.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GSpace.sm + 2),
              Text(
                // Names the check rather than assuming it. A fingerprint nobody
                // compares is a trust-all switch with extra steps.
                'Run openssl x509 -fingerprint -sha256 on your server, or read '
                'it from your server\u0027s admin page, and make sure it matches.',
                style: GType.micro.copyWith(color: t.dim),
              ),
              const SizedBox(height: GSpace.md),
              GButton(
                label: 'Trust this certificate',
                icon: Icons.verified_user_outlined,
                onPressed: onTrust,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hex in byte pairs, ten to a line, the way every tool prints it.
  static String _grouped(String hex) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i + 1 < hex.length; i += 2) {
      if (i > 0) out.write(i % 20 == 0 ? '\n' : ':');
      out.write(hex.substring(i, i + 2).toUpperCase());
    }
    return out.toString();
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(top: GSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: GType.micro.copyWith(color: t.muted)),
          Text(value, style: GType.monoSmall.copyWith(color: t.text)),
        ],
      ),
    );
  }
}

class _Parsed extends StatelessWidget {
  const _Parsed({
    required this.label,
    required this.value,
    this.tone,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GSpace.sm - 1),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(label, style: GType.micro.copyWith(color: t.dim)),
          ),
          Expanded(
            child: Text(
              value,
              style: GType.monoSmall.copyWith(color: tone ?? t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.secret = false,
    this.numeric = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool secret;
  final bool numeric;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: GType.micro.copyWith(color: t.muted)),
          const SizedBox(height: GSpace.xs + 1),
          TextField(
            controller: controller,
            obscureText: secret,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            onChanged: onChanged,
            // No autocorrect anywhere on this screen. A hostname is not a word,
            // and a capitalised share name is a failed connection.
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: GType.monoSmall.copyWith(color: t.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GType.monoSmall.copyWith(color: t.dim, fontSize: 13),
              filled: true,
              fillColor: t.panel,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: GSpace.md,
                vertical: GSpace.md - 2,
              ),
              border: OutlineInputBorder(
                borderRadius: GRadius.all(GRadius.tile),
                borderSide: BorderSide(color: t.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: GRadius.all(GRadius.tile),
                borderSide: BorderSide(color: t.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: GRadius.all(GRadius.tile),
                borderSide: BorderSide(color: t.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return AnimatedContainer(
      duration: GMotion.fast,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? t.accent : t.panelAlt,
        borderRadius: GRadius.all(GRadius.chip),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: on ? t.onAccent : t.dim,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
