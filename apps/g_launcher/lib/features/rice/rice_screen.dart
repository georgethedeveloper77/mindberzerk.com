import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/layout_snapshots.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../themes/theme_catalog.dart';
import '../themes/theme_detail_screen.dart';
import 'rice_code.dart';

/// Wear a rice someone sent: on its distro, after saving the current layout.
///
/// The CURRENT layout of that distro is committed first, so `layout undo` in
/// the terminal (or the next snapshot UI) always gets it back. A rice for a
/// distro this phone cannot boot yet opens that distro's store page instead,
/// which is the sales half of the feature.
Future<void> applyRice(
  BuildContext context,
  WidgetRef ref,
  RicePayload rice,
) async {
  final current = ref.read(selectedThemeIdProvider).asData?.value;
  final cards = await ref.read(themeCatalogProvider.future);
  ThemeCard? card;
  for (final c in cards) {
    if (c.specId == rice.distroId) card = c;
  }
  final onPhone = rice.distroId == current ||
      card?.status == CardStatus.bundled ||
      card?.status == CardStatus.installed ||
      card?.status == CardStatus.updateAvailable;

  if (!context.mounted) return;
  if (!onPhone) {
    context.showMessage(
        context.t('rice.getDistroFirst', {'name': rice.distroName}));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ThemeDetailScreen(packId: card?.packIdOrSpec ?? rice.distroId),
      ),
    );
    return;
  }

  final id = rice.distroId;
  final prefs = await ref.read(prefsProvider(id).future);
  await LayoutSnapshots.commit(
    ref.read(prefsStoreProvider),
    id,
    prefs.toJson(),
    message: 'before rice from ${rice.distroName}',
    auto: true,
  );
  await ref.read(prefsProvider(id).notifier).edit(
        (p) => LauncherPrefs.fromJson(RiceCode.applyTo(p.toJson(), rice)),
      );
  if (id != current) {
    await ref.read(selectedThemeIdProvider.notifier).select(id);
  }
  if (context.mounted) context.showMessage(context.t('rice.applied'));
}

/// Share your rice: the setup as a code, and the way to wear someone else's.
class RiceScreen extends ConsumerStatefulWidget {
  const RiceScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<RiceScreen> createState() => _RiceScreenState();
}

class _RiceScreenState extends ConsumerState<RiceScreen> {
  /// OFF by default. Which apps sit on someone's dock is theirs to publish,
  /// and most of the people receiving a rice do not have the same apps.
  bool _includeApps = false;

