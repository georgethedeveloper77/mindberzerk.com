import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pro/billing.dart';

/// Link checks a free user gets each calendar month. Pro is unlimited,
/// and so is everyone while Pro sales are closed.
const freeLinkChecksPerMonth = 10;

/// This month's link checks, kept on the phone.
class Allowance {
  const Allowance({required this.used, required this.unlimited});

  final int used;
  final bool unlimited;

  int get left => unlimited ? freeLinkChecksPerMonth : (freeLinkChecksPerMonth - used).clamp(0, freeLinkChecksPerMonth);
  bool get canCheck => unlimited || left > 0;
}

final allowanceProvider = AsyncNotifierProvider<AllowanceController, Allowance>(AllowanceController.new);

class AllowanceController extends AsyncNotifier<Allowance> {
  static const _key = 'gvpn.linkchecks.v1';

  static String _month(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool get _unlimited => !proSalesOpen || ref.watch(billingProvider).owned;

  @override
  Future<Allowance> build() async {
    final unlimited = _unlimited;
    return Allowance(used: await _usedThisMonth(), unlimited: unlimited);
  }

  Future<int> _usedThisMonth() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return 0;
    try {
      final j = jsonDecode(raw);
      // A new month starts from zero.
      return j is Map && j['month'] == _month(DateTime.now()) && j['used'] is int ? j['used'] as int : 0;
    } on FormatException {
      return 0;
    }
  }

  /// Counts one finished check (failed checks are free).
  Future<void> spend() async {
    final current = await future;
    if (current.unlimited) return;
    final used = await _usedThisMonth() + 1;
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode({'month': _month(DateTime.now()), 'used': used}));
    state = AsyncData(Allowance(used: used, unlimited: false));
  }
}
