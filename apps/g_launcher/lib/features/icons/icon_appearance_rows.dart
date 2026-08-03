/// The three icon settings that describe LOOK rather than content.
///
/// ─── WHY THEY MOVED HERE FROM SETTINGS ──────────────────────────────────────
///
/// Shape, size and corner roundness sat in Settings > Appearance, split across
/// two groups of that page, with a fifth row that led to this screen. Picking a
/// pack and deciding what shape its artwork gets cropped to are one decision
/// taken twice, and having the first here and the second two taps away meant
/// choosing a pack and then leaving the screen to find out what it looked like.
///
/// Its own file rather than more length on `icon_theme_screen.dart`, which was
/// already 979 lines before any of this arrived.
///
/// ─── AND THEY ARE GLOBAL WHILE THE PACKS BELOW ARE NOT ──────────────────────
///
/// A shape is a fact about the person and is promoted into `GlobalPrefs`; a
/// pack is content that belongs to a distro. The group says so, which is why
/// the scope label is on the group and not on the page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../design/device_preview.dart';
import '../../design/setting_previews.dart';
import '../../engine/effective_theme.dart';
import '../settings/settings_rows.dart';
import '../settings/settings_sheets.dart';

List<Widget> iconAppearanceRows(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
) {
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

  return [
        SettingPreview(
          caption: 'Icons, live',
          child: SinglePreview(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.folder,
              cols: theme.prefs.folderCols ?? 4,
              rows: theme.prefs.folderRows ?? 3,
              tileRadiusFraction: switch (theme.icons.treatment.name) {
                'circle' => 0.5,
                'square' => 0.0,
                'squircle' => 0.32,
                _ => theme.icons.cornerRadius,
              },
            ),
          ),
        ),

        SettingsGroup(
          label: 'Shape and size',
          scope: 'All distros',
          rows: [
      FilterRow(
        const ['icon shape', 'circle', 'squircle', 'rounded'],
        SettingsRow(
          icon: Icons.category_outlined,
          title: context.t('settings.iconShape'),
          subtitle: _shapeLong(theme.prefs.iconTreatment),
          trailing: ValueLabel(_shapeShort(theme.prefs.iconTreatment)),
          onTap: () => showShapeSheet(context, notifier, theme),
        ),
      ),
      FilterRow(
        const ['icon size', 'size', 'bigger', 'smaller'],
        SettingsRow(
          icon: Icons.photo_size_select_large_outlined,
          accent: true,
          title: context.t('settings.iconSize'),
          trailing: ValueLabel(_iconSizeLabel(theme.iconSizeDp)),
          onTap: () => showSliderSheet(
            context,
            title: context.t('settings.iconSize'),
            value: theme.iconSizeDp,
            min: 36,
            max: 72,
            format: (v) => '${v.round()} dp',
            onCommit: (v) => notifier.edit((p) => p.copyWith(iconSizeDp: v)),
          ),
        ),
      ),
      if (theme.icons.treatment.name == 'roundedSquare')
        FilterRow(
          const ['corner roundness', 'corners', 'rounded'],
          SettingsRow(
            icon: Icons.rounded_corner_outlined,
            accent: true,
            title: context.t('settings.cornerRoundness'),
            trailing: ValueLabel('${(theme.icons.cornerRadius * 200).round()}%'),
            onTap: () => showSliderSheet(
              context,
              title: context.t('settings.cornerRoundness'),
              value: theme.icons.cornerRadius,
              min: 0,
              max: 0.5,
              format: (v) => '${(v * 200).round()}%',
              onCommit: (v) =>
                  notifier.edit((p) => p.copyWith(cornerRadius: v)),
            ),
          ),
        ),
          ],
        ),
  ];
}

String _shapeLong(String? raw) => switch (raw) {
      null => 'Following the distro',
      'roundedSquare' => 'Rounded square',
      'circle' => 'Circle',
      'squircle' => 'Squircle',
      'square' => 'Square',
      'teardrop' => 'Teardrop',
      'original' => 'Original, unthemed',
      _ => raw,
    };

String _shapeShort(String? raw) => switch (raw) {
      null => 'Distro',
      'roundedSquare' => 'Rounded',
      'circle' => 'Circle',
      'squircle' => 'Squircle',
      'square' => 'Square',
      'teardrop' => 'Teardrop',
      'original' => 'Original',
      _ => raw,
    };

String _iconSizeLabel(double dp) => switch (dp) {
      < 44 => 'Small',
      < 54 => 'Medium',
      < 64 => 'Large',
      _ => 'Huge',
    };
