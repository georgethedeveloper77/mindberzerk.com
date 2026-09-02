import 'package:flutter/material.dart';

import '../../engine/desklet_skin.dart';
import '../../engine/effective_theme.dart';
// parseColor, for a per-widget accent override. See _accentOf.
import '../../engine/theme_spec.dart' show parseColor;

/// The shape almost every desklet actually is. PHASE D5.
///
/// ─── WHY A SHARED BODY AND NOT SIX BESPOKE WIDGETS ──────────────────────────
///
/// Monitor, fastfetch, network, storage and battery are all the same object: a
/// heading and a column of label/value rows, some of which want a bar. Writing
/// each of them five times (once per surface) would be thirty renderings to
/// keep consistent, and they would drift within a month — one distro's storage
/// tile would gain a border the others never got.
///
/// So a kind produces a [DeskletBody] and knows nothing about how it is drawn.
/// [DeskletFrame] owns all five looks. Adding a kind is a function that returns
/// rows; adding a SURFACE is one case here and every existing kind gets it.
///
/// The clock is the deliberate exception: it is 56px of type with no rows, and
/// forcing it through this model would have bent the model to fit one widget.
class DeskletRow {
  const DeskletRow(
    this.label, {
    this.value,
    this.fraction,
    this.accent = false,
  });

  final String label;

  /// Null is not a "dash" — a caller with no value OMITS THE ROW. That is the
  /// nullable-stats rule the whole stats layer is built on, enforced by never
  /// giving this model a way to express absence.
  final String? value;

  /// 0..1 draws a bar behind the row. Used by memory and storage, where the
  /// proportion is the point and the number is the detail.
  final double? fraction;

  final bool accent;
}

class DeskletBody {
  const DeskletBody({
    this.title,
    this.command,
    this.rows = const [],
    this.custom,
    this.emptyNote,
  });

  /// Heading on the graphical surfaces. Omitted on `panel`, which has one line.
  final String? title;

  /// What this would have been on a terminal: `free -h`, `df -h`, `uptime`.
  ///
  /// Every kind declares it even though only the terminal surface draws it,
  /// because a monitor desklet genuinely IS `free -h` and writing that down is
  /// what lets the same kind serve the pane surface without a second widget.
  final String? command;

  final List<DeskletRow> rows;

  /// Escape hatch for kinds that are not label/value at all — notes is a text
  /// blob, search is a control. They still get the frame, so they still look
  /// like the distro; they just fill it themselves.
  final Widget? custom;

  /// What to print when there is nothing to print. stderr, essentially.
  ///
  /// ONLY the terminal surface draws this, and that asymmetry is the point.
  ///
  /// On a desktop, a desklet with no data renders NOTHING: an empty bordered
  /// rectangle sitting on the wallpaper looks like a failed download, and the
  /// honest outcome on a locked-down ROM is that the tile is simply not there.
  ///
  /// On a terminal, silence is a BUG. A command that prints absolutely nothing
  /// is indistinguishable from a command that never ran — which is precisely
  /// how an unwired `free -h` and a `free -h` on a device that will not report
  /// memory look identical. Real `free` does not go quiet in that situation; it
  /// writes to stderr. So does this.
  ///
  /// This does not breach the nullable-stats rule. The absent ROW is still
  /// absent; an error message is not a placeholder VALUE. `mem --%` would be a
  /// lie, `cannot read meminfo` is a fact.
  final String? emptyNote;

  bool get isEmpty => rows.isEmpty && custom == null;
}

