# D2 — desklet schema + pure layout engine

## Files

| Path | State |
|---|---|
| `lib/data/prefs/launcher_prefs.dart` | REPLACED (patched from your upload) |
| `lib/data/prefs/desklet_layout.dart` | new |
| `lib/engine/desklet_spec.dart` | new |
| `test/desklet_layout_test.dart` | new |

`schemaVersion` stays 1. `desklets` is additive and `fromJson` tolerates its
absence, so every existing prefs file parses unchanged as "no desklets".

## Two bugs fixed in launcher_prefs.dart

1. **`clearing()` dropped `drawerScrollStyle`.** The parameter existed; the line
   in the returned constructor did not. So clearing ANY setting silently reset
   the drawer scroll style to null. A field omitted from that method is not
   "left alone" — it is dropped, because the constructor defaults it.
   Worth a scan of the rest of that method against the field list.

2. **`folderOrderCustom` was in `operator ==` but missing from `hashCode`.**
   Legal (equal objects still hashed equal) but the asymmetry bites in a Set or
   as a Map key.

Both have regression tests.

## The function that is not here

There is **no `prune()`**, and the plan said there would be. Writing it made the
case against it: pruning means deleting placements whose kind is not in the
registry, which is exactly what the schema exists to prevent. A CDN pack can
offer a kind a shipped APK has never heard of; if an older build prunes it, the
desktop is destroyed and updating the app does not bring it back.

`renderable()` replaces it. It is a QUERY: it answers "what can I draw right
now" and never touches storage. Unknown kinds are invisible and immortal.

`normalise()` is the only thing that rewrites, and only for data that is
structurally impossible rather than merely unrecognised: duplicate ids and
out-of-range spans, both of which can arrive from a hand-edited starter desktop.
It leaves unknown kinds entirely alone and is identity-stable when there is
nothing to repair, so it is safe to call on every load without churning
`LauncherPrefs` equality.

## Deliberate asymmetry: move refuses, resize clamps

`move()` on a collision returns prefs unchanged. `resize()` past a limit stops
growing rather than refusing. A resize handle that snaps back to where it
started feels broken; a tile that teleports on a bad drop feels worse. A clamped
size that still collides IS refused, because silently overlapping a neighbour is
not the smaller failure.

Every refusal is identity-stable (`identical(after, p)`), so callers can detect
one and say "no room" rather than watching the picker close with nothing added.

## Not run

There is no Dart toolchain in the environment these were written in, so the
tests are reviewed but unexecuted. Run before trusting them.
