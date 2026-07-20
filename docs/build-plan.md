# Mindhunter ecosystem — project structure & build plan

G Recovery · G Launcher · (later) G Editor · (later) News

---

## 0. Three decisions that shape everything below

**1. One repo, separate apps.** Each app stays a standalone Flutter project with its own `android/`, its own `lib/`, its own `applicationId`, its own Play listing and release cadence. They live in one Git repo so shared packages can be path-linked without publishing to pub.dev. Nothing is merged into a single binary.

**2. Heavy lifting is Kotlin, not Dart.** This is the most important architectural call in the whole plan.

- A multi-GB overnight backup **cannot** depend on a live Flutter engine. It runs in **WorkManager, in pure Kotlin**. Flutter configures it and observes progress.
- Scanning 50,000 photos, hashing them, and transcoding video are native jobs. Kotlin does the work and streams results into Dart.
- The launcher's app list and icon rendering live in Kotlin, cached as bitmaps. Flutter draws the desktop.

Flutter is the UI, navigation, state, and business-logic layer. It is not the engine. Plan accordingly and neither app will feel sluggish on a Tecno Spark.

**3. Ship into the existing listings.** G Recovery has 1K+ installs, reviews and search ranking. Do not publish a new app. Same `applicationId`, same signing key, higher `versionCode`, staged rollout. See §6 for the traps.

---

## 1. Stack

