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
import 'package:g_launcher/i18n/i18n.dart';
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
    this.preview,
    this.marker = SetupMarker.radio,
    this.mono = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;

  /// Right-aligned secondary text: a version string, an app count.
  final String? trailing;

  /// A small picture on the right, instead of text.
  ///
  /// ─── A SECOND PARAMETER RATHER THAN A WIDER [trailing] ────────────────────
  ///
  /// Widening `trailing` to `Widget?` would have been tidier and would have
  /// touched every existing caller, all of which pass a string and none of
  /// which wants to start writing `Text(...)` to keep doing so.
  ///
  /// It exists for the drawer step, where the options are MOTIONS. A word
  /// cannot tell a cube from a cylinder and neither can a still, so each row
  /// carries the transition playing beside its name. Nothing else uses it, and
  /// nothing else should: a picture on a row whose choice is already obvious
  /// from its label is decoration.
  ///
  /// Sized by the CALLER, because only the caller knows how tall its row is.
  final Widget? preview;

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
              if (preview != null) ...[
                const SizedBox(width: 10),
                // Clipped and cornered here rather than by the caller, so every
                // row that grows one gets the same shape without repeating it.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: preview,
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
/// A row of equal-width choices, for a setting with two to four answers.
///
/// ─── WHY THE ROWS WENT ──────────────────────────────────────────────────────
///
/// Light, dark and system were three full-width rows with radio markers and a
/// subtitle each, and so were the dock sides. That shape is right in Settings,
/// where a screen is a long list of unrelated things and a row is how you tell
/// them apart. It is wrong under a live stage: the stage has already answered
/// "what does this do", so the rows were repeating it in prose and taking three
/// times the height to do it, which pushed the stage down and made the one
/// thing worth looking at smaller.
///
/// A chip strip says the same thing in one line. The explanation, where one is
/// genuinely needed, moves to a single caption under the strip rather than a
/// subtitle on every option.
///
/// ─── EQUAL WIDTHS, AND A CAP OF FOUR ────────────────────────────────────────
///
/// Every option gets the same width, so the strip reads as one control rather
/// than as a row of buttons of assorted importance. That only works while the
/// longest label still fits: past four options, or with labels longer than a
/// word or two, the text starts eliding and a list is the honest shape again.
/// The drawer's column picker is the same control with four numbers in it.
class SetupChoice extends StatelessWidget {
  const SetupChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.mono = false,
  });

  /// Value to label, in display order.
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  /// The console keeps square brackets and no fill, like everything else there.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final entries = options.entries.toList();

    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(entries[i].key),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entries[i].key == selected && !mono
                      ? c.accent.withValues(alpha: 0.14)
                      : null,
                  border: Border.all(
                    color: entries[i].key == selected ? c.accent : c.line,
                    width: entries[i].key == selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(mono ? 0 : 10),
                ),
                child: Text(
                  mono && entries[i].key == selected
                      ? '[${entries[i].value}]'
                      : entries[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: d.text.body.copyWith(
                    color: entries[i].key == selected ? c.text : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
    this.stage,
    this.fills = false,
    this.nextEnabled = true,
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

  /// The LIVE DESKTOP, drawn once for the whole wizard.
  ///
  /// ─── WHY IT IS A SLOT ON THE FRAME AND NOT A WIDGET IN EACH STEP ────────
  ///
  /// Every step used to draw its own small preview: appear, do one job, be
  /// thrown away. Nothing accumulated, so seven answers produced seven
  /// unrelated pictures and the payoff arrived only at the boot sequence. The
  /// thing this product actually has is that the desktop is being ASSEMBLED in
  /// front of you, and that is only legible if it is the SAME desktop the whole
  /// way through.
  ///
  /// So the frame owns it. The steps below it change; this does not, except in
  /// the one way that matters, which is that each answer visibly edits it.
  ///
  /// NULL IS A FIRST-CLASS ANSWER and the layout is byte-identical to before
  /// when it is null. The welcome step passes none, because language and the
  /// home role are facts about Android rather than about the desktop and there
  /// is no distro chosen yet to draw. The console skin passes none for the
  /// reason its title bar does not exist: a TTY installer that drew a picture
  /// of a desktop would give the whole thing away.
  final Widget? stage;

  /// Should [body] STRETCH to the bottom of the window?
  ///
  /// True for steps whose body has something worth growing: the welcome step's
  /// language list, and any step built around a list rather than a handful of
  /// rows. False leaves the old top-aligned scroll, which is right for a step
  /// that is genuinely three radio buttons tall.
  ///
  /// Opt-in rather than always-on because a filling step gets no outer scroll
  /// view, so its body must be able to handle its own overflow. A step that is
  /// a plain list of rows leaves this false and keeps the scrolling frame.
  final bool fills;

  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;

  /// May the wizard advance right now?
  ///
  /// ─── DIMMED AND PRESENT, NOT ABSENT ───────────────────────────────────
  ///
  /// A flag rather than making [onNext] nullable, so the button keeps its place
  /// in the footer. A Continue that disappears while a distro downloads reads
  /// as the wizard having broken, and it moves the Back button under the thumb
  /// that was reaching for Continue.
  ///
  /// Nothing here explains WHY it is dim. [status] does, in the slot beside it,
  /// which is the installer idiom and the reason that slot exists. A disabled
  /// control with no nearby explanation is the failure `_StepWidgets` documents
  /// when it removes the position strip rather than greying it out.
  ///
  /// Opacity plus [IgnorePointer] rather than a disabled variant of
  /// [ThemedButton], matching [SetupRow]'s own disabled treatment two hundred
  /// lines up: same 0.45, same refusal to accept the tap.
  final bool nextEnabled;

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
              Expanded(child: _stageAndContent(d)),
            ],
          ),
        ),
        _footer(context, d),
      ],
    );

    // ─── THE WINDOW IS MAXIMISED, NOT FLOATING ──────────────────────────
    //
    // It used to sit inside 10dp of padding on all four sides PLUS the status
    // bar inset, on top of the SafeArea the setup screen already applies. That
    // is a dialog floating on a desktop, and on a 360dp phone it reads as an
    // app that could not fill its own screen. Every real installer runs
    // maximised, and a phone has no other sensible window state.
    //
    // So: edge to edge, square corners, no double inset. The SafeArea in
    // setup_screen still keeps the title bar clear of the notch.
    //
    // TRANSLUCENT, which is what keeps the wallpaper in the picture. Filling
    // the screen with an opaque surface would have hidden the distro wallpaper
    // entirely, trading one flat rectangle for another. At 0.94 the aubergine
    // reads through the chrome the way a compositor's window does, and the
    // text still passes against it.
    if (skin.kind != SetupFrameKind.wizard) return column;

    return Container(
      color: c.surface.withValues(alpha: 0.94),
      child: column,
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

  /// ─── WHY THIS FILLS THE WINDOW NOW ────────────────────────────────────
  ///
  /// It was a bare [SingleChildScrollView], which sizes its child to the
  /// child's own intrinsic height and top-aligns it. So the window was full
  /// height and the CONTENT was not, and every step ended in a band of dead
  /// space between the last row and the footer. On the welcome step that band
  /// was a third of the screen, which is what makes an installer read as a
  /// phone form that happens to have a title bar.
  ///
  /// ─── AND WHY THERE IS NO IntrinsicHeight HERE ─────────────────────────
  ///
  /// The textbook recipe for "fill but still scroll" is a scroll view plus a
  /// minHeight constraint plus [IntrinsicHeight], and it is wrong for this
  /// screen. IntrinsicHeight has to measure its children, a [ListView] cannot
  /// report an intrinsic height, and the language list is a ListView. It would
  /// have thrown on the one step this exists for.
  ///
  /// So a filling step gets a plain [Column] and no outer scroll at all: the
  /// header is fixed, [body] takes the rest, and the body scrolls itself if it
  /// needs to. That is also the honest structure, since a step that fills has
  /// something inside it built to scroll anyway.
  ///
  /// Non-filling steps keep the old scroll view untouched.
  /// The stage above, the step below.
  ///
  /// ─── THE HEIGHT IS THE FRAME'S DECISION, NOT THE CALLER'S ───────────────
  ///
  /// A step cannot know it. The rail is present on some skins and not others,
  /// the footer grows when the home-role nag is showing, and the window is
  /// maximised, so the space left for a stage is a fact about THIS frame at
  /// THIS moment. A caller passing a fixed height would be right on the phone
  /// it was measured on and wrong on a 5 inch Tecno, where the controls would
  /// be pushed under the footer.
  ///
  /// A FRACTION, CLAMPED. Roughly two fifths of what is left, never below
  /// 120dp (smaller than that and the dock and grid stop being readable, so it
  /// is decoration rather than a preview) and never above 260dp (beyond that
  /// it starts crowding the controls on a tall screen without showing more).
  /// Short screens shrink the stage; they do not scroll the controls away.
  Widget _stageAndContent(ChromeData d) {
    if (stage == null || skin.kind == SetupFrameKind.console) return _content(d);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = (constraints.maxHeight * 0.42).clamp(120.0, 260.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ClipRect, because DevicePreview draws a wallpaper edge to edge
            // and an unclipped child of a fixed-height box paints outside it
            // rather than being cut. The clip is what makes the stage a window
            // onto the desktop instead of a picture floating over the step.
            SizedBox(
              height: h,
              child: ClipRect(child: stage),
            ),
            Expanded(child: _content(d)),
          ],
        );
      },
    );
  }

  Widget _content(ChromeData d) {
    final c = d.colors;
    final centred = skin.kind == SetupFrameKind.assistant;

    final header = <Widget>[
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
    ];

    final padding = EdgeInsets.fromLTRB(centred ? 24 : 16, 18, 16, 12);
    final cross =
        centred ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    if (fills) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: cross,
          children: [...header, Expanded(child: body)],
        ),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: cross,
        children: [...header, body],
      ),
    );
  }

  // Takes the context so the footer's own copy can be translated. The build
  // method has one; a helper reached from it does not, and wrapping the
  // footer in a Builder just to find one would be a widget added to work
  // around an argument that costs nothing to pass.
  Widget _footer(BuildContext context, ChromeData d) {
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
                  label: context.t('common.back'),
                  kind: ThemedButtonKind.text,
                  onPressed: onBack!,
                ),
                const SizedBox(width: 6),
              ],
              // ── THE STATUS LINE OUTRANKS THE DOTS WHILE IT HAS SOMETHING
              //    TO SAY ────────────────────────────────────────────────
              //
              // This was `if (dots) ... else if (status != null) ...`, so on
              // any skin using dots, which includes GNOME and therefore the
              // default install, the status slot was never rendered at all. The
              // step counter never appeared, and neither did the pack sweep's
              // "Fetching package lists", which is the one line that explains
              // why Continue is dimmed. Confirmed on device: the footer showed
              // dots and nothing else through the whole download.
              //
              // Dots are decoration and the status is an answer, so the answer
              // takes the slot when there is one. It is transient by nature
              // (the sweep finishes, the line goes, the dots come back), which
              // is what makes borrowing the space acceptable rather than a
              // permanent loss of the step indicator.
              if (status != null)
                Expanded(
                  child: Text(
                    status!,
                    softWrap: true,
                    style: d.text.caption.copyWith(color: c.textMuted),
                  ),
                )
              else if (dots)
                Expanded(
                    child:
                        Center(child: _Dots(count: steps.length, step: step)))
              else
                const Spacer(),
              IgnorePointer(
                ignoring: !nextEnabled,
                child: Opacity(
                  opacity: nextEnabled ? 1 : 0.45,
                  child: ThemedButton(label: nextLabel, onPressed: onNext),
                ),
              ),
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
