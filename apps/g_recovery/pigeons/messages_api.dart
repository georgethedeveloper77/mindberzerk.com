import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the message archive bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/messages_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/messages_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/messages/MessagesApi.g.kt
///
/// ─── ITS OWN SCHEMA, ITS OWN PACKAGE ─────────────────────────────────────────
///
/// Not appended to the recovery schema. Pigeon emits a FlutterError class into
/// every generated Kotlin file, so two schemas sharing a package is a
/// redeclaration error, and a separate file also means these codec ids start
/// fresh at 129 without touching a single recovery id.
///
/// ─── WHAT THIS FEATURE HONESTLY IS ───────────────────────────────────────────
///
/// It is NOT reading anyone's messages out of an app. WhatsApp keeps its
/// messages in an encrypted database inside its own private directory, which no
/// app on an unrooted phone can open, and Android gives no second copy of a
/// message that has been deleted.
///
/// What it does is keep the copy Android already handed over. When a message
/// arrives it becomes a notification, and a notification listener is given that
/// text by the system. If the sender later deletes the message, the archive
/// still has what was posted.
///
/// Three consequences the UI has to state plainly rather than bury:
///
///   1. It only works for messages that arrive AFTER the listener is switched
///      on. Nothing before that exists to capture.
///   2. It captures TEXT. A photo notification says "Photo", so a view once
///      image cannot be recovered this way and must never be promised.
///   3. If the user has notifications muted for a chat, nothing is posted and
///      nothing is captured.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/messages_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/messages/MessagesApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.messages'),
    dartPackageName: 'g_recovery',
  ),
)

/// Whether capture is possible and running. Codec 129.
class MessageCapture {
  MessageCapture({
    required this.listenerEnabled,
    required this.capturing,
    required this.messageCount,
    required this.conversationCount,
    required this.since,
  });

  /// Whether notification access has been granted in system settings.
  ///
  /// The only thing standing between off and on. There is no runtime dialog for
  /// this permission: it is a settings screen the user has to visit, which is
  /// why the app has to check it on resume rather than await a result.
  final bool listenerEnabled;

  /// Whether the user has also switched capture on inside this app.
  ///
  /// Separate from [listenerEnabled] on purpose. Granting the system permission
  /// and choosing to archive are two decisions, and collapsing them would mean
  /// a user who granted access for one reason silently starts recording every
  /// message they receive.
  final bool capturing;

  final int messageCount;
  final int conversationCount;

  /// When capture began, epoch milliseconds, or null if it never has.
  ///
  /// The honest edge of the archive. Everything older than this is not missing,
  /// it never existed as far as this app is concerned, and the UI says so
  /// instead of showing an empty list.
  final int? since;
}

/// One captured message. Codec 130.
class ArchivedMessage {
  ArchivedMessage({
    required this.messageId,
    required this.packageName,
    required this.appLabel,
    required this.conversation,
    required this.sender,
    required this.text,
    required this.postedAtMillis,
    required this.removedAtMillis,
    required this.edited,
  });

  final String messageId;

  /// The app that posted it, such as com.whatsapp. Kept raw so a future filter
  /// can group by app without re-deriving it from a display name.
  final String packageName;

  final String appLabel;

  /// The chat or group title as the notification carried it. Null when the
  /// posting app gave no title, which happens on a first message from an
  /// unsaved number.
  final String? conversation;

  final String? sender;

  final String text;

  final int postedAtMillis;

  /// When the notification was taken away, epoch milliseconds, or null while it
  /// is still showing.
  ///
  /// NOT proof of deletion. A notification is removed when the user opens the
  /// chat, swipes it away, or when the sender deletes the message, and the
  /// system does not say which. The UI must not label this "deleted".
  final int? removedAtMillis;

  /// True when a later notification for the same conversation replaced this
  /// text with different text.
  ///
  /// The closest thing to real evidence of a deletion this approach can offer:
  /// WhatsApp replaces the message with "This message was deleted", which
  /// arrives as an update to the same notification, so the ORIGINAL text is
  /// still here and the replacement is what everyone else sees.
  final bool edited;
}

@HostApi()
abstract class MessagesHostApi {
  /// Whether capture is possible, and how much has been kept.
  @async
  MessageCapture captureState();

  /// Opens the system notification access screen.
  ///
  /// Returns whether a screen could be opened at all. Some heavily modified ROMs
  /// hide it, and an app that silently does nothing on those is worse than one
  /// that says it could not get there.
  @async
  bool openListenerSettings();

  /// Turns archiving on or off inside this app.
  ///
  /// Off does not delete what has been kept. Clearing is [clear], deliberately a
  /// separate and explicit act.
  @async
  void setCapturing(bool value);

  /// Newest first. [conversation] null means every chat.
  @async
  List<ArchivedMessage> messages(String? conversation, int limit);

  /// Every conversation seen, newest activity first.
  @async
  List<String> conversations();

  /// Deletes the archive.
  @async
  void clear();
}
