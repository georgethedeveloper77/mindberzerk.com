import 'package:flutter/material.dart';

import 'tokens.dart';

/// THE COLOUR OF A CATEGORY, decided once.
///
/// This was written out four times: in the home mosaic, the storage ledger, the
/// recovery source tiles and the reclaim cards. Four maps drift, and they had.
/// Audio was amber in one place and coral in another, and thumbnails and the
/// unclassified bucket both ended up on the same hue by accident.
///
/// ─── ONE KEY SPACE ───────────────────────────────────────────────────────────
///
/// Kinds, sources and reclaim actions all resolve here, because to a person
/// looking at the screen they are the same kind of thing: a label with a colour.
/// That the app calls one of them a kind and another a source is bookkeeping.
///
/// ─── ONE HUE PER CATEGORY ────────────────────────────────────────────────────
///
/// Not two. Cards used to blend from one hue into a different one, which looked
/// rich in isolation and broke the thing colour is for: Video ran cyan into
/// violet, so on a screen beside Photos it read violet. The storage bars were
/// always a single hue fading into itself, and they were right.
///
/// Depth now comes from ALPHA rather than from a second colour. Every card, bar,
/// dot and motif for one category is the same hue at different strengths, so a
/// person can learn amber means audio once and have it hold everywhere.
Color categoryTint(GTokens t, String key) {
  switch (key) {
    // ─── Kinds ───────────────────────────────────────────────────────────────
    case 'image':
      return t.photo;
    case 'video':
      return t.video;
    case 'audio':
      return t.audio;
    case 'document':
      return t.docs;

    /// Everything MediaStore indexed and could not classify: archives,
    /// installers, downloads with odd extensions. A real category with a real
    /// drill in, and often the largest actionable bucket on a tidy phone.
    case 'other':
      return t.chat;

    case 'messages':
      return t.chat;

    // ─── Recovery sources ────────────────────────────────────────────────────
    case 'media_trash':
      return t.docs;
    case 'app_trash':
      return t.chat;
    case 'thumbnails':
      return t.apps;
    case 'live_files':
      return t.audio;

    // ─── Storage buckets with nowhere to go ──────────────────────────────────
    //
    // Deliberately dim. Both are measurable and neither is removable, and a
    // colour on them would invite a tap that leads nowhere.
    case 'apps':
    case 'system':
    case 'unaccounted':
      return t.dim;

    case 'trash':
      return t.chat;

    // ─── Reclaim actions ─────────────────────────────────────────────────────
    case 'duplicates':
      return t.docs;
    case 'large':
      return t.video;
    case 'similar':
      return t.photo;
    case 'stale':
      return t.audio;
    case 'blurred':
      return t.apps;

    default:
      return t.muted;
  }
}
