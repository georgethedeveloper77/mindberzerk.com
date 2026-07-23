/// The installer chrome. T1.
///
/// Initial setup is not an onboarding carousel and it is not a settings page
/// with a Next button. It is a distro INSTALLER, and it is the first thing
/// anyone sees, so it is also the first proof that this launcher knows what it
/// is imitating.
///
/// ─── THE SKIN IS KEYED BY SHELL, NOT BY THEME ID ────────────────────────────
///
/// The same rule [BootSpec.defaultForShell], [SplashSpec.defaultForShell] and
/// [DeskletSkin.defaultFor] already follow, and for the same reason: keying on
/// `theme.id == 'ubuntu-24-04'` is precisely the trap the theme layer exists to
/// avoid. A GNOME distro gets the wizard because Ubiquity and Calamares are
/// wizards, a TUI distro gets the console because archinstall is a console, and
/// a new distro inherits its family's installer without authoring anything.
///
/// ─── ONLY THE FREE, BUNDLED DISTROS HAVE AN INSTALLER ───────────────────────
///
/// Setup offers Ubuntu, terminal and Aqua. Paid distros arrive as CDN packs and
/// are chosen in Settings, where the user already has a desktop to compare them
/// against. That is a deliberate product decision, not a technical limit: a
/// first-run screen that shows six options, three of them locked, is a shop.
library;

import 'package:flutter/material.dart';

import '../../design/components/components.dart';
import '../../engine/theme_spec.dart';

/// The structural language of the installer.
///
/// Three, not five, because there are only three free distros and each frame
/// has to be genuinely different to be worth having. A fourth frame that is
/// "the wizard but slightly bluer" is a theme, not a frame.
enum SetupFrameKind {
  /// Ubiquity and Calamares: a left rail of numbered steps, a title, a body of
  /// rows, and a footer with Back and Continue at the trailing edge.
  wizard,

  /// archinstall: no rail, no buttons at the trailing edge, a numbered prompt
  /// and a body that reads as terminal output. Everything is mono.
  console,

  /// The macOS Setup Assistant: no rail at all, everything centred, one action
  /// at the bottom. Quiet to the point of being sparse, which is the look.
  assistant,
}

/// How a frame shows where you are.
///
/// Ubuntu's CURRENT installer (the Flutter one, 23.04 onward) dropped
/// Ubiquity's left rail for a row of dots along the bottom — the screenshot
/// everyone recognises today is dots. Calamares kept its sidebar. So progress
/// style is a skin property keyed by shell like everything else here, not a
/// single hardcoded frame decision.
enum SetupProgress { rail, dots, none }

/// How one distro draws its installer.
class SetupSkin {
  const SetupSkin({
    required this.kind,
    required this.mono,
    this.progress = SetupProgress.dots,
  });

  final SetupFrameKind kind;

  /// Render titles and rows in the theme's mono family rather than its display
  /// family. A bool rather than a family string because a skin must never name
  /// a typeface: the theme owns that, and `no_constants.sh` polices it.
  final bool mono;

  /// Rail, dots, or nothing. The console shows its own [n/total] counter in
  /// the prompt line, and the assistant deliberately never tells you how many
  /// steps remain, so both use [SetupProgress.none].
  final SetupProgress progress;

  static SetupSkin defaultForShell(ShellKind shell) => switch (shell) {
        // The modern Ubuntu installer: floating window, centred title, dots.
        // Fedora would inherit this and be right, which is the point.
        ShellKind.gnome => const SetupSkin(
            kind: SetupFrameKind.wizard,
            mono: false,
            progress: SetupProgress.dots,
          ),
        // Calamares KEPT the sidebar, so KDE keeps the rail. It is unreachable
        // from setup today (KDE applies instantly as a bundled theme) and is
        // here so the switch is exhaustive rather than defaulted.
        ShellKind.plasma => const SetupSkin(
            kind: SetupFrameKind.wizard,
            mono: false,
            progress: SetupProgress.rail,
          ),
        // A tiling distro installs from a TTY. So does this.
        ShellKind.tiling => const SetupSkin(
            kind: SetupFrameKind.console,
            mono: true,
            progress: SetupProgress.none,
          ),
        ShellKind.tui => const SetupSkin(
            kind: SetupFrameKind.console,
            mono: true,
            progress: SetupProgress.none,
          ),
        // Centred, sparse, one action. No progress at all: the Setup Assistant
        // never shows you how many steps are left, which is the whole feeling.
        ShellKind.aqua => const SetupSkin(
            kind: SetupFrameKind.assistant,
            mono: false,
            progress: SetupProgress.none,
          ),
      };
}

