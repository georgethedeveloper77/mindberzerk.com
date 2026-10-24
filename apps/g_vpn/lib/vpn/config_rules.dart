/// Applies G VPN's rules to a wg-quick config before it reaches the backend.
///
/// Pure text in, text out, so it is unit tested without a device. The saved
/// config is never modified: rules are layered on at connect time, which
/// means turning a rule off restores the user's own settings exactly.
library;

/// Quad9: blocks known malware and phishing domains, never ads, and keeps no
/// IP logs. Blocking ads would break Play's VPN policy.
const shieldResolvers = ['9.9.9.9', '149.112.112.112'];

String applyRules(
  String configText, {
  Iterable<String> excludedApps = const [],
  List<String>? dns,
}) {
  final excluded = excludedApps.toList()..sort();
  final stripApps = excluded.isNotEmpty;
  final stripDns = dns != null && dns.isNotEmpty;
  if (!stripApps && !stripDns) return configText;

  final lines = configText.split('\n');
  final out = <String>[];
  var inInterface = false;
  var injected = false;

  void inject() {
    if (injected) return;
    // Trailing blank lines before the next section stay below our additions.
    var trailing = 0;
    while (out.isNotEmpty && out.last.trim().isEmpty) {
      out.removeLast();
      trailing++;
    }
    if (stripDns) out.add('DNS = ${dns.join(', ')}');
    if (stripApps) out.add('ExcludedApplications = ${excluded.join(', ')}');
    out.addAll(List.filled(trailing, ''));
    injected = true;
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      if (inInterface) inject();
      inInterface = trimmed.toLowerCase() == '[interface]';
      out.add(line);
      continue;
    }
    if (inInterface && trimmed.contains('=')) {
      final key = trimmed.substring(0, trimmed.indexOf('=')).trim().toLowerCase();
      // WireGuard allows Excluded OR Included, never both, so ours replaces
      // whichever the user's config carried.
      final ours = (stripApps && (key == 'excludedapplications' || key == 'includedapplications')) ||
          (stripDns && key == 'dns');
      if (ours) continue;
    }
    out.add(line);
  }
  if (inInterface) inject();
  return out.join('\n');
}
