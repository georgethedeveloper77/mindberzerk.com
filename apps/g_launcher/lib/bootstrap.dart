import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Runs before the first frame. Keep it FAST — every millisecond here is a
/// millisecond between the user pressing home and seeing their desktop.
///
/// Anything slow (app list, icon cache warm-up) belongs on the Kotlin side, on
/// a background thread, not in here.
///
/// ## What is deliberately NOT here: the pack bridge
///
/// `PackFlutterApi.setUp` needs a Riverpod `Ref` and there is no container yet
/// at this point — `runApp(ProviderScope(...))` has not been called. So the
/// registration lives in `packBridgeProvider`, watched once at the app root.
///
/// That is the better home anyway. Pigeon's `setUp` REPLACES any previous
/// handler on the channel, so registering from a widget's `initState` would
/// silently unhook whichever instance registered before it, and the symptom is
/// a download progress bar that works right up until you open a second screen.
/// A provider is registered once for the life of the container and cannot be
/// double-installed.
void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  // A launcher draws its own wallpaper. Let it run under the system bars.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
    ),
  );
}
