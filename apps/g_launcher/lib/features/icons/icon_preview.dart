/// Real apps, drawn by the native icon pipeline in an arbitrary tint.
///
/// ─── LIFTED OUT OF setup_screen, AND WHY THAT WAS THE RIGHT MOVE ────────────
///
/// This lived as `_iconPreviewProvider` inside the setup wizard, private, for
/// one card on one step. The Icons screen needs the same picture for a
/// different reason and had a different answer: `packPreviewUrl` points at a
/// `preview.png` inside the pack directory.
///
/// That answer cannot work for the fourteen derived packs, and not because of a
/// bug. A derived pack is 491 bytes of `{id, name, extends, tint}` with no art
/// at all, which is the whole reason fourteen products cost 10 MB rather than
/// 148. There is no image in there to point at, so the URL resolves, 404s, and
/// the card falls back to a generic schematic. Fourteen identical grey squares
/// in a row whose entire subject is colour.
///
/// Shipping fourteen PNGs would fix the symptom by reintroducing the thing the
/// format was designed to avoid: the same six glyphs, fourteen times, as
/// bitmaps, for packs built specifically to carry none.
///
/// Rendering is better on every axis. The bytes come from the same pipeline
/// that draws the drawer, so a preview cannot disagree with what applying it
/// would produce; a fifteenth pack works with no extra step; and the tint is
/// data rather than a baked pixel.
///
/// ─── AND THE TINT IS THE DISTRO'S ACCENT, BY CONSTRUCTION ───────────────────
///
/// `ubuntu-24-04-line` carries `#e95420` and so does Ubuntu's palette, because
/// `build-vector-pack.mjs` was given the accent when the pack was built. So a
/// caller with a palette has the tint without fetching anything, which is what
/// lets this work before an index has ever been read.
library;

import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../platform/launcher_api.g.dart';

/// `#RRGGBB` for the native preview bridge, which parses a hex string.
///
/// Alpha is dropped rather than passed: a tint is a colour, the pack applies it
/// at full opacity, and handing native eight hex digits where it expects six
/// fails as a black icon rather than as an error.
String previewHexOf(Color c) {
  final v = c.toARGB32() & 0x00FFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// Up to [count] of the user's real apps, rendered in [tint].
///
/// A RECORD as the family key, for the structural equality a key needs without
/// a hand-written `==` whose only failure mode is forgetting the next field.
///
/// Auto-disposing on purpose: these bitmaps describe a moment of choosing and
/// must not outlive the screen that asked. Native caches none of them either,
/// because `IconCache` keys by the APPLIED style and a previewed colour is not
/// one.
///
/// [count] is part of the key rather than a constant, because the two callers
/// want different amounts: the setup step fills an eight-cell grid, a colour
/// swatch in the strip is 34dp and wants four. Rendering eight to show four
/// would be double the native work per swatch across thirteen of them.
///
/// Empty on every failure. The pack may not be installed, or the bridge may not
/// be there at all, which is exactly the state of a widget test. Every caller
/// draws its own fallback, so an empty list is a picture rather than an error.
final iconPreviewProvider = FutureProvider.family<List<Uint8List?>,
    ({String tint, int sizePx, int count})>((ref, key) async {
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  if (apps.isEmpty) return const [];

  final keys = [for (final a in apps.take(key.count)) a.componentKey];
  try {
    return await ref
        .read(launcherHostApiProvider)
        .previewIcons(keys, key.tint, key.sizePx);
  } catch (_) {
    return const [];
  }
});
