import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_enter.dart';

/// One destination in the index.
class DeviceEntry {
  const DeviceEntry({
    required this.label,
    required this.icon,
    required this.hue,
    required this.open,
    this.value,
  });

  final String label;
  final IconData icon;
  final Color hue;
  final void Function(BuildContext) open;

  /// A figure under the label.
  ///
  /// "Battery" is a label. "Battery, 94%" is a reason to tap. Null where the
  /// reading is absent, which renders as the label alone rather than a dash.
  final String? value;
}

/// THE INDEX, as circles.
///
/// Four across, three deep, the pattern every device information app converged
/// on because it is the right one for a catalogue: a dozen equal destinations
/// where the label is the whole content and nothing needs a value beside it.
///
/// ─── ONLY WHAT EXISTS ────────────────────────────────────────────────────────
///
/// Entries are passed in rather than declared here, so the grid can never show a
/// bubble for a page that has not been built. A catalogue whose tiles lead
/// nowhere is worse than a shorter catalogue, and it is the failure mode this
/// screen invites: the layout makes adding one entry feel free.
class DeviceIndex extends StatelessWidget {
  const DeviceIndex({required this.entries, super.key});

  final List<DeviceEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // Taller than wide, because the label sits under the circle and a
        // two word entry has to wrap without clipping.
        childAspectRatio: 0.82,
        crossAxisSpacing: 4,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) => GEnter(
        index: index,
        child: _Bubble(entry: entries[index]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry});

  final DeviceEntry entry;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => entry.open(context),
        borderRadius: GRadius.all(GRadius.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.hue.withValues(
                  alpha: t.brightness == Brightness.dark ? 0.2 : 0.14,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.icon, size: 22, color: entry.hue),
            ),
            const SizedBox(height: GSpace.sm - 2),
            Flexible(
              child: Text(
                entry.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GType.micro.copyWith(color: t.text),
              ),
            ),
            // Outside the Flexible, not inside it. Flexible takes one child,
            // so the first version put this where the label's own arguments go.
            if (entry.value != null)
              Text(
                entry.value!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.monoSmall.copyWith(color: t.dim, fontSize: 9.5),
              ),
          ],
        ),
      ),
    );
  }
}
