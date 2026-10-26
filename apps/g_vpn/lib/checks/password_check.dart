import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Have I Been Pwned's Pwned Passwords range API: free, no key.
const _rangeUrl = 'https://api.pwnedpasswords.com/range/';

/// How many times [password] appears in known breaches; 0 when never.
///
/// k-anonymity: only the first 5 characters of the password's SHA-1 leave
/// the phone. The service answers with every suffix that shares them (with
/// padding, so even the size of the answer says nothing), and the match is
/// made here.
Future<int> pwnedCount(String password, {http.Client? client}) async {
  final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
  final prefix = hash.substring(0, 5), suffix = hash.substring(5);
  final c = client ?? http.Client();
  try {
    final res = await c.get(
      Uri.parse('$_rangeUrl$prefix'),
      headers: const {'Add-Padding': 'true', 'User-Agent': 'G-VPN-Android'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
    return countInRange(res.body, suffix);
  } finally {
    if (client == null) c.close();
  }
}

/// Finds [suffix] in a range answer ("SUFFIX:COUNT" lines). Padding rows
/// carry a count of 0, so they never match as a leak.
int countInRange(String body, String suffix) {
  for (final line in const LineSplitter().convert(body)) {
    final i = line.indexOf(':');
    if (i <= 0) continue;
    if (line.substring(0, i).trim().toUpperCase() == suffix) {
      return int.tryParse(line.substring(i + 1).trim()) ?? 0;
    }
  }
  return 0;
}