/// The marker at the leading edge of a [SetupRow].
enum SetupMarker { radio, check, chevron }

/// One selectable row.
///
/// ROWS, NOT CHIPS, and no ellipsis anywhere. A chip can only carry a word, so
/// a chip row forces every option to be named in one word and then truncates
/// the ones that are not. A row carries a name, a version and a line of prose,
/// which is what an installer's option list actually is. Long labels wrap.
class SetupRow extends StatelessWidget {
  const SetupRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.marker = SetupMarker.radio,
    this.mono = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;

  /// Right-aligned secondary text: a version string, an app count.
  final String? trailing;

  final bool selected;
  final SetupMarker marker;
  final bool mono;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    final titleStyle = (mono ? d.text.label : d.text.body).copyWith(
      color: enabled ? c.text : c.textMuted,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.surfaceAlt : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? c.accent : c.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _marker(d),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // softWrap with no overflow handler: a name that does not
                    // fit takes a second line. Truncation is what the ellipsis
                    // ban is about, and an installer has the room.
                    Text(title, style: titleStyle, softWrap: true),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        softWrap: true,
                        style: d.text.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: d.text.caption.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(ChromeData d) {
    final c = d.colors;
    switch (marker) {
      case SetupMarker.chevron:
        // The console frame's cursor. A selected line is the one the prompt is
        // pointing at, which is how a TTY menu shows selection.
        return SizedBox(
          width: 14,
          height: 18,
          child: Center(
            child: Text(
              selected ? '>' : ' ',
              style: TextStyle(color: c.accent, height: 1),
            ),
          ),
        );

      case SetupMarker.check:
        return SizedBox(
          width: 16,
          height: 18,
          child: Center(
            child: Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: selected ? c.accent : c.line,
            ),
          ),
        );

      case SetupMarker.radio:
        return Container(
          width: 15,
          height: 15,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? c.accent : null,
            border: Border.all(color: selected ? c.accent : c.line),
          ),
          child: selected
              ? Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.onAccent,
                    ),
                  ),
                )
              : null,
        );
    }
  }
}

/// The installer window.
///
/// Owns the frame and nothing else: it does not know what a distro is, it does
/// not touch prefs, and it never decides whether Continue is allowed. The
/// screen passes a title, a body and a footer callback, exactly the way
/// [BootSequence] takes a [BootSpec] and renders it without knowing why.
class SetupInstallerFrame extends StatelessWidget {
  const SetupInstallerFrame({
    super.key,
    required this.skin,
    required this.steps,
    required this.step,
    required this.windowTitle,
    required this.title,
    required this.body,
    required this.onNext,
    required this.nextLabel,
    this.subtitle,
    this.onBack,
    this.status,
    this.footerNote,
  });

  final SetupSkin skin;

  /// Rail labels, in order. Also the count, so the frame never has to be told
  /// the total separately and the two cannot drift.
  final List<String> steps;
  final int step;

  /// The title bar text: "Install Ubuntu".
  final String windowTitle;

  final String title;
  final String? subtitle;
  final Widget body;

  /// Bottom-left status line, the way an installer reports what it is doing.
  final String? status;

