/// Appearance: how the desktop looks.
///
/// One of five section builders, each in its own file. They return a list of
/// widgets rather than a page, because the landing mounts them ALL FLAT when a
/// search query is typed and `SettingsGroup` filters them in place. That is
/// what keeps a row three taps deep findable by typing, and it is the reason a
/// section is a function and not a screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../design/device_preview.dart';
import '../../../design/setting_previews.dart';
import '../../../engine/effective_theme.dart';
import '../../icons/icon_theme_screen.dart';
import '../settings_rows.dart';
import '../settings_sheets.dart';
import '../wallpaper_screen.dart';

String _iconsLong(EffectiveTheme theme) {
  if (theme.prefs.systemIconPack != null) {
    return 'An installed pack, over the distro icons';
  }
  final hero = theme.prefs.iconPackId;
  if (hero != null) return 'The $hero icon theme';
  return "The distro's own icons";
}

String _iconsShort(EffectiveTheme theme) {
  if (theme.prefs.systemIconPack != null) return 'Custom';
  return theme.prefs.iconPackId ?? 'Distro';
}

/// Appearance: the distro, its artwork, and how text reads.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.
List<Widget> appearanceSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  ref.read(launcherHostApiProvider);

  final mode = theme.prefs.themeMode ?? 'system';
  final hasLight = theme.spec.paletteLight != null;

  return [
    // ── WHAT THE PAGE IS ABOUT, AT THE TOP OF IT ───────────────────
    //
    // Icon shape, corner roundness and label length are the three settings on
    // this page whose effect you cannot picture from a value. "Squircle",
    // "22%" and "Two lines" are each accurate and each unreadable until you
    // have applied them and backed out to look, which is the loop this
    // replaces.
    //
    // The FOLDER mode rather than the drawer: it is the one that honours
    // tileRadiusFraction, which is the whole reason this picture is here.
    if (q.isEmpty)
      SettingPreview(
        query: q,
        caption: 'Icons and labels, live',
        child: SinglePreview(
          child: DevicePreview(
            palette: theme.palette,
            mode: DevicePreviewMode.folder,
            // The folder defaults, spelled out: EffectiveTheme resolves the
            // grid and the drawer but not these, so the two callers that
            // need them carry the same 4 and 3 LauncherPrefs documents.
            cols: theme.prefs.folderCols ?? 4,
            rows: theme.prefs.folderRows ?? 3,
            // The shape row and the roundness slider are two ways of setting
            // one thing, so the preview resolves them the same way the icon
            // pipeline does rather than reading the slider alone: a circle is
            // not a rounded square with a large radius, it is a different
            // answer, and a preview that showed one while the grid drew the
            // other would be worse than no preview.
            tileRadiusFraction: switch (theme.icons.treatment.name) {
              'circle' => 0.5,
              'square' => 0.0,
              'squircle' => 0.32,
              _ => theme.icons.cornerRadius,
            },
          ),
        ),
      ),

    // ── Personalize ────────────────────────────────────────────────
    SettingsGroup(
      label: context.t('settings.personalize'),
      scope: 'This distro',
      query: q,
      rows: [
        FilterRow(
          // 'icon pack' kept as a search term even though the row is now called
          // Icons: it is what Play, Nova and Icon Pack Studio all call the
          // thing, so it is what someone will type.
          const ['icons', 'icon pack', 'icon theme', 'adaptive', 'yaru', 'nova'],
          SettingsRow(
            icon: Icons.grid_view_outlined,
            // "Icons", because in Linux an icon set is an icon THEME and the
            // distro is the other thing on this screen. The old title said
            // "Icon pack", which is what an APK from Play is — one of the two
            // sources the page now shows, not the whole subject.
            title: context.t('settings.icons'),
            // ─── THIS ROW WAS TAP-INERT AND SAID SO ────────────────────────
            //
            // It read "Adaptive — every app covered" with no onTap, and its
            // comment said it would grow a picker "when downloadable hero packs
            // ship". They ship now, and `IconPackPage` — a picker for the
            // third-party half — had been sitting in the tree the whole time
            // with nothing importing it.
            //
            // Both halves now live in `IconThemeScreen`, because they are not
            // alternatives: a Nova pack covers what it has art for and the
            // distro's icon theme fills the rest. See the file's header.
            subtitle: _iconsLong(theme),
            trailing: ValueLabel(_iconsShort(theme)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IconThemeScreen()),
            ),
          ),
        ),
        FilterRow(
          const ['wallpaper', 'background', 'photo', 'rotation'],
          SettingsRow(
            icon: Icons.image_outlined,
            title: context.t('settings.wallpaper'),
            subtitle: context.t('settings.presetsYourPhotosRotation'),
            trailing: const Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WallpaperScreen(theme: theme),
              ),
            ),
          ),
        ),
        FilterRow(
          const [
            'verbose boot',
            'boot',
            'boot log',
            'startup',
            'systemd',
            'terminal',
          ],
          SettingsToggleRow(
            icon: Icons.terminal,
            title: context.t('settings.verboseBoot'),
            // Off = the quick splash. On = the full [  OK  ] scroll every
            // time the shell opens, themed to this distro.
            subtitle: context.t('settings.playTheFullLinux'),
            // null = off; the toggle reads and writes an explicit bool.
            value: theme.prefs.verboseBoot ?? false,
            onChanged: (v) => notifier.edit((p) => p.copyWith(verboseBoot: v)),
          ),
        ),
      ],
    ),

    // A LIVE PREVIEW, not another list row.
    //
    // Dock side, the app-grid button and the drawer width are spatial
    // settings, and a row that says "Dock position — Left" makes you
    // apply it and back out to find out what changed. Setup shows the
    // same picture from the same widget; Settings should not be the
    // poorer of the two just because it came first.
    //
    // Hidden while searching: a preview is not a search result, and it
    // would sit above a filtered list looking like one.
    // ── Labels ─────────────────────────────────────────────────────

    // ─── NOTIFICATION BADGES ───────────────────────────────────────────
    //
    // Its own group rather than a row under Icons, because the first thing in
    // it is a PERMISSION and permissions deserve to be asked for somewhere the
    // user can read a sentence about what they are granting. Android's own
    // dialog is going to tell them this app can read every notification on the
    // phone, which is true of the API and not true of what we do with it, and
    // the only place to say so is here.
    // ─── PERMISSIONS, ON THEIR OWN ─────────────────────────────────────
    //
    // Split out from the badge settings below, because a permission is a
    // different kind of row from a preference and belongs somewhere a person
    // can go looking for it. "Where do I turn notification access back on" has
    // an answer now that is not "scroll until you find the badges".
    //
    // The gesture service is the other permission this launcher asks for, and
    // it keeps its card at the top of the Gestures section rather than moving
    // here. Deliberately: that card carries an explanation the service
    // genuinely needs, and moving it would make Gestures the one section that
    // cannot say why half of it is inert.
    SettingsGroup(
      label: context.t('settings.lightAndDark'),
      scope: 'All distros',
      query: q,
      rows: [
        // ── THE PICTURE IS THE CONTROL ─────────────────────────────
        //
        // Three radio ROWS, which is what this was, describe three appearances
        // in words and show none of them. And the words were the weak part:
        // "Always light" is unambiguous, but what a distro's light palette
        // actually looks like is a per-distro fact this launcher exists to
        // make visible, and every one of them is different.
        //
        // The tiles paint from `spec.paletteLight` and `spec.palette`, so this
        // is the real answer for the distro on screen rather than a generic
        // pale rectangle and a generic dark one.
        FilterRow(
          const ['light', 'dark', 'theme mode', 'appearance', 'night'],
          PreviewChoice<String>(
            value: mode,
            onSelect: (v) => notifier.edit((p) => p.copyWith(themeMode: v)),
            options: [
              PreviewOption(
                value: 'light',
                label: 'Light',
                child: DevicePreview(
                  palette: theme.spec.paletteLight ?? theme.spec.palette,
                  mode: DevicePreviewMode.desktop,
                  dock: theme.dock,
                  framed: false,
                ),
              ),
              PreviewOption(
                value: 'dark',
                label: 'Dark',
                child: DevicePreview(
                  palette: theme.spec.palette,
                  mode: DevicePreviewMode.desktop,
                  dock: theme.dock,
                  framed: false,
                ),
              ),
              PreviewOption(
                value: 'system',
                label: 'System',
                child: SplitTile(
                  left: DevicePreview(
                    palette: theme.spec.paletteLight ?? theme.spec.palette,
                    mode: DevicePreviewMode.desktop,
                    dock: theme.dock,
                    framed: false,
                  ),
                  right: DevicePreview(
                    palette: theme.spec.palette,
                    mode: DevicePreviewMode.desktop,
                    dock: theme.dock,
                    framed: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!hasLight)
          FilterRow(
            const ['light', 'dark'],
            SettingsRow(
              icon: Icons.info_outline,
              title: context.t('settings.distroDarkOnly', {'name': theme.spec.name}),
              subtitle: context.t('settings.appliesToBoth'),
              trailing: const SizedBox.shrink(),
            ),
          ),
      ],
    ),

    SettingsGroup(
      label: context.t('settings.labels'),
      scope: 'All distros',
      query: q,
      rows: [
        FilterRow(
          const ['wrap', 'app names', 'labels', 'truncate'],
          SettingsToggleRow(
            icon: Icons.wrap_text,
            title: context.t('settings.wrapLongAppNames'),
            // Reversed default. One line is now the default, because two
            // costs a whole ROW of grid height on every page to
            // accommodate the one app in twenty whose name wraps: on a
            // 412dp phone a paged drawer fits six rows at one line and
            // five at two. The setting stays for the people who would
            // rather read "Secure Folder" than "Secure Fold…".
            subtitle: context.t('settings.twoLinesInsteadOf'),
            value: theme.labelLines > 1,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(labelLines: v ? 2 : 1)),
          ),
        ),
        FilterRow(
          const ['text size', 'font size', 'labels'],
          SettingsRow(
            icon: Icons.format_size,
            title: context.t('settings.textSize'),
            trailing: ValueLabel('${(theme.textScale * 100).round()}%'),
            onTap: () => showSliderSheet(
              context,
              title: context.t('settings.textSize'),
              value: theme.textScale,
              min: 0.8,
              max: 1.4,
              format: (v) => '${(v * 100).round()}%',
              onCommit: (v) => notifier.edit((p) => p.copyWith(textScale: v)),
            ),
          ),
        ),
      ],
    ),

    // ── Light and dark ─────────────────────────────────────────────
    //
    // First in the section because it is the coarsest appearance decision
    // there is, and because it is the one setting here that applies to EVERY
    // distro rather than the one on screen. It writes the same global value
    // the setup wizard's Appearance step does; see GlobalPrefs.themeMode.
    // ─── SURFACES ──────────────────────────────────────────────────
    //
    // The main slider governs EVERYTHING, and the three below it split out one
    // section each from that number.
    //
    // The old reasoning here was that a per-page version would mean a settings
    // page and a sheet over it disagreeing about how solid they are, which
    // reads as a rendering fault. That still holds, and it is why the split
    // stops where it does: only the three PERMANENT chrome surfaces get their
    // own control. Sheets, dialogs and menus are transient and stay on this
    // slider, so nothing that stacks over something else can disagree with it.
    //
    // ─── AND THE THREE LIVE WITH THEIR SECTIONS, NOT HERE ──────────────
    //
    // Dock opacity sits under Layout beside the dock's position, drawer
    // opacity under App drawer, bar opacity under Icons and bar beside the
    // top-bar switch. Someone adjusting the dock is already on the dock's
    // rows; making them come here instead means the one screen that knows
    // what a dock is has nothing to say about how solid it looks. This slider
    // remains the one that governs everything, and each section follows it
    // until moved.
    SettingsGroup(
      label: context.t('settings.surfaces'),
      scope: 'All distros',
      query: q,
      rows: [
        FilterRow(
          const ['opacity', 'transparency', 'surface', 'glass', 'wallpaper'],
          OpacityRow(
            value: theme.surfaceOpacity,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(surfaceOpacity: v)),
          ),
        ),
      ],
    ),

    // ─── PANELS ────────────────────────────────────────────────────────
    //
    // Directly under the main opacity slider, because the first row here is
    // the same material question one level down: that slider governs pages,
    // these govern the things that float over them.
    //
    // The PREVIEW is the reason this group is worth having rather than four
    // loose rows. Blur, tint and corner radius are the three settings in the
    // app whose effect is impossible to describe in a subtitle and obvious the
    // instant you see it, and the surface they change is one that only appears
    // when you are no longer looking at this screen.
    SettingsGroup(
      label: context.t('settings.panels'),
      scope: 'All distros',
      query: q,
      rows: [
        FilterRow(
          const ['panel', 'sheet', 'dialog', 'menu', 'preview', 'glass'],
          PanelPreview(theme: theme),
        ),
        FilterRow(
          const ['panel', 'sheet', 'opacity', 'transparency', 'glass'],
          OpacityRow(
            label: context.t('settings.panels.opacity'),
            sub: context.t('settings.panels.opacitySub'),
            value: theme.panelOpacity,
            following: theme.prefs.panelOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(panelOpacity: true)),
          ),
        ),
        FilterRow(
          const ['blur', 'panel', 'glass', 'frosted', 'performance', 'lag'],
          PanelSlider(
            icon: Icons.blur_on,
            label: context.t('settings.panels.blur'),
            // The honest reason this is exposed, said plainly. Someone whose
            // launcher stutters is not going to guess that the frosted glass
            // is what costs them the frames.
            sub: context.t('settings.panels.blurSub'),
            value: theme.panelBlur,
            min: 0,
            max: 24,
            divisions: 12,
            format: (v) =>
                v <= 0 ? context.t('settings.panels.blurOff') : v.round().toString(),
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelBlur: v)),
          ),
        ),
        FilterRow(
          const ['tint', 'colour', 'color', 'panel', 'distro'],
          PanelSlider(
            icon: Icons.palette_outlined,
            label: context.t('settings.panels.tint'),
            sub: context.t('settings.panels.tintSub'),
            value: theme.panelTint,
            min: 0,
            max: 1,
            divisions: 10,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelTint: v)),
          ),
        ),
        FilterRow(
          const ['corner', 'radius', 'rounded', 'panel', 'shape'],
          PanelSlider(
            icon: Icons.rounded_corner_outlined,
            label: context.t('settings.panels.corners'),
            sub: context.t('settings.panels.cornersSub'),
            value: theme.panelRadius,
            min: 0,
            max: 28,
            divisions: 14,
            format: (v) => '${v.round()}',
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelRadius: v)),
          ),
        ),
      ],
    ),
  ];
}
