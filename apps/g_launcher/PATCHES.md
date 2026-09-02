# Phase 2b: no patches. Nothing to apply by hand.

The last two builds failed on the same three lines because Phase 1 and Phase 2
shipped `AppChangeWatcher.kt` and `LauncherHostApiImpl.kt` as written
instructions rather than as files. That was the wrong call: I had both files
on disk and should have edited them.

Both are now in this drop-in, complete and patched:

  apps/AppChangeWatcher.kt      + fun notifyChanged()
  apps/LauncherHostApiImpl.kt   + fun webAppsChanged()

Everything else is unchanged from Phase 2.

## Full file list

  apps/AppChangeWatcher.kt      patched (was instructions)
  apps/LauncherHostApiImpl.kt   patched (was instructions)
  apps/AppRepository.kt         Phase 1 + Phase 2 edits
  apps/ShortcutRepository.kt    Phase 1 + Phase 2 edits
  icons/IconCache.kt            Phase 2

Phase 1's other files are unchanged and are NOT in this zip. If you have not
already unzipped Phase 1, you still need:

  apps/WebAppStore.kt           new
  apps/PinShortcutActivity.kt   new
  AndroidManifest.xml           the CONFIRM_PIN_SHORTCUT activity
  lib/data/repositories/app_repository.dart

The one remaining hand edit in the whole feature is the schema DOC COMMENT in
pigeons/launcher_api.dart, which changes nothing at build time:

  ///   web_app            a site added from a browser; no package to remove
