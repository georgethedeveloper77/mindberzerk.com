import '../../learn/state/learn_model.dart';

/// WHAT A FOLDER IS FOR, in one line.
///
/// The whole reason the browser exists. A list of directory names teaches
/// nothing: DCIM means nothing to anyone who has not been told, and the folder a
/// person most wants to open is the one Android will not let them.
///
/// ─── KEYED ON THE PATH TAIL, NOT THE FULL PATH ───────────────────────────────
///
/// So that WhatsApp under Android/media and WhatsApp under the storage root both
/// resolve, and so an SD card's DCIM is annotated the same as internal storage's.
/// Matching whole paths would mean maintaining a list of every prefix a phone
/// might use, which differs per OEM.
///
/// ─── EVERY ENTRY LINKS TO A CHAPTER WHERE ONE EXISTS ─────────────────────────
///
/// The line here is the label; the chapter is the explanation. Learn already had
/// the chapters and nothing pointing at them from a place a person would
/// naturally be curious.
class FolderNote {
  const FolderNote({required this.text, this.chapterId});

  final String text;
  final String? chapterId;
}

/// Case insensitive, longest tail first, so `Android/data` beats `Android`.
FolderNote? noteFor(String path) {
  final String lower = path.toLowerCase();
  for (final MapEntry<String, FolderNote> entry in _notes.entries) {
    if (lower.endsWith('/${entry.key}')) return entry.value;
  }
  return null;
}

const Map<String, FolderNote> _notes = <String, FolderNote>{
  // Two segments first. The map is iterated in declaration order and the first
  // match wins, so anything more specific has to come before its parent.
  'android/data': FolderNote(
    text:
        'Each app keeps its private files here. Locked since Android 11, '
        'including to this app.',
    chapterId: LearnIds.androidData,
  ),
  'android/obb': FolderNote(
    text: 'Extra data for large games. Locked in the same way.',
    chapterId: LearnIds.androidData,
  ),
  'android/media': FolderNote(
    text:
        'App files that are meant to be visible. This is where WhatsApp '
        'moved its media in 2021.',
    chapterId: LearnIds.scopedStorage,
  ),
  'dcim/camera': FolderNote(text: 'Photos and video from the camera itself.'),
  'dcim/.thumbnails': FolderNote(
    text:
        'Small copies Android keeps so galleries open fast. They often '
        'outlive the originals.',
    chapterId: LearnIds.thumbnails,
  ),

  'dcim': FolderNote(
    text:
        'Everything the camera produced, and where most apps put photos they '
        'save for you.',
    chapterId: LearnIds.standardFolders,
  ),
  'download': FolderNote(
    text: 'Anything a browser or an app saved deliberately.',
    chapterId: LearnIds.standardFolders,
  ),
  'pictures': FolderNote(
    text: 'Screenshots, and images apps create rather than photograph.',
    chapterId: LearnIds.standardFolders,
  ),
  'movies': FolderNote(text: 'Video that did not come from the camera.'),
  'music': FolderNote(text: 'Audio files, usually ones you put here yourself.'),
  'documents': FolderNote(text: 'Files apps save for you to keep and reopen.'),
  'ringtones': FolderNote(text: 'Sounds available in the phone settings.'),
  'android': FolderNote(
    text:
        'Where apps keep their own files. Most of it is closed to every app '
        'but its owner.',
    chapterId: LearnIds.scopedStorage,
  ),
  '.trash': FolderNote(
    text: 'The system bin. Files here are recoverable for thirty days.',
    chapterId: LearnIds.theTrash,
  ),
  '.trashed': FolderNote(
    text: 'The system bin. Files here are recoverable for thirty days.',
    chapterId: LearnIds.theTrash,
  ),
};
