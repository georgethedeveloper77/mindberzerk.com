import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/desklet_layout.dart';
import '../../../data/prefs/launcher_prefs.dart';
import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../design/components/components.dart';
import '../../../design/terminal_tokens.dart'
    show DeviceInfo, deviceInfoProvider;
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../conky/conky_template.dart';
import '../desklet_frame.dart';

/// The conky, driven by the person's own conkyrc.
///
/// The System monitor is a fixed set of rows; this is a text config with
/// real conky variable names, rendered by [ConkyTemplate] and drawn in the
/// distro's desklet skin. Its config travels in a shared rice, which is the
/// point of it: a conkyrc is the part of a rice people copy.
class ConkyDesklet extends ConsumerStatefulWidget {
  const ConkyDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  /// The config key. Absent means [ConkyTemplate.defaultRc].
  static const configKey = 'conkyrc';

  static String rcOf(Desklet d) {
    final v = d.config[configKey];
    return v is String && v.trim().isNotEmpty ? v : ConkyTemplate.defaultRc;
  }

  @override
  ConsumerState<ConkyDesklet> createState() => _ConkyDeskletState();
}

class _ConkyDeskletState extends ConsumerState<ConkyDesklet> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ConkyDesklet old) {
    super.didUpdateWidget(old);
    if (ConkyDesklet.rcOf(old.desklet) != ConkyDesklet.rcOf(widget.desklet)) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Every second only when the rc prints seconds; otherwise on the minute,
  /// so an idle desktop is not repainted sixty times for nothing.
  void _schedule() {
    _tick?.cancel();
    if (ConkyTemplate.needsSeconds(ConkyDesklet.rcOf(widget.desklet))) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    } else {
      final now = DateTime.now();
      final toMinute = Duration(seconds: 60 - now.second);
      _tick = Timer(toMinute, () {
        _refresh();
        _schedule();
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final skin = widget.skin;
    final p = theme.palette;
    final rc = ConkyDesklet.rcOf(widget.desklet);

    final lines = ConkyTemplate.render(
      rc,
      conkyReadings(
        now: _now,
        stats: ref.watch(systemStatsProvider).asData?.value,
        host: ref.watch(deviceInfoProvider).asData?.value,
        appCount: ref.watch(shellAppsProvider(theme)).length,
      ),
    );

    final size = skin.num_('rowSize', 12);
    final shadows = skin.surface == DeskletSurface.bare
        ? [
            Shadow(
              color: p.bgBottom.withValues(alpha: 0.55),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    Color inkOf(ConkyInk ink) => switch (ink) {
          ConkyInk.normal => p.onDark.withValues(alpha: 0.92),
          ConkyInk.accent => p.accent,
          ConkyInk.muted => p.onDark.withValues(alpha: 0.6),
        };

    TextStyle styleOf(ConkyInk ink) => TextStyle(
          fontFamily: theme.typography.mono,
          fontSize: size,
          height: 1.5,
          color: inkOf(ink),
          shadows: shadows,
        );

    /// Consecutive text merges into one span, so a line clips as a unit
    /// instead of wrapping; each bar becomes an Expanded.
    List<Widget> runs(List<ConkyPiece> pieces) {
      final out = <Widget>[];
      var spans = <InlineSpan>[];
      void flush() {
        if (spans.isEmpty) return;
        out.add(Text.rich(
          TextSpan(children: spans),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ));
        spans = <InlineSpan>[];
      }

      for (final piece in pieces) {
        switch (piece) {
          case ConkyText(:final text, :final ink):
            spans.add(TextSpan(text: text, style: styleOf(ink)));
          case ConkyBar(:final fraction, :final ink):
            flush();
            out.add(Expanded(
              child: _Bar(
                fraction: fraction,
                color: inkOf(ink),
                track: p.onDark.withValues(alpha: 0.16),
              ),
            ));
        }
      }
      flush();
      return out;
    }

    Widget lineOf(ConkyLine l) {
      if (l.rule) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(height: 1, color: p.onDark.withValues(alpha: 0.25)),
        );
      }
      final left = runs(l.left);
      final right = runs(l.right);
      final leftBar = l.left.any((x) => x is ConkyBar);
      final rightBar = l.right.any((x) => x is ConkyBar);

      return Row(
        // `${alignr}` is honoured by spaceBetween: the right run sits at the
        // edge whatever the left one measures.
        mainAxisAlignment: right.isEmpty
            ? MainAxisAlignment.start
            : MainAxisAlignment.spaceBetween,
        children: [
          if (left.isNotEmpty && !leftBar)
            Expanded(child: left.single)
          else
            ...left,
          if (right.isNotEmpty && !rightBar)
            Flexible(child: right.single)
          else
            ...right,
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => editConkyrc(context, ref, theme, widget.desklet),
      child: DeskletFrame(
        theme: theme,
        skin: skin,
        body: DeskletBody(
          command: 'conky -c ~/.conkyrc',
          custom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in lines)
                l.isEmpty ? SizedBox(height: size * 0.75) : lineOf(l),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The live readings, by conky name. Every value is one the other desklets
/// already show, from the same snapshot, so a conky and a System monitor on
/// one desktop can never disagree.
ConkyReadings conkyReadings({
  required DateTime now,
  SystemStats? stats,
  DeviceInfo? host,
  int? appCount,
}) {
  final s = stats;
  final memFrac = s != null && s.hasMemory && s.memTotalGb! > 0
      ? s.memUsedGb! / s.memTotalGb!
      : null;
  final fsFrac = s != null && s.hasStorage && s.storageTotalBytes! > 0
      ? s.storageUsedBytes! / s.storageTotalBytes!
      : null;
  String gb(double v) => '${v.toStringAsFixed(1)}G';

  return ConkyReadings(
    now: now,
    text: {
      'nodename': host?.host ?? host?.deviceModel,
      'sysname': 'Android',
      'user_names': host?.user,
      'uptime': s?.uptime == null ? null : formatUptime(s!.uptime),
      'uptime_short': s?.uptime == null ? null : _short(s!.uptime!),
      'battery_percent': s?.batteryPercent?.toString(),
      'battery_status': s?.batteryCharging == null
          ? null
          : (s!.batteryCharging! ? 'charging' : 'discharging'),
      'acpitemp': s?.batteryTempC?.round().toString(),
      'cpu': s?.cpuPercent?.toString(),
      'mem': s?.memUsedGb == null ? null : gb(s!.memUsedGb!),
      'memmax': s?.memTotalGb == null ? null : gb(s!.memTotalGb!),
      'memperc': memFrac == null ? null : '${(memFrac * 100).round()}',
      'fs_used': s?.storageUsedBytes == null
          ? null
          : SystemStats.bytes(s!.storageUsedBytes),
      'fs_size': s?.storageTotalBytes == null
          ? null
          : SystemStats.bytes(s!.storageTotalBytes),
      'fs_free': s == null || !s.hasStorage
          ? null
          : SystemStats.bytes(s.storageTotalBytes! - s.storageUsedBytes!),
      'fs_used_perc': fsFrac == null ? null : '${(fsFrac * 100).round()}',
      'downspeed': s?.netDownBytesPerSec == null
          ? null
          : SystemStats.rate(s!.netDownBytesPerSec),
      'upspeed': s?.netUpBytesPerSec == null
          ? null
          : SystemStats.rate(s!.netUpBytesPerSec),
      'apps': appCount?.toString(),
    },
    bars: {
      'battery_bar':
          s?.batteryPercent == null ? null : s!.batteryPercent! / 100,
      'membar': memFrac,
      'fs_bar': fsFrac,
      'cpubar': s?.cpuPercent == null ? null : s!.cpuPercent! / 100,
    },
  );
}

/// `3d 4h`, `5h 12m`, `12m`: conky's `${uptime_short}`.
String _short(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

/// Edit the conkyrc in a mono sheet. Not in place on the desktop, for the
/// same reason the note is not: a live field there would raise the keyboard
/// over the wallpaper on any stray tap.
Future<void> editConkyrc(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  Desklet desklet,
) async {
  final rc = await ThemedSheet.show<String>(
    context,
    title: '~/.conkyrc',
    isScrollControlled: true,
    builder: (_) => _ConkyEditor(
      theme: theme,
      initial: ConkyDesklet.rcOf(desklet),
    ),
  );
  if (rc == null) return;
  // configure() MERGES, so a key a newer build wrote survives. The default
  // is stored as an absence, so a later improvement to it reaches people
  // who never changed theirs.
  await ref.read(prefsProvider(theme.spec.id).notifier).edit(
        (p) => DeskletLayout.configure(p, desklet.id, {
          ConkyDesklet.configKey:
              rc.trim() == ConkyTemplate.defaultRc.trim() ? null : rc,
        }),
      );
}

class _ConkyEditor extends StatefulWidget {
  const _ConkyEditor({required this.theme, required this.initial});

  final EffectiveTheme theme;
  final String initial;

  @override
  State<_ConkyEditor> createState() => _ConkyEditorState();
}

class _ConkyEditorState extends State<_ConkyEditor> {
  late final _rc = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _rc.dispose();
    super.dispose();
  }

  /// Put `${name}` at the cursor, replacing any selection.
  void _insert(String name) {
    final token = '\${$name}';
    final v = _rc.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, token);
    _rc.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final mono = d.text.value.copyWith(fontSize: 12, height: 1.5);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _rc,
                minLines: 8,
                maxLines: 14,
                maxLength: ConkyTemplate.maxLength,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.multiline,
                style: mono,
                cursorColor: c.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: context.t('desklets.conkyHint'),
                  hintStyle: mono.copyWith(color: c.textFaint),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in [
                  ...ConkyTemplate.textVariables,
                  ...ConkyTemplate.barVariables,
                  ...ConkyTemplate.controls,
                ])
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _insert(name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        name,
                        style: mono.copyWith(fontSize: 11, color: c.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ThemedButton(
                  label: context.t('desklets.conkyReset'),
                  kind: ThemedButtonKind.text,
                  onPressed: () => _rc.text = ConkyTemplate.defaultRc,
                ),
                const Spacer(),
                ThemedButton(
                  label: context.t('common.cancel'),
                  kind: ThemedButtonKind.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                ThemedButton(
                  label: context.t('common.save'),
                  onPressed: () => Navigator.of(context).pop(_rc.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