/// Renders a [DeskletBody] in the distro's idiom.
class DeskletFrame extends StatelessWidget {
  const DeskletFrame({
    super.key,
    required this.theme,
    required this.skin,
    required this.body,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final DeskletBody body;

  @override
  Widget build(BuildContext context) {
    // A desklet whose every stat is unavailable renders NOTHING rather than an
    // empty box. On a locked-down ROM that is the honest outcome, and an empty
    // bordered rectangle on the wallpaper looks like a failed download.
    //
    // EXCEPT on the terminal, which always echoes its command line. See
    // [DeskletBody.emptyNote]: on a shell, printing nothing at all is the one
    // failure mode you cannot debug, because it looks exactly like the command
    // not being wired up.
    if (body.isEmpty && skin.surface != DeskletSurface.terminal) {
      return const SizedBox.shrink();
    }

    return switch (skin.surface) {
      DeskletSurface.bare => _Bare(theme: theme, skin: skin, body: body),
      DeskletSurface.card => _Card(theme: theme, skin: skin, body: body),
      DeskletSurface.panel => _Panel(theme: theme, skin: skin, body: body),
      DeskletSurface.terminal =>
        _Terminal(theme: theme, skin: skin, body: body),
    };
  }
}

String? _family(EffectiveTheme t, DeskletSkin s) =>
    s.font == DeskletFont.mono ? t.typography.mono : t.typography.display;

/// The accent this desklet draws with.
///
/// ─── WHY A SKIN PROP AND NOT A NEW PARAMETER ────────────────────────────────
///
/// The distro's accent is the default and always will be. A per-widget override
/// arrives as `accentHex` in [DeskletSkin.props], which is where a theme's own
/// tuning already lives and which `mergedWith` already merges, so the user's
/// value reaches here by the same path a distro's would. Threading a colour
/// through every surface constructor would have been a second mechanism for the
/// same idea.
///
/// An unparseable value falls back rather than throwing, the same contract
/// every other free-form read in the theme layer follows: this string can come
/// from a CDN pack or a prefs file written by a newer build.
Color _accentOf(EffectiveTheme t, DeskletSkin s) =>
    parseColor(s.text('accentHex', '')) ?? t.palette.accent;

/// The drop shadow that lets unboxed text survive a light wallpaper. A scrim
/// would turn the bare surface into the card surface with extra steps.
List<Shadow> _shadows(EffectiveTheme t) => [
      Shadow(
        color: t.palette.bgBottom.withValues(alpha: 0.55),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// bare — the conky. GNOME and Aqua.
// ─────────────────────────────────────────────────────────────────────────────

class _Bare extends StatelessWidget {
  const _Bare({required this.theme, required this.skin, required this.body});

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final DeskletBody body;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final size = skin.num_('rowSize', 11.5);

    // Right-aligned by default because that is where a conky lives and how it
    // reads: the numbers line up against the screen edge. A theme that wants it
    // left-aligned says so rather than getting a second surface.
    final right = skin.flag('alignRight', true);
    final cross =
        right ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return DefaultTextStyle(
      style: TextStyle(
        // Mono unless the theme says otherwise: aligned digits are most of what
        // makes a conky read as a conky, and a proportional font undoes it.
        fontFamily: theme.typography.mono,
        fontSize: size,
        height: 1.55,
        color: p.onDark.withValues(alpha: 0.78),
        shadows: _shadows(theme),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          if (body.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                body.title!,
                style: TextStyle(
                  fontSize: size,
                  color: p.onDark.withValues(alpha: 0.55),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          for (var i = 0; i < body.rows.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
              child: _BareRow(
                theme: theme,
                accent: _accentOf(theme, skin),
                row: body.rows[i],
                right: right,
              ),
            ),
          if (body.custom != null) body.custom!,
        ],
      ),
    );
  }
}

class _BareRow extends StatelessWidget {
  const _BareRow({
    required this.theme,
    required this.accent,
    required this.row,
    required this.right,
  });

  final EffectiveTheme theme;

  /// Already resolved by [_accentOf]. Passed rather than re-derived so the row
  /// and its parent cannot disagree about which accent this tile is wearing.
  final Color accent;

  final DeskletRow row;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;

    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${row.label} ',
            style: TextStyle(color: p.onDark.withValues(alpha: 0.6)),
          ),
          if (row.value != null)
            TextSpan(
              text: row.value,
              style: TextStyle(
              color: row.accent ? accent : p.onDark,
            ),
            ),
        ],
      ),
    );

    if (row.fraction == null) return text;

