import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/desklet_spec.dart';
import '../../../engine/effective_theme.dart';
import '../desklet_frame.dart';

/// The distro's own greeting card: a title and a short list of links.
///
/// ─── THE OBJECTION, AND WHY IT SHAPED THE DESIGN RATHER THAN KILLING IT ─────
///
/// A greeting stops being useful the moment you know which distro you are on,
/// which is roughly day two, and a permanent card telling you where the forum
/// is becomes furniture. The obvious conclusion is not to build one.
///
/// The distro this exists for reached the opposite conclusion and shipped the
/// answer with it: EndeavourOS's Welcome app has a "do not show on startup"
/// checkbox, and stays in the menu forever after you tick it. So this is an
/// ordinary desklet in every respect that matters. It arrives on workspace one
/// through `starter`, its long press removes it exactly like a clock, and it
/// stays in the picker so it can come back. What the distro sells is that it
/// GREETS you, not that you cannot make it stop.
///
/// ─── EVERY WORD OF IT IS AUTHORED ───────────────────────────────────────────
///
/// `config['title']` and `config['rows']` come from the starter placement in
/// theme.json, which `StarterDesklet.fromJson` has always parsed and which
/// nothing has used until now. So Manjaro and Garuda can ship their own card
/// without a line of Dart, and EndeavourOS's copy is not baked into a widget
/// every distro shares.
///
/// The kind's defaults are EMPTY rather than EndeavourOS's, on purpose. A kind
/// that ships one distro's copy as its floor is a kind the next distro has to
/// fight, and a half-authored card that silently reads "Welcome to
/// EndeavourOS" on Manjaro is worse than one that draws nothing.
///
/// Nothing authored means nothing drawn: [DeskletBody.isEmpty] takes it from
/// there and [DeskletFrame] renders `SizedBox.shrink`, which is the same
/// contract a stat desklet with no readings follows.
class WelcomeDesklet extends ConsumerWidget {
  const WelcomeDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const kind = DeskletKinds.welcome;
    final title = kind.read<String>(desklet.config, 'title', '').trim();

    // Defensive on every field. This list arrives from a CDN theme.json that a
    // shipped APK has never seen, so a row that is not a map, or a map with no
    // label, is DROPPED rather than fatal. Same contract as PanelModule.parse
    // and BootLineKind: a card missing a line is a card, a theme that fails to
    // parse is a black screen.
    final raw = desklet.config['rows'] ?? kind.defaults['rows'];
    final rows = <({String label, String? url})>[
      for (final e in (raw is List ? raw : const []))
        if (e is Map)
          if (('${e['label'] ?? ''}').trim().isNotEmpty)
            (
              label: '${e['label']}'.trim(),
              url: ('${e['url'] ?? ''}').trim().isEmpty
                  ? null
                  : '${e['url']}'.trim(),
            ),
    ];

    final palette = theme.palette;
    // The skin decides whether the accent is spent on this card at all, the
    // same question every other kind asks it. A distro that wants a quiet
    // greeting sets `accent: false` and gets its own ink.
    final accent = skin.accent ? palette.accent : palette.onDark;
    final font = skin.font == DeskletFont.mono
        ? theme.typography.mono
        : theme.typography.display;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: font,
              fontSize: 13 * theme.textScale,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 7),
        ],
        for (final r in rows)
          _Row(
            theme: theme,
            font: font,
            label: r.label,
            // A row with no url draws and does nothing, deliberately: a distro
            // listing a step it cannot link to would otherwise have to leave
            // the step out of its own card.
            onTap: r.url == null ? null : () => _open(r.url!),
          ),
      ],
    );

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        // What a terminal skin echoes. `welcome` is a real EndeavourOS binary,
        // so the shell surface reads as a command someone actually ran.
        command: 'welcome',
        custom: (title.isEmpty && rows.isEmpty) ? null : content,
      ),
    );
  }

  /// External, because every row here points at a wiki, a forum or a store.
  ///
  /// Failure is SWALLOWED. A device with no browser, or a url a theme typed
  /// wrong, must not throw out of a tap on the desktop; the row simply does
  /// nothing, which is what a row with no url does anyway.
  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Intentionally silent. See the doc above.
    }
  }
}

/// One link line. A glyph, the label, and nothing else.
class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.font,
    required this.label,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String? font;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink =
        theme.palette.onDark.withValues(alpha: onTap == null ? 0.5 : 0.9);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              // One glyph for every row rather than a per-row icon field. The
              // rows are a list of places to go, and picking a different arrow
              // for each would be decoration the author has to maintain.
              Icons.chevron_right,
              size: 14 * theme.textScale,
              color: theme.palette.accent.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 11.5 * theme.textScale,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
