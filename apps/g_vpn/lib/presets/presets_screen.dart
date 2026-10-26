import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import '../design/meridian.dart';
import '../design/meridian_widgets.dart';
import '../i18n/strings.g.dart';
import '../map/map_data.dart';
import '../rules/rules_store.dart';
import '../rules/shield_screen.dart';
import '../vpn/vpn_controller.dart';
import '../design/appear.dart';
import 'preset_glyph.dart';
import 'presets.dart';

/// One line on what a preset does: "Fastest · not my country · SSTP".
String presetSummary(Preset p) => [
      p.place == PresetPlace.country && p.country != null
          ? countryName(p.country!, p.country!)
          : t.presets.fastestOption,
      if (p.skipMyCountry && p.place == PresetPlace.fastest) t.presets.notMine,
      if (p.protocol == PresetProtocol.sstp) 'SSTP',
      if (p.protocol == PresetProtocol.openvpn) 'OpenVPN',
      if (p.shield != null) shieldLevelName(p.shield!),
      if (p.allApps) t.presets.allAppsShort,
    ].join(' · ');

/// Connects with [preset] and says so when no server fits it.
Future<void> runPreset(BuildContext context, Preset preset) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await applyPreset(container, preset);
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(t.presets.none)));
}

Future<void> _edit(BuildContext context, Preset preset) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PresetEditScreen(preset: preset)));

