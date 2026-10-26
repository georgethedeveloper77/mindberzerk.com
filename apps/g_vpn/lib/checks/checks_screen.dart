import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../history/stats_widgets.dart' show MiniSegment;
import '../i18n/strings.g.dart';
import '../pro/pro_screen.dart';
import 'check_allowance.dart';
import 'link_check.dart';
import 'password_check.dart';

enum CheckKind { password, link }

/// Password and link checks, one switch apart.
class ChecksScreen extends StatefulWidget {
  const ChecksScreen({super.key, this.initial = CheckKind.password});

  final CheckKind initial;

  @override
  State<ChecksScreen> createState() => _ChecksScreenState();
}

class _ChecksScreenState extends State<ChecksScreen> {
  late CheckKind _kind = widget.initial;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(title: Text(t.checks.title), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: MiniSegment(
              labels: [t.checks.password, t.checks.link],
              index: _kind.index,
              onChanged: (i) => setState(() => _kind = CheckKind.values[i]),
            ),
          ),
          const SizedBox(height: 18),
          // Each keeps its own field and result while the other is shown.
          Offstage(offstage: _kind != CheckKind.password, child: const _PasswordCheck()),
          Offstage(offstage: _kind != CheckKind.link, child: const _LinkCheck()),
        ],
      ),
    );
  }
}

// ── Password ────────────────────────────────────────────────────────────

class _PasswordCheck extends StatefulWidget {
  const _PasswordCheck();

  @override
  State<_PasswordCheck> createState() => _PasswordCheckState();
}

class _PasswordCheckState extends State<_PasswordCheck> {
  final _field = TextEditingController();
  bool _visible = false;
  bool _busy = false;

  /// Times seen in leaks; null before a check or after a failure.
  int? _count;
  bool _failed = false;

  @override
  void dispose() {
    // The password is not kept once the screen closes.
    _field.clear();
    _field.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final password = _field.text;
    if (password.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _failed = false;
      _count = null;
    });
    try {
      final n = await pwnedCount(password);
      if (mounted) setState(() => _count = n);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final n = _count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.checks.pwTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
        const SizedBox(height: 14),
        TextField(
          controller: _field,
          obscureText: !_visible,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          onChanged: (_) => setState(() {}),
          style: m.monoStyle(size: 17, color: m.text),
          decoration: InputDecoration(
            labelText: t.checks.pwHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: IconButton(
              tooltip: _visible ? t.checks.hidePassword : t.checks.showPassword,
              onPressed: () => setState(() => _visible = !_visible),
              icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CheckButton(busy: _busy, onPressed: _field.text.isEmpty ? null : _check),
        const SizedBox(height: 16),
        if (n != null && n > 0)
          _Result(
            tone: m.bad,
            icon: Icons.warning_amber_rounded,
            title: t.checks.leaked,
            detail: t.checks.seen(n: MaterialLocalizations.of(context).formatDecimal(n)),
            advice: t.checks.leakedAdvice,
          )
        else if (n == 0)
          _Result(tone: m.good, icon: Icons.verified_outlined, title: t.checks.notFound, advice: t.checks.notFoundAdvice)
        else if (_failed)
          _Result(tone: m.warn, icon: Icons.wifi_off_rounded, title: t.checks.failed),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: m.good),
            const SizedBox(width: 6),
            Text(t.checks.private, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: m.muted)),
          ],
        ),
      ],
    );
  }
}

// ── Link ────────────────────────────────────────────────────────────────

class _LinkCheck extends ConsumerStatefulWidget {
  const _LinkCheck();

  @override
  ConsumerState<_LinkCheck> createState() => _LinkCheckState();
}

