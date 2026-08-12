import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../engine/effective_theme.dart';
import '../../engine/widget_span.dart';
import '../../platform/launcher_api.g.dart' as api;
import 'desklet_cell.dart';
import 'widget_catalog.dart';

/// One third-party widget, presented as a card rather than a list row.
///
/// ─── WHY THE PREVIEW IS FULL WIDTH AND ITS HEIGHT IS NOT FIXED ──────────────
///
/// The row this replaces put every preview in the same 96x64 box. A 4x1 media
/// bar and a 2x2 tile letterboxed into one rectangle are both the wrong shape,
/// and a preview of the wrong shape is a preview of a different widget: the
/// single largest reason our picker read as a cheap version of the stock one.
///
/// So the preview spans the card and its HEIGHT comes from the provider's own
/// aspect. A 4x1 draws as a band, a 4x2 as a block, and what you see is the
/// footprint you are about to spend. It is also the only size at which the
/// native `previewLayout` render is legible enough to be worth doing.
///
/// ─── THE SPAN LABEL IS IN ANDROID'S CELLS, NOT OURS ─────────────────────────
///
/// "4 × 1" here means what it means in every other launcher and in the widget's
/// own store listing, which is the number the user recognises. It deliberately
/// does NOT describe our grid: the desklet grid is finer, so the same widget
/// occupies a different number of OUR cells, and [_pickWidget] already does that
/// conversion when it places one. Two different numbers for two different jobs,
/// and this is the one the user reads.
class WidgetProviderCard extends ConsumerWidget {
  const WidgetProviderCard({
    super.key,
    required this.theme,
    required this.provider,
    required this.onPlace,
  });

  final EffectiveTheme theme;
  final api.WidgetProviderInfo provider;
  final void Function(api.WidgetProviderInfo) onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => onPlace(provider),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: p.onDark.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.onDark.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  if (!w.isFinite || w <= 0) return const SizedBox.shrink();
                  return _Preview(
                    theme: theme,
                    provider: provider,
                    width: w,
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                provider.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 14,
                  color: p.onDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                spanLabel(provider),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 11.5,
                  color: p.onDark.withValues(alpha: 0.5),
                ),
              ),
              // ─── THE PROVIDER'S OWN PITCH ─────────────────────────────
              //
              // "Play your favs and find new tunes, right from your home
              // screen." The stock picker prints this and it is most of why a
              // widget reads there as a considered offer rather than as a row
              // in a list.
              //
              // ABSENT, not empty. A provider that never set a description, or
              // any device below API 31, renders no line at all rather than a
              // gap where one would be. Same rule the nullable stats follow
              // everywhere else in this app.
              if (provider.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  provider.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    fontSize: 12.5,
                    height: 1.35,
                    color: p.onDark.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The preview itself, sized from the provider's aspect and replaced by the
/// bitmap's OWN aspect once it arrives.
///
/// Two aspects rather than one, because they answer different questions. The
/// declared footprint is what reserves the right amount of vertical space
/// BEFORE the native render returns, so the list does not jump as previews
/// stream in. The bitmap's aspect is the truth once there is a bitmap: a
/// `previewImage` is a picture whose proportions are its own, and forcing it
/// back into the declared shape would reintroduce the stretch.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.theme,
    required this.provider,
    required this.width,
  });

  final EffectiveTheme theme;
  final api.WidgetProviderInfo provider;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;

    // ─── THE SHAPE IT WILL ACTUALLY OCCUPY, ON THIS DISTRO'S GRID ─────────
    //
    // Resolved through the same `WidgetSpanResolver` that places the widget, so
    // the preview is the rectangle you are about to spend rather than the
    // provider's own idea of its proportions. Switch distros and this changes,
    // because the widget genuinely would. No other launcher does that.
    //
    // Falls back to the declared footprint before any desktop has laid out,
    // which is the picker's first frame on a cold start and nothing else.
    final cell = ref.watch(deskletCellProvider);
    final aspect = cell == null
        ? _aspect(provider)
        : () {
            final span = WidgetSpanResolver.resolve(
              widgetFootprint(provider),
              cell: cell,
              colFactor: DeskletLayout.colFactor,
              rowFactor: DeskletLayout.rowFactor,
            );
            return WidgetSpanResolver.aspectOf(span.spanX, span.spanY, cell: cell);
          }();

    // Capped so a 1x4 tower does not turn one widget into a full screen, and
    // floored so a very wide, very short strip is still tappable and visible.
    final height = (width / aspect).clamp(64.0, 260.0);

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final req = (
      providerKey: provider.providerKey,
      width: (width * dpr).round(),
      height: (height * dpr).round(),
    );
    final preview = ref.watch(widgetPreviewProvider(req));

    return SizedBox(
      width: width,
      height: height,
      child: preview.maybeWhen(
        data: (bytes) => bytes == null
            ? _fallback(p.onDark)
            // contain, never cover: the native side already returned a bitmap
            // at the right shape, so this only absorbs rounding. cover would
            // crop a preview that is correct.
            : Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
        orElse: () => _fallback(p.onDark),
      ),
    );
  }

  Widget _fallback(Color onDark) => Center(
        child: Icon(
          Icons.widgets_outlined,
          size: 24,
          color: onDark.withValues(alpha: 0.30),
        ),
      );
}

/// Width over height, from whichever of the two footprints the provider gave.
double _aspect(api.WidgetProviderInfo p) {
  if (p.targetCellWidth > 0 && p.targetCellHeight > 0) {
    return p.targetCellWidth / p.targetCellHeight;
  }
  if (p.minWidthDp > 0 && p.minHeightDp > 0) {
    return p.minWidthDp / p.minHeightDp;
  }
  return 1;
}

/// "4 × 1", in Android's nominal cells.
///
/// `targetCellWidth`/`targetCellHeight` say it outright on Android 12+, and
/// where they are absent the platform's own published relationship recovers it:
/// a widget spanning n cells declares a minimum of `70n - 30` dp, so n is
/// `(minWidthDp + 30) / 70` rounded up. That formula is why a 4-cell widget
/// declares 250dp rather than 280 and is the reason a naive divide-by-70 reads
/// every widget one cell short.
String spanLabel(api.WidgetProviderInfo p) {
  final cols = p.targetCellWidth > 0 ? p.targetCellWidth : _cells(p.minWidthDp);
  final rows = p.targetCellHeight > 0 ? p.targetCellHeight : _cells(p.minHeightDp);
  return '$cols \u00d7 $rows';
}

int _cells(int dp) {
  if (dp <= 0) return 1;
  return ((dp + 30) / 70).ceil().clamp(1, 8);
}
