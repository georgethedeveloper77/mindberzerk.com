import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/components/components.dart';
import 'package:g_launcher/i18n/i18n.dart';
import '../../engine/desklet_skin.dart';
import '../../engine/effective_theme.dart';
// parseColor, for the accent swatches.
import '../../engine/theme_spec.dart' show parseColor;

/// Per-widget appearance: corners, background, accent.
///
/// ─── THESE ARE SKIN OVERRIDES, NOT A NEW MECHANISM ──────────────────────────
///
/// [DeskletSkin.props] is already free-form, already merged rather than
/// replaced, and [DeskletFrame] already reads `radius` and `opacity` out of it
/// because that is how a distro tunes its own card. So a user's per-widget
/// settings are the same three keys written to [Desklet.config], merged over
/// the distro's skin at render time in `desklet_surface`.
///
/// That ordering is the whole point and it matches every other preference in
/// the app: the distro provides the default, the person beats it. It also means
/// a widget with nothing set renders EXACTLY as it did before this screen
/// existed, because an absent key inherits.
///
/// ─── WHY THE ACCENT SWATCHES ARE A SHORT LIST ───────────────────────────────
///
/// A full colour picker was the obvious thing and it is the wrong one here.
/// This launcher's argument is that a distro owns its colour; handing every
/// tile an arbitrary hex turns a GNOME desktop into a dashboard. The list is
/// the distro's own accent, a handful that read on any wallpaper, and "follow
/// the distro", which CLEARS the key rather than writing today's accent, so a
/// tile set to follow keeps following when the distro changes.
/// KEYS, not sentences. These are top-level `const`, so they cannot call
/// `context.t` at all: a const list is built before any widget exists. The
/// labels resolve where they are drawn, which is the same shape `_taglineKeyFor`
/// takes in setup and for the same reason.
const _cornerChoices = <({String labelKey, double radius})>[
  (labelKey: 'settings.square', radius: 0),
  (labelKey: 'settings.rounded', radius: 10),
  (labelKey: 'desklets.pill', radius: 22),
];

const _backgroundChoices = <({String labelKey, double opacity})>[
  (labelKey: 'desklets.none', opacity: 0),
  (labelKey: 'settings.light', opacity: 0.35),
  (labelKey: 'settings.medium', opacity: 0.62),
  (labelKey: 'desklets.solid', opacity: 0.92),
];

/// theme-exempt: a per-widget accent is by definition not the theme's, and this
/// is the fixed set offered beside it. The first entry is null, meaning follow.
const _accentChoices = <String?>[
  null,
  '#22D3EE',
  '#4ADE80',
  '#FBBF24',
  '#F472B6',
  '#A78BFA',
];

