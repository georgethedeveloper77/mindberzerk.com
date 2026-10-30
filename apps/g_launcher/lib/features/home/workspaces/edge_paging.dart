/// Page while dragging: hold a dragged icon against the screen's left or right
/// edge and the home turns to the next page, as a phone's home screen does.
///
/// Not `edge_pager.dart`, which models the same dwell from raw pointer x. A
/// held icon is already a drag, and a drag reports enter and leave on a
/// [DragTarget] for free, so this needs no pointer arithmetic at all.
///
/// ─── WHY THE STRIPS ONLY EXIST DURING A DRAG ────────────────────────────────
///
/// A [DragTarget] hit-tests translucently, and inside a Stack the first child
/// that claims a hit ends the search. Two permanent edge strips would swallow
/// every swipe that starts at the edge of the screen, which is where most
/// page swipes start. Mounted only while [homeDragActiveProvider] is true,
/// they cost nothing the rest of the time.
///
/// ─── AND WHY THEY NEVER ACCEPT ──────────────────────────────────────────────
///
/// A strip is a sensor, not a destination. Refusing in `onWillAccept` still
/// reports the enter and the leave, which is all the timer needs, and a drop
/// released over a strip falls through to whatever the drag does with no
/// target (it returns home) rather than being swallowed by a surface that has
/// nowhere to put an app.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drawer/drawer_drag.dart';

/// Is an icon from the home grid or the dock being dragged right now?
///
/// Set by the sources (grid apps, grid folders, dock slots), read by
/// [EdgePageSensor]. A provider for `dockDragActiveProvider`'s reason: the writer
/// is a tile, the reader is the pager several widgets above it.
final homeDragActiveProvider =
    NotifierProvider<HomeDragActive, bool>(HomeDragActive.new);

class HomeDragActive extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) {
    if (state == v) return;
    state = v;
  }
}

/// The two edge sensors. Lay over a horizontally paged home.
class EdgePageSensor extends ConsumerStatefulWidget {
  const EdgePageSensor({super.key, required this.onTurn});

  /// Turn one page: -1 left, +1 right. Returns false when there is no page
  /// that way, and the sensor stops asking until the finger leaves.
  final bool Function(int direction) onTurn;

  @override
  ConsumerState<EdgePageSensor> createState() => _EdgePageSensorState();
}

class _EdgePageSensorState extends ConsumerState<EdgePageSensor> {
  /// How wide each sensor is. Wide enough to find with a held icon, narrow
  /// enough that a drop near the edge of the grid still reaches its column.
  static const _edge = 20.0;

  /// The first turn waits a beat, so passing the edge on the way to a cell
  /// does not flip the page. Later turns come a little slower, so a finger
  /// left on the edge reads each page as it goes by.
  static const _first = Duration(milliseconds: 650);
  static const _repeat = Duration(milliseconds: 800);

  Timer? _timer;
  int _side = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _enter(int side) {
    if (_side == side) return;
    _timer?.cancel();
    _side = side;
    _timer = Timer(_first, _turn);
  }

  void _leave(int side) {
    if (_side != side) return;
    _timer?.cancel();
    _timer = null;
    _side = 0;
  }

  void _turn() {
    if (!mounted || _side == 0) return;
    if (!widget.onTurn(_side)) return;
    HapticFeedback.selectionClick();
    _timer = Timer(_repeat, _turn);
  }

  Widget _sensor(int side) => DragTarget<DrawerDrag>(
        onWillAcceptWithDetails: (_) {
          _enter(side);
          return false;
        },
        onLeave: (_) => _leave(side),
        builder: (_, __, ___) => const SizedBox.expand(),
      );

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(homeDragActiveProvider);
    if (!active) {
      _leave(_side);
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _edge,
          child: _sensor(-1),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _edge,
          child: _sensor(1),
        ),
      ],
    );
  }
}
