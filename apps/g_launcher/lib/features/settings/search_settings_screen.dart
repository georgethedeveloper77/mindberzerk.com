import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../command/bangs.dart';
import '../command/search_engines.dart';
import '../command/search_settings.dart';

/// Open Search settings. Settings and the search page's overflow both call
/// this, so the page has one way in.
Future<void> openSearchSettings(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchSettingsScreen()),
    );

/// The web engine and the person's own bangs, launcher-wide.
///
/// Its own page rather than rows in the Apps section: a list someone edits
/// gets its own surface, and the bang list can run to fifty entries.
class SearchSettingsScreen extends ConsumerWidget {
  const SearchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(searchSettingsProvider).asData?.value ??
        const SearchSettings();
    final notifier = ref.read(searchSettingsProvider.notifier);
    final builtInKeys = {for (final b in Bangs.builtIn) b.key};

    // ChromeScope is provided BY ThemedScaffold, so the body reads it from
    // below through a Builder.
    return ThemedScaffold(
      title: context.t('searchSettings.title'),
      body: Builder(
        builder: (context) {
          final d = ChromeScope.of(context);
          return ListView(
            padding: EdgeInsets.only(bottom: context.bottomInset + 16),
            children: [
              _Header(context.t('searchSettings.engine')),
              for (final e in SearchEngine.all)
                ThemedListRow(
                  title: e.label,
                  subtitle: e.host,
                  trailing: Icon(
                    e.id == settings.engineId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: e.id == settings.engineId
                        ? d.colors.accent
                        : d.colors.textMuted,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.setEngine(e.id);
                  },
                ),
              _Header(
                context.t('searchSettings.yourBangs'),
                trailing: settings.bangs.isEmpty
                    ? null
                    : '${settings.bangs.length}/${BangRules.maxCustom}',
              ),
              if (settings.bangs.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    context.t('searchSettings.noBangs'),
                    style: d.text.caption,
                  ),
                ),
              for (final b in settings.bangs)
                ThemedListRow(
                  title: '!${b.key}  ${b.label}',
                  subtitle: builtInKeys.contains(b.key)
                      ? context.t('searchSettings.replacesBuiltIn', {
                          'key': b.key,
                        })
                      : _shortTemplate(b.template),
                  onTap: () => _edit(context, ref, existing: b),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: d.colors.textMuted),
                    tooltip: context.t('searchSettings.remove'),
                    onPressed: () {
                      notifier.removeBang(b.key);
                      context.showMessage(
                        context.t('searchSettings.removed', {'key': b.key}),
                      );
                    },
                  ),
                ),
              ThemedListRow(
                icon: Icons.add,
                title: context.t('searchSettings.addBang'),
                subtitle: settings.canAdd
                    ? null
                    : context.t('searchSettings.limit', {
                        'max': '${BangRules.maxCustom}',
                      }),
                enabled: settings.canAdd,
                onTap: settings.canAdd ? () => _edit(context, ref) : null,
              ),
              _Header(context.t('searchSettings.builtIn')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  [for (final b in Bangs.builtIn) '!${b.key}'].join('  '),
                  style: d.text.value.copyWith(color: d.colors.textMuted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  context.t('searchSettings.howTo'),
                  style: d.text.caption,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The template without its scheme and `www.`, which is what tells two
  /// bangs apart at a glance.
  static String _shortTemplate(String t) =>
      t.replaceFirst(RegExp(r'^https?://(www\.)?'), '');

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Bang? existing,
  }) async {
    final bang = await ThemedSheet.show<Bang>(
      context,
      title: context.t(
        existing == null ? 'searchSettings.addBang' : 'searchSettings.editBang',
      ),
      isScrollControlled: true,
      builder: (_) => _BangEditor(existing: existing),
    );
    if (bang == null) return;
    await ref
        .read(searchSettingsProvider.notifier)
        .saveBang(bang, replacing: existing?.key);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: d.text.title)),
          if (trailing != null) Text(trailing!, style: d.text.caption),
        ],
      ),
    );
  }
}

/// Key, name and URL, each checked against [BangRules] as it is typed, with
/// a preview of what the bang would open. Pops with the bang on Save.
class _BangEditor extends StatefulWidget {
  const _BangEditor({this.existing});

  final Bang? existing;

  @override
  State<_BangEditor> createState() => _BangEditorState();
}

class _BangEditorState extends State<_BangEditor> {
  late final _key = TextEditingController(text: widget.existing?.key ?? '');
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _template = TextEditingController(
    text: widget.existing?.template ?? 'https://',
  );

  /// Errors stay quiet until Save is tried once, so an empty form does not
  /// open already shouting at the person.
  bool _tried = false;

  @override
  void dispose() {
    _key.dispose();
    _label.dispose();
    _template.dispose();
    super.dispose();
  }

  String get _keyValue => BangRules.normalizeKey(_key.text);

  String? get _keyError => BangRules.keyError(_keyValue);
  String? get _labelError => BangRules.labelError(_label.text);
  String? get _templateError => BangRules.templateError(_template.text);

  bool get _valid =>
      _keyError == null && _labelError == null && _templateError == null;

  void _save() {
    if (!_valid) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(
      Bang(_keyValue, _label.text.trim(), _template.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final preview = _templateError == null && _keyError == null
        ? Bang(_keyValue, '', _template.text.trim()).urlFor('react')
        : null;

    return Padding(
      // Lifted above the keyboard, which a scroll-controlled sheet does not
      // do on its own.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Field(
              label: context.t('searchSettings.key'),
              controller: _key,
              prefix: '!',
              mono: true,
              autofocus: widget.existing == null,
              error: _tried ? _keyError : null,
              onChanged: () => setState(() {}),
            ),
            _Field(
              label: context.t('searchSettings.name'),
              controller: _label,
              error: _tried ? _labelError : null,
              onChanged: () => setState(() {}),
            ),
            _Field(
              label: context.t('searchSettings.url'),
              controller: _template,
              mono: true,
              keyboard: TextInputType.url,
              error: _tried ? _templateError : null,
              onChanged: () => setState(() {}),
              onSubmitted: _save,
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  '!$_keyValue react  →  $preview',
                  style: d.text.value.copyWith(
                    fontSize: 12,
                    color: d.colors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ThemedButton(
                  label: context.t('common.cancel'),
                  kind: ThemedButtonKind.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                ThemedButton(
                  label: context.t('common.save'),
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled input in the chrome's colours, with its error under it.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error,
    this.prefix,
    this.mono = false,
    this.autofocus = false,
    this.keyboard,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  /// An i18n key, or null when the field is fine.
  final String? error;
  final String? prefix;
  final bool mono;
  final bool autofocus;
  final TextInputType? keyboard;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final style = mono ? d.text.value : d.text.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: d.text.caption),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: error == null ? c.line : c.danger),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: keyboard,
              textInputAction: onSubmitted == null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onChanged: (_) => onChanged(),
              onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
              style: style,
              cursorColor: c.accent,
              decoration: InputDecoration(
                prefixText: prefix,
                prefixStyle: style.copyWith(color: c.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.t(error!),
                style: d.text.caption.copyWith(color: c.danger),
              ),
            ),
        ],
      ),
    );
  }
}
