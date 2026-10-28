import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/recent_searches.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import 'bangs.dart';
import 'calc.dart';
import 'command_router.dart';

/// Colours and type for a command row, so the same row can sit in the GNOME
/// search page (ChromeScope) and in the drop-down sheet (raw palette)
/// without either surface learning the other's styling system.
class CommandRowStyle {
  const CommandRowStyle({
    required this.text,
    required this.muted,
    required this.accent,
    this.fontFamily,
    this.monoFamily,
    this.scale = 1,
  });

  final Color text;
  final Color muted;
  final Color accent;
  final String? fontFamily;
  final String? monoFamily;
  final double scale;
}

/// Open [url] with whatever on the phone handles it: the browser for https,
/// Play for market:, the maps app for geo:. Says so when nothing can.
Future<bool> openCommandUrl(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final ok = await ref
      .read(launcherHostApiProvider)
      .openIntent('android.intent.action.VIEW', url, null);
  if (!ok && context.mounted) {
    context.showMessage(context.t('command.nothingOpens'));
  }
  return ok;
}

/// Do what a command hit means. Returns true when the surface should close
/// (a site or Play opened), false when it should stay (a value was copied, or
/// a bang key was filled in for the person to keep typing).
Future<bool> activateCommandHit(
  BuildContext context,
  WidgetRef ref,
  CommandHit hit, {
  required String query,
  required void Function(String) fillQuery,
}) async {
  switch (hit) {
    case CalcHit():
      await _copy(context, hit.value);
      return false;
    case ConvertHit():
      await _copy(context, hit.conversion.result);
      return false;
    case BangSearchHit():
      ref.read(recentSearchesProvider.notifier).record(query);
      return openCommandUrl(context, ref, hit.hit.url);
    case BangHintHit():
      if (hit.bangs.isNotEmpty) fillQuery('!${hit.bangs.first.key} ');
      return false;
  }
}

Future<void> _copy(BuildContext context, double v) async {
  // Copied WITHOUT the grouping commas, so it pastes into another calculator
  // or a form as a number.
  final plain = Calc.format(v).replaceAll(',', '');
  await Clipboard.setData(ClipboardData(text: plain));
  HapticFeedback.selectionClick();
  if (context.mounted) {
    context.showMessage(context.t('command.copied', {'value': plain}));
  }
}

/// One command answer, drawn as a row.
class CommandHitRow extends StatelessWidget {
  const CommandHitRow({
    super.key,
    required this.hit,
    required this.style,
    required this.onTap,
    this.onBang,
  });

  final CommandHit hit;
  final CommandRowStyle style;
  final VoidCallback onTap;

  /// For [BangHintHit]: a tapped chip fills that bang's key.
  final void Function(Bang)? onBang;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final big = TextStyle(
      fontFamily: s.monoFamily,
      fontSize: 22 * s.scale,
      fontWeight: FontWeight.w700,
      color: s.text,
    );
    final sub = TextStyle(
      fontFamily: s.fontFamily,
      fontSize: 12 * s.scale,
      color: s.muted,
    );

    return switch (hit) {
      CalcHit(:final expression, :final display) => _Row(
          onTap: onTap,
          leading: Icon(Icons.calculate_outlined, color: s.accent),
          title: Text('= $display', style: big),
          subtitle: Text(
            context.t('command.tapToCopy', {'expr': expression}),
            style: sub,
          ),
        ),
      ConvertHit(:final conversion) => _Row(
          onTap: onTap,
          leading: Icon(Icons.swap_horiz, color: s.accent),
          title: Text(conversion.output, style: big),
          subtitle: Text(
            context.t('command.tapToCopy', {'expr': conversion.input}),
            style: sub,
          ),
        ),
      BangSearchHit(:final hit) => _Row(
          onTap: onTap,
          leading: Icon(Icons.travel_explore, color: s.accent),
          title: Text(
            context.t('command.searchSite', {'site': hit.bang.label}),
            style: sub.copyWith(color: s.text, fontSize: 14 * s.scale),
          ),
          subtitle: Text(hit.terms, style: sub),
        ),
      BangHintHit(:final bangs) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in bangs)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onBang == null ? null : () => onBang!(b),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: s.muted.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '!${b.key}  ${b.label}',
                      style: sub.copyWith(
                        color: s.text,
                        fontFamily: s.monoFamily,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    };
  }
}

/// "Search the web for X" and "Find X on Play Store": the two answers that
/// replace a dead "nothing matches".
class CommandFallbackRows extends ConsumerWidget {
  const CommandFallbackRows({
    super.key,
    required this.query,
    required this.style,
    required this.onOpened,
  });

  final String query;
  final CommandRowStyle style;

  /// Called after a URL opened, so the surface can close itself.
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = style;
    final title = TextStyle(
      fontFamily: s.fontFamily,
      fontSize: 14 * s.scale,
      color: s.text,
    );

    Future<void> open(String url) async {
      ref.read(recentSearchesProvider.notifier).record(query);
      if (await openCommandUrl(context, ref, url)) onOpened();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(
          onTap: () => open(CommandRouter.webSearchUrl(query)),
          leading: Icon(Icons.public, color: s.muted),
          title: Text(
            context.t('command.searchWeb', {'query': query.trim()}),
            style: title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _Row(
          onTap: () => open(CommandRouter.playSearchUrl(query)),
          leading: Icon(Icons.shop_outlined, color: s.muted),
          title: Text(
            context.t('command.searchPlay', {'query': query.trim()}),
            style: title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // 48dp touch target floor.
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, if (subtitle != null) subtitle!],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
