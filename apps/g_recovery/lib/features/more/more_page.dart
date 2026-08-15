import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/ui/g_stat.dart';

import '../../app/shell.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/content_api.g.dart';
import '../../bridge/messages_api.g.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/app_info.dart';
import '../../core/content/content_store.dart';
import '../../core/format.dart';
import '../../core/i18n/g_strings.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../core/update/app_update.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_card.dart';
import '../device/tools/screen_test_page.dart';
import '../learn/limits_page.dart';
import '../messages/messages_page.dart';
import '../messages/state/messages_providers.dart';
import '../pro/pro_page.dart';
import '../pro/state/pro_providers.dart';
import '../recovery/state/recovery_providers.dart';
import '../server/server_page.dart';
import '../storage/browse/browse_page.dart';
import 'language_page.dart';
import 'settings_pages.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoveryAccess? access = ref.watch(recoveryAccessProvider).value;
    final MessageCapture? capture = ref.watch(messageCaptureProvider).value;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final GThemeState theme = ref.watch(gThemeProvider);
    final bool pro = ref.watch(proUnlockedProvider);
    final GUpdateState update = ref.watch(gUpdateProvider);
    final GAppInfo appInfo = ref.watch(gAppInfoProvider);

    return GPageBody(
      children: <Widget>[
        GAppBar(title: context.s('More')),

        _Status(access: access, capture: capture, summary: summary),

        // ─── YOUR PHONE ─────────────────────────────────────────────────────
        GOverline('Your phone'),
        const SizedBox(height: GSpace.sm + 1),
        _Group(
          rows: <_MoreRow>[
            _MoreRow(
              icon: Icons.folder_open_rounded,
              hue: t.photo,
              title: context.s('Browse files'),
              detail: 'Every folder on this phone, explained',
              onTap: () => Navigator.of(context).push(BrowsePage.route()),
            ),
            _MoreRow(
              icon: Icons.grid_on_rounded,
              hue: t.video,
              title: context.s('Screen test'),
              detail: 'Dead pixels, backlight and touch response',
              onTap: () => Navigator.of(context).push(ScreenTestPage.route()),
            ),
            _MoreRow(
              icon: Icons.dns_outlined,
              hue: t.docs,
              title: context.s('Home server'),
              detail: 'Send files to a machine you own',
              onTap: () => Navigator.of(context).push(ServerPage.route()),
            ),
            _MoreRow(
              icon: Icons.help_outline_rounded,
              hue: t.docs,
              title: context.s('What can come back'),
              detail: 'And what cannot, with the reason',
              onTap: () => Navigator.of(context).push(LimitsPage.route()),
            ),
            _MoreRow(
              icon: Icons.forum_outlined,
              hue: t.chat,
              title: context.s('Message archive'),
              detail: (capture?.capturing ?? false)
                  ? '${GFormat.count(capture!.messageCount)} kept'
                  : 'Not running',
              flag: (capture?.capturing ?? false) ? null : 'Off',
              onTap: () => Navigator.of(context).push(MessagesPage.route()),
            ),
          ],
        ),

        // ─── PRO ────────────────────────────────────────────────────────────
        //
        // One row, in a list, under a heading that says what it is. Not a
        // banner, not a badge on the tab bar, and nothing on Home. An app that
        // advertises its paid tier on every screen is one whose paid tier is
        // not worth mentioning once.
        const SizedBox(height: GSpace.lg),
        GOverline('Pro'),
        const SizedBox(height: GSpace.sm + 1),
        _Group(
          rows: <_MoreRow>[
            _MoreRow(
              icon: pro
                  ? Icons.check_circle_outline_rounded
                  : Icons.workspace_premium_outlined,
              hue: t.accent,
              title: pro ? 'Pro is on' : 'Pro',
              detail: pro
                  ? 'Scheduled backups, video compression, more servers'
                  : 'Onetime Payment',
              onTap: () => Navigator.of(context).push(ProPage.route()),
            ),
          ],
        ),

        // ─── SETTINGS ───────────────────────────────────────────────────────
        //
        // Appearance is a ROW now, not the inline card it was. Every entry on
        // this page is the same shape, so the list reads as a list rather than
        // as a list interrupted by a widget.
        const SizedBox(height: GSpace.lg),
        GOverline('Settings'),
        const SizedBox(height: GSpace.sm + 1),
        _Group(
          rows: <_MoreRow>[
            _MoreRow(
              icon: Icons.palette_outlined,
              hue: t.apps,
              title: context.s('Appearance'),
              detail: '${_modeName(theme.mode)}  ·  ${theme.accent.label}',
              onTap: () => Navigator.of(context).push(AppearancePage.route()),
            ),
            _MoreRow(
              icon: Icons.language_rounded,
              hue: t.video,
              title: context.s('Language'),
              detail: GLanguage.forCode(ref.watch(gLocaleProvider)).nativeName,
              onTap: () => Navigator.of(context).push(LanguagePage.route()),
            ),
            _MoreRow(
              icon: Icons.lock_outline_rounded,
              hue: (access?.allFilesAccess ?? false) ? t.docs : t.apps,
              title: context.s('Permissions'),
              detail: _permissionLine(access, capture),
              flag: _missingCount(access, capture) == 0
                  ? null
                  : '${_missingCount(access, capture)}',
              onTap: () async {
                await ref.read(recoveryBridgeProvider).requestAllFilesAccess();
                ref.invalidate(recoveryAccessProvider);
              },
            ),
            _MoreRow(
              icon: Icons.shield_outlined,
              hue: t.chat,
              title: context.s('Privacy'),
              detail: 'Nothing leaves this phone',
              onTap: () => Navigator.of(context).push(PrivacyPage.route()),
            ),
          ],
        ),

        // ─── CONTENT ────────────────────────────────────────────────────────
        const SizedBox(height: GSpace.lg),
        GOverline('Content'),
        const SizedBox(height: GSpace.sm + 1),
        const ContentCard(),

        // ─── ABOUT ──────────────────────────────────────────────────────────
        const SizedBox(height: GSpace.lg),
        GOverline('About'),
        const SizedBox(height: GSpace.sm + 1),
        _Group(
          rows: <_MoreRow>[
            _MoreRow(
              icon: Icons.info_outline_rounded,
              hue: t.dim,
              title: context.s('G Recovery'),
              // No version at all rather than a placeholder, on the one
              // phone where the package read failed. The rule holds here as
              // everywhere: an absent figure is an absent line.
              detail: appInfo.hasVersion
                  ? '${appInfo.version}  ·  Mindberzerk'
                  : 'Mindberzerk',
              onTap: () => Navigator.of(context).push(PrivacyPage.route()),
            ),
            // Absent on any build Play did not install, which is every build
            // during development and every sideload. Silence rather than a row
            // explaining why the row cannot work.
            if (_updateVisible(update.stage))
              _MoreRow(
                icon: _updateIcon(update.stage),
                hue: _updateHue(t, update.stage),
                title: _updateTitle(context, update.stage),
                detail: _updateDetail(context, update, appInfo),
                onTap: () => _tapUpdate(context, ref, update),
              ),
          ],
        ),
      ],
    );
  }

  /// Only once Play has answered.
  ///
  /// idle is the window between launch and the first check coming back, and
  /// unavailable is every build Play does not own. Both draw nothing, so the
  /// row appears when it has something true to say and never flickers through
  /// a state it is about to leave.
  static bool _updateVisible(GUpdateStage stage) =>
      stage != GUpdateStage.idle && stage != GUpdateStage.unavailable;

  static IconData _updateIcon(GUpdateStage stage) => switch (stage) {
    GUpdateStage.available => Icons.system_update_alt_rounded,
    GUpdateStage.downloading => Icons.downloading_rounded,
    GUpdateStage.ready => Icons.restart_alt_rounded,
    _ => Icons.verified_outlined,
  };

  /// Never the warning tone.
  ///
  /// The flag badge on this row type is amber, and amber means caution
  /// everywhere else in the app. A newer version is not a caution, so the state
  /// is carried by the icon's own colour and the title, and the badge is left
  /// for the things that have earned it.
  static Color _updateHue(GTokens t, GUpdateStage stage) => switch (stage) {
    GUpdateStage.ready => t.success,
    GUpdateStage.available || GUpdateStage.downloading => t.accent,
    _ => t.dim,
  };

  /// Context is threaded in so every literal below sits inside an s() call.
  ///
  /// tool/i18n/extract.py collects by reading the source for string literals
  /// written directly inside s(), so a helper that cannot reach a context is a
  /// helper whose strings can never be translated. That is how these four
  /// escaped the table on the first pass.
  static String _updateTitle(BuildContext context, GUpdateStage stage) =>
      switch (stage) {
        GUpdateStage.available => context.s('Update available'),
        GUpdateStage.downloading => context.s('Downloading update'),
        GUpdateStage.ready => context.s('Restart to finish updating'),
        GUpdateStage.checking => context.s('Checking'),
        _ => context.s('Up to date'),
      };

  /// Build, not version.
  ///
  /// availableVersionCode is the build number, and the row above this one says
  /// 2.0.0. Calling the incoming one "version 13" beside it would read as a
  /// contradiction, so the two are named for what they each are.
  static String _updateDetail(
    BuildContext context,
    GUpdateState update,
    GAppInfo info,
  ) {
    switch (update.stage) {
      case GUpdateStage.available:
        final int? there = update.availableVersionCode;
        final int? here = info.build;
        if (there == null) return context.s('A newer build is on Play');
        // Two numbers when both are known, because one number on its own
        // invites the reader to compare it against the 2.0.0 in the row above
        // and find that it does not match. Interpolated lines are left
        // untranslated here, as every other detail line on this page is.
        if (here == null) return 'Build $there is on Play';
        return 'Build $here now, build $there on Play';
      case GUpdateStage.downloading:
        return context.s('Play is fetching it in the background');
      case GUpdateStage.ready:
        return context.s('Tap to install and restart');
      case GUpdateStage.checking:
        return context.s('Asking Play');
      case GUpdateStage.current:
      case GUpdateStage.idle:
      case GUpdateStage.unavailable:
        return context.s('Tap to check again');
    }
  }

  /// One row, four meanings, and nothing happens that was not tapped.
  ///
  /// Immediate is reserved for two cases: a release marked urgent, and a phone
  /// where Play refuses a flexible update outright. Everything else downloads in
  /// the background and waits, because a full screen Play sheet over the app
  /// someone just opened is the behaviour this row exists to avoid.
  static Future<void> _tapUpdate(
    BuildContext context,
    WidgetRef ref,
    GUpdateState update,
  ) async {
    final GUpdateController controller = ref.read(gUpdateProvider.notifier);

    if (update.stage == GUpdateStage.downloading) return;

    if (update.stage == GUpdateStage.ready) {
      final GUpdateOutcome outcome = await controller.install();
      // Reaching this line at all usually means it did not work: a successful
      // install kills the process from inside Play.
      if (!context.mounted || outcome == GUpdateOutcome.done) return;
      GMessenger.show(
        context,
        GMessage.danger(context.s('Play could not install the update')),
      );
      return;
    }

    if (update.stage == GUpdateStage.available) {
      final bool immediate =
          update.immediateAllowed &&
          (update.isUrgent || !update.flexibleAllowed);
      final GUpdateOutcome outcome = immediate
          ? await controller.updateNow()
          : await controller.download();
      if (!context.mounted) return;
      switch (outcome) {
        // Denied is a decision, not a fault. Saying anything here would be
        // arguing with someone who has just said no.
        case GUpdateOutcome.done:
        case GUpdateOutcome.denied:
          return;
        case GUpdateOutcome.failed:
        case GUpdateOutcome.notPossible:
          GMessenger.show(
            context,
            GMessage.warning(context.s('Play could not start the update')),
          );
      }
      return;
    }

    // Up to date, or mid check. Either way the tap means check again, and this
    // one is deliberate so it is allowed to say what it found.
    final GUpdateOutcome outcome = await controller.refresh(force: true);
    if (!context.mounted) return;
    if (outcome != GUpdateOutcome.done) {
      GMessenger.show(
        context,
        GMessage.warning(context.s('Play did not answer')),
      );
      return;
    }
    final GUpdateStage now = ref.read(gUpdateProvider).stage;
    if (now == GUpdateStage.current) {
      GMessenger.show(
        context,
        GMessage.success(context.s('This is the newest build')),
      );
    }
  }

  static String _modeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Auto',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  /// Both grants, and only the ones that are off.
  ///
  /// A row reading "File access on, notifications on" is noise. The interesting
  /// state is what is missing, so a fully granted phone says so in two words.
  static String _permissionLine(
    RecoveryAccess? access,
    MessageCapture? capture,
  ) {
    final List<String> missing = _missing(access, capture);
    if (missing.isEmpty) return 'Everything granted';
    return 'Missing ${missing.join(' and ')}';
  }

  static List<String> _missing(
    RecoveryAccess? access,
    MessageCapture? capture,
  ) => <String>[
    if (!(access?.allFilesAccess ?? false)) 'file access',
    if (!(capture?.listenerEnabled ?? false)) 'notification access',
  ];

  static int _missingCount(RecoveryAccess? access, MessageCapture? capture) =>
      _missing(access, capture).length;
}

