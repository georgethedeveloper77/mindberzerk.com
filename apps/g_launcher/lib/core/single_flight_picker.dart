/// One system photo picker at a time, process-wide.
///
/// ─── WHY EVERY PICK GOES THROUGH HERE ───────────────────────────────────────
///
/// image_picker holds a single pending intent natively. A second call while
/// one is open (a double tap on an add tile, or the Gallery strip and a
/// collection screen racing) throws `PlatformException(already_active)`, and
/// both call sites awaited it bare, so it reached PlatformDispatcher.onError
/// as a fatal: the `image_picker_android` `_extractReplyValueOrThrow` crash.
///
/// A launch already in flight is joined instead of repeated. `already_active`
/// can still arrive when Android restored the process under an open picker, so
/// it is treated as "nothing picked" rather than an error.
library;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

abstract final class SingleFlightPicker {
  static final ImagePicker _picker = ImagePicker();

  /// The open launch, typed loosely because single and multi picks share it.
  static Future<Object?>? _inFlight;

  /// One photo, or null when cancelled or when a picker is already open.
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) =>
      _single<XFile?>(
        () => _picker.pickImage(source: source),
        none: null,
      );

  /// One video, or null when cancelled or when a picker is already open.
  static Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
  }) =>
      _single<XFile?>(
        () => _picker.pickVideo(source: source),
        none: null,
      );

  /// Several photos, or an empty list when cancelled or already open.
  static Future<List<XFile>> pickMultiImage() => _single<List<XFile>>(
        _picker.pickMultiImage,
        none: const <XFile>[],
      );

  static Future<T> _single<T>(
    Future<T> Function() launch, {
    required T none,
  }) async {
    final pending = _inFlight;
    if (pending != null) {
      // Same kind of pick: share its answer. Different kind: this tap simply
      // loses, which is what the user sees anyway with one sheet on screen.
      final shared = await pending;
      return shared is T ? shared : none;
    }

    final run = _guarded(launch, none);
    _inFlight = run;
    try {
      return await run;
    } finally {
      _inFlight = null;
    }
  }

  static Future<T> _guarded<T>(Future<T> Function() launch, T none) async {
    try {
      return await launch();
    } on PlatformException catch (e) {
      if (e.code == 'already_active') return none;
      rethrow;
    }
  }
}
