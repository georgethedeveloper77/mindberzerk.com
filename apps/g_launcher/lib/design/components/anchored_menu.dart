import 'package:flutter/material.dart';

import '../../engine/theme_spec.dart' show ChromeFamily;
import 'chrome_theme.dart';
import 'glass_panel.dart';
import 'themed_list_row.dart';

/// A context menu that opens beside the thing it is about.
///
/// ─── WHY THIS EXISTS: THERE WERE THREE OF IT ────────────────────────────────
///
/// The desklet menu, the folder-member menu and the drawer's overflow menu were
/// each written separately and each arrived at the same shape: a glass card,
/// clamped into the screen, below the anchor when there is room and above when
/// there is not. Three implementations of one idea, and they had already
/// drifted: 14 versus 16 corner radius, 220 versus 236 versus 244 width,
/// prefer-below versus prefer-above with no way to say which you wanted.
///
/// Two more menus still needed converting from bottom sheets. Writing the
/// arithmetic a fourth and fifth time is how the drift becomes permanent.
///
/// ─── THE CHILD IS MEASURED, NOT ESTIMATED ───────────────────────────────────
///
/// This is the part every copy got wrong in the same way, and it is the reason
/// the extraction is worth more than a tidy-up.
///
/// Each of them computed its own height before laying anything out:
///
///     final height = rowCount * rowH + pad;      // 52.0, or 56.0, plus 12
///
/// That number is a guess about a widget that has not been built yet, and it is
/// wrong the moment anything changes: a row that wraps to two lines, a larger
/// system font, a translation longer than the English, a subtitle added to one
/// row. The menu is then positioned against a height it does not have, so it
/// hangs off the bottom of the screen or floats above the anchor with a gap,
/// and the failure is invisible in English on the phone it was written on.
///
/// [CustomSingleChildLayout] hands the delegate the child's REAL size after it
/// has been laid out, so the position is computed from what will actually be
/// drawn. No row-height constant, no padding constant, no count. Adding a row
/// to any menu below is now just adding a row.
///
/// ─── THE ROUTE BOUNDARY ─────────────────────────────────────────────────────
///
/// `showGeneralDialog` pushes a route that is NOT a descendant of the caller's
/// [ChromeScope], so the chrome is passed in and re-provided inside, the same
/// rule [ThemedSheet] and [ThemedDialog] follow. Callers on the desktop build
/// their own [ChromeData] from the theme, because the shells are not guaranteed
/// to sit under a scope at all.
/// One of the three quick actions across the top of a menu.
///
/// Separate from [ThemedListRow] because it is drawn as a glyph over a word in
/// a third of the panel's width, not as a row: the label sits under the icon,
/// wraps to two lines, and has no subtitle. A row that needs a subtitle is not
/// a quick action and belongs in the list below.
class MenuAction {
  const MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// Runs AFTER the menu has closed, and that is not a detail.
  ///
  /// ─── THE POP IS THE PRIMITIVE'S JOB, NOT THE CALLER'S ────────────────────
  ///
  /// A row in [AnchoredMenu.rows] receives the menu's own context and pops it
  /// itself, which works and is a trap: the closure usually also needs the
  /// CALLER's context, for a message or a push, and the two look identical at
  /// the call site. Popping the wrong one closes the drawer instead of the
  /// menu, and the symptom is a whole screen vanishing when you tap Hide.
  ///
  /// So an action never pops. It closes over whatever context it likes and this
  /// runs once the panel is gone, which is also the right order for anything
  /// that opens a system screen.
  final VoidCallback onTap;

  /// Uninstall and its relatives.
  ///
  /// Red rather than the palette accent, and that is the one colour in this
  /// file that does not come from the distro. An accent is whatever the distro
  /// chose, so on Kali it is already red and every action would read as
  /// destructive, while on a green-accented distro nothing would. Destructive
  /// is a meaning rather than a decoration, and it needs the colour everyone
  /// already reads as one.
  final bool danger;
}

class AnchoredMenu {
  const AnchoredMenu._();

  /// Which side of the anchor to try FIRST.
  ///
  /// Both fall back to the other side when there is no room, so this is a
  /// preference and never a guarantee. It matters because the right first
  /// choice differs by surface: a menu about a drawer icon wants to open
  /// downward, and the drawer's own overflow button sits on a search bar at the
  /// bottom of the screen where downward is always off-screen.
  static const preferBelow = true;
  static const preferAbove = false;

