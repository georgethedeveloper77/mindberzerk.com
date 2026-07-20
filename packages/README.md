# packages — EMPTY ON PURPOSE

Nothing lives here yet, and that's the plan.

Shared code currently sits inside the launcher:

    apps/g_launcher/lib/core/     ->  becomes packages/g_core/
    apps/g_launcher/lib/design/   ->  becomes packages/g_design/

## The lift (do this the day G Recovery starts)

1. Add `melos.yaml` + a workspace root `pubspec.yaml`.
2. `git mv apps/g_launcher/lib/core packages/g_core/lib`
3. `git mv apps/g_launcher/lib/design packages/g_design/lib`
4. Path-depend both apps on them. Fix imports.
5. `melos bootstrap`.

An afternoon — **if and only if** those folders never imported anything
launcher-specific. That is the whole reason for the rule.

Later arrivals: `g_net`, `g_account`, `g_content`, `g_media`.
