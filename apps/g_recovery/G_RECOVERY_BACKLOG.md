# G RECOVERY / BACKLOG

Everything raised during device testing that is not part of the current phase.
Nothing here is lost, nothing here blocks a phase, and each item names where it
lands. Companion to `G_RECOVERY.md`, which holds the phase plan.

Status key: **OPEN** not started / **QUEUED** scheduled into a named phase /
**NEEDS DECISION** waiting on George.

---

## Home and visual polish

| ID | Item | Target | Status |
|---|---|---|---|
| P1 | Hero art drawn in code rather than a Lottie file. Animate the painter directly: cards rising and falling back, bin lid tilt, the count ticking up once. Removes the Lottie dependency entirely and keeps the accent recolour for free. | 8 | QUEUED |
| P2 | More colour and motion on home generally. Category tiles animating in, count transitions, subtle gradient movement behind the hero. | 8 | QUEUED |
| P3 | Category tiles should grow and shrink with available width instead of a fixed 3 column grid with a fixed aspect ratio. | 8 | QUEUED |
| P4 | The "Files deleted outside a trash folder" paragraph becomes an info icon that opens the explanation, not a wall of small text under every screen. | 7 | QUEUED |
| P5 | Bottom nav bar taller than 62 dp, with the Device tab given a clearer glyph. | 8 | QUEUED |
| P6 | Device strip placement on home. **The note was cut off mid sentence, so the intent is not recorded.** Currently it sits after the category grid and the access prompt. | 8 | NEEDS DECISION |

## Search

| ID | Item | Target | Status |
|---|---|---|---|
| S1 | Typewriter placeholder that cycles through example queries when the field is empty. | 8 | QUEUED |
| S2 | Documents are effectively unsearchable. MediaStore only indexes a document if an app registered it, so a PDF dropped in by a file manager is often invisible. Needs a direct tree read over `Documents` and `Download` to fill the gap. | 6b | QUEUED |
| S3 | Messages are not searchable because the feature does not exist yet. | 1.1 | QUEUED |

## Viewing and playback

| ID | Item | Target | Status |
|---|---|---|---|
| V1 | Tapping an item in a list or grid does nothing. It should open a full screen viewer with pinch zoom. The viewer already exists inside the review deck and needs lifting into a shared route. | 6b | QUEUED |
| V2 | Video playback. Needs `video_player`, and `VideoPlayerController.contentUri` for MediaStore items. Both the review deck and the viewer use it. | 6b | QUEUED |
| V3 | Duplicate and near duplicate grouping. Size bucket, then partial hash, then full hash only on collision. | 6b | QUEUED |
| V4 | Compression, the Pro hook. Re-encode a large video to 1080p on device with MediaCodec. | 1.3 | QUEUED |

## Content and coverage

| ID | Item | Target | Status |
|---|---|---|---|
| C1 | **WhatsApp Status media is being picked up.** Correct, and it is the single most requested recovery case there is: a status expires after 24 hours and the file is sitting on disk. It must be LABELLED as Status rather than mixed into Photos, and it needs a Save action rather than Restore, because the file was never deleted. | 6b | QUEUED |
| C2 | Trashmap coverage for Transsion, Xiaomi and Oppo is unverified guesswork. The CDN pipeline is what lets it be corrected without a release. | 7 | IN PROGRESS |
| C3 | Thumbnail classifier trusts a missing extension and calls it an image. Should sniff magic bytes so cache index files stop rendering as grey glyphs. | 6b | QUEUED |

## Correctness carried forward

| ID | Item | Target | Status |
|---|---|---|---|
| K1 | Play listing still declares "Contains ads". Must be removed and Data Safety resubmitted. | 9 | OPEN |
| K2 | App icon is a stock trash can shared with roughly nine competitors. | 9 | OPEN |
| K3 | Store screenshots show `0 Files`. Reshoot against a populated home. | 10 | OPEN |
| K4 | Neither `apps/g_recovery` nor `packages/device_probe` has joined the pub workspace. Four edits, all or none. | 8 | OPEN |
| K5 | Cold start to populated home has never been measured on a release build. Phase 4's exit criterion was under 1.2 s. | 9 | OPEN |

---

## Standing rules learned on device

These belong in `MINDHUNTER.md` alongside the existing list.

- **An `AnimationController` is always constructed in `initState`**, never as a `late final` with an initialiser. The lazy form defers construction to first access, and if that access is `dispose()`, `createTicker` looks up `TickerMode` on a deactivated element. The stack blames `dispose`, which is the last place anyone looks for a construction bug.
- **Never write a shell glob in a Pigeon doc comment.** A star immediately before a slash closes the generated KDoc block early, and the rest of the sentence lands inside a Kotlin constructor. The compiler then names a parameter that does not exist in the schema.
- **Adding a HostApi method touches four files**: the schema, the Kotlin impl, the Dart wrapper, and the call site. The wrapper is the one that gets forgotten.
- **`Container` asserts `margin.isNonNegative`.** To draw wider than the incoming constraints, use `OverflowBox` with a `LayoutBuilder`, never a negative margin.
- **`_guard<T>` returns `Future<T?>`.** A bridge method whose native return is already nullable needs its type argument written out, or inference demands a non-null future.
- **A category is a kind, not a source.** Users ask for photos; which source a file came from is our bookkeeping and belongs on the row as a fidelity stamp, not in the routing.
- **Riverpod 3 removed `AsyncValue.valueOrNull`.** `value` is nullable now.
- **Do not annotate family providers with `FutureProviderFamily`.** Let the type be inferred; the family type names are Riverpod internals.
