import 'package:flutter/material.dart';

import '../../../data/prefs/desklet_layout.dart';
import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';

/// Several widgets sharing one footprint.
///
/// ─── WHY THIS DRAWS ITS MEMBERS RATHER THAN OWNING THEM ─────────────────────
///
/// A stack holds ids, and each member is an ordinary [Desklet] parked on
/// [DeskletLayout.stackedPage]. So this looks them up and hands each to the
/// SAME builder the desktop uses. Nothing about a clock changes because it is
/// in a stack, which is the property that stops this becoming a second
/// rendering path that slowly disagrees with the first.
///
/// ─── THE DOTS ARE THE ONLY CHROME IT ADDS ───────────────────────────────────
///
/// A stack is a container, and a container that decorates itself competes with
/// the thing it contains. One row of dots, small, at the bottom edge, which is
/// the convention every phone already uses for exactly this.
///
/// ─── ONE PAGE IS BUILT AT A TIME, AND THAT MATTERS FOR HOSTED WIDGETS ───────
///
/// [PageView] is lazy, so only the visible member and its immediate neighbour
/// exist. For a drawn desklet that is a small saving. For a hosted AppWidget it
/// is the difference between one live `AppWidgetHostView` and one per member,
/// each holding a native allocation and each being pushed size updates. A stack
/// of four widgets that hosted all four at once would cost more than the four
/// tiles it replaced.
class StackDesklet extends StatefulWidget {
  const StackDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
    required this.build,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  /// `buildDesklet` from the surface, passed in rather than imported.
  ///
  /// The surface's switch is what knows how to draw every kind, and it already
  /// imports this file's siblings. Importing it back would be a cycle, so the
  /// function comes in as a parameter: this widget needs to draw arbitrary
  /// kinds without knowing what they are.
  final Widget? Function(EffectiveTheme, Desklet, DeskletSkin) build;

  @override
  State<StackDesklet> createState() => _StackDeskletState();
}

class _StackDeskletState extends State<StackDesklet> {
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      final p = (_controller.page ?? 0).round();
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        DeskletLayout.stackContents(widget.theme.prefs, widget.desklet.id);

    // An empty or single-member stack should not exist: `removeFromStack`
    // dissolves at one. This is the floor for a prefs file written by hand or
    // by a newer build, and it draws the survivor rather than a broken frame.
    if (members.isEmpty) return const SizedBox.shrink();
    if (members.length == 1) {
      return widget.build(widget.theme, members.first, widget.skin) ??
          const SizedBox.shrink();
    }

    final ink = widget.theme.palette.onDark;

    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _controller,
            itemCount: members.length,
            itemBuilder: (context, i) {
              // Each member is drawn with the STACK's skin, so a distro's card
              // styling and any per-widget override on the stack apply to the
              // whole stack rather than making each page look like a different
              // desktop.
              return widget.build(widget.theme, members[i], widget.skin) ??
                  const SizedBox.shrink();
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < members.length; i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink.withValues(alpha: i == _page ? 0.85 : 0.30),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
