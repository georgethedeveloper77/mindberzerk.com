# Delete before building

The native font path is gone. These files are dead and one of them (the certs
placeholder) is what was making every preview return null:

```bash
rm -rf android/app/src/main/kotlin/com/mindhunter/g_launcher/fonts
rm -f  android/app/src/main/res/values/font_certs.xml
dart run pigeon --input pigeons/launcher_api.dart
```

`LauncherHostApiImpl.kt` in this zip already has the imports, fields and both
override methods removed, so it compiles once the fonts package is gone.

`path_provider` is still used elsewhere in the app; do not remove it from
pubspec. `google_fonts: ^8.2.1` is already there.
