import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the home server bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/server_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/server_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/server/ServerApi.g.kt
///
/// ─── ITS OWN SCHEMA AND PACKAGE ──────────────────────────────────────────────
///
/// Pigeon emits a FlutterError class into every generated Kotlin file, so two
/// schemas in one package is a redeclaration error. Codec ids start fresh at 129
/// and nothing in storage, recovery, messages or compare moves.
///
/// ─── WHAT THIS IS, AND IS NOT ────────────────────────────────────────────────
///
/// A ONE WAY COPY. Files go from the phone to a machine the user owns, and
/// nothing ever comes back on its own. Deleting a file on the server must never
/// delete it on the phone, and this API deliberately has no method that could.
///
/// Sync would need conflict resolution, and a recovery app that removed
/// someone's photos because their NAS was rebuilt would be the worst failure
/// this product could have. That is not a feature waiting to be added; it is a
/// door left shut.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 ServerConfig   130 ServerProbe    131 TransferState
///   132 RemoteFile     133 ReclaimCandidate
///
/// ADD NEW TYPES AT THE END. NO ENUMS, ever: they number before classes.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/server_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/server/ServerApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.server'),
    dartPackageName: 'g_recovery',
  ),
)
/// A server the user has told us about. Codec 129.
///
/// ─── NO PASSWORD FIELD, AND THAT IS DELIBERATE ───────────────────────────────
///
/// The password crosses this bridge exactly once, as an argument to [save], and
/// is never handed back. Native keeps it in EncryptedSharedPreferences and Dart
/// has no way to read it again.
///
/// If it were a field here it would be in every state read, sitting in Dart heap
/// for the life of the app and printable by any careless log line. There is no
/// screen that needs to display it: a password field shows dots, and re-entry is
/// safer than recall.
class ServerConfig {
  ServerConfig({
    required this.id,
    required this.protocol,
    required this.label,
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.remotePath,
    required this.encrypt,
    required this.wifiOnly,
    required this.whileCharging,
    required this.scheduled,
    this.secure,
    this.basePath,
    this.certPin,
  });

  final String id;

  /// "smb" | "sftp" | "webdav"
  ///
  /// A String rather than an enum, matching every other schema here: an enum
  /// numbers before classes and adding a fourth protocol would renumber all
  /// five.
  final String protocol;

  /// What the user calls it. Defaults to the host, because a person with two
  /// servers needs to tell them apart and an IP address does not help.
  final String label;

  final String host;
  final int port;

  /// SMB only. The share name, which SFTP and WebDAV do not have.
  final String? share;

  final String username;

  /// Folder on the server. Everything is written under here.
  final String remotePath;

  /// OFF BY DEFAULT, and free rather than sold.
  ///
  /// The point of a home server is that it is yours: readable photos on your own
  /// NAS can be opened by your desktop, served by Plex, and backed up again by
  /// whatever you already run. Encrypting turns your machine into a blob store
  /// only this app can read, which is the property people dislike about cloud
  /// services.
  ///
  /// It earns its place for a server you do not fully control, such as a VPS,
  /// which is why it is a switch with that reason attached rather than a
  /// default.
  final bool encrypt;

  final bool wifiOnly;
  final bool whileCharging;

  /// Unattended nightly runs. The Pro half of this feature, because it sells
  /// labour rather than capability: connecting, copying and reclaiming all work
  /// free, by hand.
  final bool scheduled;

  // ─── APPENDED FOR WEBDAV. NEW FIELDS GO BELOW THIS LINE, NEVER ABOVE IT ────
  //
  // All three nullable, which is what makes appending safe: Pigeon gives a
  // nullable field `= null` in Kotlin and an optional named parameter in Dart,
  // so every existing construction site still compiles untouched and every SMB
  // server already saved reads back with these absent.

  /// HTTPS rather than plain HTTP. WebDAV only.
  ///
  /// Null means HTTPS, because null is what an SMB record and every server
  /// saved before this field existed will report, and the safe reading of "not
  /// stated" is the encrypted one. Only an explicit false sends credentials in
  /// the clear.
  final bool? secure;

  /// The DAV root, taken from the address the user pasted. WebDAV only.
  ///
  /// Separate from [remotePath] because they answer different questions.
  /// This is where the server's WebDAV endpoint lives and the user copies it
  /// from their server settings; remotePath is the folder they chose inside it
  /// and is theirs to name. Nextcloud gives out
  /// /remote.php/dav/files user, which nobody would type by hand and nobody
  /// should have to keep re-typing when they rename their backup folder.
  final String? basePath;

  /// SHA-256 of a certificate the user chose to trust, in hex. WebDAV only.
  ///
  /// ─── PINNED, NOT TRUSTED BLINDLY ─────────────────────────────────────────
  ///
  /// A self-hosted server usually presents its own certificate, so refusing
  /// outright would rule out most of the servers this feature exists for. The
  /// alternative most apps reach for is a "trust all certificates" switch,
  /// which is one tap and turns HTTPS into an unauthenticated channel for
  /// everything afterwards.
  ///
  /// This holds ONE certificate the user checked once, by fingerprint. Anything
  /// else is still refused, so a network attacker's certificate fails even
  /// though the real server's own certificate passes.
  final String? certPin;
}

/// The result of trying to reach a server. Codec 130.
class ServerProbe {
  ServerProbe({
    required this.reachable,
    required this.writable,
    required this.detail,
    required this.freeBytes,
    this.code,
    this.certFingerprint,
    this.serverName,
  });

  final bool reachable;

  /// Reachable and writable are separate on purpose.
  ///
  /// A share that accepts the login and refuses a write is the commonest
  /// misconfiguration there is, and discovering it at 2am during the first
  /// scheduled run is far too late. The test writes a small file and removes it.
  final bool writable;