  /// The rectangle a menu should open beside, for a widget that has one.
  ///
  /// Measured from the caller's own render box, which is what a menu about a
  /// TILE wants: the panel sits under the tile rather than under the point the
  /// finger happened to land on. A menu triggered by a pointer should pass that
  /// pointer position as a zero-size rect instead, which is what
  /// [Rect.fromCenter] with a width and height of one gives.
  ///
  /// Null when the box is not laid out, which the callers below treat the same
  /// way a missing anchor is treated: centred.
  static Rect? anchorOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Open the menu.
  ///
  /// [rows] receives the MENU's own context, which is what a row must pop. A
  /// row that pushes a further screen or sheet has to use a context that
  /// OUTLIVES this route, because the menu's own is dead the instant it pops
  /// and pushing onto a dead route silently does nothing. Callers pass their
  /// own context down for that.
  static Future<void> show({
    required BuildContext context,
    required ChromeData chrome,

    /// Null centres the menu, which is only reachable when a caller could not
    /// measure itself. Honest fallback rather than a crash or a corner.
    required Rect? anchor,
    required List<Widget> Function(BuildContext menuContext) rows,
    String? title,

    /// The three most common actions, drawn as glyphs across the top.
    ///
    /// ─── AND WHY THEY ARE NOT JUST MORE ROWS ────────────────────────────
    ///
    /// Because a menu about an APP has one or two things you came for and three
    /// or four you did not, and a flat list makes you read all of them every
    /// time. A row of glyphs is hit by muscle memory after the second use,
    /// which is the same argument `desktop_menu` already makes for its bar.
    ///
    /// THREE, not four. At a readable label size on a 360dp phone a fourth
    /// column forces the words to one line and then to an ellipsis, and an
    /// action nobody can read is worse than one more row. Anything past three
    /// goes in [rows] underneath.
    List<MenuAction> actions = const [],

    /// The (i) button beside the title. Null draws no button and no spacer.
    VoidCallback? onInfo,
    double width = 240,
    bool below = preferBelow,
    String barrierLabel = 'Dismiss',
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      // BARELY THERE, and lighter than a sheet's on purpose. A context menu is
      // not a modal: the entire reason it opens at the anchor is so the thing
      // it is about stays visible, and a heavy scrim throws that away.
      //
      // theme-exempt: a scrim is not chrome. It is a neutral dim over whatever
      // wallpaper is behind, and tinting it with the distro's palette would
      // colour the photograph underneath it.
      barrierColor: const Color(0x33000000), // theme-exempt: neutral scrim
      transitionDuration: const Duration(milliseconds: 130),
      pageBuilder: (menuContext, _, __) {
        final media = MediaQuery.of(menuContext);
        // ONCE. The builder can be a real build rather than a list literal,
        // and calling it twice to ask "are there any" would run every closure
        // and every provider read in it a second time.
        final rowWidgets = rows(menuContext);
        final asList = chrome.family == ChromeFamily.aqua;

        return ChromeScope(
          data: chrome,
          child: CustomSingleChildLayout(
            delegate: _AnchorDelegate(
              anchor: anchor ??
                  Rect.fromCenter(
                    center: media.size.center(Offset.zero),
                    width: 1,
                    height: 1,
                  ),
              safe: media.viewPadding,
              width: width,
              below: below,
            ),
            child: GlassPanel(
              child: Material(
                // Transparent: the glass paints. Material is here at all
                // because ThemedListRow draws ink and showGeneralDialog builds
                // outside the app's Scaffold, so there is no ancestor.
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(chrome.panelRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      _Header(
                        title: title,
                        chrome: chrome,
                        onInfo: onInfo,
                        menuContext: menuContext,
                      )
                    else
                      const SizedBox(height: 6),

                    // ── THE FORK IS ON THE FAMILY, NEVER ON THE DISTRO ──
                    //
                    // Eleven distros resolve into four families, and a twelfth
                    // needs no code here. Same rule `BootSpec.defaultForShell`
                    // states: keying on `theme.id == 'fedora'` is the trap the
                    // whole theme layer exists to avoid.
                    //
                    // Aqua takes the list. A Mac answers a long press with a
                    // plain vertical menu and no glyph strip, so giving it one
                    // would be the single least Mac-like thing on that shell.
                    // The actions are not lost: they fall into the rows below
                    // in the same order.
                    if (actions.isNotEmpty && !asList) ...[
                      _Actions(
                        actions: actions,
                        chrome: chrome,
                        menuContext: menuContext,
                      ),
                      if (rowWidgets.isNotEmpty)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: chrome.colors.line,
                        ),
                    ],
                    if (actions.isNotEmpty && asList)
                      for (final a in actions)
                        ThemedListRow(
                          icon: a.icon,
                          title: a.label,
                          danger: a.danger,
                          // Popped here too, so the Aqua list and the glyph row
                          // give an action the same contract.
                          onTap: () {
                            Navigator.pop(menuContext);
                            a.onTap();
                          },
                        ),
                    ...rowWidgets,
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          // A small scale rather than a slide. A slide has to know which
          // direction the menu ended up on, which the transition builder cannot
          // see; growing from slightly small reads as the menu coming OUT of
          // the thing it is anchored to, whichever side that turned out to be.
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// Positions the menu from its MEASURED size. See the class note.
class _AnchorDelegate extends SingleChildLayoutDelegate {
  const _AnchorDelegate({
    required this.anchor,
    required this.safe,
    required this.width,
    required this.below,
  });

  final Rect anchor;
  final EdgeInsets safe;
  final double width;
  final bool below;

  /// Between the anchor and the menu.
  static const double _gap = 8;

  /// Between the menu and the edge of the screen. Non-zero so a clamped menu
  /// never kisses the bezel, which reads as it having been cut off.
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The width is fixed and the height is free, which is what lets the child
    // report a real height for the delegate to position against.
    //
    // Clamped to the viewport, so a menu with more rows than the screen can
    // hold is capped rather than laid out past the bottom edge. A caller with
    // genuinely unbounded content wants a sheet, not a context menu.
    final maxW = constraints.maxWidth - _margin * 2;
    final maxH =
        constraints.maxHeight - safe.top - safe.bottom - _margin * 2;

    return BoxConstraints(
      minWidth: width > maxW ? maxW : width,
      maxWidth: width > maxW ? maxW : width,
      maxHeight: maxH < 0 ? 0 : maxH,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // ── HORIZONTAL: centred on the anchor, clamped into the screen ───────
    //
    // The clamp bounds are ordered before use. On a screen narrower than the
    // menu the max would fall below the min and `clamp` throws, which is a
    // crash on a tablet-sized menu on a small phone rather than a squeeze.
    const minX = _margin;
    final maxX = size.width - childSize.width - _margin;
    final x = maxX <= minX
        ? minX
        : (anchor.center.dx - childSize.width / 2).clamp(minX, maxX);

    // ── VERTICAL: the preferred side, then the other, then clamped ───────
    final topLimit = safe.top + _margin;
    final bottomLimit = size.height - safe.bottom - _margin - childSize.height;

    final under = anchor.bottom + _gap;
    final over = anchor.top - _gap - childSize.height;

    final double y;
    if (below) {
      y = under <= bottomLimit ? under : over;
    } else {
      y = over >= topLimit ? over : under;
    }

    return Offset(
      x,
      bottomLimit <= topLimit ? topLimit : y.clamp(topLimit, bottomLimit),
    );
  }

  @override
  bool shouldRelayout(_AnchorDelegate old) =>
      old.anchor != anchor ||
      old.safe != safe ||
      old.width != width ||
      old.below != below;
}

/// The app's name, centred, above everything else.
///
/// ─── CENTRED NEEDS AN INVISIBLE BOX ─────────────────────────────────────────
///
/// A centred title with a button on one side only is off-centre by half a
/// button, and it reads as sloppy rather than as centred. So the leading spacer
/// is exactly the trailing button's width and appears only when the button
/// does. It looks like nothing and it is the whole difference.
///
/// ─── TWO LINES, WRAPPING, AND NO ELLIPSIS ───────────────────────────────────
///
/// App names are long and this panel can simply be taller. `TextOverflow.fade`
/// rather than `ellipsis` past two lines: the ellipsis exists for a row whose
/// height is fixed by the list around it, and nothing here is.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.chrome,
    required this.menuContext,
    this.onInfo,
  });

  final String title;
  final ChromeData chrome;
  final BuildContext menuContext;
  final VoidCallback? onInfo;

  static const _button = 34.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onInfo == null ? 16 : 6, 12, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onInfo != null) const SizedBox(width: _button),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.fade,
              style: chrome.text.title,
            ),
          ),
          if (onInfo != null)
            SizedBox(
              width: _button,
              height: _button,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 19,
                // Pops FIRST. Info opens Android's app settings, and leaving
                // the menu up behind a system screen means coming back to a
                // panel about an app you may have just uninstalled.
                onPressed: () {
                  Navigator.pop(menuContext);
                  onInfo!();
                },
                icon: Icon(
                  Icons.info_outline,
                  color: chrome.colors.textMuted,
                ),
                tooltip: 'App info',
              ),
            ),
        ],
      ),
    );
  }
}

/// Three glyphs over words, evenly divided.
///
/// Shaped like `desktop_menu`'s bar on purpose: it is the same idea about a
/// different subject, and two idioms for "a row of quick actions" in one app
/// would be two things to keep in step.
/// The destructive red. See [MenuAction.danger] for why this is not from the
/// palette.
const _danger = Color(0xFFFF6B6B); // theme-exempt: destructive is a meaning, not a distro colour

class _Actions extends StatelessWidget {
  const _Actions({
    required this.actions,
    required this.chrome,
    required this.menuContext,
  });

  final List<MenuAction> actions;
  final ChromeData chrome;

  /// Popped before the action runs. See [MenuAction.onTap].
  final BuildContext menuContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.pop(menuContext);
                  a.onTap();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        a.icon,
                        size: 21,
                        color: a.danger ? _danger : chrome.colors.text,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        // Two lines here too, for the same reason as the title:
                        // "Add to home" does not fit one line in a third of a
                        // 236px panel, and it certainly does not fit in German.
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        style: chrome.text.caption.copyWith(
                          color: a.danger ? _danger : chrome.colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
