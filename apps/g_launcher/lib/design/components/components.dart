/// The chrome primitive set — Phase B, B1/B2.
///
/// Import this one file to get every themed primitive plus the [ChromeScope] /
/// [ChromeData] plumbing:
///
///   import 'package:g_launcher/design/components/components.dart';
///
/// The contract, in one line: put a [ThemedScaffold] at the root of a chrome
/// screen and build its body out of these; nothing reads the house tokens or
/// the desktop [ThemeSpec] directly. See chrome_theme.dart for how the palette
/// becomes chrome.
library;

export 'chrome_theme.dart';
export 'glass_panel.dart';
export 'themed_button.dart';
export 'themed_dialog.dart';
export 'themed_list_row.dart';
export 'themed_progress.dart';
export 'themed_scaffold.dart';
export 'themed_sheet.dart';
export 'themed_slider.dart';
export 'themed_toggle.dart';