  /// Why it failed, in words a person can act on. Empty when it worked.
  ///
  /// Never a raw exception. "Connection refused" tells someone nothing; "nothing
  /// is listening on port 445, check the server is on" tells them what to do.
  final String detail;

  /// Free space on the share, or null where the protocol does not report it.
  final int? freeBytes;

  // ─── APPENDED FOR WEBDAV. NEW FIELDS GO BELOW THIS LINE ───────────────────

  /// Which outcome this is, for the UI to branch on. Null from older code.
  ///
  /// ─── WHY [detail] IS NOT ENOUGH ──────────────────────────────────────────
  ///
  /// detail is a sentence for a person and must stay that way. But one of these
  /// outcomes needs a button the others do not: an untrusted certificate is the
  /// only failure the user can resolve from inside the app, by checking a
  /// fingerprint and pinning it. Deciding that from the text would mean
  /// matching on English, which breaks the moment the string is translated.
  ///
  /// One of: "ok", "auth", "cert", "not_dav", "path", "space", "network".
  /// Anything unrecognised must be treated as a plain failure and shown as
  /// [detail], so a newer native layer can add a code without breaking an
  /// older screen.
  final String? code;

  /// SHA-256 of the certificate that was refused, in hex. Set only with "cert".
  ///
  /// Shown so the user can compare it against their own server before pinning
  /// it. Displaying it is the entire point: a fingerprint nobody checks is a
  /// trust-all switch with extra steps.
  final String? certFingerprint;

  /// What the server calls itself, when it says. Absent rather than guessed.
  final String? serverName;
}

/// How a copy is going. Codec 131.
class TransferState {
  TransferState({
    required this.running,
    required this.sent,
    required this.total,
    required this.bytesSent,
    required this.bytesTotal,
    required this.currentName,
    required this.failed,
    required this.lastRunMillis,
    required this.lastError,
  });

  final bool running;
  final int sent;
  final int total;
  final int bytesSent;
  final int bytesTotal;

  /// What is being copied right now, for the progress line. Null between files.
  final String? currentName;

  /// Files that could not be copied. Reported rather than retried forever: a
  /// file that fails twice is usually one the server will never accept, and a
  /// silent infinite retry is how a backup appears to run all night and achieve
  /// nothing.
  final int failed;

  final int? lastRunMillis;

  /// Null when the last run finished cleanly.
  final String? lastError;
}

/// Something already on the server. Codec 132.
class RemoteFile {
  RemoteFile({
    required this.remotePath,
    required this.name,
    required this.sizeBytes,
    required this.modifiedMillis,
  });

  final String remotePath;
  final String name;
  final int sizeBytes;
  final int modifiedMillis;
}

/// A local file that could be removed because the server has it. Codec 133.
class ReclaimCandidate {
  ReclaimCandidate({
    required this.fileId,
    required this.name,
    required this.sizeBytes,
    required this.verified,
  });

  final String fileId;
  final String name;
  final int sizeBytes;

  /// Whether the copy on the server was checked and matched.
  ///
  /// FALSE MEANS DO NOT TOUCH IT. The reclaim flow removes originals, so a
  /// candidate that has not been verified by size and checksum is offered to
  /// nobody. This is the one place in the app where being wrong destroys
  /// something.
  final bool verified;
}

@HostApi()
abstract class ServerHostApi {
  /// The saved server, or null when none is set up. One at a time, for now.
  @async
  ServerConfig? current();

  /// Tries to reach a server without saving anything.
  ///
  /// [password] is passed for the test and not retained. A person changing a
  /// setting on a saved server should not have to retype it, so an empty
  /// password here means use the stored one.
  @async
  ServerProbe test(ServerConfig config, String password);

  /// Saves, after a successful test. An empty [password] keeps the stored one.
  @async
  void save(ServerConfig config, String password);

  /// Forgets the server and its password. Nothing on the server is touched.
  @async
  void forget();

  /// Turns the nightly run on or off.
  ///
  /// ─── SEPARATE FROM save, DELIBERATELY ────────────────────────────────────
  ///
  /// Saving a config writes settings. This schedules or cancels actual work in
  /// the system, and folding it into save would mean every edit to a port
  /// number silently re-queued a job.
  @async
  void setSchedule(bool enabled);

  /// When the next run is due, or null when nothing is scheduled.
  ///
  /// From WorkManager rather than computed, so a phone that has deferred the
  /// job for battery reasons reports what will actually happen rather than what
  /// was asked for.
  @async
  int? nextRunMillis();

  /// Starts a copy. Returns at once; watch [transferState].
  @async
  void startBackup();

  @async
  void cancelBackup();

  @async
  TransferState transferState();

  /// Checks the chosen files byte for byte before they are removed.
  ///
  /// ─── SEPARATE FROM [reclaimable], AND THAT IS THE POINT ──────────────────
  ///
  /// The listing compares sizes, which is cheap enough to run over a whole
  /// library and catches a file that was truncated or replaced. It does not
  /// catch a file of the same length whose contents differ, which is exactly
  /// the case where deleting the local copy loses something.
  ///
  /// So the hash runs only on what the user actually selected: reading both
  /// sides of four thousand files to answer a question about the twelve they
  /// chose would take minutes and achieve nothing.
  ///
  /// Returns the ids that MATCHED. Anything missing from the result failed and
  /// must not be touched.
  @async
  List<String> verify(List<String> fileIds);

  /// Local files whose copy on the server has been verified.
  ///
  /// Verification is size and checksum, done here rather than trusted from the
  /// upload, because the interesting failure is a file that uploaded months ago
  /// and has since been moved or truncated.
  @async
  List<ReclaimCandidate> reclaimable(int limit);
}