/// Home's row of presets: one tap connects with that recipe.
class PresetsRow extends ConsumerWidget {
  const PresetsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final state = ref.watch(presetsProvider).value;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    if (state == null) return const SizedBox.shrink();
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(t.presets.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.text)),
              ),
              MerAction(
                t.presets.all,
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PresetsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = state.presets[i];
                final applied = state.applied == p.id;
                final color = presetColor(p.tone, m);
                return Appear(
                  index: i,
                  child: SizedBox(
                  width: 116,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: applied ? color.withValues(alpha: .12) : m.surface,
                      borderRadius: BorderRadius.circular(Meridian.rTile),
                      border: Border.all(color: applied ? color : m.line, width: applied ? 1.5 : 1),
                    ),
                    child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Meridian.rTile),
                      onTap: busy ? null : () => runPreset(context, p),
                      onLongPress: () => _edit(context, p),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PresetGlyph(
                              icon: p.icon,
                              tone: p.tone,
                              size: 36,
                              active: applied && phase == VpnPhase.on,
                              working: applied && phase == VpnPhase.connecting,
                            ),
                            const Spacer(),
                            Text(
                              p.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: m.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Every preset, what each does, and a way to add one.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.mer;
    final state = ref.watch(presetsProvider).value;
    final phase = ref.watch(vpnProvider.select((s) => s.phase));
    final busy = phase == VpnPhase.connecting || phase == VpnPhase.disconnecting;

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(title: Text(t.presets.title)),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                MerCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, p) in state.presets.indexed) ...[
                        if (i > 0) Divider(height: 1, color: m.line),
                        ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                          leading: PresetGlyph(
                            icon: p.icon,
                            tone: p.tone,
                            active: state.applied == p.id && phase == VpnPhase.on,
                            working: state.applied == p.id && phase == VpnPhase.connecting,
                          ),
                          title: Text(p.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: m.text)),
                          subtitle: Text(presetSummary(p), style: TextStyle(fontSize: 13, color: m.muted)),
                          onTap: busy
                              ? null
                              : () async {
                                  // Started before leaving, so it reads this
                                  // screen's context while it still exists.
                                  final run = runPreset(context, p);
                                  Navigator.of(context).pop();
                                  await run;
                                },
                          trailing: IconButton(
                            tooltip: t.presets.edit,
                            onPressed: () => _edit(context, p),
                            icon: Icon(Icons.tune_rounded, color: m.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => _edit(context, Preset(id: 'p${DateTime.now().microsecondsSinceEpoch}')),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t.presets.newPreset),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Edits one preset. Built-ins can be changed and later reset; the user's
/// own can be deleted.
class PresetEditScreen extends ConsumerStatefulWidget {
  const PresetEditScreen({super.key, required this.preset});

  final Preset preset;

  @override
  ConsumerState<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends ConsumerState<PresetEditScreen> {
  late Preset _draft = widget.preset;
  late final _name = TextEditingController(text: widget.preset.label);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final typed = _name.text.trim();
    // A built-in keeps its translated name unless it was actually renamed.
    final name = typed.isEmpty || (_draft.builtIn && _draft.name == null && typed == widget.preset.label) ? _draft.name : typed;
    await ref.read(presetsProvider.notifier).save(_draft.named(name));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final countries = ref.watch(countryServersProvider);
    final codes = {
      for (final c in countries) if (c.servers.isNotEmpty) c.code,
      if (_draft.country != null) _draft.country!.toUpperCase(),
    }.toList()
      ..sort((a, b) => countryName(a, a).compareTo(countryName(b, b)));
    final exists = ref.watch(presetsProvider).value?.presets.any((p) => p.id == _draft.id) ?? false;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: m.muted)),
        );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => MerCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: m.text)),
            value: value,
            onChanged: onChanged,
          ),
        );

    Widget choices<T>(List<(T, String)> options, T selected, ValueChanged<T> onPick) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: value == selected,
                onSelected: (_) => onPick(value),
                showCheckmark: false,
                selectedColor: m.brandSoft,
                backgroundColor: m.surface,
                side: BorderSide(color: value == selected ? m.brand : m.line),
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: value == selected ? m.brand : m.text),
              ),
          ],
        );

    return Scaffold(
      backgroundColor: m.bg,
      appBar: AppBar(title: Text(exists ? t.presets.edit : t.presets.newPreset)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Center(child: PresetGlyph(icon: _draft.icon, tone: _draft.tone, size: 72, working: true)),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: t.presets.name, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final tone in PresetTone.values)
                Semantics(
                  selected: tone == _draft.tone,
                  button: true,
                  child: InkResponse(
                    radius: 26,
                    onTap: () => setState(() => _draft = _draft.copyWith(tone: tone)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: presetColor(tone, m),
                        shape: BoxShape.circle,
                        border: Border.all(color: tone == _draft.tone ? m.text : Colors.transparent, width: 3),
                      ),
                      child: tone == _draft.tone ? Icon(Icons.check_rounded, size: 20, color: m.bg) : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final icon in PresetIcon.values)
                Semantics(
                  selected: icon == _draft.icon,
                  button: true,
                  child: Material(
                    color: icon == _draft.icon ? presetColor(_draft.tone, m).withValues(alpha: .16) : m.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: icon == _draft.icon ? presetColor(_draft.tone, m) : m.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _draft = _draft.copyWith(icon: icon)),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(presetIconData(icon), color: icon == _draft.icon ? presetColor(_draft.tone, m) : m.muted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          heading(t.presets.server),
          choices(
            [(PresetPlace.fastest, t.presets.fastestOption), (PresetPlace.country, t.presets.countryOption)],
            _draft.place,
            (place) => setState(() => _draft = _draft.copyWith(place: place)),
          ),
          const SizedBox(height: 10),
          if (_draft.place == PresetPlace.country)
            MerCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _draft.country?.toUpperCase(),
                  hint: Text(t.presets.pickCountry),
                  dropdownColor: m.surface,
                  items: [
                    for (final code in codes)
                      DropdownMenuItem(value: code, child: Text(countryName(code, code))),
                  ],
                  onChanged: (code) => setState(() => _draft = _draft.copyWith(country: code)),
                ),
              ),
            )
          else
            toggle(t.presets.skipMyCountry, _draft.skipMyCountry,
                (v) => setState(() => _draft = _draft.copyWith(skipMyCountry: v))),
          heading(t.presets.protocol),
          choices(
            [(PresetProtocol.auto, t.presets.auto), (PresetProtocol.sstp, 'SSTP'), (PresetProtocol.openvpn, 'OpenVPN')],
            _draft.protocol,
            (p) => setState(() => _draft = _draft.copyWith(protocol: p)),
          ),
          const SizedBox(height: 10),
          toggle(t.presets.tryNext, _draft.tryNext, (v) => setState(() => _draft = _draft.copyWith(tryNext: v))),
          heading(t.presets.shield),
          choices<ShieldLevel?>(
            [
              (null, t.presets.followRules),
              (ShieldLevel.off, t.shield.off),
              (ShieldLevel.malware, t.shield.malware),
              (ShieldLevel.family, t.shield.family),
            ],
            _draft.shield,
            (level) => setState(() => _draft = _draft.copyWith(shield: () => level)),
          ),
          const SizedBox(height: 10),
          toggle(t.presets.allApps, _draft.allApps, (v) => setState(() => _draft = _draft.copyWith(allApps: v))),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _draft.place == PresetPlace.country && _draft.country == null ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: Text(t.presets.save),
            ),
          ),
          if (exists) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(presetsProvider.notifier).remove(_draft.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: m.bad, minimumSize: const Size.fromHeight(48)),
              child: Text(_draft.builtIn ? t.presets.reset : t.presets.delete),
            ),
          ],
        ],
      ),
    );
  }
}
