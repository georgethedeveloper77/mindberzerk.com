/// Turning the app list into `/apps` entries.
///
/// Pure functions, no Riverpod, no platform, so the naming rule that the whole
/// namespace depends on is testable without a device.
library;

/// The entry name an app gets inside `/apps`.
///
/// A slugged LABEL, not the package name. Nobody types `org.mozilla.firefox`,
/// and the package is still printed by `ls -l` and by `cat`, which is where the
/// truthful identifier belongs.
///
/// Labels collide, and on the Transsion devices this app targets they collide
/// constantly: two apps called Camera is the normal case, not the edge one. So
/// a clash appends `-2`, `-3`, in the order the list arrives, which is already
/// alphabetical by label from `shellAppsProvider`. Deterministic ordering in
/// means deterministic names out, which matters because a user who typed
/// `cat /apps/camera-2` yesterday should get the same app today.
String appSlug(String label) {
  final StringBuffer out = StringBuffer();
  var lastWasDash = true;
  for (final int unit in label.toLowerCase().codeUnits) {
    final bool alnum = (unit >= 0x61 && unit <= 0x7a) ||
        (unit >= 0x30 && unit <= 0x39);
    if (alnum) {
      out.writeCharCode(unit);
      lastWasDash = false;
    } else if (!lastWasDash) {
      out.write('-');
      lastWasDash = true;
    }
  }
  var slug = out.toString();
  while (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  // A label with nothing sluggable in it, which a CJK or emoji-only name is.
  // Falling back to a fixed word and letting the collision counter do the rest
  // keeps every app reachable by SOME name rather than by none.
  return slug.isEmpty ? 'app' : slug;
}

/// Assign a unique slug to each label, in order.
List<String> assignSlugs(Iterable<String> labels) {
  final Map<String, int> seen = <String, int>{};
  final List<String> out = <String>[];
  for (final String label in labels) {
    final String base = appSlug(label);
    final int count = (seen[base] ?? 0) + 1;
    seen[base] = count;
    out.add(count == 1 ? base : '$base-$count');
  }
  return out;
}

/// The package name a component key names.
///
/// ─── READ THIS BEFORE CHANGING IT ───────────────────────────────────────────
///
/// `AppEntry` may well expose a package name directly, in which case this
/// derivation should be deleted and the ONE call site in the adapter changed to
/// read the field. I have not read `launcher_api.g.dart`, so this parses the
/// component key instead of asserting about a schema I have not seen.
///
/// The shapes it handles are the conventional ones: `package/class`, and a work
/// profile suffix `#userSerial` if one is present. Anything without a separator
/// is returned whole, so the worst case is that `cat` prints the component key
/// rather than the package, which is a cosmetic loss and not a wrong answer.
String packageOfComponentKey(String componentKey) {
  var key = componentKey;
  final int hash = key.indexOf('#');
  if (hash > 0) key = key.substring(0, hash);
  final int slash = key.indexOf('/');
  if (slash > 0) key = key.substring(0, slash);
  return key;
}
