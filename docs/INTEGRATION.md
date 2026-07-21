# Phase C — the three lines that make it run

Everything else is written. These are the wiring points, and each one fails
silently if missed, which is why they are listed rather than left to a diff.

## 1. `pubspec.yaml` — add the shared package

```yaml
dependencies:
  g_account:
    path: ../../packages/g_account
```

Then `melos bootstrap` from the repo root. Under a pub workspace the path is
resolved once for the whole repo; without the entry, `entitlements.dart` will
not import.

## 2. `app.dart` — watch the bridge, once, at the root

Inside the root widget's `build`, before anything else:

```dart
ref.watch(packBridgeProvider);
```

**If this is missing:** downloads still work, but the progress bar never moves
and the storefront never refreshes after an install, because nothing is
listening to `PackFlutterApi`. It looks like the download hanging.

It has to be the root and it has to be exactly once. Pigeon's `setUp` REPLACES
any previous handler on the channel, so a second registration from a screen
silently unhooks the first, and the symptom is a progress bar that works right
up until you open a second screen.

It cannot go in `bootstrap()`: there is no ProviderContainer at that point,
since `runApp(ProviderScope(...))` has not been called yet.

## 3. Wherever Remote Config resolves — push the CDN base URL

```dart
await ref.read(packActionsProvider).pushCdnBaseUrl(
  remoteConfig.getString('cdn_base_url'),
);
```

**If this is missing:** everything still works, on the compiled-in default
`https://cdn.mindberzerk.com`. What you lose is the ability to move hosts
without a Play release, which is the entire reason the value is in Remote Config.

This writes a file that the headless `PackSyncWorker` reads, which is why it
goes through native rather than staying in Dart: the worker runs with no Dart
engine attached.

## Also worth adding, not strictly wiring

A **"Restore purchases"** row in Settings, calling `restorePurchasesProvider`.
This is not optional in practice. A user who reinstalls, or signs in on a new
phone, has no other way to get their packs back, and its absence generates
refund requests from people who did nothing wrong.

```dart
ThemedListRow(
  icon: Icons.restore,
  title: 'Restore purchases',
  onTap: () async {
    await ref.read(restorePurchasesProvider)();
    if (context.mounted) context.showMessage('Checked with Play');
  },
),
```

## Checklist before the AAB goes out

- [ ] `PackKeys.ACCEPTED_HEX` holds the PUBLIC half of your signing key, not the
      placeholder zeros. If this ships wrong, every pack is refused with
      `UnknownKey` and the only fix is another release.
- [ ] `pubspec.yaml` says `version: 6.0.0+6`. It was reverted to `5.0.0+3` at
      some point, and with `--min-app 6` on your signed packs that makes every
      install come back `AppTooOld`.
- [ ] `dart run pigeon --input pigeons/pack_api.dart` has been run and the
      generated files are in place.
- [ ] The ten products exist in Play Console with the IDs from
      `backend/content/products.json`.
- [ ] `index.json` and `index.sig` are uploaded to `g-launcher/` in the bucket.
- [ ] `./scripts/no_readmes.sh` and the other three gates report 0.
