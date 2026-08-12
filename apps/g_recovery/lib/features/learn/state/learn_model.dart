import 'package:flutter/foundation.dart' show immutable;

/// One rendered element inside a chapter.
///
/// A SMALL FIXED SET, not markdown. Markdown would need a parser, a renderer,
/// and a decision about which subset is supported, and every one of those is a
/// place for published content to render wrong on a user's phone. Six block
/// types cover everything these chapters need, an unknown type is skipped
/// rather than shown raw, and the panel can validate against the same list.
@immutable
class ContentBlock {
  const ContentBlock({
    required this.type,
    this.text,
    this.name,
    this.items = const <String>[],
  });

  /// "p" | "h" | "note" | "warn" | "path" | "list"
  final String type;

  final String? text;

  /// The label on a "path" block.
  final String? name;

  final List<String> items;

  factory ContentBlock.fromJson(Map<String, Object?> json) => ContentBlock(
    type: json['t'] as String? ?? 'p',
    text: json['text'] as String?,
    name: json['name'] as String?,
    items: <String>[
      for (final Object? item
          in (json['items'] as List<Object?>? ?? const <Object?>[]))
        if (item is String) item,
    ],
  );
}

@immutable
class LearnChapter {
  const LearnChapter({
    required this.id,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.blocks,
  });

  final String id;
  final String title;
  final String summary;
  final int minutes;
  final List<ContentBlock> blocks;

  factory LearnChapter.fromJson(Map<String, Object?> json) => LearnChapter(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    minutes: (json['minutes'] as num? ?? 2).toInt(),
    blocks: <ContentBlock>[
      for (final Object? block
          in (json['blocks'] as List<Object?>? ?? const <Object?>[]))
        if (block is Map<String, Object?>) ContentBlock.fromJson(block),
    ],
  );
}

@immutable
class LearnBook {
  const LearnBook({required this.version, required this.chapters});

  final int version;
  final List<LearnChapter> chapters;

  static const LearnBook empty = LearnBook(
    version: 0,
    chapters: <LearnChapter>[],
  );

  LearnChapter? chapter(String id) {
    for (final LearnChapter chapter in chapters) {
      if (chapter.id == id) return chapter;
    }
    return null;
  }

  /// Never throws. Malformed published content means a short book, which is
  /// recoverable; a crash on opening Learn is not.
  factory LearnBook.fromJson(Map<String, Object?> json) {
    if (json.isEmpty) return empty;
    return LearnBook(
      version: (json['version'] as num? ?? 0).toInt(),
      chapters: <LearnChapter>[
        for (final Object? chapter
            in (json['chapters'] as List<Object?>? ?? const <Object?>[]))
          if (chapter is Map<String, Object?>) LearnChapter.fromJson(chapter),
      ],
    );
  }
}

/// Chapter ids referenced from elsewhere in the app.
///
/// Named constants rather than string literals at each call site, because an
/// info icon pointing at a chapter that was renamed in the panel should fail
/// here, in one place, and not silently open nothing.
class LearnIds {
  const LearnIds._();

  static const String whereFilesLive = 'where-files-live';
  static const String standardFolders = 'standard-folders';
  static const String androidData = 'android-data';
  static const String theTrash = 'the-trash';
  static const String thumbnails = 'thumbnails';
  static const String scopedStorage = 'scoped-storage';
  static const String factoryReset = 'factory-reset';
}
