/// The Spatial Desktop: every workspace at once, on a hold or a pinch.
///
/// ─── WHY THIS IS AN OVERLAY AND NOT A PAGE ──────────────────────────────────
///
/// The obvious build is another entry in the pager, the way the apps page is
/// one. It is wrong for the same reason `appsPageProvider` documents in
/// reverse: the apps page is a DESTINATION you swipe to and stay on, and an
/// overview is a MODE you enter, act in, and leave. Making it a page would mean
/// the overview has an index, that index competes with the apps page for "last
/// page", and `ActiveWorkspace.goTo` would clamp against a number that changes
/// depending on whether you happen to be zoomed out.
///
/// So it sits above the shell in `home_screen`, owns back through the one
/// PopScope there, and the pager underneath never learns it exists.
///
/// ─── AND WHY THE CARDS ARE THE REAL PAGES, SCALED ───────────────────────────
///
/// The cheap version paints coloured rectangles with the palette. That is what
/// `DevicePreview` does for the settings tiles and it is right there, because a
/// settings tile is describing a distro you have not installed. This is
/// describing YOUR workspace, and the entire question the user is asking is
/// "which one has my clock on it". A rectangle cannot answer that.
///
/// So each card mounts the same `HomeGrid` and `DeskletSurfaceView` the page
/// itself does, inside a `Transform.scale`. `PageView.builder` only keeps the
/// visible cards and their immediate neighbours alive, so this is three pages
/// mounted rather than five, which is what the desktop already costs while you
/// swipe.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/branded_message.dart';
import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
// WorkspaceAxis only. The overview asks the same field the canvas does.
import '../../../engine/theme_spec.dart' show WorkspaceAxis;
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_surface.dart';
import '../gnome/desktop_menu.dart';
import '../home_grid.dart';
import 'workspace_controller.dart';
import 'workspace_dots.dart';

/// ─── EVERY POSITION IS A FRACTION OF THE SCREEN ────────────────────────────
///
/// This surface was a Column: a home mark, then an Expanded pager, then the
/// control row, then the bar. That makes every vertical position a consequence
/// of everything above it, so the card's height was 92% of a band whose size
/// depended on the glyph, the row and the bar, and the only way to move one
/// thing was to guess at a number and look.
///
/// Measured off the reference, the card is 65% of the SCREEN's height and its
/// top edge is at 12.8% of it. Those are facts about the screen and they do not
/// change when the bar grows a second line of labels. So the layout is a Stack
/// of positioned children at literal fractions, each one checkable against the
/// measurement it came from.
///
/// The gap is the only one measured along the RUN rather than down the screen,
/// because it is what separates one card from the next, and the run is
/// sideways on a horizontally-paging distro.
const _cardWidth = 0.75;
const _cardHeight = 0.64;
const _cardTop = 0.135;
const _cardGap = 0.05;
const _homeMarkTop = 0.103;
const _rowTop = 0.818;

/// How far the pager's band stops short of the control row.
///
/// Without it the band's edge and the row's top are the same line, and a card
/// scrolling past leaves a hairline of itself under the dots.
const _rowClearance = 0.015;
const _barTop = 0.884;

/// Is the overview open?
///
/// A [Notifier] rather than a `StateProvider` so the two verbs are named. Six
/// places will eventually want to close this and `state = false` at each of
/// them is how `openApps` ended up existing.
final workspaceOverviewProvider =
    NotifierProvider<WorkspaceOverviewOpen, bool>(WorkspaceOverviewOpen.new);

class WorkspaceOverviewOpen extends Notifier<bool> {
  @override
  bool build() => false;

  /// ─── REFUSED DURING EDIT MODE ───────────────────────────────────────────
  ///
  /// Desklet editing is a per-page arrangement with a drag in progress and an
  /// edit bar explaining itself. Zooming out mid-drag would leave the pointer
  /// holding a desklet that is now a sixth of its size on a page that is no
  /// longer under it. `workspace_canvas` already takes the pager's physics away
  /// for exactly this reason; this is the same refusal one layer up.
  void open() {
    if (ref.read(deskletEditProvider).active) return;
    if (!state) state = true;
  }

  void close() {
    if (state) state = false;
  }

  void toggle() => state ? close() : open();
}

/// The overview itself. Mounted above the shell, drawn only when open.
class WorkspaceOverview extends ConsumerStatefulWidget {
  const WorkspaceOverview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<WorkspaceOverview> createState() => _WorkspaceOverviewState();
}

class _WorkspaceOverviewState extends ConsumerState<WorkspaceOverview> {
  PageController? _pages;

