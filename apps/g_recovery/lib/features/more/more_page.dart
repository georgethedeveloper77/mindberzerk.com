import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_recovery/ui/g_stat.dart';

import '../../app/shell.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/content_api.g.dart';
import '../../bridge/messages_api.g.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/content/content_store.dart';
import '../../core/format.dart';
import '../../core/i18n/g_strings.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_card.dart';
import '../device/tools/screen_test_page.dart';
import '../learn/limits_page.dart';
import '../pro/pro_page.dart';
import '../pro/state/pro_providers.dart';
import '../messages/messages_page.dart';
import '../messages/state/messages_providers.dart';
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

    return GPageBody(
      children: <Widget>[
        GAppBar(title: 'More'),

        _Status(access: access, capture: capture, summary: summary),

        // ─── YOUR PHONE ─────────────────────────────────────────────────────
        GOverline('Your phone'),
        const SizedBox(height: GSpace.sm + 1),
        _Group(
          rows: <_MoreRow>[
            _MoreRow(
              icon: Icons.folder_open_rounded,
              hue: t.photo,
              title: 'Browse files',
              detail: 'Every folder on this phone, explained',
              onTap: () => Navigator.of(context).push(BrowsePage.route()),
            ),
            _MoreRow(
              icon: Icons.grid_on_rounded,
              hue: t.video,
              title: 'Screen test',
              detail: 'Dead pixels, backlight and touch response',
              onTap: () => Navigator.of(context).push(ScreenTestPage.route()),
            ),
            _MoreRow(
              icon: Icons.dns_outlined,
              hue: t.docs,
              title: 'Home server',
              detail: 'Send files to a machine you own',
              onTap: () => Navigator.of(context).push(ServerPage.route()),
            ),
            _MoreRow(
              icon: Icons.help_outline_rounded,
              hue: t.docs,
              title: 'What can come back',
              detail: 'And what cannot, with the reason',
              onTap: () => Navigator.of(context).push(LimitsPage.route()),
            ),
            _MoreRow(
              icon: Icons.forum_outlined,
              hue: t.chat,
              title: 'Message archive',
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
                  : 'One payment for the work the app does without you',
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
              title: 'Appearance',
              detail: '${_modeName(theme.mode)}  ·  ${theme.accent.label}',
              onTap: () => Navigator.of(context).push(AppearancePage.route()),
            ),
            _MoreRow(
              icon: Icons.language_rounded,
              hue: t.video,
              title: 'Language',
              detail: GLanguage.forCode(ref.watch(gLocaleProvider)).nativeName,
              onTap: () => Navigator.of(context).push(LanguagePage.route()),
            ),
            _MoreRow(
              icon: Icons.lock_outline_rounded,
              hue: (access?.allFilesAccess ?? false) ? t.docs : t.apps,
              title: 'Permissions',
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
              title: 'Privacy',
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
              title: 'G Recovery',
              detail: '2.0.0  ·  Mindberzerk',
              onTap: () => Navigator.of(context).push(PrivacyPage.route()),
            ),
          ],
        ),
      ],
    );
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
                      label: 'can be brought back',
                      tone: t.text,
                    ),
                    _Stat(
                      value: GFormat.count(summary!.sources.length),
                      label: 'places checked',
                      tone: t.text,
                    ),
                    if (!good)
                      _Stat(
                        value: '$off',
                        label: 'to turn on',
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
                  'Recovery coverage',
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
