/// THE SHAPE OF THIS PHONE, for anything that draws a picture of one.
///
/// ─── WHY THIS IS A FILE AND NOT A CONSTANT ──────────────────────────────────
///
/// It was a constant. `DevicePreview` framed itself at `10 / 17`, which is
/// 0.588, and every framed preview in Settings and setup inherited it. On an
/// S22 the real number is 360 / 780, which is 0.462. So the app's picture of a
/// phone was 27% wider, relative to its height, than the phone it was drawn on.
///
/// That was cosmetic while a preview only had to say WHERE the dock is. It
/// stopped being cosmetic when [WallpaperFraming.defaultFit] became `fill`.
/// That fit's whole claim, written into its own docblock, is that it maps the
/// image onto exactly this screen so the picture the settings page draws is the
/// picture the phone draws. A `fill` inside a box of the wrong shape does not
/// weaken that claim, it inverts it: the preview becomes the one place the
/// wallpaper is guaranteed to be wrong.
///
/// So the number now comes from the device, and it comes from ONE place. Two
/// callers compute it today, [DevicePreview] for its frame and [WallpaperPaint]
/// for the guard below it, and a second implementation is how those two would
/// come to disagree about whether a box is the right shape while both believing
/// they were asking the same question.
///
/// ─── A LEAF, LIKE wallpaper_framing.dart AND FOR THE SAME REASON ────────────
///
/// `wallpaper_paint.dart` is imported by `device_preview.dart`. Putting this in
/// either of them would make the other import it, and in one direction that is
/// a cycle. One import of `widgets.dart` and nothing else.
library;

import 'package:flutter/widgets.dart';

/// Below this a preview reads as a strip rather than as a phone, and the
/// clamp is what keeps a landscape window or a split-screen sliver from
/// producing one.
const double kMinPreviewAspect = 0.40;

/// Above this a preview is a tablet, and a tablet-shaped picture inside a
/// settings row eats the row. Foldables opened flat land here.
const double kMaxPreviewAspect = 0.80;

/// Used when the window has no usable size yet. A modern phone, and the same
/// number an S22 reports, so the first frame is not a different shape from the
/// second.
const double kFallbackPreviewAspect = 0.46;

/// This window's aspect, clamped to something a preview can draw.
///
/// ─── THE WINDOW, NOT THE SCREEN, AND THAT IS CORRECT ────────────────────────
///
/// `MediaQuery.sizeOf` reports the size of the window this app is rendering
/// into, which in split screen is smaller than the panel. That is the right
/// answer anyway: the launcher draws into the window, and the clamp catches the
/// shapes a split-screen sliver would otherwise produce.
///
/// Deliberately NOT reduced by the system insets. The home screen renders edge
/// to edge behind the status and navigation bars and the wallpaper fills the
/// whole surface, so subtracting the insets would describe a smaller phone than
/// the one the wallpaper is actually painted on.
double previewAspectOf(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final w = size.width;
  final h = size.height;
  // Zero on the frame before the first layout, and non-finite is not reachable
  // from a real window but is cheap to refuse. Either way, guessing beats
  // dividing by zero and handing an AspectRatio a NaN, which throws in layout.
  if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
    return kFallbackPreviewAspect;
  }
  // `.toDouble()` AFTER the clamp. `num.clamp` is declared to return `num` and
  // `double` does not override it, so without this the return does not compile.
  // It reads like a redundant conversion and is not one, which is the same note
  // `WallpaperFraming.fromJson` carries over the same trap.
  return (w / h).clamp(kMinPreviewAspect, kMaxPreviewAspect).toDouble();
}

/// How far [boxAspect] may drift from this device's before a preview stops
/// being a picture of it.
///
/// 12% is roughly the difference between a 19.5:9 phone and a 16:9 one, which
/// is a range of real devices whose wallpapers all read as correct. Past it the
/// distortion is visible on a face or a horizon without measuring anything.
const double kPreviewAspectTolerance = 0.12;

/// Is a box of [boxAspect] close enough to this device to claim it is one.
///
/// Non-finite or degenerate returns TRUE, which is the safe direction: it means
/// "no opinion", and an unbounded constraint is not evidence that the box is
/// the wrong shape. Refusing to degrade on a question that was not answerable
/// leaves the authored fit alone, which is what every caller got before this
/// existed.
bool boxMatchesDevice(BuildContext context, double boxAspect) {
  if (!boxAspect.isFinite || boxAspect <= 0) return true;
  final device = previewAspectOf(context);
  final drift = boxAspect / device;
  return drift <= 1 + kPreviewAspectTolerance &&
      drift >= 1 / (1 + kPreviewAspectTolerance);
}