  RicePayload? _rice;
  String _code = '';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final t = widget.theme;
    final prefs = await ref.read(prefsProvider(t.spec.id).future);
    if (!mounted) return;
    final rice = RiceCode.fromPrefs(
      distroId: t.spec.id,
      distroName: t.spec.name,
      prefsJson: prefs.toJson(),
      includeApps: _includeApps,
    );
    setState(() {
      _rice = rice;
      _code = RiceCode.encode(rice);
    });
  }

  String _message() => context.t('rice.shareMessage', {
        'name': widget.theme.spec.name,
        'code': _code,
      });

  Future<void> _share() async {
    final ok = await ref.read(launcherHostApiProvider).shareText(_message());
    if (!ok && mounted) await _copy();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _message()));
    if (mounted) context.showMessage(context.t('rice.copied'));
  }

  /// Clipboard first, because the usual path is "copied it from a chat".
  /// A text field only when there is nothing usable there.
  Future<void> _import() async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    var rice = RiceCode.decode(clip);
    if (!mounted) return;
    rice ??= await _askForCode();
    if (rice == null || !mounted) return;

    final ok = await ThemedDialog.confirm(
      context,
      title: context.t('rice.applyTitle', {'name': rice.distroName}),
      message: context.t('rice.applyBody', {
        'desklets': '${rice.deskletCount}',
        'apps': rice.includesApps
            ? context.t('rice.withApps')
            : context.t('rice.withoutApps'),
      }),
      confirmLabel: context.t('rice.apply'),
    );
    if (ok != true || !mounted) return;
    await applyRice(context, ref, rice);
  }

  Future<RicePayload?> _askForCode() async {
    final field = TextEditingController();
    final text = await ThemedSheet.show<String>(
      context,
      title: context.t('rice.pasteTitle'),
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: field,
              autofocus: true,
              maxLines: 4,
              style: ChromeScope.of(sheet).text.body.copyWith(
                    fontFamily: widget.theme.typography.mono,
                  ),
              decoration: InputDecoration(
                hintText: 'GRICE1.',
                hintStyle: ChromeScope.of(sheet).text.caption,
              ),
            ),
            const SizedBox(height: 12),
            ThemedButton(
              label: context.t('rice.apply'),
              expand: true,
              onPressed: () => Navigator.pop(sheet, field.text),
            ),
          ],
        ),
      ),
    );
    field.dispose();
    if (text == null || !mounted) return null;
    final rice = RiceCode.decode(text);
    if (rice == null) context.showMessage(context.t('rice.badCode'));
    return rice;
  }

  /// The QR, large, for another phone's camera across a table.
  void _showQr(BuildContext context) {
    ThemedDialog.show<void>(
      context,
      title: context.t('rice.qrTitle', {'name': widget.theme.spec.name}),
      content: Center(child: _QrSquare(code: _code, size: 280)),
      actionsBuilder: (dialog) => [
        ThemedButton(
          label: dialog.t('common.done'),
          kind: ThemedButtonKind.text,
          onPressed: () => Navigator.of(dialog).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScaffold(
      title: context.t('rice.title'),
      body: Builder(
        builder: (context) {
          final d = ChromeScope.of(context);
          final c = d.colors;
          final rice = _rice;
          return ListView(
            padding: EdgeInsets.fromLTRB(0, 8, 0, context.bottomInset + 16),
            children: [
              ThemedSectionHeader(context.t('rice.yours')),
              if (rice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    [
                      rice.distroName,
                      if (rice.iconPack != null) rice.iconPack!,
                      context.t(
                          'rice.deskletCount', {'n': '${rice.deskletCount}'}),
                      if (rice.includesApps)
                        context.t('rice.dockCount', {'n': '${rice.dockCount}'}),
                    ].join('  ·  '),
                    style: d.text.body,
                  ),
                ),
              ThemedListRow(
                icon: Icons.apps_outlined,
                title: context.t('rice.includeApps'),
                subtitle: context.t('rice.includeAppsSub'),
                trailing: ThemedToggle(
                  value: _includeApps,
                  onChanged: (v) {
                    setState(() => _includeApps = v);
                    _build();
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _code,
                    style: TextStyle(
                      fontFamily: widget.theme.typography.mono,
                      fontSize: 11,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  context.t('rice.codeSize', {'n': '${_code.length}'}),
                  style: d.text.caption,
                ),
              ),
              if (_code.isNotEmpty)
                _RiceQr(code: _code, onTap: () => _showQr(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ThemedButton(
                        label: context.t('rice.share'),
                        icon: Icons.ios_share,
                        onPressed: _code.isEmpty ? null : _share,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ThemedButton(
                        label: context.t('rice.copy'),
                        icon: Icons.copy_outlined,
                        kind: ThemedButtonKind.secondary,
                        onPressed: _code.isEmpty ? null : _copy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ThemedSectionHeader(context.t('rice.theirs')),
              ThemedListRow(
                icon: Icons.content_paste_go_outlined,
                title: context.t('rice.import'),
                subtitle: context.t('rice.importSub'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: _import,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The code as a QR, or why it cannot be one.
///
/// The payload is the bare `GRICE1.` code, not the share message: any camera
/// app reads it as text, and Import already takes a code from the clipboard,
/// so the receiving phone needs no scanner of its own.
///
/// Low error correction, because the code is long and a phone screen is a
/// clean target. A rice with many placed apps can still outgrow the largest
/// QR (about 2.9 KB), and then the card says so instead of drawing a code
/// that would not scan.
class _RiceQr extends StatelessWidget {
  const _RiceQr({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final fits = _QrSquare.fits(code);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: fits
          ? Column(
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: _QrSquare(code: code, size: 200),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('rice.qrHint'),
                  textAlign: TextAlign.center,
                  style: d.text.caption,
                ),
              ],
            )
          : Text(context.t('rice.qrTooBig'), style: d.text.caption),
    );
  }
}

/// Black on white whatever the distro, with a quiet zone: a themed QR on a
/// dark panel is the version cameras fail to read.
class _QrSquare extends StatelessWidget {
  const _QrSquare({required this.code, required this.size});

  final String code;
  final double size;

  static const _level = QrErrorCorrectLevel.L;

  static bool fits(String code) =>
      QrValidator.validate(
        data: code,
        version: QrVersions.auto,
        errorCorrectionLevel: _level,
      ).status ==
      QrValidationStatus.valid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: QrImageView(
        data: code,
        version: QrVersions.auto,
        errorCorrectionLevel: _level,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        semanticsLabel: context.t('rice.qrLabel'),
      ),
    );
  }
}
