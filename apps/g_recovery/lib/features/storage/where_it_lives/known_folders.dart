library;

/// A folder the user would recognise by name rather than by path.
///
/// Resolution never fails. When nothing matches, the last path segment
/// becomes the name, so every row and tile can always be labelled.
class KnownFolder {
  const KnownFolder(
    this.name, {
    this.regenerable = false,
    this.appOwned = false,
    this.collapse = false,
    this.packageName,
  });

  /// What the user is shown, for example "Thumbnail cache".
  final String name;

  /// The system rebuilds this folder on demand, so clearing it is safe.
  final bool regenerable;

  /// The folder belongs to an installed app rather than to the user.
  final bool appOwned;

  /// Everything beneath this folder reports under this one name. Set for the
  /// containers whose children are machine generated, where the child name is
  /// noise rather than information.
  final bool collapse;

  /// Set for `Android/data`, `Android/media` and `Android/obb` children.
  ///
  /// When the platform cannot resolve a label for this package the app is no
  /// longer installed, which makes the folder leftover data worth surfacing.
  final String? packageName;
}

/// Path prefixes relative to the volume root, lowercase, no trailing slash.
///
/// Longest match wins, so `dcim/camera` beats `dcim`.
const Map<String, KnownFolder> kKnownFolders = <String, KnownFolder>{
  'dcim/camera': KnownFolder('Camera'),
  'dcim/screenshots': KnownFolder('Screenshots'),
  'dcim/restored': KnownFolder('Restored photos'),
  'dcim': KnownFolder('Camera roll'),
  'pictures/screenshots': KnownFolder('Screenshots'),
  'pictures/messenger': KnownFolder('Messenger photos'),
  'pictures/instagram': KnownFolder('Instagram'),
  'pictures': KnownFolder('Pictures'),
  'movies': KnownFolder('Movies'),
  'music': KnownFolder('Music'),
  'download': KnownFolder('Downloads'),
  'downloads': KnownFolder('Downloads'),
  'documents': KnownFolder('Documents'),
  'recordings': KnownFolder('Voice recordings'),
  'audiobooks': KnownFolder('Audiobooks'),
  'podcasts': KnownFolder('Podcasts'),
  'ringtones': KnownFolder('Ringtones'),
  'alarms': KnownFolder('Alarms'),
  'notifications': KnownFolder('Notification sounds'),
  'bluetooth': KnownFolder('Received over Bluetooth'),
  'telegram': KnownFolder('Telegram'),
  'whatsapp/media': KnownFolder('WhatsApp media'),
  'whatsapp/databases': KnownFolder('WhatsApp backups'),
  'whatsapp': KnownFolder('WhatsApp'),
  'android/.thumbnails': KnownFolder(
    'Thumbnail cache',
    regenerable: true,
    collapse: true,
  ),
  '.thumbnails': KnownFolder(
    'Thumbnail cache',
    regenerable: true,
    collapse: true,
  ),
  'android/.trash': KnownFolder('Recently deleted', collapse: true),
  '.trashed': KnownFolder('Recently deleted', collapse: true),
  'android/data': KnownFolder('App data', appOwned: true),
  'android/media': KnownFolder('App media', appOwned: true),
  'android/obb': KnownFolder('Game data', appOwned: true),
  'lost.dir': KnownFolder('Recovered fragments', collapse: true),
  'log': KnownFolder('Logs', regenerable: true, collapse: true),
  'cache': KnownFolder('Cache', regenerable: true, collapse: true),
};

/// Labels for packages a phone is likely to hold, used when the platform does
/// not resolve one. Not a substitute for PackageManager: this is the fallback
/// that keeps the commonest folders readable before that hook is wired, and it
/// is also what names a folder left behind by an app that was uninstalled.
const Map<String, String> kKnownPackages = <String, String>{
  'com.whatsapp': 'WhatsApp',
  'com.whatsapp.w4b': 'WhatsApp Business',
  'org.telegram.messenger': 'Telegram',
  'com.instagram.android': 'Instagram',
  'com.facebook.katana': 'Facebook',
  'com.facebook.orca': 'Messenger',
  'com.snapchat.android': 'Snapchat',
  'com.zhiliaoapp.musically': 'TikTok',
  'com.twitter.android': 'X',
  'com.spotify.music': 'Spotify',
  'com.google.android.youtube': 'YouTube',
  'com.viber.voip': 'Viber',
  'org.thoughtcrime.securesms': 'Signal',
  'com.tencent.mm': 'WeChat',
  'com.microsoft.teams': 'Teams',
  'us.zoom.videomeetings': 'Zoom',
  'com.opera.mini.native': 'Opera Mini',
  'com.android.chrome': 'Chrome',
};

