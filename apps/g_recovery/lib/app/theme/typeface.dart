/// The user selectable typefaces, and the one function that applies one.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/logging.dart';

/// A sans face and the monospace face that goes with it.
///
/// Paired rather than chosen separately. Two pickers would let a user put
/// Space Grotesk headings above Roboto Mono figures, and nobody who wants that
/// combination is going to find it in a settings screen anyway. One choice,
/// two families, and the pairing is a decision made here once.
///
/// The mono half matters more than it looks. Every byte count, every sensor
/// reading and every uppercase section label is drawn in it, so a face whose
/// digits are ambiguous at 10.5 dp is disqualified regardless of how the
/// headings look.
enum GTypeface {
  /// Downloads nothing and always renders. This is the default and it stays
  /// the default: an app whose first launch is often on a metered connection
  /// should not spend it on a font before the user has asked for one.
  system(id: 'system', label: 'System', sansFamily: null, monoFamily: null),

  inter(
    id: 'inter',
    label: 'Inter',
    sansFamily: 'Inter',
    monoFamily: 'JetBrains Mono',
  ),

  /// Carries Arabic, Hebrew and Cyrillic in the same family, which none of the
  /// others below do. The safest choice for the non Latin locales.
  rubik(
    id: 'rubik',
    label: 'Rubik',
    sansFamily: 'Rubik',
    monoFamily: 'JetBrains Mono',
  ),

  plex(
    id: 'plex',
    label: 'IBM Plex',
    sansFamily: 'IBM Plex Sans',
    monoFamily: 'IBM Plex Mono',
  ),

  manrope(
    id: 'manrope',
    label: 'Manrope',
    sansFamily: 'Manrope',
    monoFamily: 'JetBrains Mono',
  ),

  nunito(
    id: 'nunito',
    label: 'Nunito Sans',
    sansFamily: 'Nunito Sans',
    monoFamily: 'Roboto Mono',
  ),

  grotesk(
    id: 'grotesk',
    label: 'Space Grotesk',
    sansFamily: 'Space Grotesk',
    monoFamily: 'JetBrains Mono',
  );

  const GTypeface({
    required this.id,
    required this.label,
    required this.sansFamily,
    required this.monoFamily,
  });

  /// Persisted string. Never the enum index: adding a face in the middle of
  /// this list would otherwise reassign every user's choice.
  final String id;

  final String label;

  /// The Google Fonts family name, exactly as the manifest spells it. Null
  /// means leave the family alone and let the platform decide.
  final String? sansFamily;
  final String? monoFamily;

  bool get isSystem => sansFamily == null;

  static const GTypeface fallback = GTypeface.system;

  static GTypeface fromId(String? id) {
    for (final GTypeface face in GTypeface.values) {
      if (face.id == id) return face;
    }
    return fallback;
  }
}

/// Applies [family] to [base], keeping everything [base] already decided.
///
/// ─── WHY THE COPYWITH AFTERWARDS ─────────────────────────────────────────────
///
/// GoogleFonts.getFont builds its own style and sets its own fallback chain, so
/// the tabular figures feature and our monospace fallback stack are both lost
/// on the way through. Putting them back is not belt and braces: without the
/// feature the storage headline changes width on every tick of GCountUp, and
/// without the stack a face that failed to download renders in whatever
/// proportional font the platform picks rather than in the platform monospace.
///
/// A missing family is a caught error rather than a crash. The manifest is a
/// remote list that we do not control, and a face that disappears from it
/// should cost the user their font choice, not their app.
TextStyle applyFace(TextStyle base, String? family) {
  if (family == null) return base;
  try {
    return GoogleFonts.getFont(family, textStyle: base).copyWith(
      fontFeatures: base.fontFeatures,
      fontFamilyFallback: base.fontFamilyFallback,
    );
  } on Object catch (cause) {
    GLog.w('typeface $family is not available', scope: 'type', cause: cause);
    return base;
  }
}