class _LinkCheckState extends ConsumerState<_LinkCheck> {
  final _field = TextEditingController();
  bool _busy = false;
  LinkResult? _result;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _field.text = text);
  }

  Future<void> _check() async {
    if (_busy || _field.text.trim().isEmpty) return;
    final allowance = await ref.read(allowanceProvider.future);
    if (!allowance.canCheck || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final r = await checkLink(_field.text);
      // Only an answered check uses one of the month's free checks.
      await ref.read(allowanceProvider.notifier).spend();
      if (mounted) setState(() => _result = r);
    } on LinkCheckException catch (e) {
      if (mounted) setState(() => _error = e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final r = _result;
    final allowance = ref.watch(allowanceProvider).value;
    final usedUp = allowance != null && !allowance.canCheck;
    final error = switch (_error) {
      null => null,
      'invalid' => t.checks.invalid,
      'busy' => t.checks.busy,
      'unavailable' => t.checks.unavailable,
      _ => t.checks.failed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.checks.linkTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5, color: m.text)),
        const SizedBox(height: 14),
        TextField(
          controller: _field,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _check(),
          onChanged: (_) => setState(() {}),
          style: m.monoStyle(size: 15, color: m.text),
          decoration: InputDecoration(
            labelText: t.checks.linkHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: TextButton(onPressed: _paste, child: Text(t.checks.paste)),
          ),
        ),
        const SizedBox(height: 12),
        _CheckButton(busy: _busy, onPressed: _field.text.trim().isEmpty || usedUp ? null : _check),
        if (allowance != null && !allowance.unlimited && !usedUp) ...[
          const SizedBox(height: 8),
          Text(
            t.checks.left(n: allowance.left, total: freeLinkChecksPerMonth),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: m.muted),
          ),
        ],
        const SizedBox(height: 16),
        if (usedUp)
          _Result(
            tone: m.brand,
            icon: Icons.workspace_premium_outlined,
            title: t.checks.usedUp,
            advice: t.checks.usedUpSub,
            action: (t.checks.getPro, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProScreen()))),
          )
        else if (r != null && r.verdict == LinkVerdict.danger)
          _Result(
            tone: m.bad,
            icon: Icons.gpp_bad_outlined,
            title: t.checks.danger,
            detail: t.checks.listed,
            advice: t.checks.dangerAdvice,
            rows: [
              if (r.hops > 0) (t.checks.goesTo, r.finalUrl),
              if (r.hops > 0) (t.checks.redirects, '${r.hops}'),
            ],
          )
        else if (r != null && r.verdict == LinkVerdict.missing)
          _Result(tone: m.warn, icon: Icons.link_off_rounded, title: t.checks.missing, advice: t.checks.missingAdvice)
        else if (r != null)
          _Result(
            tone: m.good,
            icon: Icons.verified_user_outlined,
            title: t.checks.clear,
            advice: t.checks.clearAdvice,
            rows: [
              if (r.hops > 0) (t.checks.goesTo, r.finalUrl),
              if (r.hops > 0) (t.checks.redirects, '${r.hops}'),
            ],
          )
        else if (error != null)
          _Result(tone: m.warn, icon: Icons.info_outline_rounded, title: error),
      ],
    );
  }
}

// ── Shared ──────────────────────────────────────────────────────────────

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          child: busy
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.mer.muted))
              : Text(t.checks.check),
        ),
      );
}

/// A verdict card, tinted by [tone], with optional detail rows.
class _Result extends StatelessWidget {
  const _Result({
    required this.tone,
    required this.icon,
    required this.title,
    this.detail,
    this.advice,
    this.rows = const [],
    this.action,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String? detail;
  final String? advice;
  final List<(String, String)> rows;

  /// A button under the advice: label and what it does.
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(Meridian.rCard),
          border: Border.all(color: tone.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tone)),
                      if (detail != null && detail!.isNotEmpty) Text(detail!, style: m.monoStyle(size: 13, color: m.text)),
                    ],
                  ),
                ),
              ],
            ),
            if (advice != null) ...[
              const SizedBox(height: 10),
              Text(advice!, style: TextStyle(fontSize: 14, height: 1.45, color: m.text)),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final (label, value) in rows) MerRow(label, value, mono: true),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: action!.$2,
                  style: FilledButton.styleFrom(
                    backgroundColor: tone,
                    foregroundColor: m.onBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(action!.$1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
