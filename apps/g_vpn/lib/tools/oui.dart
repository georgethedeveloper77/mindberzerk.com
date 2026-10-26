import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Makers by hardware address prefix, from the IEEE registry bundled in
/// assets/oui/ (tool/build_oui.py). Loaded once, on first use.
abstract final class Oui {
  static Future<Map<String, String>>? _table;

  static Future<Map<String, String>> _load() async {
    try {
      final data = await rootBundle.load('assets/oui/oui.tsv.gz');
      final text = utf8.decode(gzip.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
      return {
        for (final line in const LineSplitter().convert(text))
          if (line.length > 7) line.substring(0, 6): line.substring(7),
      };
    } on Exception {
      // No list bundled: makers simply stay unknown.
      return const {};
    }
  }

  /// True when the address was made up by the device (privacy addresses):
  /// the "locally administered" bit is set, so no maker owns it.
  static bool isPrivate(String mac) {
    final first = int.tryParse(mac.split(':').first, radix: 16);
    return first != null && first & 0x02 != 0;
  }

  /// The maker for [mac], or null when unknown or private.
  static Future<String?> maker(String mac) async {
    if (mac.length < 8 || isPrivate(mac)) return null;
    final table = await (_table ??= _load());
    return table[mac.replaceAll(':', '').substring(0, 6).toUpperCase()];
  }
}

/// [mac] with its last three parts hidden ("30:FD:65:••:••:••") when [hide].
String maskMac(String mac, {required bool hide}) {
  if (!hide) return mac.toUpperCase();
  final parts = mac.toUpperCase().split(':');
  if (parts.length != 6) return mac;
  return [...parts.take(3), '••', '••', '••'].join(':');
}
