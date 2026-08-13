import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/server_api.g.dart';
import '../../bridge/server_bridge.dart';
import '../../core/format.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_sheet.dart';
import '../pro/pro_page.dart';
import '../pro/state/pro_providers.dart';
import 'reclaim_page.dart';
import 'server_setup_page.dart';
import '../../core/i18n/g_strings.dart';

/// THE HOME SERVER, ONCE THERE IS ONE.
///
/// ─── WHAT IS DELIBERATELY NOT HERE ───────────────────────────────────────────
///
/// The design has three more things on this screen: which folders get sent, a
/// nightly schedule, and the reclaim entry. None of them is built, so none of
/// them is drawn. A toggle for documents that the engine ignores, or a schedule
/// that never runs, is a promise the screen cannot keep, and this app has spent
/// weeks removing exactly those.
///
/// They arrive with the code behind them, in that order.
class ServerPage extends ConsumerWidget {
  const ServerPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const ServerPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final ServerConfig? config = ref.watch(serverConfigProvider).value;

    if (config == null) return const _Empty();

    final TransferState? state = ref.watch(transferProvider).value;
    final bool running = state?.running ?? false;

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
              title: config.label,
              subtitle:
                  '${config.host}  ·  ${config.share ?? config.remotePath}',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                GIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => Navigator.of(
                    context,
                  ).push(ServerSetupPage.route(existing: config)),
                ),
              ],
            ),

            _Reach(config: config),

            const SizedBox(height: GSpace.md),
            _State(state: state),

            const SizedBox(height: GSpace.md),
            GButton(
              label: running ? 'Stop' : 'Back up now',
              icon: running ? Icons.stop_rounded : Icons.cloud_upload_outlined,
              kind: running ? GButtonKind.danger : GButtonKind.primary,
              onPressed: () async {
                final ServerBridge bridge = ref.read(serverBridgeProvider);
                if (running) {
                  await bridge.cancelBackup();
                } else {
                  await bridge.startBackup();
                }
                // The poll ends itself once a transfer settles, so a run started
                // after that would never be seen without this.
                ref.invalidate(transferProvider);
              },
            ),

            const SizedBox(height: GSpace.lg),
            _Schedule(config: config),

            const SizedBox(height: GSpace.lg),
            const _Reclaim(),

            const SizedBox(height: GSpace.lg),
            Text(
              context.s('SERVER'),
              style: GType.overline.copyWith(color: t.dim),
            ),
            const SizedBox(height: GSpace.sm + 1),
            GCard(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
              child: Column(
                children: <Widget>[
                  _Fact(label: context.s('Address'), value: _address(config)),
                  if (config.share != null)
                    _Fact(label: context.s('Share'), value: config.share!),
                  _Fact(label: context.s('Folder'), value: config.remotePath),
                  _Fact(
                    label: context.s('Signed in as'),
                    value: config.username,
                  ),
                  if (config.protocol == 'webdav')
                    _Fact(
                      label: context.s('Certificate'),
                      // Only two states worth naming. "Pinned" is the one that
                      // matters, because it says the user vouched for this
                      // server themselves rather than a public authority doing
                      // it for them.
                      value: config.certPin == null
                          ? 'Signed by a public authority'
                          : 'Pinned by you',
                    ),
                  _Fact(
                    label: context.s('Files'),
                    value: config.encrypt
                        ? 'Encrypted, only this app can open them'
                        : 'Readable by any app on your computer',
                    last: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: GSpace.lg),
            GCard(
              onTap: () => _confirmForget(context, ref),
              child: Row(
                children: <Widget>[
                  Icon(Icons.link_off_rounded, size: 19, color: t.danger),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.s('Forget this server'),
                          style: GType.heading.copyWith(color: t.text),
                        ),
                        Text(
                          // Says what it does NOT do. Someone disconnecting a
                          // NAS needs to know their photos are still on it.
                          context.s(
                            'Nothing on the server is touched or deleted',
                          ),
                          style: GType.micro.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The address as the user would recognise it.
  ///
  /// A WebDAV host on its own is not the thing they pasted, and someone
  /// checking why a backup failed needs to see the same string they copied out
  /// of their server settings.
  static String _address(ServerConfig config) {
    if (config.protocol != 'webdav') return config.host;
    final String scheme = (config.secure ?? true) ? 'https' : 'http';
    final int port = config.port;
    final bool standard =
        (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80);
    final String authority = standard ? config.host : '${config.host}:$port';
    final String base = config.basePath ?? '';
    return base.isEmpty
        ? '$scheme://$authority/'
        : '$scheme://$authority/$base/';
  }

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final GTokens t = context.g;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: GRadius.all(GRadius.card)),
        title: Text(
          context.s('Forget this server'),
          style: GType.title.copyWith(color: t.text),
        ),
        content: Text(
          context.s(
            'The address and password are removed from this phone. Everything '
            'already copied stays on the server, untouched.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.s('Keep'),
              style: GType.label.copyWith(color: t.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.s('Forget'),
              style: GType.label.copyWith(color: t.danger),
            ),
          ),
        ],
      ),
    );
    if (go != true) return;
    await ref.read(serverBridgeProvider).forget();
    ref.invalidate(serverConfigProvider);
  }
}

/// The one card that answers what happened last.
class _State extends StatelessWidget {
  const _State({required this.state});

  final TransferState? state;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final TransferState? s = state;

    // Never run. Not a failure and not a warning: a server set up two minutes
    // ago is in exactly this state and nothing is wrong.
    if (s == null || (s.lastRunMillis == null && !s.running)) {
      return _Shell(
        hue: t.accent,
        title: context.s('Ready'),
        body:
            'Nothing has been copied yet. Start a backup when you are on '
            'the same network as the server.',
      );
    }

    if (s.running) {
      final bool measured = s.bytesTotal > 0;
      return _Shell(
        hue: t.accent,
        title: context.s('Copying'),
        body: s.currentName ?? 'Working through the list',
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: GSpace.md),
            GBar(
              fraction: measured ? s.bytesSent / s.bytesTotal : null,
              colour: t.accent,
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              '${GFormat.count(s.sent)} of ${GFormat.count(s.total)}  ·  '
              '${GFormat.bytes(s.bytesSent)} of ${GFormat.bytes(s.bytesTotal)}',
              style: GType.monoSmall.copyWith(color: t.dim),
            ),
          ],
        ),
      );
    }

    final bool failed = s.lastError != null;
    return _Shell(
      hue: failed ? t.warning : t.success,
      title: failed ? 'Finished with problems' : 'Up to date',
      body: failed
          ? s.lastError!
          : 'Last run ${_ago(s.lastRunMillis!)}. Everything on the phone is on '
                'the server.',
      extra: s.sent == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: GSpace.md),
              child: Row(
                children: <Widget>[
                  _Stat(
                    value: GFormat.count(s.sent),
                    label: context.s('files sent'),
                  ),
                  _Stat(value: GFormat.bytes(s.bytesSent), label: 'copied'),
                  if (s.failed > 0)
                    _Stat(
                      value: GFormat.count(s.failed),
                      label: context.s('could not be sent'),
                      tone: t.warning,
                    ),
                ],
              ),
            ),
    );
  }

  static String _ago(int millis) {
    final Duration since = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    if (since.inMinutes < 1) return 'just now';
    if (since.inMinutes < 60) return '${since.inMinutes} minutes ago';
    if (since.inHours < 24) return '${since.inHours} hours ago';
    return '${since.inDays} days ago';
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.hue,
    required this.title,
    required this.body,
    this.extra,
  });

  final Color hue;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            hue.withValues(alpha: dark ? 0.2 : 0.13),
            hue.withValues(alpha: dark ? 0.07 : 0.05),
          ],
        ),
        border: Border.all(color: hue.withValues(alpha: dark ? 0.4 : 0.28)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.lg - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: GType.title.copyWith(color: t.text)),
            const SizedBox(height: GSpace.sm),
            Text(body, style: GType.bodySmall.copyWith(color: t.muted)),
            ?extra,
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.tone});

  final String value;
  final String label;
  final Color? tone;

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
            style: GType.monoNumber.copyWith(
              color: tone ?? t.text,
              fontSize: 17,
            ),
          ),
          Text(label, style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: GType.body.copyWith(color: t.text)),
          const SizedBox(width: GSpace.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GType.monoSmall.copyWith(color: t.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// No server yet.
class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

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
              title: context.s('Home server'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            const SizedBox(height: GSpace.md),
            Text(
              context.s('Your files,\non your own machine'),
              style: GType.display.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.md),
            Text(
              context.s(
                'Send photos and video to a computer or NAS you own. No account, '
                'no subscription, and nothing passes through us.',
              ),
              style: GType.bodySmall.copyWith(color: t.muted),
            ),

            const SizedBox(height: GSpace.lg),
            // SMB first, and not alphabetically.
            //
            // It needs no software installed on the server, which makes it the
            // right answer for most people, and the reach line underneath is
            // what tells the minority it is wrong for them.
            _Option(
              glyph: Icons.dns_outlined,
              tone: t.photo,
              title: context.s('Windows share'),
              detail:
                  'A PC, NAS or router with file sharing turned on. '
                  'Nothing to install.',
              anywhere: false,
              onTap: () => Navigator.of(
                context,
              ).push(ServerSetupPage.route(protocol: 'smb')),
            ),

            const SizedBox(height: GSpace.sm + 1),
            _Option(
              glyph: Icons.cloud_outlined,
              tone: t.docs,
              title: context.s('WebDAV'),
              detail:
                  'Nextcloud, ownCloud, Synology Drive and most '
                  'self-hosted drives.',
              anywhere: true,
              onTap: () => Navigator.of(
                context,
              ).push(ServerSetupPage.route(protocol: 'webdav')),
            ),

            const SizedBox(height: GSpace.md),
            Text(
              // Named as absent rather than shown as a dead row, which stops
              // someone hunting for it. SFTP is in the schema and not in the
              // code, and saying when it arrives would be a promise.
              context.s(
                'SFTP is not here yet. If your server only speaks SSH, wait for '
                'a later update rather than opening it up.',
              ),
              style: GType.micro.copyWith(color: t.dim),
            ),

            const SizedBox(height: GSpace.lg),
            GCard(
              onTap: () => showGSheet(
                context: context,
                title: context.s('How this works'),
                children: <Widget>[
                  GSheetPoint(
                    icon: Icons.upload_rounded,
                    tone: t.docs,
                    text: context.s(
                      'Files go one way, from the phone to your server. '
                      'Deleting something on the server never deletes it '
                      'here.',
                    ),
                  ),
                  GSheetPoint(
                    icon: Icons.folder_outlined,
                    tone: t.docs,
                    text: context.s(
                      'Your folder structure is kept, so the copy is '
                      'browsable with anything, not just this app.',
                    ),
                  ),
                  GSheetPoint(
                    icon: Icons.wifi_rounded,
                    text: context.s(
                      'A Windows share only works while the phone is on '
                      'the same network. WebDAV over https works from '
                      'anywhere, which is what makes an overnight backup '
                      'away from home possible.',
                    ),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.help_outline_rounded,
                    size: 19,
                    color: t.accentText,
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      context.s('How this works'),
                      style: GType.heading.copyWith(color: t.text),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One protocol on the picker, with its reach stated on the card.
///
/// Reach is the fact that decides this choice, so it sits here rather than in
/// help text a page away. Someone who needs backups away from home can rule out
/// the first card without reading a word about SMB.
class _Option extends StatelessWidget {
  const _Option({
    required this.glyph,
    required this.tone,
    required this.title,
    required this.detail,
    required this.anywhere,
    required this.onTap,
  });

  final IconData glyph;
  final Color tone;
  final String title;
  final String detail;
  final bool anywhere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Color hue = anywhere ? t.success : t.warning;

    return GCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(glyph, size: 20, color: tone),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GType.heading.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
                const SizedBox(height: GSpace.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      anywhere ? Icons.public_rounded : Icons.home_outlined,
                      size: 13,
                      color: hue,
                    ),
                    const SizedBox(width: GSpace.xs + 2),
                    Text(
                      anywhere ? 'Works from anywhere' : 'Home network only',
                      style: GType.micro.copyWith(color: hue),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
        ],
      ),
    );
  }
}

/// WHERE THIS SERVER CAN BE REACHED FROM, SAID ON EVERY SCREEN THAT SHOWS ONE.
///
/// ─── THE ONE LINE THAT EXPLAINS A FAILED NIGHT ───────────────────────────────
///
/// SMB is a local protocol in practice: port 445 should not face the internet
/// and on almost every home network it does not. So a scheduled backup over SMB
/// runs when the phone is home and silently does not when it is not, and
/// without this line that reads as an unreliable app rather than as the
/// protocol working exactly as designed.
///
/// It is deliberately not a warning. Home network only is the correct answer
/// for most people, who charge their phone in the same building as their NAS.
class _Reach extends StatelessWidget {
  const _Reach({required this.config});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool anywhere = config.protocol == 'webdav';
    final Color hue = anywhere ? t.success : t.warning;

    return Row(
      children: <Widget>[
        GBadge(label: anywhere ? 'WebDAV' : 'SMB', tone: GBadgeTone.none),
        const SizedBox(width: GSpace.sm + 1),
        Icon(
          anywhere ? Icons.public_rounded : Icons.home_outlined,
          size: 14,
          color: hue,
        ),
        const SizedBox(width: GSpace.xs + 2),
        Expanded(
          child: Text(
            anywhere
                ? 'Reachable from anywhere'
                : 'Reachable on your home network only',
            style: GType.micro.copyWith(color: hue),
          ),
        ),
      ],
    );
  }
}

/// The entry to reclaim, showing what it would free.
///
/// Absent until the server actually holds something. A card offering to free
/// space on a phone that has never backed anything up is an invitation to a
/// dead end.
class _Reclaim extends ConsumerWidget {
  const _Reclaim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<ReclaimCandidate> candidates =
        ref.watch(reclaimableProvider).value ?? const <ReclaimCandidate>[];

    final List<ReclaimCandidate> ready = candidates
        .where((ReclaimCandidate c) => c.verified)
        .toList();
    if (ready.isEmpty) return const SizedBox.shrink();

    final int bytes = ready.fold<int>(
      0,
      (int sum, ReclaimCandidate c) => sum + c.sizeBytes,
    );
    final bool dark = t.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: dark ? 0.14 : 0.1),
        border: Border.all(
          color: t.accent.withValues(alpha: dark ? 0.34 : 0.26),
        ),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.lg - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${GFormat.bytes(bytes)} can be reclaimed',
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              '${GFormat.count(ready.length)} files are already on the server. '
              'Free the space they take here.',
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            const SizedBox(height: GSpace.md),
            GButton(
              label: context.s('Review and reclaim'),
              icon: Icons.cleaning_services_rounded,
              onPressed: () => Navigator.of(context).push(ReclaimPage.route()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The nightly run.
///
/// ─── NOT GATED YET, AND NOT FAKE GATED ───────────────────────────────────────
///
/// This is the feature Pro sells. Billing does not exist in this app yet, and a
/// padlock that leads nowhere is worse than an ungated feature: it teaches
/// someone the app is trying to charge them before it can.
///
/// The gate goes here when billing lands, as one condition on the toggle.
class _Schedule extends ConsumerWidget {
  const _Schedule({required this.config});

  final ServerConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final int? next = ref.watch(nextRunProvider).value;
    final bool pro = ref.watch(proUnlockedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('WHEN', style: GType.overline.copyWith(color: t.dim)),
        const SizedBox(height: GSpace.sm + 1),
        GCard(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
          child: Column(
            children: <Widget>[
              _Toggle(
                title: context.s('Back up on its own'),
                // "About once a day", not "every night at 2am". Android defers
                // this job for battery and Doze, so naming an hour would be
                // promising something the system will not keep.
                detail: !pro
                    ? 'Part of Pro'
                    : config.scheduled
                    ? next == null
                          ? 'About once a day'
                          : 'Next run ${_when(next)}'
                    : 'Only when you tap Back up now',
                // ─── THE GATE, AND IT IS THE ONLY ONE ON THIS PAGE ──────────
                //
                // Connecting, copying and reclaiming all stay free and by hand,
                // exactly as the schema promises. What is sold is the run that
                // happens while nobody is watching, which is the one thing here
                // no competitor offers at all.
                //
                // Off rather than hidden. A person who cannot see what they
                // would be buying cannot decide they want it, and a row that
                // simply is not there teaches them the app cannot do it.
                on: pro && config.scheduled,
                onTap: () async {
                  if (!pro) {
                    await Navigator.of(context).push(ProPage.route());
                    return;
                  }
                  await ref
                      .read(serverBridgeProvider)
                      .setSchedule(enabled: !config.scheduled);
                  ref.invalidate(serverConfigProvider);
                  ref.invalidate(nextRunProvider);
                },
              ),
              _Toggle(
                title: context.s('Wi-Fi only'),
                detail: 'Never on mobile data',
                on: config.wifiOnly,
                onTap: () => _save(ref, wifiOnly: !config.wifiOnly),
              ),
              _Toggle(
                title: context.s('While charging'),
                detail: 'Waits for a charger before starting',
                on: config.whileCharging,
                onTap: () => _save(ref, charging: !config.whileCharging),
                last: true,
              ),
            ],
          ),
        ),

        // Said once, under the thing it applies to, and nowhere else on the
        // page. The two toggles beneath it are settings for a run, not features
        // of their own, so gating them as well would be charging twice for one
        // thing.
        if (!pro) ...<Widget>[
          const SizedBox(height: GSpace.sm),
          Text(
            context.s(
              'Backing up by hand, reclaiming space and everything else here '
              'stay free. Pro is for the run that happens without you.',
            ),
            style: GType.micro.copyWith(color: t.dim),
          ),
        ],
      ],
    );
  }

  /// Saves, then re-schedules if a run is queued.
  ///
  /// The constraints live in the queued job, not in the worker, so changing one
  /// without re-enqueuing would leave a job that still waits for the old
  /// conditions.
  Future<void> _save(WidgetRef ref, {bool? wifiOnly, bool? charging}) async {
    final ServerConfig next = ServerConfig(
      id: config.id,
      protocol: config.protocol,
      label: config.label,
      host: config.host,
      port: config.port,
      share: config.share,
      username: config.username,
      remotePath: config.remotePath,
      encrypt: config.encrypt,
      wifiOnly: wifiOnly ?? config.wifiOnly,
      whileCharging: charging ?? config.whileCharging,
      scheduled: config.scheduled,
    );

    final ServerBridge bridge = ref.read(serverBridgeProvider);
    await bridge.save(next);
    if (next.scheduled) await bridge.setSchedule(enabled: true);

    ref.invalidate(serverConfigProvider);
    ref.invalidate(nextRunProvider);
  }

  static String _when(int millis) {
    final Duration until = DateTime.fromMillisecondsSinceEpoch(
      millis,
    ).difference(DateTime.now());
    if (until.isNegative) return 'due now';
    if (until.inHours < 1) return 'in ${until.inMinutes} minutes';
    if (until.inHours < 24) return 'in ${until.inHours} hours';
    return 'in ${until.inDays} days';
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.detail,
    required this.on,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final String detail;
  final bool on;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: GType.body.copyWith(color: t.text)),
                      Text(detail, style: GType.micro.copyWith(color: t.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: GSpace.md),
                AnimatedContainer(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