/// IS THIS APP DOING ITS JOB.
///
/// The question the tab now opens with, and nothing in the app answered it
/// before. Two of the four capabilities are off by default, and the only hint a
/// person ever got was the alert on Home, which fires for file access alone.
///
/// ─── IT TURNS GREEN, AND THAT MATTERS ────────────────────────────────────────
///
/// A card that is only ever amber is a nag. This one says so when everything is
/// on, which is the state most users will reach and the one worth confirming.
class _Status extends StatelessWidget {
  const _Status({
    required this.access,
    required this.capture,
    required this.summary,
  });

  final RecoveryAccess? access;
  final MessageCapture? capture;
  final RecoverySummary? summary;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    // Nothing at all until the reads land. A card that flashes amber on every
    // cold start and then turns green is worse than one that arrives a beat
    // late.
    if (access == null) return const SizedBox.shrink();

    final bool files = access!.allFilesAccess;
    final bool notifications = capture?.listenerEnabled ?? false;
    final int off = <bool>[files, notifications].where((bool v) => !v).length;
    final bool good = off == 0;
    final Color hue = good ? t.success : t.warning;
    final bool dark = t.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.lg),
      child: DecoratedBox(
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
              Text(
                good
                    ? 'Everything is on'
                    : off == 1
                    ? 'One thing is off'
                    : 'Two things are off',
                style: GType.title.copyWith(color: t.text),
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                _line(files: files, notifications: notifications),
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
              if (summary != null) ...<Widget>[
                const SizedBox(height: GSpace.md + 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Stat(
                      value: GFormat.count(summary!.totalItems),
                      label: context.s('can be brought back'),
                      tone: t.text,
                    ),
                    _Stat(
                      value: GFormat.count(summary!.sources.length),
                      label: context.s('places checked'),
                      tone: t.text,
                    ),
                    if (!good)
                      _Stat(
                        value: '$off',
                        label: context.s('to turn on'),
                        tone: t.warning,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Says what still works, not only what does not.
  ///
  /// Someone who has granted file access and refused notifications has a fully
  /// working recovery app, and telling them only about the gap would misdescribe
  /// their own phone to them.
  static String _line({required bool files, required bool notifications}) {
    if (files && notifications) {
      return 'Recovery reaches every place it can, and messages are being kept '
          'as they arrive.';
    }
    if (files) {
      return 'File access is on, so recovery works everywhere. The message '
          'archive is not running.';
    }
    if (notifications) {
      return 'Messages are being kept, but without file access recovery can '
          'only see files this app made itself.';
    }
    return 'Without file access, recovery can only see files this app made '
        'itself. The message archive is not running either.';
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
            style: GType.monoNumber.copyWith(color: tone, fontSize: 18),
          ),
          Text(label, style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

/// A card of rows, so every group on this page is built the same way.
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<_MoreRow> rows;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.hue,
    required this.title,
    required this.detail,
    required this.onTap,
    this.flag,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// A short badge on the right, for a row in a state worth noticing.
  ///
  /// Null on a row that is fine. A badge on every row is wallpaper, and the
  /// only ones that earn it here are a capability switched off and a count of
  /// missing permissions.
  final String? flag;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hue.withValues(alpha: 0.18),
                  borderRadius: GRadius.all(11),
                ),
                child: Icon(icon, size: 17, color: hue),
              ),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: GType.body.copyWith(color: t.text)),
                    const SizedBox(height: 1),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              if (flag != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSpace.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: t.warning.withValues(alpha: 0.18),
                    borderRadius: GRadius.all(GRadius.chip),
                  ),
                  child: Text(
                    flag!,
                    style: GType.micro.copyWith(color: t.warning),
                  ),
                ),
                const SizedBox(width: GSpace.sm),
              ],
              Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
            ],
          ),
        ),
      ),
    );
  }
}