    // A hairline bar UNDER the text rather than beside it. Beside it, the bar
    // would have to steal width from the numbers, and on a 2-cell tile there is
    // none to steal.
    return Column(
      crossAxisAlignment:
          right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(height: 2),
        _Bar(
          theme: theme,
          accent: accent,
          fraction: row.fraction!,
          width: 78,
          height: 2,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// card — Breeze.
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.skin, required this.body});

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final DeskletBody body;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final size = skin.num_('rowSize', 12);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bar.withValues(alpha: skin.num_('opacity', 0.72)),
        borderRadius: BorderRadius.circular(skin.num_('radius', 10)),
        border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.title != null) ...[
              Text(
                body.title!,
                style: TextStyle(
                  fontFamily: _family(theme, skin),
                  fontSize: size,
                  fontWeight: FontWeight.w600,
                  color: p.onDark.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
            ],
            for (final row in body.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _CardRow(
                  theme: theme,
                  accent: _accentOf(theme, skin),
                  row: row,
                  size: size,
                ),
              ),
            if (body.custom != null) body.custom!,
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.theme,
    required this.accent,
    required this.row,
    required this.size,
  });

  final EffectiveTheme theme;

  /// See [_BareRow.accent].
  final Color accent;

  final DeskletRow row;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: TextStyle(
                  fontSize: size,
                  color: p.onDark.withValues(alpha: 0.62),
                ),
              ),
            ),
            if (row.value != null)
              Text(
                row.value!,
                style: TextStyle(
                  // The VALUE is mono even on a card, so a column of numbers
                  // lines up. The label is not, so it reads as prose.
                  fontFamily: theme.typography.mono,
                  fontSize: size,
                  color: row.accent ? accent : p.onDark,
                ),
              ),
          ],
        ),
        if (row.fraction != null) ...[
          const SizedBox(height: 3),
          _Bar(
            theme: theme,
            accent: accent,
            fraction: row.fraction!,
            width: null,
            height: 3,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// panel — a waybar module on the desktop. One line, always.
// ─────────────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.theme, required this.skin, required this.body});

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final DeskletBody body;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;

    // Collapsed onto one line with a separator, because that is what a waybar
    // module does: it has one row and no interest in a second. Rows with a
    // fraction lose the bar here and keep the number, which is the right thing
    // to drop when there is no vertical room for both.
    final text = body.rows
        .where((r) => r.value != null)
        .map((r) => '${r.label} ${r.value}')
        .join('  |  ');

    if (text.isEmpty && body.custom == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bar.withValues(alpha: skin.num_('opacity', 0.9)),
        borderRadius: BorderRadius.circular(skin.num_('radius', 4)),
        border: Border(
          left: BorderSide(color: _accentOf(theme, skin), width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: body.custom ??
            Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: skin.num_('rowSize', 12),
                  fontWeight: FontWeight.w600,
                  color: skin.accent ? _accentOf(theme, skin) : p.onDark,
                ),
              ),
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// terminal — the command and its output.
// ─────────────────────────────────────────────────────────────────────────────

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.theme,
    required this.skin,
    required this.body,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final DeskletBody body;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final mono = theme.typography.mono;
    final size = skin.num_('rowSize', 12.5);

    // Labels padded to a common width so the values form a column. Real command
    // output aligns; a terminal desklet that does not is immediately wrong.
    final width = body.rows.fold<int>(0, (w, r) {
      return r.label.length > w ? r.label.length : w;
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            // ─── SHADOWED, LIKE THE CONKY, AND FOR THE SAME REASON ──────
            //
            // This surface draws no plate and no border: it is command output
            // sitting on the wallpaper, which is the whole point of it. That
            // makes it the bare surface in every respect that matters for
            // legibility, and `_Bare` carries `_shadows` precisely because
            // unboxed text over an arbitrary photograph is unreadable at the
            // wrong moment.
            //
            // It went unnoticed because every distro using this surface ships
            // dark wallpapers. The failure needs a user to pick a light photo,
            // at which point mono text in `onDark` disappears entirely and the
            // desklet looks like it failed to load rather than like it needs a
            // different wallpaper.
            style: TextStyle(
              fontFamily: mono,
              fontSize: size,
              height: 1.6,
              shadows: _shadows(theme),
            ),
            children: [
              TextSpan(
                text: '~ \u276f ',
                style: TextStyle(
                  color: _accentOf(theme, skin),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: skin.text('command', body.command ?? ''),
                style: TextStyle(color: p.onDark.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        for (final row in body.rows)
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: mono,
                fontSize: size,
                height: 1.6,
                shadows: _shadows(theme),
              ),
              children: [
                TextSpan(
                  text: row.label.padRight(width + 2),
                  style: TextStyle(color: p.onDark.withValues(alpha: 0.55)),
                ),
                TextSpan(
                  text: row.value ?? '',
                  style: TextStyle(
                    // `_Terminal` holds the skin itself, unlike `_BareRow` and
                    // `_CardRow`, which are handed the resolved colour.
                    color: row.accent ? _accentOf(theme, skin) : p.onDark,
                  ),
                ),
              ],
            ),
          ),

        // stderr. Dimmed rather than coloured with the accent, because the
        // accent is this shell's "here is a result" colour and an error is not
        // one.
        if (body.rows.isEmpty && body.custom == null && body.emptyNote != null)
          Text(
            body.emptyNote!,
            style: TextStyle(
              fontFamily: mono,
              fontSize: size,
              height: 1.6,
              color: p.onDark.withValues(alpha: 0.45),
              // The stderr line needs this MOST. It is already the dimmest
              // text on the surface, so on a light wallpaper it is the first
              // thing to vanish, and it is the one line that exists to tell
              // you something has gone wrong.
              shadows: _shadows(theme),
            ),
          ),

        if (body.custom != null) body.custom!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  const _Bar({
    required this.theme,
    required this.accent,
    required this.fraction,
    required this.width,
    required this.height,
  });

  final EffectiveTheme theme;

  /// Passed in rather than read off the palette, so a per-widget accent reaches
  /// the gauge too. A tile whose numbers are cyan and whose bar is still the
  /// distro orange looks like a rendering bug rather than a setting.
  final Color accent;
  final double fraction;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final f = fraction.clamp(0.0, 1.0);

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: p.onDark.withValues(alpha: 0.18),
              ),
            ),
            FractionallySizedBox(
              widthFactor: f,
              child: ColoredBox(
                // Accent below the line, warn above it. 0.9 rather than 0.8:
                // a storage bar that turns red at 80% full cries wolf on a
                // 128GB phone, and this ecosystem's whole storage pitch is that
                // it tells the truth about space.
                color: f > 0.9 ? accent : accent.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );

    return width == null ? bar : SizedBox(width: width, child: bar);
  }
}
