import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

@immutable
class GNavItem {
  const GNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Custom bar rather than Material 3 NavigationBar.
///
/// NavigationBar hard codes a 80dp height, owns its own indicator geometry, and
/// applies a surface tint that has to be fought back with three overrides. The
/// design calls for a 62dp bar with a hairline top edge and a pill indicator
/// that hugs the icon. Writing it is less code than overriding it.
class GBottomNav extends StatelessWidget {
  const GBottomNav({
    required this.items,
    required this.index,
    required this.onSelected,
    super.key,
  });

  final List<GNavItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(top: BorderSide(color: t.line)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: GSpace.navHeight,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _GNavCell(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GNavCell extends StatelessWidget {
  const _GNavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Color tone = selected ? t.accentText : t.dim;

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: GMotion.fast,
              curve: GMotion.enter,
              width: GSpace.navPillWidth,
              height: GSpace.navPillHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.accentSoft : const Color(0x00000000),
                borderRadius: GRadius.all(GRadius.chip),
              ),
              child: Icon(item.icon, size: GSpace.navIcon, color: tone),
            ),
            const SizedBox(height: GSpace.xs),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.navLabel.copyWith(
                color: tone,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