/// What content is installed, and a way to force a check.
///
/// Visible on purpose. The pipeline's whole value is that coverage improves
/// without a release, and a user who reports "it still misses my Tecno's
/// recycle bin" needs to be able to say which registry version they have.
class ContentCard extends ConsumerWidget {
  const ContentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<ContentPackInfo> packs =
        ref.watch(installedPacksProvider).value ?? const <ContentPackInfo>[];
    final ContentSyncResult? sync = ref.watch(contentSyncProvider).value;

    return GCard(
      onTap: () {
        ref.invalidate(contentSyncProvider);
        ref.invalidate(installedPacksProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.s('Recovery coverage'),
                  style: GType.heading.copyWith(color: t.text),
                ),
              ),
              if (sync != null) _statusBadge(sync.status),
            ],
          ),
          const SizedBox(height: GSpace.sm - 2),
          Text(
            packs.isEmpty
                // Not a failure. It is what every phone shows until the first
                // successful sync, and the app works exactly the same either
                // way.
                ? 'Using the copy built into this version. Tap to check for '
                      'updates.'
                : 'Updated without needing a new app version. Tap to check '
                      'again.',
            style: GType.bodySmall.copyWith(color: t.muted),
          ),
          if (packs.isNotEmpty) ...<Widget>[
            const GCardDivider(),
            for (final ContentPackInfo pack in packs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        pack.packId,
                        style: GType.bodySmall.copyWith(color: t.muted),
                      ),
                    ),
                    Text(
                      'v${pack.installedVersion}',
                      style: GType.monoSmall.copyWith(color: t.text),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'updated':
        return GBadge.full('Updated');
      case 'upToDate':
        return GBadge.full('Current');
      case 'offline':
        // Offline is ORDINARY, not an error. A phone in a lift, or a first
        // launch on aeroplane mode, and the app is entirely fine.
        return GBadge(label: 'Offline');
      case 'rejected':
        return GBadge.partial('Rejected');
      default:
        return GBadge.partial('Retry');
    }
  }
}
