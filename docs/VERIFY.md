# The five files from the C2b zip that never landed

`PackPaths.kt` was the one the compiler named, but it was not alone. That zip
carried five files and **none of them arrived**:

| File | What is missing without it |
|---|---|
| `cdn/PackPaths.kt` | The verified packs root. Compile error, which is how we found it. |
| `cdn/PackSyncWorker.kt` | The `bundledPackIds` exception. Without it the worker only updates already-installed packs, and `simple-icons` ships bundled, so the ENTIRE CDN pipeline is a silent no-op on every device. |
| `icons/BrandIconResolver.kt` | `reload()`, and the read path. Compiles fine; reads `filesDir/brandpacks`, which nothing verifies and nothing writes. |
| `icons/HeroIconResolver.kt` | Same. |
| `icons/IconCache.kt` | Self-registration with `PackChangeNotifier`. Compiles fine; a downloaded pack sits on disk doing nothing until the process dies. |

The last three are the dangerous ones: they compile, so nothing tells you. You
would have shipped a launcher that downloads and verifies packs correctly and
then never reads them, and the symptom is indistinguishable from the download
having failed.

## Verify, do not assume

```bash
cd apps/g_launcher/android/app/src/main/kotlin/com/mindhunter/g_launcher

# 7 files
ls cdn/

# each should print 1
grep -c "fun reload" icons/BrandIconResolver.kt
grep -c "fun reload" icons/HeroIconResolver.kt
grep -c "PackChangeNotifier" icons/IconCache.kt   # prints 2
grep -c "bundledPackIds" cdn/PackSyncWorker.kt

# should print NOTHING — the old unverified paths are gone
grep -rn "filesDir, \"brandpacks\"\|filesDir, \"heropacks\"" icons/
```

That last grep is the important one. If it prints anything, the resolver edits
did not land and the icon pipeline still has a read path that skips
`PackVerifier`.

## Extraction

Five files from one zip, all silently absent, is not a one-off. From the
terminal, `unzip` merges into the current tree:

```bash
cd /Users/karani/Documents/Projects/mindberzerk
unzip -o ~/Downloads/<name>.zip
```

Finder unpacks into a folder named after the archive instead, which leaves a
`mindberzerk/` nested inside `mindberzerk/` that is easy to miss entirely.

Worth a one-line check after every extraction from now on: `git status` should
show the files you expected, and nothing in a nested directory.
