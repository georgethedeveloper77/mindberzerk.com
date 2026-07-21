# Two build errors, both mine

## 1. `FlutterError` redeclaration

Pigeon emits a `FlutterError` class into EVERY generated Kotlin file. Both
schemas were pointed at package `com.mindhunter.g_launcher`, so the second one
redeclared the first.

My argument for a separate schema file was codec isolation, and I did not carry
it through to the Kotlin package. Fixed: `pack_api.dart` now generates into
`com.mindhunter.g_launcher.pack`.

**Delete the old generated file first**, or you will have two:

```bash
cd apps/g_launcher
rm -f android/app/src/main/kotlin/com/mindhunter/g_launcher/PackApi.g.kt
dart run pigeon --input pigeons/pack_api.dart
```

That writes `android/app/src/main/kotlin/com/mindhunter/g_launcher/pack/PackApi.g.kt`.

`LauncherApi.g.kt` is untouched. Its codec ids and its `FlutterError` stay
exactly where a shipped APK expects them.

## 2. `PackHostApiImpl` unresolved

The file was never on disk. Same as `pack_repository.dart`, `pigeons/pack_api.dart`
and `r2.mjs` before it — that is now four files from four different zips that
did not land, so it is worth working out what is happening on extraction rather
than re-shipping one at a time.

A guess worth testing: if you are extracting by double-clicking in Finder, macOS
unpacks to a folder named after the zip rather than merging into the current
directory, and a `mindberzerk/` inside `mindberzerk/` is easy to miss. From the
terminal it merges:

```bash
cd /Users/karani/Documents/Projects/mindberzerk
unzip -o ~/Downloads/<name>.zip
```

`-o` overwrites without prompting, which is what you want for these.

## Verify before building

```bash
cd apps/g_launcher
ls android/app/src/main/kotlin/com/mindhunter/g_launcher/cdn/
```

Expect seven files:

```
CdnClient.kt  CdnConfig.kt  CdnIndex.kt  PackDownloader.kt
PackHostApiImpl.kt  PackPaths.kt  PackSyncWorker.kt
```

Any missing one is a zip that did not extract, and the compile error will name
it.

## Then

```bash
rm -f android/app/src/main/kotlin/com/mindhunter/g_launcher/PackApi.g.kt
dart run pigeon --input pigeons/pack_api.dart
flutter run
```

Remember `flutter run` resets the default home app, so follow with
`adb shell cmd package set-home-activity` before judging anything about the app
list.

## Unrelated warning you can ignore for now

The KGP warning about `firebase_analytics` is upstream. It builds today; it will
need a plugin version bump before a future Flutter release. Not blocking.
