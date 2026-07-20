import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/boot_spec.dart';
import '../../engine/splash_spec.dart';

/// Whether the fake-boot overlay is currently on screen, and what it is playing.
///
/// The overlay is decoupled from onboarding on purpose. Onboarding (A7) lives
/// in its own thread; the theme-switch path and the cold-start path live
/// elsewhere again. Rather than teach each of them about the others, they all
/// just call [BootController.play] with a resolved [BootSpec], and the shell
/// gate ([BootGate], or a Stack in home_screen) watches this one provider.
///
/// Plain Riverpod 3 Notifier, no codegen.
/// What the gate is showing, if anything.
///
/// Exactly one of [spec] and [splash] is non-null while playing: the verbose
/// boot log and the quick splash are ALTERNATIVES, not a sequence. Showing a
/// splash and then a boot log would be two loading screens back to back, which
/// is what the verboseBoot pref exists to let you choose between.
class BootState {
  const BootState({
    this.playing = false,
    this.spec,
    this.splash,
    this.queued,
  });

  final bool playing;

  /// The verbose `[  OK  ]` log currently on screen.
  final BootSpec? spec;

  /// The quick splash currently on screen.
  final SplashSpec? splash;

  /// A splash to play once [spec] finishes — the FIRST-RUN chain.
  ///
  /// Normally the log and the splash are alternatives (you chose one in
  /// Settings). First run is the exception, and deliberately so: installing a
  /// Linux system means watching it boot and THEN seeing the distro's splash as
  /// the session starts. Doing both, once, is the payoff for having just set
  /// the thing up. Doing both on every launch would be tedious.
  final SplashSpec? queued;

  static const idle = BootState();
}

class BootController extends Notifier<BootState> {
  @override
  BootState build() => BootState.idle;

  /// Start a boot animation. Callers:
  ///   - cold start, if verboseBoot is on (bootstrap / home initState)
  ///   - a theme switch, if verboseBoot is on
  ///   - onboarding, once, right after "set as home"
  void play(BootSpec spec) {
    state = BootState(playing: true, spec: spec);
  }

  /// Start the quick splash — the common path, for everyone who has not turned
  /// verbose boot on. Callers: cold start and theme switch (home_screen), and
  /// the end of first-run setup.
  ///
  /// [SplashStyle.none] is a no-op rather than a zero-length overlay: the
  /// terminal theme boots into a terminal, and mounting a gate that instantly
  /// dismisses itself would still cost a frame and a rebuild.
  void playSplash(SplashSpec splash) {
    if (splash.style == SplashStyle.none) return;
    state = BootState(playing: true, splash: splash);
  }

  /// The full first-run sequence: boot log, then splash, then the desktop.
  ///
  /// Played once, at the end of initial setup. [finish] walks the chain, so the
  /// renderers stay dumb — neither knows the other exists.
  void playFirstRun(BootSpec spec, SplashSpec splash) {
    state = BootState(
      playing: true,
      spec: spec,
      // A `none` splash (the terminal theme) queues nothing, so the log ends
      // straight on the prompt rather than flashing an empty overlay.
      queued: splash.style == SplashStyle.none ? null : splash,
    );
  }

  /// The renderer calls this on completion or on tap-to-skip.
  ///
  /// If something is queued behind it, this ADVANCES rather than dismissing.
  /// That is what makes tap-to-skip on the boot log skip the log, not the whole
  /// first-run sequence.
  void finish() {
    if (!state.playing) return;

    final next = state.queued;
    if (next != null) {
      state = BootState(playing: true, splash: next);
      return;
    }

    state = BootState.idle;
  }
}

final bootControllerProvider =
    NotifierProvider<BootController, BootState>(BootController.new);
