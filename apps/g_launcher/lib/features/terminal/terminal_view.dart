/// Drawing a session's output, in either of the two shapes it comes in.
///
/// ─── TWO MODES, BECAUSE THERE ARE GENUINELY TWO SHAPES ──────────────────────
///
/// LINE MODE renders a [TerminalBuffer] plus the line still being written. That
/// is local command output: a list that only ever grows, where scrolling back
/// is reading history.
///
/// GRID MODE renders a [TerminalEmulator]: a fixed screen of cells that a
/// remote program draws on, with the lines that have scrolled off the top
/// underneath it as history. `vim` and `htop` need this and cannot be expressed
/// as a list of finished lines.
///
/// One widget rather than two, because everything below the mode is shared: the
/// palette, the font, the selection behaviour, the reversed list that keeps the
/// view pinned to the newest output, and the truncation notice.
///
/// ─── THE SEAM, UNCHANGED ────────────────────────────────────────────────────
///
/// The canvas paints from [TerminalPalette]. Chrome around it is whatever hosts
/// this. See the original note: `desklet_frame.dart` made the same call for its
/// terminal surface, and two renderers disagreeing would be visible on the one
/// screen that shows both.
library;

import 'package:flutter/material.dart';

import '../../engine/terminal_spec.dart';
import 'ansi.dart';
import 'ansi_palette.dart';
import 'terminal_buffer.dart';
import 'terminal_emulator.dart';
import 'terminal_grid.dart';

class TerminalView extends StatelessWidget {
  /// Local output: a growing list of lines.
  const TerminalView({
    super.key,
    required this.buffer,
    required this.palette,
    this.current,
    this.fontFamily,
    this.fontSize = 13,
    this.lineHeight = 1.45,
    this.showCursor = true,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  }) : emulator = null;

  /// A remote session: a live screen with history above it.
  const TerminalView.grid({
    super.key,
    required TerminalEmulator this.emulator,
    required this.palette,
    this.fontFamily,
    this.fontSize = 13,
    this.lineHeight = 1.45,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  })  : buffer = null,
        current = null,
        showCursor = false;

  final TerminalBuffer? buffer;
  final TerminalEmulator? emulator;
  final TerminalPalette palette;

  /// The unfinished local line. Null when there is none, which is not the same
  /// as an empty one: an empty current line still gets a cursor.
  final AnsiLine? current;

  /// From `EffectiveTheme.typography.mono`.
  final String? fontFamily;

  final double fontSize;
  final double lineHeight;
  final bool showCursor;
  final ScrollController? controller;
  final EdgeInsets padding;

