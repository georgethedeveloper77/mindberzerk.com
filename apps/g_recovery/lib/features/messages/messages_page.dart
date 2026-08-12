import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/messages_api.g.dart';
import '../../core/date_groups.dart';
import '../../core/format.dart';
import '../../ui/art/escape_art.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_group_header.dart';
import 'state/messages_providers.dart';

/// THE MESSAGE ARCHIVE.
///
/// This page used to open with six paragraphs and a bulleted list of everything
/// the feature could not do. All of it was true and none of it belonged on the
/// first screen: a wall of caveats before a person understands what they are
/// looking at reads as an apology, not as honesty.
///
/// The limits have not been softened, only moved. They are one tap away behind
/// the info icon, in a sheet, in the same words. What is left on the page is the
/// art, one sentence, and the button.
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const MessagesPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final MessageCapture? capture = ref.watch(messageCaptureProvider).value;
    final List<ArchivedMessage> messages =
        ref.watch(archivedMessagesProvider).value ?? const <ArchivedMessage>[];

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: 'Messages',
                subtitle: capture == null || capture.messageCount == 0
                    ? null
                    : '${GFormat.count(capture.messageCount)} kept from '
                          '${GFormat.count(capture.conversationCount)} chats',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  if (messages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: GSpace.sm),
                      child: GIconButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => _confirmClear(context, ref),
                      ),
                    ),
                  GIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _showLimits(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? _Intro(capture: capture)
                  : _Archive(messages: messages, capture: capture),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final GTokens t = context.g;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: GRadius.all(GRadius.card)),
        title: Text(
          'Delete the archive',
          style: GType.title.copyWith(color: t.text),
        ),
        content: Text(
          'Everything kept so far leaves this phone for good. Capture stays on, '
          'so new messages begin a fresh archive.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep', style: GType.label.copyWith(color: t.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: GType.label.copyWith(color: t.danger)),
          ),
        ],
      ),
    );

    if (go != true) return;
    await ref.read(messagesBridgeProvider).clear();
    ref.invalidate(archivedMessagesProvider);
    ref.invalidate(messageCaptureProvider);
  }

  /// The limits, in full, one tap away.
  ///
  /// Nothing here is shorter or gentler than the version that used to sit on the
  /// page. A sheet is not a place to hide something; it is a place to put
  /// something that is essential to understand and unhelpful to read first.
  void _showLimits(BuildContext context) {
    final GTokens t = context.g;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            GSpace.md,
            GSpace.gutter,
            GSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: GRadius.all(2),
                  ),
                ),
              ),
              const SizedBox(height: GSpace.lg),
              Text(
                'How this works',
                style: GType.title.copyWith(color: t.text),
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                'Android hands every arriving message to this app as a '
                'notification. G Recovery writes that text down. If the sender '
                'deletes the message afterwards, your copy is still here.',
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
              const SizedBox(height: GSpace.lg),
              Text(
                'What it cannot do',
                style: GType.heading.copyWith(color: t.text),
              ),
              const SizedBox(height: GSpace.sm),
              const _Limit(
                text:
                    'Nothing from before you switch it on. No copy of those '
                    'messages exists anywhere for this app to find.',
              ),
              const _Limit(
                text:
                    'Text only. A photo arrives as the word Photo, so a view '
                    'once image cannot be kept this way.',
              ),
              const _Limit(
                text:
                    'Nothing from a muted chat, because a muted chat posts no '
                    'notification at all.',
              ),
              const SizedBox(height: GSpace.md),
              Text(
                'Messaging apps only',
                style: GType.heading.copyWith(color: t.text),
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                'WhatsApp, Telegram, Instagram, Messenger and Messages. Every '
                'other notification, including bank alerts and sign in codes, '
                'is discarded before it is written down.',
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Art, one sentence, one button.
class _Intro extends ConsumerWidget {
  const _Intro({required this.capture});

  final MessageCapture? capture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final bool listener = capture?.listenerEnabled ?? false;
    final bool capturing = capture?.capturing ?? false;
    final bool running = listener && capturing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          EscapeArt(height: 230, shape: EscapeShape.messages),
          const SizedBox(height: GSpace.lg),
          Text(
            running
                ? 'Listening.\nNothing yet'
                : 'Keep what was sent,\neven if it is taken back',
            style: GType.display.copyWith(color: t.text),
          ),
          const SizedBox(height: GSpace.md),
          Text(
            running
                ? 'The next message to arrive will be kept here, even if it is '
                      'deleted afterwards.'
                : 'A deleted message is already on your phone, in the '
                      'notification that announced it.',
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
          const Spacer(),

          if (!listener)
            GButton(
              label: 'Allow notification access',
              onPressed: () async {
                await ref.read(messagesBridgeProvider).openListenerSettings();
                ref.invalidate(messageCaptureProvider);
              },
            )
          else
            GButton(
              label: capturing
                  ? 'Stop keeping messages'
                  : 'Start keeping messages',
              kind: capturing ? GButtonKind.danger : GButtonKind.primary,
              onPressed: () async {
                await ref
                    .read(messagesBridgeProvider)
                    .setCapturing(value: !capturing);
                ref.invalidate(messageCaptureProvider);
              },
            ),

          const SizedBox(height: GSpace.lg),
        ],
      ),
    );
  }
}