  /// Rendered above the footer buttons. The home-role nag lives here.
  final Widget? footerNote;

  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleBar(d),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (skin.kind == SetupFrameKind.wizard &&
                  skin.progress == SetupProgress.rail)
                _Rail(steps: steps, step: step),
              Expanded(child: _content(d)),
            ],
          ),
        ),
        _footer(d),
      ],
    );

    // The console IS the screen and the assistant is deliberately bare, but
    // the wizard is a WINDOW: the modern Ubuntu installer floats a rounded
    // card over the wallpaper, and that floating card is most of what makes
    // the screenshot recognisable. Margins clear Android's own status bar the
    // same way the shells do — the wallpaper shows through around it because
    // the scaffold behind this frame is transparent.
    if (skin.kind != SetupFrameKind.wizard) return column;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.viewPaddingOf(context).top + 10,
        10,
        10 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(color: c.surface, child: column),
      ),
    );
  }

  Widget _titleBar(ChromeData d) {
    final c = d.colors;
    // The console has no window: it IS the screen. A title bar over a TTY would
    // be the one detail that gives the whole thing away.
    if (skin.kind == SetupFrameKind.console) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Text(
          '$windowTitle  [${step + 1}/${steps.length}]',
          style: d.text.caption.copyWith(color: c.accent),
        ),
      );
    }

    if (skin.kind == SetupFrameKind.assistant) {
      return const SizedBox(height: 18);
    }

    // CENTRED, like the reference: "Welcome to Ubuntu" sits in the middle of
    // the window's top edge with a hairline under it. No close button — a
    // launcher's setup has nowhere to close TO (there is no other home screen
    // behind it once the role is granted), and a decorative X that does
    // nothing would be worse than none.
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Text(windowTitle, style: d.text.body.copyWith(color: c.text)),
    );
  }

  Widget _content(ChromeData d) {
    final c = d.colors;
    final centred = skin.kind == SetupFrameKind.assistant;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(centred ? 24 : 16, 18, 16, 12),
      child: Column(
        crossAxisAlignment:
            centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: centred ? TextAlign.center : TextAlign.start,
            style: d.text.display,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: centred ? TextAlign.center : TextAlign.start,
              style: d.text.body.copyWith(color: c.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }

  Widget _footer(ChromeData d) {
    final c = d.colors;
    final dots = skin.progress == SetupProgress.dots;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (footerNote != null) ...[
            footerNote!,
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (onBack != null) ...[
                ThemedButton(
                  label: 'Back',
                  kind: ThemedButtonKind.text,
                  onPressed: onBack!,
                ),
                const SizedBox(width: 6),
              ],
              // Dots take the middle, the reference layout. Without dots the
              // slot carries the console-style status line instead; both are
              // Expanded so the Next button always sits at the trailing edge.
              if (dots)
                Expanded(
                    child:
                        Center(child: _Dots(count: steps.length, step: step)))
              else if (status != null)
                Expanded(
                  child: Text(
                    status!,
                    softWrap: true,
                    style: d.text.caption.copyWith(color: c.textMuted),
                  ),
                )
              else
                const Spacer(),
              ThemedButton(label: nextLabel, onPressed: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bottom progress dots — the modern Ubuntu installer's step indicator.
/// Filled accent for the current step, hollow line-colour for the rest, no
/// numbers: the reference never counts steps out loud.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.step});

  final int count;
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == step ? 9 : 7,
            height: i == step ? 9 : 7,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? c.accent : c.line,
            ),
          ),
      ],
    );
  }
}

/// Ubiquity's step rail.
class _Rail extends StatelessWidget {
  const _Rail({required this.steps, required this.step});

  final List<String> steps;
  final int step;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Container(
      width: 84,
      color: c.surfaceAlt,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: i == step ? c.accent : c.surfaceAlt,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                steps[i],
                softWrap: true,
                style: d.text.caption.copyWith(
                  // Three states, not two: done reads differently from pending,
                  // which is what makes the rail a progress indicator rather
                  // than a table of contents.
                  color: i == step ? c.text : (i < step ? c.textMuted : c.line),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
