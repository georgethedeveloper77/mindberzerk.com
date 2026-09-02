/// The icons a folder or a distro category may wear.
///
/// ─── WHY A CURATED MAP AND NOT THE WHOLE MATERIAL SET ───────────────────────
///
/// Flutter ships thousands of Material Symbols and every one of them is
/// reachable from `IconData`. Exposing that to a picker is worse than useless:
/// nobody scrolls three thousand glyphs to name a folder Games, and the answers
/// they want are about twenty shapes that repeat across every launcher ever
/// made. A short list is a better picker AND a smaller surface to keep stable.
///
/// ─── AND WHY NOT THE BRAND-ICON PIPELINE ────────────────────────────────────
///
/// `BrandIconResolver` looks like the obvious home for this and is not.
/// `resolve` is keyed by COMPONENT KEY and the pack format is a map of package
/// to path data, so there is no lookup by glyph name; reaching Simple Icons
/// from here would need a new native call and a second pack shape. It is also
/// the wrong register. A brand mark answers "which app is this"; a category
/// icon answers "what kind of thing is in here", and those are different
/// questions with different artwork.
///
/// ─── THE IDS ARE A WIRE FORMAT ──────────────────────────────────────────────
///
/// They are written into prefs by the picker and into theme.json by the panel,
/// so an id that ships is permanent. Renaming one silently blanks every folder
/// and every published pack that used it. Add freely; never rename, and never
/// reuse a retired id for a different shape.
///
/// Const on purpose. The tree-shaker keeps an icon only when some expression
/// names it literally, and every entry below is such an expression, so a glyph
/// restored from a year-old backup still has a font to draw from.
library;

import 'package:flutter/material.dart';

/// What the picker returns for "use the default".
///
/// A sentinel rather than an empty string, because an empty string is also what
/// a corrupted or hand-edited prefs entry looks like, and the two must not be
/// the same value arriving at the write. It is deliberately not a valid
/// catalogue id, so a value that somehow reaches storage resolves to the
/// fallback rather than to a glyph nobody chose.
const String kFolderGlyphCleared = '__default__';

/// Drawn when a folder names no glyph and its category authors none.
///
/// Deliberately NOT `FolderGlyph`'s artwork. That draws `assets/svg/folder.svg`
/// with the member icons tucked into it, which is right at tile size on a home
/// screen and unreadable at 32dp in a rail, where three overlapping app icons
/// are noise. The rail asks "what kind of thing", and an outline folder answers
/// it at any size.
const IconData kFolderGlyphFallback = Icons.folder_outlined;

/// Every glyph a picker offers, in the order it offers them.
///
/// Ordered roughly by how often a launcher category wants one, so the useful
/// answers are above the fold on a phone.
const Map<String, IconData> kFolderGlyphs = <String, IconData>{
  'folder': Icons.folder_outlined,
  'star': Icons.star_outline,
  // ─── NOT A STAR, AND THAT IS THE WHOLE POINT ──────────────────────────
  //
  // Suggestions wore 'star' and so did the Zorin rail's Pinned slot, which
  // meant pinning your first app made a SECOND star appear in the rail. Two
  // identical glyphs, one holding what you chose and one holding what the
  // launcher guessed, and no way to tell which was which without tapping both.
  //
  // Sparkles is the convention everywhere automatic suggestions appear, and
  // the distinction it draws is exactly the right one: a star is a thing you
  // marked, sparkles are a thing the machine decided.
  'sparkle': Icons.auto_awesome_outlined,
  'apps': Icons.apps_outlined,
  'globe': Icons.public_outlined,
  'chat': Icons.chat_bubble_outline,
  'mail': Icons.mail_outline,
  'phone': Icons.phone_outlined,
  'camera': Icons.photo_camera_outlined,
  'photo': Icons.photo_outlined,
  'music': Icons.music_note_outlined,
  'video': Icons.movie_outlined,
  'game': Icons.sports_esports_outlined,
  'book': Icons.menu_book_outlined,
  'news': Icons.article_outlined,
  'work': Icons.work_outline,
  'document': Icons.description_outlined,
  'calendar': Icons.calendar_today_outlined,
  'clock': Icons.schedule_outlined,
  'map': Icons.map_outlined,
  'car': Icons.directions_car_outlined,
  'plane': Icons.flight_outlined,
  'cart': Icons.shopping_cart_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'bank': Icons.account_balance_outlined,
  'health': Icons.favorite_outline,
  'fitness': Icons.fitness_center_outlined,
  'food': Icons.restaurant_outlined,
  'home': Icons.home_outlined,
  'school': Icons.school_outlined,
  'science': Icons.science_outlined,
  'brush': Icons.brush_outlined,
  'code': Icons.code_outlined,
  'terminal': Icons.terminal_outlined,
  'tools': Icons.build_outlined,
  'settings': Icons.tune_outlined,
  'security': Icons.security_outlined,
  'cloud': Icons.cloud_outlined,
  'download': Icons.download_outlined,
  'devices': Icons.devices_outlined,
  'storage': Icons.storage_outlined,
};

/// The icon for [id], or null when nothing in the catalogue answers to it.
///
/// NULL RATHER THAN THE FALLBACK, so a caller can tell "this folder chose
/// nothing" apart from "this folder chose something this build has never heard
/// of". The two look identical on screen and must not look identical to a
/// migration: a value written by a newer build is worth preserving in storage
/// even while it cannot be drawn, and silently rewriting it to the fallback on
/// the next save is how a downgrade eats a user's choices.
IconData? folderGlyphFor(String? id) {
  if (id == null) return null;
  final trimmed = id.trim();
  if (trimmed.isEmpty) return null;
  return kFolderGlyphs[trimmed];
}

/// What to actually draw: the folder's own glyph, else the category's authored
/// one, else [kFolderGlyphFallback].
///
/// The chain lives here rather than at each drawing site because there are
/// three of them (the Zorin rail, the drawer grid, the folder overlay's title)
/// and a fourth would eventually disagree about the order. Same reason
/// `LayoutResolver` owns the layout chain.
IconData resolveFolderGlyph({String? folderGlyph, String? categoryGlyph}) =>
    folderGlyphFor(folderGlyph) ??
    folderGlyphFor(categoryGlyph) ??
    kFolderGlyphFallback;

/// The seven built-in buckets and the remainder, each with an icon.
///
/// Lives here rather than beside [kCategoryOrder] in `drawer_items.dart`
/// because that file must not import Flutter: it is provider and model code,
/// and `IconData` would drag `material.dart` into it. The names are the ones
/// `kCategoryOrder` lists, and adding a bucket there without adding it here is
/// harmless, since the chain falls through to [kFolderGlyphFallback].
const Map<String, String> kBuiltInCategoryGlyphs = <String, String>{
  'Social': 'chat',
  'Media': 'video',
  'Productivity': 'work',
  'Games': 'game',
  'News': 'news',
  'Travel': 'map',
  'Utilities': 'tools',
  'Other': 'folder',
  'Suggestions': 'sparkle',
};
