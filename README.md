# Mindhunter

An Android app ecosystem. Separate apps, shared foundations, one backend — later.

| App        | Package                     | Status                    |
|------------|-----------------------------|---------------------------|
| G Launcher | `com.mindhunter.g_launcher` | **In build** — Phase 0/4  |
| G Recovery | `com.mindhunter.g_recovery` | Next — Phase 2            |
| G Editor   | `com.mindhunter.g_editor`   | Later — Phase 7           |

## How to work in this repo today

**There is no melos workspace, and that is deliberate.** Each app is a plain,
standalone Flutter project. You `cd` in and run it:

    cd apps/g_launcher
    flutter run

`packages/` is empty on purpose. Shared code currently lives *inside* the
launcher, at `lib/core/` and `lib/design/`. Those two folders must never import
anything launcher-specific — that one discipline is what lets them be lifted out
into real shared packages in an afternoon, the day G Recovery starts.

A shared package with one consumer isn't a shared package. It's a folder with
extra ceremony. Melos pays for itself when app #2 exists, not before.

## Read next

| File                            | What it's for                        |
|---------------------------------|--------------------------------------|
| `apps/g_launcher/OVERLAY.md`    | **Start here.** Get the launcher running |
| `docs/architecture.md`          | The decisions, and why                |
| `docs/build-plan.md`            | Full phases, file trees, Play traps   |
| `docs/theme-spec.md`            | The theme contract                    |