Future<void> showDeskletSettings(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  Desklet desklet,
) {
  return ThemedSheet.show<void>(
    context,
    title: context.t('desklets.widgetSettings'),
    builder: (sheet) => _Body(theme: theme, deskletId: desklet.id),
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.theme, required this.deskletId});

  final EffectiveTheme theme;
  final String deskletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);

    // LIVE, not the snapshot handed in. Every control below writes and the
    // sheet stays open, so reading the desklet off the push-time value would
    // show the old selection until it was closed and reopened.
    final live = ref.watch(prefsProvider(theme.spec.id)).hasValue
        ? ref.watch(prefsProvider(theme.spec.id)).requireValue
        : theme.prefs;

    final desklet = DeskletLayout.byId(live, deskletId);
    if (desklet == null) return const SizedBox.shrink();

    final config = desklet.config;

    void write(Map<String, Object?> patch) {
      HapticFeedback.selectionClick();
      // configure MERGES, so writing corners cannot drop the accent, and a key
      // written by a newer build survives being edited here.
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => DeskletLayout.configure(p, deskletId, patch),
          );
    }

    // A hosted third-party widget draws its own contents, so only its frame is
    // ours to shape. Saying so beats offering two controls that do nothing.
    final hosted = desklet.kind == 'appwidget';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(text: context.t('desklets.corners')),
          _Choices(
            labels: [for (final c in _cornerChoices) context.t(c.labelKey)],
            selected: _nearestCorner(config['radius']),
            onPick: (i) => write({'radius': _cornerChoices[i].radius}),
          ),
          if (hosted) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                context.t('desklets.hostedNote'),
                style: d.text.caption.copyWith(color: d.colors.textMuted),
              ),
            ),
          ] else ...[
            _Label(text: context.t('desklets.background')),
            _Choices(
              labels: [for (final b in _backgroundChoices) context.t(b.labelKey)],
              selected: _nearestBackground(config['opacity']),
              onPick: (i) => write({'opacity': _backgroundChoices[i].opacity}),
            ),
            _Label(text: context.t('desklets.accent')),
            _Swatches(
              themeAccent: theme.palette.accent,
              selected: config['accentHex'] as String?,
              onPick: (hex) => write({'accentHex': hex}),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(
                context.t('desklets.followsDistro'),
                style: d.text.caption.copyWith(color: d.colors.textFaint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Which corner choice a stored radius corresponds to. Nearest rather than
  /// exact, so a value authored by a theme's skin still lights a button up
  /// instead of leaving all three dark.
  static int _nearestCorner(Object? raw) {
    final v = raw is num ? raw.toDouble() : 10.0;
    var best = 0;
    for (var i = 1; i < _cornerChoices.length; i++) {
      if ((_cornerChoices[i].radius - v).abs() <
          (_cornerChoices[best].radius - v).abs()) {
        best = i;
      }
    }
    return best;
  }

  static int _nearestBackground(Object? raw) {
    final v = raw is num ? raw.toDouble() : 0.72;
    var best = 0;
    for (var i = 1; i < _backgroundChoices.length; i++) {
      if ((_backgroundChoices[i].opacity - v).abs() <
          (_backgroundChoices[best].opacity - v).abs()) {
        best = i;
      }
    }
    return best;
  }
}

/// Turn a desklet's config into the skin overrides [DeskletFrame] reads.
///
/// Lives here rather than in the surface so the writer and the reader of these
/// three keys sit in one file. An absent key stays absent, which is what makes
/// [DeskletSkin.mergedWith] inherit the distro's value rather than overwrite it
/// with a manufactured default; that is the exact bug the skin's own doc
/// describes at length.
DeskletSkin skinOverridesFor(Desklet desklet) {
  final c = desklet.config;

  return DeskletSkin(
    props: {
      if (c['radius'] is num) 'radius': c['radius'],
      if (c['opacity'] is num) 'opacity': c['opacity'],
      if (c['accentHex'] is String) 'accentHex': c['accentHex'],
    },
  );
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Text(
        text,
        style: d.text.label.copyWith(color: d.colors.textMuted),
      ),
    );
  }
}

/// A segmented row. Built here rather than reaching for a primitive, the same
/// call `_SuggestionRow` in folders_screen makes: it is a few tokens and a Row,
/// and it needs no configuration surface of its own.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.labels,
    required this.selected,
    required this.onPick,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == selected ? c.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: d.text.caption.copyWith(
                        color: i == selected ? c.onAccent : c.text,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.themeAccent,
    required this.selected,
    required this.onPick,
  });

  final Color themeAccent;
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final hex in _accentChoices)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(hex),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    // The first swatch shows the distro's own accent, but picks
                    // NULL, so a tile set to follow keeps following when the
                    // distro changes rather than freezing today's colour.
                    color: hex == null
                        ? themeAccent
                        : (parseColor(hex) ?? themeAccent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hex == selected ? c.text : c.line,
                      width: hex == selected ? 2.5 : 1,
                    ),
                  ),
                  child: hex == null
                      ? Icon(Icons.auto_awesome, size: 14, color: c.onAccent)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