| Layer | Choice | Why |
|---|---|---|
| UI | Flutter (stable, pinned) | Shared design system across apps |
| State | Riverpod (codegen) | Testable, no BuildContext plumbing, good solo ergonomics |
| Routing | go_router | Deep links matter for both apps |
| Local DB | **Drift** (SQLite) | The media index is 100k+ rows. SQLite is right, and Drift is actively maintained (Isar's maintenance has been unreliable) |
| Models | freezed + json_serializable | |
| Native bridge | **Pigeon** | Type-safe channels, generated both sides. Do not hand-roll MethodChannels |
| Networking | dio | Interceptors, retry, ETag caching |
| Background work | **WorkManager (Kotlin)** | Backups and scans must survive process death |
| Video transcode | **Jetpack Media3 Transformer** | FFmpegKit was retired in 2025 — do not build on it |
| Workspace | Dart pub workspaces + Melos for scripts | Pin the current stable versions; don't take my numbers on faith |
| Backend | Cloudflare Workers + R2 + D1 | ~$0–5/mo at your scale, no cold starts, no egress fees |
| Admin | Next.js on Cloudflare Pages | Fastest path. Use Flutter Web only if you want one language everywhere |

**minSdk 24, target the latest API Play requires.** Gate features by capability, never by assumption:

- MediaStore trash APIs → API 30+
- Monochrome themed icons → API 33+
- Partial photo access (`READ_MEDIA_VISUAL_USER_SELECTED`) → API 34+

---

## 2. Repository layout

```
mindhunter/
├── melos.yaml
├── pubspec.yaml                    # workspace root
├── analysis_options.yaml           # one lint config for everything
├── .github/workflows/
│   ├── ci.yaml                     # analyze + test + build on every PR
│   ├── release_recovery.yaml       # → Play internal track
│   └── release_launcher.yaml
│
├── apps/
│   ├── g_recovery/                 # com.mindhunter.g_recovery
│   ├── g_launcher/                 # com.mindhunter.g_launcher
│   └── g_editor/                   # placeholder — Phase 7
│
├── packages/                       # shared Dart/Flutter only
│   ├── g_core/                     # pure Dart: Result, failures, logging, env, feature flags
│   ├── g_design/                   # design system: tokens, components, charts
│   ├── g_net/                      # dio client, auth interceptor, ETag cache
│   ├── g_account/                  # device id, sign-in, Play Billing, entitlements
│   ├── g_content/                  # CDN manifests, signature verify, download/unpack
│   └── g_media/                    # SHARED native plugin: MediaStore scan, hashing, thumbnails
│                                   # (G Recovery uses it now; G Editor will reuse it)
│
├── backend/
│   ├── workers/api/                # Cloudflare Worker
│   ├── content/                    # source of truth for everything on the CDN
│   ├── schema/                     # JSON schemas for every manifest
│   └── scripts/                    # sign + publish
│
├── admin/                          # Next.js admin panel
└── tools/                          # icon generation, screenshot capture, release helpers
```

### Why `g_media` is shared but the backup engine is not

`g_media` is scanning and hashing — G Recovery needs it, G Editor will need it. Backup transports, the launcher's `LauncherApps` glue, and the icon renderer are app-specific and stay inside their app's `android/`. Resist the urge to share code that only one app uses.

---

## 3. Shared packages

```
packages/
├── g_core/lib/
│   ├── result.dart                 # Result<T, Failure> — no thrown exceptions across layers
│   ├── failure.dart
│   ├── logger.dart
│   ├── env.dart                    # CDN base url, api url, public signing key
│   └── feature_flags.dart          # remote-config backed kill switches
│
├── g_design/lib/
│   ├── tokens/
│   │   ├── colors.dart             # recovery: ink/mint. launcher chrome: neutral
│   │   ├── typography.dart         # sans + mono. Mono for ALL data values
│   │   ├── spacing.dart
│   │   └── radii.dart
│   ├── components/
│   │   ├── g_card.dart
│   │   ├── g_chip.dart             # ok / warn / off / info
│   │   ├── g_list_row.dart
│   │   ├── g_metric.dart
│   │   ├── g_segmented.dart
│   │   ├── g_switch_row.dart
│   │   └── g_paywall_sheet.dart
│   ├── charts/                     # this is a selling point — treat it as one
│   │   ├── storage_bar.dart        # segmented storage bar
│   │   ├── growth_chart.dart       # storage over time + fill-up forecast
│   │   └── donut.dart
│   └── theme.dart
│
├── g_net/lib/
│   ├── api_client.dart
│   ├── interceptors/{auth,retry,etag_cache}.dart
│   └── cdn_client.dart
│
├── g_account/lib/
│   ├── device_identity.dart        # anonymous install id
│   ├── billing/
│   │   ├── billing_client.dart     # Play Billing wrapper
│   │   ├── products.dart           # pro_unlock, theme packs
│   │   └── restore.dart
│   ├── entitlements.dart           # single source of truth for "is Pro"
│   └── license_verifier.dart       # server-signed token, cached offline
│
├── g_content/lib/
│   ├── manifest/
│   │   ├── root_manifest.dart      # index of everything available
│   │   ├── theme_manifest.dart
│   │   ├── icon_pack_manifest.dart
│   │   ├── oem_guide.dart
│   │   └── backup_guide.dart
│   ├── signature.dart              # ed25519 verify — CDN content is code-adjacent, sign it
│   ├── downloader.dart
│   └── pack_store.dart             # local cache, version pinning, eviction
│
└── g_media/                        # Flutter plugin (Dart + Kotlin)
    ├── lib/g_media.dart
    ├── pigeons/g_media_api.dart
    └── android/src/main/kotlin/com/mindhunter/g_media/
        ├── MediaScanner.kt         # MediaStore paging, no OOM on 100k items
        ├── ThumbnailLoader.kt
        ├── Hashing.kt              # SHA-256 (exact) + dHash (perceptual)
        └── ImageQuality.kt         # Laplacian variance → blur; histogram → dark
```

**Entitlements deserve one owner.** `g_account/entitlements.dart` is the only place in either app that answers "is this user Pro." Everything else asks it. This is what stops paywall logic metastasising across 40 files.

---

## 4. G Recovery

### 4.1 Native layer (Kotlin) — the actual engine

```
apps/g_recovery/android/app/src/main/kotlin/com/mindhunter/g_recovery/
├── MainActivity.kt
├── GRecoveryApi.g.kt                    # Pigeon-generated
│
├── scan/
│   ├── TrashAggregator.kt               # THE recovery pillar. Unified view of:
│   │                                    #   MediaStore IS_TRASHED items (API 30+)
│   │                                    #   OEM gallery/file-manager trash where readable
│   │                                    #   Google Photos trash (via user account, read-only)
│   ├── SafScanner.kt                    # SD card / OTG via SAF tree grant
│   ├── ThumbnailScanner.kt              # leftover low-res previews of older deletions
│   ├── WhatsAppMediaScanner.kt          # Android/media/com.whatsapp — SHARED storage, legal
│   ├── AppStorageInspector.kt           # StorageStatsManager → per-app media breakdown
│   └── StorageSnapshotWorker.kt         # daily row → powers the growth chart + forecast
│
├── clean/
│   ├── DuplicateFinder.kt               # size → partial hash → full SHA-256
│   ├── SimilarityGrouper.kt             # dHash + Hamming distance, brute force is fine
│   └── DeleteRequestBuilder.kt          # see the batching note below — this is load-bearing
│
├── compress/
│   ├── ZipArchiver.kt
│   └── MediaTranscoder.kt               # Media3 Transformer: H.265, downscale, bitrate cap
│
├── backup/                              # runs with NO Flutter engine alive
│   ├── BackupWorker.kt                  # WorkManager: constraints, retry, foreground notif
│   ├── BackupPlanner.kt                 # diff local index vs remote index
│   ├── CryptoStream.kt                  # AES-256-GCM, chunked, streaming
│   ├── KeyManager.kt                    # Argon2id from passphrase → Android Keystore
│   └── transport/
│       ├── Transport.kt                 # interface: put / list / delete / probe
│       ├── SmbTransport.kt              # smbj — NO usable Dart SMB client exists
│       ├── WebDavTransport.kt           # also covers Nextcloud
│       ├── NextcloudTransport.kt        # WebDAV + chunked upload endpoint
│       └── SftpTransport.kt             # sshj
│
├── device/
│   ├── DeviceInfoProbe.kt               # SoC, RAM, storage, patch level
│   ├── NetworkProbe.kt                  # carrier, signal, band, Wi-Fi channel
│   └── PermissionProbe.kt               # powers the "what I can reach" manifest
│
├── oem/
│   └── OemProfileResolver.kt            # Build.MANUFACTURER → remote-config guide
└── archive/
    └── ArchiveReclaimer.kt              # verify on server → then free local. Verify FIRST.
```

**Two platform realities that dictate the UX:**

**Batched deletes.** On Android 11+ you cannot silently delete media the app doesn't own — the system shows a consent dialog. So the swipe-clean flow must **queue decisions and submit one `createDeleteRequest` at the end**. Design the screen around a single "Delete 23 items" confirmation, not a dialog per swipe. Get this wrong and the feature is unusable.

**Archive-and-reclaim must verify before it frees.** Upload → read back the checksum from the server → only then delete locally. Anything else is a data-loss bug waiting to happen, in an app whose entire pitch is trust.

### 4.2 Dart layer

```
apps/g_recovery/lib/
├── main.dart
├── bootstrap.dart                       # DI, Drift open, migrations, crash reporting
├── app.dart
├── router.dart
│
├── platform/                            # Pigeon Dart side + thin wrappers
│
├── data/
│   ├── db/
│   │   ├── database.dart                # Drift
│   │   └── tables/{media,hashes,backup_runs,snapshots,servers}.dart
│   └── repositories/
│       ├── media_repository.dart
│       ├── recovery_repository.dart
│       ├── backup_repository.dart
│       ├── storage_repository.dart
│       └── device_repository.dart
│
├── features/
│   ├── home/                            # protection state, reach manifest, jump-to tiles
│   ├── recover/                         # wizard + trash aggregation results
│   ├── backup/                          # server setup, schedule, run, history
│   │   └── setup/                       # guided flows: Nextcloud-on-Pi, SMB NAS, SFTP
│   ├── storage/                         # breakdown, growth chart, forecast, per-app media
│   ├── swipe_clean/                     # ← the niche feature. photo zoom + inline playback
│   ├── duplicates/
│   ├── compress/
│   ├── device/                          # device + network + permission passport
│   ├── oem_guide/                       # per-brand recovery paths (remote config)
│   ├── paywall/
│   └── settings/
│
└── shared/widgets/
```

Each feature folder: `view/` (screens + widgets), `controller.dart` (Riverpod), `state.dart` (freezed). Keep it flat — a solo dev does not need four Clean Architecture layers per feature.

### 4.3 Free vs Pro

| Free — matches Files/My Files | Pro — the reasons to pay |
|---|---|
| Trash aggregation + basic recovery | Automated encrypted backup, multiple servers |
| Large files, unused apps, junk | Archive-and-reclaim (offload → free space) |
| Storage breakdown | Growth charts + fill-up forecast |
| Manual one-shot backup, one server | Compression (zip + video re-encode) |
| Device + network info | Swipe-clean beyond a daily quota |
| OEM recovery guide | Duplicate + similar-photo grouping at scale |

**No ads.** One-time Pro unlock, priced regionally for the Infinix/Tecno base.

---

## 5. G Launcher

### 5.1 Native layer (Kotlin) — this app is *mostly* native

```
apps/g_launcher/android/app/src/main/kotlin/com/mindhunter/g_launcher/
├── LauncherActivity.kt                  # HOME + DEFAULT intent filters, singleTask,
│                                        # resume-on-home-press must be instant
├── LauncherApplication.kt               # warm the FlutterEngine at process start
├── GLauncherApi.g.kt                    # Pigeon
│
├── apps/
│   ├── AppRepository.kt                 # LauncherApps.getActivityList() + profiles
│   ├── PackageChangeReceiver.kt         # install/uninstall/update → invalidate cache
│   └── ShortcutRepository.kt            # deep shortcuts, pinned shortcuts
│
├── icons/                               # the 100%-coverage engine
│   ├── IconExtractor.kt                 # AdaptiveIconDrawable fg/bg + getMonochrome() (33+)
│   ├── IconRenderer.kt                  # apply theme mask + tint + shape → Bitmap
│   ├── HeroIconResolver.kt              # package → hand-crafted theme icon (overrides)
│   └── IconCache.kt                     # disk cache keyed (package, themeId, size, version)
│
├── host/
│   ├── WidgetHost.kt                    # AppWidgetHost — needed for the conky tile,
│   │                                    # G Recovery status tiles, later the news feed
│   └── WallpaperController.kt
│
├── system/
│   ├── RoleRequester.kt                 # RoleManager ROLE_HOME → "set as default"
│   ├── SettingsIntents.kt               # deep-link to real Android settings
│   └── NotificationDots.kt              # optional. NotificationListenerService = Play review
└── theme/
    └── ThemeAssetLoader.kt              # load + verify downloaded packs
```

### 5.2 Dart layer

```
apps/g_launcher/lib/
├── main.dart
├── bootstrap.dart
├── router.dart
│
├── engine/                              # ← the heart of the product
│   ├── theme_spec.dart                  # the data model a "distro" compiles down to
│   ├── theme_engine.dart                # spec → live widget tree
│   ├── theme_registry.dart              # bundled + downloaded, with fallback
│   └── layout_resolver.dart             # theme defaults ⊕ user overrides
│
├── shells/                              # one shell per desktop metaphor, NOT one per distro
│   ├── gnome_shell.dart                 # top bar + left dock + activities  → Ubuntu, Fedora
│   ├── plasma_shell.dart                # bottom panel + kickoff            → KDE
│   ├── tiling_shell.dart                # bar + workspaces                  → Arch/Hyprland
│   └── tui_shell.dart                   # terminal + command palette        → Terminal, Kali
│
├── features/
│   ├── home/                            # workspaces (pages), dock, widget tiles
│   ├── drawer/                          # Activities grid, search, frequent/all
│   ├── palette/                         # type-to-launch fuzzy matcher — the flagship
│   ├── themes/                          # gallery, previews, download, Pro packs
│   ├── settings/                        # One UI styled; dock position, grid, icon size,
│   │                                    # gestures, + deep-links to system settings
│   ├── folders/
│   ├── gestures/                        # incl. double-tap-left-edge → show dock (preserved)
│   └── ecosystem/                       # G Recovery tiles; later, news feed
│
└── data/
    ├── db/                              # Drift: layout, folders, usage counts
    └── repositories/
```

**Four shells, many themes.** Ubuntu and Fedora are both GNOME — same shell, different `ThemeSpec`. This is what makes "ship a new distro over the CDN without an app update" actually true. If you write a new shell per distro, you have built a maintenance trap.

### 5.3 What a theme *is*

```json
{
  "id": "ubuntu-24-04",
  "name": "Ubuntu",
  "version": "24.04",
  "shell": "gnome",
  "tier": "free",
  "palette": { "bg": "#2C0A22", "accent": "#E95420", "bar": "#1A171B", "dock": "#201B21BD" },
  "typography": { "display": "Ubuntu", "mono": "Ubuntu Mono" },
  "layout": { "dock": "left", "topBar": true, "grid": { "rows": 5, "cols": 4 } },
  "icons": { "treatment": "squircle", "heroPack": "yaru", "tint": null },
  "wallpaper": { "url": "…", "blurhash": "…" },
  "minAppVersion": 20000,
  "signature": "ed25519:…"
}
```

Palette, shell, dock side, icon treatment, wallpaper. That is a distro. **Signed** — CDN content that drives UI is code-adjacent; verify the signature before loading, or a CDN compromise becomes an app compromise.

`layout` is the theme's *default*. User overrides in Settings always win, and are stored per-theme so switching themes doesn't wipe the user's preferences.

### 5.4 Icons — answering "do I draw every icon?"

No.

1. **Generator (automatic, 100% coverage).** Every app's adaptive icon has foreground/background layers; Android 13+ apps also ship a monochrome layer. `IconRenderer` re-masks, re-shapes and re-tints them to the theme. Every app on the device gets themed, including ones you've never heard of.
2. **Hero set (hand-crafted, ~40–60 per theme).** Only the icons that *define* the distro: Files/Nautilus, Terminal, Settings, Software, plus the common third-party ones (Chrome, WhatsApp, Camera, Gallery). These override the generator.

You draw 40–60 icons per theme, not 142. And they ship as an icon-pack over the CDN.

---

## 6. Backend, CDN, admin

```
backend/
├── workers/api/src/
│   ├── index.ts
│   ├── routes/
│   │   ├── entitlement.ts          # POST purchase token → signed entitlement JWT
│   │   ├── config.ts               # remote config + feature flags
│   │   └── content.ts              # signed URLs for paid packs
│   └── play/verifyPurchase.ts      # Play Developer API, service account
│
├── content/                        # git is the source of truth; CI publishes to R2
│   ├── index.json                  # root manifest (signed)
│   ├── themes/ubuntu-24-04/{theme.json, wallpaper.webp, icons/}
│   ├── icon-packs/yaru/
│   ├── oem-guides/{infinix,tecno,xiaomi,samsung,oppo}.json
│   └── backup-guides/{nextcloud-pi,smb-nas,sftp}.md
│
├── schema/                         # JSON Schema — CI fails if content doesn't validate
└── scripts/{sign_manifest.ts, publish.ts}

admin/                              # Next.js. Internal only.
└── app/{themes,icon-packs,guides,flags,releases}/
```

**Ed25519 signing.** Private key in GitHub Actions secrets; public key compiled into both apps. Every manifest is signed at publish time and verified at load time.

**Don't build the license server in Phase 1.** Ship with Play Billing verified locally and content served as static signed JSON from R2. Add the entitlement Worker when piracy or cross-app licensing actually justifies it. A backend you don't need yet is a backend that rots.

---

## 7. Play Store traps that can sink this

These are release-blockers, not details.

1. **Signing key.** You must keep the existing upload key (or Play App Signing). Lose it and you can never update the listing again — a rebuilt-from-scratch app is still an *update*, and Play will reject a mismatched key. Verify you have it **before** writing code.
2. **versionCode must exceed the live one.** Check the Play Console and set the new floor deliberately.
3. **`MANAGE_EXTERNAL_STORAGE` ("All files access")** needs a Play declaration form and strict review. File-manager and backup-and-restore apps are permitted use cases, so G Recovery has a legitimate claim — but *justify it in the form*, and use `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` wherever photo/video access is all you need. Expect this to take a review cycle. Start it early.
4. **Handle partial photo access** (`READ_MEDIA_VISUAL_USER_SELECTED`, Android 14+). Users can grant access to *some* photos. The app must degrade gracefully, not break.
5. **Removing ads changes your declarations.** Update the Ads declaration and the Data safety form when you ship the ad-free build.
6. **Package visibility for the launcher.** `LauncherApps` is the correct API and should not need `QUERY_ALL_PACKAGES`. **Verify this empirically in the Phase 0 spike** — don't discover it at submission.
7. **`NotificationListenerService`** (notification dots) triggers a Play review. Treat dots as optional and ship without them if the review drags.
8. **No "forensics", "spy", or "recover anyone's deleted messages" language** anywhere in the listing. It invites policy scrutiny and it's the positioning you're deliberately escaping.

---

## 8. Build phases

Sizing assumes solo, part-time. Treat as relative weight, not a promise.

### Phase 0 — Spikes. Do not skip. (~1 week)

Prove the two things that could invalidate the plan, *before* building on them.

- **Spike A — Flutter as a launcher.** Blank Flutter app, HOME intent, set as default, install on a real Infinix/Tecno. Measure cold start and home-press latency. Warm the engine in `Application`. **If it feels bad, build the launcher shell natively (Kotlin + Compose) and keep Flutter for G Recovery.** Better to learn this now than after Phase 4.
- **Spike B — What can you actually recover?** On a real budget device: enumerate `MediaStore` trashed items, read the OEM gallery trash, list the WhatsApp media folder. Confirm the recovery pillar is real on the phones your users actually own.
- Confirm you hold the **upload signing key** for both listings.
- Verify launcher package visibility without `QUERY_ALL_PACKAGES`.

**Exit:** you know whether the launcher is Flutter or Kotlin, and exactly what "recovery" honestly means on a Tecno.

### Phase 1 — Foundations (~1–2 weeks)

Workspace + melos + CI. `g_core`, `g_design` (port the mockup tokens: ink/mint, mono-for-data, the chart components), `g_net`. Drift schema. Pigeon plumbing. Both app shells building and installing.

**Exit:** `melos bootstrap && melos run build` produces two installable APKs from one repo.

### Phase 2 — G Recovery v2, the honest core (~3–4 weeks)

Table stakes plus the trust hook. Everything free.

- Home: protection state + **the "what I can reach" manifest** (the differentiator that costs almost nothing to build)
- Recover: wizard + trash aggregation
- Storage: breakdown, large files, unused apps, junk
- Device: device/network/permission passport
- OEM guide via remote config (Infinix, Tecno, Xiaomi, Samsung first)
- Ads removed; Play declarations updated

**Ship it.** Internal → closed → staged rollout to the existing listing. You have 1K+ installs of free feedback; use them.

**Exit:** live on Play, ad-free, no regression in rating.

### Phase 3 — G Recovery differentiators + Pro (~4–5 weeks)

The reasons to pay.

- **Backup to your own server**: SMB / WebDAV / Nextcloud / SFTP, AES-256-GCM, WorkManager, scheduling. Test against Dockerised Samba + Nextcloud in CI.
- Guided "set up a Pi in 15 minutes" flows
- **Swipe-clean** with photo zoom + inline video playback, batched delete request
- Compression: zip + Media3 video re-encode
- Duplicates + similar photos
- Growth chart + fill-up forecast
- **Archive-and-reclaim** (verify-then-free)
- Pro unlock + paywall

**Exit:** Pro is live and someone who isn't you has paid for it.

### Phase 4 — G Launcher core (~4–6 weeks)

- Launcher activity, HOME role, default-launcher prompt
- `AppRepository` + package-change handling
- **Icon engine** (generator + hero overrides + cache) — the hardest piece; budget for it
- `gnome_shell`: top bar, left dock, workspaces, conky tile
- Activities drawer + search
- Settings: dock position, grid, icon size, gestures, system deep-links
- Double-tap-left-edge preserved

**Exit:** you daily-drive it on your own phone for a week without going back.

### Phase 5 — G Launcher themes + store (~3–4 weeks)

- `ThemeSpec` + engine + registry, signature verification
- The other shells: `tui_shell` (**terminal + type-to-launch palette — the flagship**), `plasma_shell`, `tiling_shell`
- Themes gallery with live previews
- CDN pack download + install
- Theme-pack IAPs (Arch/Hyprland, Kali, Pop!_OS as Pro)
- Admin panel: publish a theme without shipping an app update

**Exit:** you add a new distro end-to-end from the admin panel, and it appears on a phone that isn't updated.

### Phase 6 — Ecosystem (~2 weeks)

- Shared account/license across both apps
- Launcher widget tiles surfacing G Recovery status (storage, last backup, network)
- Cross-promotion, done tastefully

### Phase 7 — Later

G Editor (run the same repositioning exercise first — don't build until it has a niche). The news app + its launcher feed. iOS, as genuinely different apps: no launcher exists on iOS (themes/widgets/Shortcuts companion only), and no on-device undelete (photo cleanup + backup-to-your-server + vault).

---

## 9. Critical path

```
Spike A ─┬─→ launcher tech decision ──────────→ Phase 4 → 5 → 6
         │
Spike B ─┴─→ Phase 1 → Phase 2 (SHIP) → Phase 3 (SHIP Pro)
```

G Recovery ships twice before the launcher ships once. That's deliberate: it has the audience, the traffic, and the clearer path to revenue, and it funds the launcher's longer build.

---

## 10. First three actions

1. Confirm you still hold the **upload signing key** for both Play listings. Everything downstream depends on it.
2. Run **Spike A** on a real Infinix or Tecno. The result decides whether the launcher is Flutter or Kotlin.
3. Scaffold the workspace, `g_design`, and the two app shells — then port the mockup tokens into `g_design` so both apps are visually real from day one.