/// Package containers whose immediate child is a package name.
const List<String> kPackageParents = <String>[
  'android/data',
  'android/media',
  'android/obb',
];

const List<String> _volumeRoots = <String>[
  '/storage/emulated/0',
  '/sdcard',
  '/mnt/sdcard',
];

/// Strips the volume root and any surrounding slashes.
String normaliseFolderPath(String path) {
  var value = path.trim().replaceAll(r'\', '/');
  for (final root in _volumeRoots) {
    if (value.startsWith(root)) {
      value = value.substring(root.length);
      break;
    }
  }
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// Resolves a folder path to something a person recognises.
///
/// [appLabelFor] should return the launcher label for a package, or null when
/// the package is not installed. Wire it to PackageManager through the existing
/// bridge so any app's folder gets a real name without a table entry.
KnownFolder resolveKnownFolder(
  String path, {
  String? Function(String packageName)? appLabelFor,
}) {
  final relative = normaliseFolderPath(path);
  if (relative.isEmpty) return const KnownFolder('Internal storage');

  final lower = relative.toLowerCase();

  final packaged = _resolvePackaged(relative, lower, appLabelFor);
  if (packaged != null) return packaged;

  final exact = kKnownFolders[lower];
  if (exact != null) return exact;

  String? bestKey;
  for (final key in kKnownFolders.keys) {
    if (!lower.startsWith('$key/')) continue;
    if (bestKey == null || key.length > bestKey.length) bestKey = key;
  }
  if (bestKey != null) {
    /// The parent name alone, never parent plus leaf. Samsung's trash holds
    /// directories named things like `!%#@$`, and gluing that onto "Recently
    /// deleted" puts encoded junk on screen. The leaf is already visible on the
    /// path line for anyone who wants it.
    final parent = kKnownFolders[bestKey]!;
    if (parent.collapse) return parent;
    return KnownFolder(
      _segmentName(relative),
      regenerable: parent.regenerable,
      appOwned: parent.appOwned,
    );
  }

  return KnownFolder(_segmentName(relative));
}

KnownFolder? _resolvePackaged(
  String relative,
  String lower,
  String? Function(String packageName)? appLabelFor,
) {
  for (final parent in kPackageParents) {
    if (!lower.startsWith('$parent/')) continue;

    final tail = relative.substring(parent.length + 1);
    final slash = tail.indexOf('/');
    final package = slash == -1 ? tail : tail.substring(0, slash);
    if (package.isEmpty) continue;

    final label = appLabelFor?.call(package) ?? kKnownPackages[package];
    final name = label ?? package;
    final suffix = slash == -1 ? '' : ' / ${_segmentName(tail)}';

    return KnownFolder(
      '$name$suffix',
      appOwned: true,
      packageName: package,
      regenerable: lower.contains('/cache'),
    );
  }
  return null;
}

/// The folder a path reports under.
///
/// Native walks the tree and returns folders at whatever depth it found them,
/// so `Android/.Trash/!%#@$`, `Android/.Trash/com.sec.android.gallery3d` and a
/// dozen `WhatsApp/Media/...` directories arrive as separate rows. Grouping them
/// is what stops the section listing the same thing seven times.
///
/// Depth is the deepest of three candidates: [maxDepth] segments from the volume
/// root, the longest matching entry in the known folder table, and the package
/// level inside an `Android/data`, `Android/media` or `Android/obb` container.
/// A collapse marked entry wins outright, since everything under it is one thing.
String folderGroupKey(String folderPath, {int maxDepth = 2}) {
  final relative = normaliseFolderPath(folderPath);
  if (relative.isEmpty) return '';

  final lower = relative.toLowerCase();
  final segments = relative
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  var depth = segments.length < maxDepth ? segments.length : maxDepth;

  for (final parent in kPackageParents) {
    if (!lower.startsWith('$parent/')) continue;
    final packageDepth = parent.split('/').length + 1;
    if (segments.length >= packageDepth && packageDepth > depth) {
      depth = packageDepth;
    }
  }

  for (final entry in kKnownFolders.entries) {
    final key = entry.key;
    if (lower != key && !lower.startsWith('$key/')) continue;
    final keyDepth = key.split('/').length;
    if (entry.value.collapse) return segments.take(keyDepth).join('/');
    if (keyDepth > depth) depth = keyDepth;
  }

  return segments.take(depth).join('/');
}

String _segmentName(String relative) {
  final segments = relative.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return 'Internal storage';

  var leaf = segments.last;
  if (leaf.startsWith('.') && leaf.length > 1) leaf = leaf.substring(1);
  if (leaf.isEmpty) return 'Internal storage';

  return leaf[0].toUpperCase() + leaf.substring(1);
}