  bool get _isGrid => emulator != null;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      color: palette.fg,
      // Terminal output is columns of numbers as often as it is prose, and
      // proportional digits make a column of them wander.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ColoredBox(
      color: palette.bg,
      child: SelectionArea(
        // Long press to select, which is the only way to get text off a phone
        // terminal. SelectionArea rather than SelectableText per line, because
        // per-line selection cannot span lines, and a stack trace you can only
        // copy one line at a time is a stack trace you retype.
        child: _isGrid ? _buildGrid(base) : _buildLines(base),
      ),
    );
  }

  // ── line mode ──────────────────────────────────────────────────────────────

  Widget _buildLines(TextStyle base) {
    final b = buffer!;
    final hasCurrent = current != null;
    final hasNotice = b.droppedLines > 0;
    final count = b.length + (hasCurrent ? 1 : 0) + (hasNotice ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: padding,
      // REVERSED, so offset zero is the BOTTOM. New output then appears without
      // touching the scroll offset, which is what makes the view stick to the
      // newest line with no controller work and no jump when a line arrives
      // while the user is reading.
      reverse: true,
      itemCount: count,
      itemBuilder: (context, i) {
        if (hasCurrent && i == 0) {
          return _Line(
            line: current!,
            palette: palette,
            base: base,
            cursor: showCursor,
          );
        }

        final j = i - (hasCurrent ? 1 : 0);
        final index = b.length - 1 - j;
        if (index >= 0) {
          return _Line(line: b[index], palette: palette, base: base);
        }

        return _TruncationNotice(
          dropped: b.droppedLines,
          palette: palette,
          base: base,
        );
      },
    );
  }

  // ── grid mode ──────────────────────────────────────────────────────────────

  Widget _buildGrid(TextStyle base) {
    final e = emulator!;
    final grid = e.grid;

    // ON THE ALTERNATE SCREEN THERE IS NO HISTORY, and that is not a
    // simplification. A full-screen program owns the whole viewport, and its
    // scrollback is its own business: scrolling up inside `less` is `less`
    // redrawing, not the terminal moving. Offering our scrollback there would
    // let someone scroll the shell out from under a running program.
    final history = e.isAlternateScreen ? const <AnsiLine>[] : e.scrollback;
    final hasNotice = !e.isAlternateScreen && e.droppedLines > 0;
    final count = grid.rows + history.length + (hasNotice ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: padding,
      reverse: true,
      // The live screen must never be recycled out from under a redraw, and it
      // is only ever a few dozen rows.
      addAutomaticKeepAlives: false,
      itemCount: count,
      itemBuilder: (context, i) {
        if (i < grid.rows) {
          return _Line(
            line: _rowOf(grid, grid.rows - 1 - i),
            palette: palette,
            base: base,
          );
        }

        final j = i - grid.rows;
        final index = history.length - 1 - j;
        if (index >= 0) {
          return _Line(line: history[index], palette: palette, base: base);
        }

        return _TruncationNotice(
          dropped: e.droppedLines,
          palette: palette,
          base: base,
        );
      },
    );
  }

  /// One grid row, with the cursor drawn into it.
  ///
  /// INVERSE VIDEO, which is what a terminal does, and it costs nothing: the
  /// style model already carries inverse and the palette already resolves it.
  /// A separately positioned overlay would have to track the character cell in
  /// pixels and would drift the moment the font metrics moved.
  AnsiLine _rowOf(TerminalGrid grid, int y) {
    if (!grid.cursorVisible || y != grid.cursorY) return grid.toAnsiLine(y);

    final cells = List<TerminalCell>.from(grid.lineAt(y));
    final x = grid.cursorX.clamp(0, cells.length - 1);
    final cell = cells[x];
    cells[x] = TerminalCell(
      // A cursor on an unwritten cell still needs something to invert.
      cell.char.isEmpty ? ' ' : cell.char,
      cell.style.copyWith(inverse: !cell.style.inverse),
    );
    return gridLineToAnsiLine(cells);
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.palette,
    required this.base,
    this.cursor = false,
  });

  final AnsiLine line;
  final TerminalPalette palette;
  final TextStyle base;
  final bool cursor;

  @override
  Widget build(BuildContext context) {
    // A blank line still occupies a row. Rendering an empty TextSpan collapses
    // to zero height and the output closes up, which turns deliberate spacing
    // in a program's output into a solid block of text.
    if (line.isEmpty && !cursor) return Text(' ', style: base);

    final spans = <InlineSpan>[
      for (final s in line.spans) _span(s),
      if (cursor)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _Cursor(palette: palette, base: base),
        ),
    ];

    return Text.rich(TextSpan(children: spans), style: base);
  }

  TextSpan _span(AnsiSpan s) {
    final r = palette.resolveStyle(s.style);
    return TextSpan(
      text: s.text,
      style: TextStyle(
        color: r.fg,
        backgroundColor: r.bg,
        fontWeight: r.bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
        decoration: TextDecoration.combine([
          if (r.underline) TextDecoration.underline,
          if (r.strike) TextDecoration.lineThrough,
        ]),
        decorationColor: r.fg,
      ),
    );
  }
}

/// A block cursor for LINE MODE.
///
/// Grid mode draws its cursor as inverse video inside the row, because there
/// the cursor has a cell to sit in. Here there is no grid, only a line being
/// appended to, so the cursor is a widget at the end of it.
class _Cursor extends StatefulWidget {
  const _Cursor({required this.palette, required this.base});

  final TerminalPalette palette;
  final TextStyle base;

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1060),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.base.fontSize ?? 13;
    final block = Container(
      width: size * 0.6,
      height: size * (widget.base.height ?? 1.45),
      color: widget.palette.cursor,
    );

    // A blink is an animation, and a person who has turned animations off has
    // usually done it because motion is a problem for them. A steady block is
    // still a cursor.
    if (MediaQuery.of(context).disableAnimations) return block;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        // A hard step, not a fade. A terminal cursor has never faded, and the
        // difference is noticeable to exactly the audience this ships for.
        opacity: _c.value < 0.5 ? 1 : 0,
        child: child,
      ),
      child: block,
    );
  }
}

/// Says history was dropped rather than pretending the session started here.
class _TruncationNotice extends StatelessWidget {
  const _TruncationNotice({
    required this.dropped,
    required this.palette,
    required this.base,
  });

  final int dropped;
  final TerminalPalette palette;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '[ $dropped earlier ${dropped == 1 ? 'line' : 'lines'} dropped ]',
        style: base.copyWith(
          color: palette.dim,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