  /// How much of the run one card takes.
  ///
  /// ─── ONE CARD, NOT THREE ────────────────────────────────────────────────
  ///
  /// This was 0.62, chosen so the current card sat whole between two visible
  /// neighbours and the set read as a strip. On the device it reads as three
  /// competing thumbnails, and the card you came to look at is small enough
  /// that the desktop inside it is a texture rather than a picture of anything.
  ///
  /// Sizing now lives in the constants at the head of this file.

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(workspaceOverviewProvider);
    if (!open) {
      // Disposed on close rather than kept, so reopening always lands on the
      // live workspace instead of wherever the user last scrolled to and then
      // backed out of.
      _pages?.dispose();
      _pages = null;
      return const SizedBox.shrink();
    }

    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final theme = widget.theme;
    final palette = theme.palette;

    final screen = MediaQuery.sizeOf(context);
    final horizontal = theme.workspaceAxis == WorkspaceAxis.horizontal;

    // ─── THE BAND IS BOUNDED BY THE ROW, AND IT WAS NOT ─────────────────
    //
    // The band was sized to card-plus-two-gaps from [_cardTop] downward, which
    // put its bottom edge at 82.8% while the control row sits at 80%. On the
    // device the next card carried on straight through the dots and behind the
    // bar, which reads as the pager having escaped its box.
    //
    // The cause is not a bad number, it is that the reference cannot be copied
    // exactly on this axis. Samsung's gap runs SIDEWAYS, across a dimension
    // nothing else competes for. Ours runs down the screen on a vertical distro
    // and the row is already standing there, so the card, its two gaps and the
    // row all want the same band. Something has to give, and it is the card:
    // shortened until it and its gaps fit above the row.
    //
    // A horizontal distro keeps the measured 65% exactly, because there the gap
    // costs width instead.
    final bandTop = screen.height * (_cardTop - _cardGap);
    final bandBottom = screen.height * (_rowTop - _rowClearance);
    final bandHeight = bandBottom - bandTop;
    final cardHeightPx = horizontal
        ? screen.height * _cardHeight
        : bandHeight - screen.height * _cardGap * 2;

    // Derived, not chosen: the card's share of the run. Move [_cardWidth],
    // [_cardGap] or [_rowTop] and this follows, which is what the previous
    // hand-picked number could never do.
    _pages ??= PageController(
      initialPage: active.clamp(0, count - 1),
      viewportFraction: horizontal
          ? _cardWidth + _cardGap * 2
          : cardHeightPx / bandHeight,
    );

