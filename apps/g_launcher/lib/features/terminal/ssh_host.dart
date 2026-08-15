/// A host you can reach, and the key you saw it present.
///
/// ─── NO PASSWORDS HERE, AND NOT AS A SIMPLIFICATION ─────────────────────────
///
/// A saved password on a phone is a credential at rest, and the only honest
/// place for one is behind the keystore with a biometric. That work belongs
/// with the key manager, where the same machinery serves both. Until then the
/// password is asked for on every connect and held only for the life of the
/// connection.
///
/// Prompting every time is worse ergonomics and better security, and for a
/// credential that opens a server it is the right side of that trade to be on
/// while the storage is still being built.
///
/// ─── THE FINGERPRINT IS STORED, NOT COMPUTED ────────────────────────────────
///
/// [KnownHost] holds a fingerprint STRING it was handed. Computing one means
/// hashing the wire-format key, which belongs where the key bytes actually
/// arrive rather than in a model, and keeping the hash out of here means this
/// file needs no crypto dependency and stays testable as plain Dart.
library;

/// One saved host.
class SshHost {
  const SshHost({
    required this.alias,
    required this.user,
    required this.host,
    this.port = defaultPort,
  });

  static const int defaultPort = 22;

  /// What you type instead of the whole target. Unique, lowercase.
  final String alias;

  final String user;

  /// Hostname or address. Not resolved here; a name that does not resolve is a
  /// connection failure, not a validation failure, and refusing to SAVE one
  /// would make a host unaddable while its DNS was down.
  final String host;

  final int port;

  /// `user@host` or `user@host:port`, the form a person recognises.
  ///
  /// The port is shown only when it is not 22, because a target reading
  /// `g@example.com:22` looks like something was configured when nothing was.
  String get target =>
      port == defaultPort ? '$user@$host' : '$user@$host:$port';