class _Limit extends StatelessWidget {
  const _Limit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.remove_rounded, size: 15, color: t.warning),
          ),
          const SizedBox(width: GSpace.sm + 1),
          Expanded(
            child: Text(text, style: GType.bodySmall.copyWith(color: t.muted)),
          ),
        ],
      ),
    );
  }
}

/// The archive, with a chart of when it filled up.
class _Archive extends StatelessWidget {
  const _Archive({required this.messages, required this.capture});

  final List<ArchivedMessage> messages;
  final MessageCapture? capture;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    // The same grouping the recovery grid uses, over a different item. Messages
    // have no size, so every group total would read 0 B and the header takes
    // the count alone.
    final List<DateGroup<ArchivedMessage>> groups =
        groupByDate<ArchivedMessage>(
          messages,
          dateOf: (ArchivedMessage m) => m.postedAtMillis,
          sizeOf: (ArchivedMessage m) => 0,
        );

    final int deleted = messages.where((ArchivedMessage m) => m.edited).length;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.gutter,
              0,
              GSpace.gutter,
              GSpace.md,
            ),
            child: _Pulse(groups: groups, deleted: deleted),
          ),
        ),
        for (final DateGroup<ArchivedMessage> group in groups) ...<Widget>[
          SliverPersistentHeader(
            pinned: true,
            delegate: GGroupHeader(
              label: group.label,
              meta: GFormat.count(group.count),
              tokens: t,
              muted: !group.dated,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) =>
                    _Message(message: group.items[index]),
                childCount: group.items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: GSpace.md)),
        ],
        if (capture?.since != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                GSpace.md,
                GSpace.gutter,
                GSpace.xl,
              ),
              child: Text(
                // The honest edge of the archive, where the list stops. Without
                // it, running out of scroll looks like data went missing.
                'The archive starts here. Messages from before you switched '
                'this on were never captured.',
                textAlign: TextAlign.center,
                style: GType.micro.copyWith(color: t.dim),
              ),
            ),
          ),
      ],
    );
  }
}

/// How busy the archive has been, as bars behind two numbers.
///
/// Drawn from the groups that are already computed, so it costs one pass over a
/// list the page had to build anyway. Oldest on the left, like every other
/// timeline in this app.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.groups, required this.deleted});

  final List<DateGroup<ArchivedMessage>> groups;
  final int deleted;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    final List<int> counts = <int>[
      for (final DateGroup<ArchivedMessage> group in groups.reversed)
        if (group.dated) group.count,
    ];
    final int peak = counts.isEmpty
        ? 0
        : counts.reduce((int a, int b) => a > b ? a : b);
    final int total = counts.fold<int>(0, (int sum, int value) => sum + value);

    return GCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 108,
        child: Stack(
          children: <Widget>[
            if (peak > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 62,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final int value in counts)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: value == 0 ? 0.04 : value / peak,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: t.chat.withValues(alpha: 0.45),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(GSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Stat(
                    value: GFormat.count(total),
                    label: 'kept',
                    tone: t.text,
                  ),
                  // Only when there is one. "0 deleted by sender" is the number
                  // nobody opened this page to read.
                  if (deleted > 0)
                    _Stat(
                      value: GFormat.count(deleted),
                      label: 'deleted by sender',
                      tone: t.warning,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tone});

  final String value;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GType.monoNumber.copyWith(color: tone, fontSize: 21),
          ),
          Text(label, style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final ArchivedMessage message;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.chat.withValues(alpha: 0.2),
                    borderRadius: GRadius.all(9),
                  ),
                  child: Icon(Icons.forum_outlined, size: 14, color: t.chat),
                ),
                const SizedBox(width: GSpace.sm + 1),
                Expanded(
                  child: Text(
                    message.conversation ?? message.appLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.heading.copyWith(color: t.text),
                  ),
                ),
                Text(
                  _clock(message.postedAtMillis),
                  style: GType.monoSmall.copyWith(color: t.dim, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(height: GSpace.sm),
            Text(message.text, style: GType.bodySmall.copyWith(color: t.muted)),
            if (message.edited) ...<Widget>[
              const SizedBox(height: GSpace.sm),
              Row(
                children: <Widget>[
                  Icon(Icons.block_rounded, size: 14, color: t.warning),
                  const SizedBox(width: GSpace.xs + 1),
                  Text(
                    // Only where the sending app said so itself. A notification
                    // being dismissed is not evidence of anything and is never
                    // labelled here.
                    'Deleted by sender',
                    style: GType.micro.copyWith(color: t.warning),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _clock(int millis) {
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(millis);
    final String hour = at.hour.toString().padLeft(2, '0');
    final String minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