    return Material(
      // theme-exempt: the wash below paints the distro's own colour; Material
      // must not put an opaque slab under it.
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(workspaceOverviewProvider.notifier).close(),
              child: ColoredBox(
                // 0.82 let the live desktop through clearly enough that a
                // desklet appeared twice, once behind the wash and once in the
                // card, which reads as the overview having failed to cover the
                // screen rather than as translucency.
                color: palette.bgBottom.withValues(alpha: 0.98),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // ─── POSITIONED, NOT STACKED IN A COLUMN ────────────────────────
          //
          // See the constants at the head of this file. Each `top` below is the
          // measurement it is named after, so a position can be checked against
          // the reference without running the app.
          //
          // No SafeArea. These fractions are of the whole screen, which is what
          // was measured, and insetting them by the status bar would shift
          // every one of them by a different amount on every device.
          Positioned(
            top: screen.height * _homeMarkTop,
            left: 0,
            right: 0,
            child: Center(
              // ─── A MARK, NOT A TITLE ──────────────────────────────────
              //
              // The word WORKSPACES in accent caps sat here and the reference
              // has nothing like it: a mode that took over the whole screen
              // does not need to announce itself, and the label was the
              // loudest thing on a surface whose subject is a card.
              //
              // Decorative on purpose, so nothing here competes with the card
              // for the tap.
              child: Icon(
                Icons.home_outlined,
                size: 20,
                color: palette.onDark.withValues(alpha: 0.7),
              ),
            ),
          ),
          // The band is the card plus one gap either side. It is what CLIPS the
          // neighbours: they are full size and simply run out of it, which is
          // the shape the reference has and the reason nothing here is scaled
          // down to suggest depth.
          Positioned(
            top: bandTop,
            left: 0,
            right: 0,
            height: bandHeight,
            child: PageView.builder(
                  controller: _pages,
                  scrollDirection:
                      horizontal ? Axis.horizontal : Axis.vertical,
                  // ─── ONE MORE THAN THERE ARE, UNTIL THE CEILING ───────
                  //
                  // The extra index is the ADD card: swipe past the last
                  // workspace and there is a place for the next one, with a
                  // plus in it. Adding a page happens where the page will be
                  // rather than at a button somewhere else, which is also why
                  // the control row can stay as sparse as it is.
                  //
                  // It disappears at [WorkspaceCount.max], because a slot you
                  // can reach and cannot use is worse than no slot.
                  itemCount: count < WorkspaceCount.max ? count + 1 : count,
                  // ─── SCROLLING RETARGETS, AND IT DID NOT ──────────────
                  //
                  // This had no `onPageChanged`, so the overview's own scroll
                  // position and `activeWorkspaceProvider` were unrelated:
                  // the dots stayed on the desktop's page and, worse, the
                  // trash deleted whatever the DESKTOP was on rather than the
                  // card in front of you. Swiping two cards along and tapping
                  // delete took the wrong workspace.
                  //
                  // Guarded on the add card, which is not a workspace and has
                  // no index to go to.
                  onPageChanged: (page) {
                    if (page >= count) return;
                    ref.read(activeWorkspaceProvider.notifier).goTo(page);
                  },
                  itemBuilder: (context, page) => page >= count
                      ? _AddCard(
                          theme: theme,
                          height: cardHeightPx,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(workspaceCountProvider.notifier)
                                .set(count + 1);
                          },
                        )
                      : _Card(
                          theme: theme,
                          page: page,
                          height: cardHeightPx,
                          onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(activeWorkspaceProvider.notifier).goTo(page);
                      ref.read(workspaceOverviewProvider.notifier).close();
                    },
                  ),
                ),
          ),
          Positioned(
            top: screen.height * _rowTop,
            left: 0,
            right: 0,
            child: _Pages(theme: theme, count: count),
          ),
          Positioned(
            top: screen.height * _barTop,
            left: 0,
            right: 0,
            child:               ChromeScope(
                data: ChromeData.fromPalette(
                  palette,
                  typography: theme.typography,
                  textScale: theme.textScale,
                  family: theme.chromeFamily,
                  opacity: theme.surfaceOpacity,
                  panelBlur: theme.panelBlur,
                  panelTint: theme.panelTint,
                  panelRadius: theme.panelRadius,
                ),
                child: DesktopActionBar(
                  theme: theme,
                  // LABELS STAY. The glyph-only argument was made against a
                  // six-column bar squeezed under a three-card strip; the
                  // reference keeps its words, wraps them to two lines, and
                  // fits five comfortably. Six is the case that will not, and
                  // that is a per-distro answer rather than a global one.
                  showLabels: true,
                  plated: false,
                  actions: desktopActions(
                    context: context,
                    ref: ref,
                    theme: theme,
                    navigator: Navigator.of(context),
                    // THE OVERVIEW IS NOT A ROUTE. There is nothing to pop:
                    // it is a Stack layer toggled by a provider, so going
                    // away means closing that. This is the one thing the two
                    // surfaces do differently and it is why `desktopActions`
                    // takes a callback at all.
                    dismiss: () => ref
                        .read(workspaceOverviewProvider.notifier)
                        .close(),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

/// One workspace, at the measured size.
///
/// ─── NO TRANSFORM ANY MORE ──────────────────────────────────────────────────
///
/// This rotated and shrank by distance from centre, on the reasoning that a
/// strip of cards needs depth to read as a strip. Both settled at zero once the
/// reference was measured with content in it: its neighbours are full size and
/// simply run off the screen edge, and the depth is between the card and the
/// SCREEN rather than between the cards.
///
/// At zero the AnimatedBuilder was still rebuilding this subtree on every pixel
/// of every scroll to apply an identity matrix, so it is gone, and with it the
/// controller this widget no longer has any reason to hold.
class _Card extends StatelessWidget {
  const _Card({
    required this.theme,
    required this.page,
    required this.height,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final int page;

  /// Resolved by the owner, because on a vertical pager it depends on where the
  /// control row is and this widget has no business knowing that.
  final double height;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final screen = MediaQuery.sizeOf(context);

    return Center(
      // BOTH DIMENSIONS FROM THE SCREEN. Width was already measured this way;
      // height used to be whatever the pager handed down, which is what made it
      // depend on the size of the bar underneath it.
      child: SizedBox(
        width: screen.width * _cardWidth,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Quiet. At this size the card is the subject, and a strong plate
              // with a bright edge reads as a panel laid over the desktop
              // rather than as the desktop seen from further away.
              color: palette.bgTop.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.onDark.withValues(alpha: 0.10),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _Miniature(theme: theme, page: page),
            ),
          ),
        ),
      ),
    );
  }
}

/// The slot after the last workspace: tap it to make one.
///
/// ─── SAME BOX AS A CARD, DELIBERATELY EMPTY ─────────────────────────────────
///
/// It takes the padding and the aspect of [_Card] so the strip does not jump
/// when you swipe onto it, and it is quieter in every other respect: a lower
/// fill and a lighter edge, because it is a place rather than a page.
///
/// NO DASHES. A dashed border needs a CustomPainter in Flutter, and a painter
/// for one hairline on one card would be the most code in this file for the
/// least of it. The weight difference carries the same meaning.
class _AddCard extends StatelessWidget {
  const _AddCard({
    required this.theme,
    required this.height,
    required this.onTap,
  });

  final EffectiveTheme theme;

  /// The same height the real cards get, so the strip does not change size when
  /// you swipe onto the end of it.
  final double height;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: EdgeInsets.zero,
      child: Center(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * _cardWidth,
          height: height,
          child: Semantics(
            button: true,
            label: context.t('home.addWorkspace'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.bgTop.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: palette.onDark.withValues(alpha: 0.14),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 34,
                    color: palette.onDark.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's real contents, scaled to fit the card.
///
/// ─── LAID OUT AT SCREEN SIZE, THEN SHRUNK ───────────────────────────────────
///
/// Not laid out at card size. `HomeGrid` and `DeskletSurfaceView` compute cell
/// geometry from the constraints they are given, so building them inside a
/// 200dp box produces a genuinely different arrangement: a desklet spanning two
/// columns might wrap, and the card would then be an honest picture of a
/// desktop that does not exist.
///
/// `OverflowBox` hands them the full screen and `Transform.scale` shrinks the
/// result, so what you see is the page you will land on, smaller.
class _Miniature extends StatelessWidget {
  const _Miniature({required this.theme, required this.page});

  final EffectiveTheme theme;
  final int page;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // ─── BY WIDTH, AND THE CARD'S WIDTH IS THE ZOOM ─────────────────
        //
        // Contain was tried and it belongs with an aspect-locked card, which
        // this no longer is. Against a box that is 75% wide and taller than
        // that in proportion, the smaller ratio is the width one anyway, so
        // this is the same number with none of the machinery.
        //
        // `alignment: topCenter` below is what makes the crop land on the
        // BOTTOM, which is the only place it can: the top of a desktop is where
        // its clock and its desklets are.
        final scale = constraints.maxWidth / screen.width;

        return IgnorePointer(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: 0,
            maxWidth: screen.width,
            minHeight: 0,
            maxHeight: screen.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: screen.width,
                height: screen.height,
                child: Stack(
                  children: [
                    if (theme.desktopIcons)
                      Positioned.fill(
                        child: HomeGrid(theme: theme, page: page),
                      ),
                    Positioned.fill(
                      child: DeskletSurfaceView(theme: theme, page: page),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Delete the workspace you are looking at.
///
/// ─── TWO TAPS, NOT A DIALOG ─────────────────────────────────────────────────
///
/// This is the only destructive action in the launcher that takes content with
/// it, so it cannot be a single tap. It is also sitting on top of a surface
/// that is itself a mode, and a modal dialog over a zoomed-out desktop puts a
/// third layer on the screen to ask one question.
///
/// So the target arms itself. The first tap turns it red and says what the next
/// one will do; the second does it. Tapping anything else, or leaving, disarms
/// it, because an armed delete that survives being ignored is worse than the
/// dialog it replaced.
///
/// ─── AND IT DISARMS WHEN THE PAGE CHANGES ───────────────────────────────────
///
/// Arming names a specific workspace. Swiping to another one while armed would
/// leave a red button pointing at a page the user is no longer looking at, and
/// the second tap would delete the wrong thing.
class _Trash extends ConsumerStatefulWidget {
  const _Trash({required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<_Trash> createState() => _TrashState();
}

class _TrashState extends ConsumerState<_Trash> {
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final palette = theme.palette;
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider).clamp(0, count - 1);

    // Disarm on any move between pages. `listen` rather than a comparison in
    // build: this has to fire on the change itself, not on whatever else
    // rebuilt this widget. It matters more now that the pager retargets on
    // scroll, so swiping is the common way to change the answer.
    ref.listen<int>(activeWorkspaceProvider, (_, __) {
      if (_armed) setState(() => _armed = false);
    });

    // The last workspace cannot go. Greyed rather than hidden, so the row does
    // not change width when you reach the floor.
    final on = count > WorkspaceCount.min;
    final tint = !on
        ? palette.onDark.withValues(alpha: 0.28)
        : _armed
            // theme-exempt: ThemePalette carries bgTop, bgBottom, bar, dock,
            // accent and onDark, and no danger colour. The accent is wrong here
            // on purpose: on Ubuntu it is the orange the active dot uses two
            // glyphs away, so an armed delete would read as a selection.
            ? const Color(0xFFE06C75)
            : palette.onDark.withValues(alpha: 0.75);

    return Semantics(
      button: true,
      label: _armed
          ? context.t('home.deleteWorkspaceConfirm')
          : context.t('home.deleteWorkspace'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !on
            ? null
            : () {
                if (!_armed) {
                  HapticFeedback.selectionClick();
                  setState(() => _armed = true);
                  // ─── THE WARNING IS A MESSAGE, NOT A LABEL ───────────
                  //
                  // Armed state used to grow a line of text under the glyph,
                  // which changed the height of the row and pushed the card
                  // up. In the row there is no space for a word at all, so the
                  // sentence goes through the branded message the rest of the
                  // app uses and the glyph only changes colour.
                  context.showMessage(
                    context.t('home.deleteWorkspaceConfirm'),
                  );
                  return;
                }
                HapticFeedback.mediumImpact();
                ref.read(workspaceCountProvider.notifier).removePage(active);
                setState(() => _armed = false);
              },
        // 44 square, the same target every other glyph in this row gets.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.delete_outline, size: 18, color: tint),
        ),
      ),
    );
  }
}

/// The dot strip, and the two things you can do to the set.
///
/// ─── DOTS RATHER THAN A SENTENCE ────────────────────────────────────────────
///
/// This read "Workspace 2 of 4" above a pair of chips. The strip says the same
/// thing in the shape the desktop already uses for it, and it is tappable, so
/// the overview gains a way to jump pages that does not involve scrolling the
/// card you are looking for into the middle first.
///
/// [WorkspaceDots] is the right-edge indicator lying on its side. It takes an
/// axis for exactly this and is otherwise the same widget, so the mockup's
/// 6/18/7 numbers stay in one file.
class _Pages extends ConsumerWidget {
  const _Pages({required this.theme, required this.count});

  final EffectiveTheme theme;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final active = ref.watch(activeWorkspaceProvider);
    final notifier = ref.read(workspaceCountProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ─── THE TRASH SITS IN THE ROW NOW ────────────────────────────────
        //
        // It was a glyph and a hairline above the card, which is the busiest
        // thing on the screen and the one piece the reference has no equivalent
        // for: there, a page is deleted by dragging it, and nothing is shown
        // until you do.
        //
        // Dragging fights the pager on a vertically-paging distro, so the
        // target stays. In the row it is the same three-group shape the
        // reference has, and it takes the position that was holding a glyph
        // with no job in this app.
        _Trash(theme: theme),
        const SizedBox(width: 14),
        WorkspaceDots(
          axis: Axis.horizontal,
          count: count,
          active: active.clamp(0, count - 1),
          stripLabel: context.t('settings.workspaces'),
          stripValue: context.t('home.workspaceNOfTotal', {
            'n': '${active.clamp(0, count - 1) + 1}',
            'total': '$count',
          }),
          dotLabel: (i) => context.t('home.workspaceN', {'n': '${i + 1}'}),
          accent: palette.accent,
          idle: palette.onDark.withValues(alpha: 0.32),
          onSelect: (i) {
            HapticFeedback.selectionClick();
            ref.read(activeWorkspaceProvider.notifier).goTo(i);
          },
        ),
        const SizedBox(width: 14),
        // ─── A GLYPH IN THE ROW, NOT A BUTTON BESIDE IT ───────────────────
        //
        // This was a 44dp plated square sitting next to a row of 6dp dots,
        // which made the row read as "some dots, and also a button". The plus
        // belongs to the strip: it is one more position on it, the one that
        // does not exist yet.
        //
        // DISABLED, NOT HIDDEN, at the ceiling. A control that disappears at
        // the boundary makes the row jump width and leaves the user wondering
        // whether they imagined it.
        Semantics(
          button: true,
          label: context.t('home.addWorkspace'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: count < WorkspaceCount.max
                ? () {
                    HapticFeedback.selectionClick();
                    notifier.set(count + 1);
                  }
                : null,
            // 44 square of touch around an 18dp glyph, the same trick
            // `WorkspaceDots` uses to make a 6dp dot hittable.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.add,
                size: 18,
                color: count < WorkspaceCount.max
                    ? palette.onDark.withValues(alpha: 0.85)
                    : palette.onDark.withValues(alpha: 0.28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