  /// Parse `user@host`, `user@host:port`, or a bare `host`.
  ///
  /// Null when there is nothing usable. Deliberately permissive about the host
  /// itself: an IPv4 address, a name, and a Tailscale magic-DNS name are all
  /// legitimate, and a regex tight enough to reject a typo would reject one of
  /// those too.
  ///
  /// IPv6 in brackets is NOT parsed, and that absence is deliberate rather than
  /// forgotten: `[::1]:22` needs its own grammar, and a half-implementation
  /// that silently mangled an address into a hostname would fail at connect
  /// time with a DNS error naming a string the user never typed.
  static SshHost? parseTarget(String raw, {String? alias}) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('[') || s.contains(']')) return null;

    var user = '';
    var rest = s;

    final at = s.lastIndexOf('@');
    if (at >= 0) {
      user = s.substring(0, at).trim();
      rest = s.substring(at + 1).trim();
      if (user.isEmpty) return null;
    }

    var host = rest;
    var port = defaultPort;

    final colon = rest.lastIndexOf(':');
    if (colon >= 0) {
      host = rest.substring(0, colon).trim();
      final p = int.tryParse(rest.substring(colon + 1).trim());
      // A colon with no valid port is a typo, not a hostname containing a
      // colon. Refusing beats connecting to port 22 of something that was
      // meant to be port 2222.
      if (p == null || p < 1 || p > 65535) return null;
      port = p;
    }

    if (host.isEmpty) return null;
    if (host.contains('/') || host.contains(' ')) return null;

    return SshHost(
      alias: (alias ?? host).trim().toLowerCase(),
      user: user,
      host: host,
      port: port,
    );
  }

  /// Is this alias usable as one?
  ///
  /// Lowercase, starting with a letter, no spaces. Kept tight because an alias
  /// is TYPED AT A PROMPT: one that needed quoting would be an alias nobody
  /// uses, and one that collided with a command name would silently never run.
  static bool isValidAlias(String alias) =>
      RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(alias);

  SshHost copyWith({String? alias, String? user, String? host, int? port}) =>
      SshHost(
        alias: alias ?? this.alias,
        user: user ?? this.user,
        host: host ?? this.host,
        port: port ?? this.port,
      );

  Map<String, Object?> toJson() => {
        'alias': alias,
        'user': user,
        'host': host,
        'port': port,
      };

  /// Null for anything unusable, so one corrupt row cannot take the list with
  /// it. The same tolerance the theme layer parses under, for the same reason:
  /// a person with three good hosts and one bad row should lose one row.
  static SshHost? fromJson(Map<String, Object?> j) {
    final alias = (j['alias'] as String?)?.trim().toLowerCase();
    final host = (j['host'] as String?)?.trim();
    if (alias == null || alias.isEmpty) return null;
    if (host == null || host.isEmpty) return null;

    final port = (j['port'] as num?)?.toInt() ?? defaultPort;
    return SshHost(
      alias: alias,
      user: (j['user'] as String?)?.trim() ?? '',
      host: host,
      port: port < 1 || port > 65535 ? defaultPort : port,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SshHost &&
      other.alias == alias &&
      other.user == user &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(alias, user, host, port);

  @override
  String toString() => 'SshHost($alias -> $target)';
}

/// The key a host presented, remembered.
///
/// ─── TRUST ON FIRST USE, AND WHY IT IS NOT OPTIONAL ─────────────────────────
///
/// An SSH client that accepts whatever key it is handed has no protection
/// against a machine in the middle: the attacker terminates the connection,
/// presents their own key, and reads the password in clear. Every real client
/// pins the key on first connect and refuses loudly when it changes, and a
/// client that skips this is not a secure client with a missing feature, it is
/// an insecure one.
///
/// First connect asks the person to confirm a fingerprint, exactly as OpenSSH
/// does. Every connect after that compares, and a mismatch REFUSES rather than
/// prompting: the one time it matters, a prompt is a button someone taps to
/// make the error go away.
class KnownHost {
  const KnownHost({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.acceptedAt,
  });

  /// Keyed by host and port, NOT by alias. Two aliases for one machine are the
  /// same machine, and re-confirming its key because you renamed a bookmark
  /// would teach people to tap through the one prompt that matters.
  final String host;
  final int port;

  /// `ssh-ed25519`, `ecdsa-sha2-nistp256`, and so on. Stored because a host
  /// legitimately offers several, and a change of TYPE is not a change of key.
  final String keyType;

  /// The OpenSSH form, `SHA256:` followed by unpadded base64. Handed in, never
  /// computed here.
  final String fingerprint;

  final DateTime acceptedAt;

  String get id => '$host:$port';

  /// Same machine, same key?
  ///
  /// A different TYPE from the same host is not a mismatch, it is the host
  /// offering another algorithm, so it is reported separately by the caller.
  bool matches(String keyType, String fingerprint) =>
      this.keyType == keyType && this.fingerprint == fingerprint;

  Map<String, Object?> toJson() => {
        'host': host,
        'port': port,
        'keyType': keyType,
        'fingerprint': fingerprint,
        'acceptedAt': acceptedAt.toUtc().toIso8601String(),
      };

  static KnownHost? fromJson(Map<String, Object?> j) {
    final host = (j['host'] as String?)?.trim();
    final keyType = (j['keyType'] as String?)?.trim();
    final fp = (j['fingerprint'] as String?)?.trim();
    if (host == null || host.isEmpty) return null;
    if (keyType == null || keyType.isEmpty) return null;
    if (fp == null || fp.isEmpty) return null;

    return KnownHost(
      host: host,
      port: (j['port'] as num?)?.toInt() ?? SshHost.defaultPort,
      keyType: keyType,
      fingerprint: fp,
      // An unparseable timestamp becomes now rather than dropping the row. The
      // date is for display; the fingerprint is the security-bearing field, and
      // discarding a pinned key over a bad date would silently downgrade a
      // known host to an unknown one.
      acceptedAt: DateTime.tryParse(j['acceptedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KnownHost &&
      other.host == host &&
      other.port == port &&
      other.keyType == keyType &&
      other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(host, port, keyType, fingerprint);
}

/// The verdict for a key a host just presented, given whatever was pinned.
///
/// A pure function rather than a method on the store, because this is the check
/// that decides whether a password is handed to a machine in the middle, and it
/// should be testable without a container, a network or Play.
HostKeyVerdict verdictFor(
  KnownHost? pinned, {
  required String keyType,
  required String fingerprint,
}) {
  if (pinned == null) return HostKeyVerdict.unknown;
  if (pinned.matches(keyType, fingerprint)) return HostKeyVerdict.trusted;
  // Same algorithm, different key: the dangerous one. A different algorithm
  // from the same host is the host offering another of its keys, which is
  // normal and still worth asking about.
  return pinned.keyType == keyType
      ? HostKeyVerdict.mismatch
      : HostKeyVerdict.newAlgorithm;
}

/// What a host key check concluded.
enum HostKeyVerdict {
  /// Never seen. Ask the person to confirm the fingerprint.
  unknown,

  /// Seen, and identical. Connect.
  trusted,

  /// Seen this host offer a DIFFERENT algorithm before. Not an attack, and not
  /// automatically safe either, so it is asked about rather than assumed.
  newAlgorithm,

  /// Same algorithm, DIFFERENT key. Refuse.
  ///
  /// The server may have been rebuilt, or something is impersonating it, and
  /// from the client's position those are indistinguishable. The only safe
  /// response is to stop and make the person remove the pin deliberately.
  mismatch,
}
