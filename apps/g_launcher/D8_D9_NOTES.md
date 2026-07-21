# D8 and D9 — closing them out as deferred

Phase D ends here. D8 and D9 are blocked, not skipped, and this records what
each is blocked ON so neither turns into a rediscovery exercise later.

---

## D9 — third-party AppWidgetHost

**Shipped in this zip:** the `WidgetHost.kt` stub, rewritten to carry the full
reasoning and the id-leak trap. Nothing is implemented.

The trap, because it is the expensive one:

> Every `allocateAppWidgetId()` not matched by a `deleteAppWidgetId()` leaks a
> permanent host id, and on several OEM skins those survive an app data clear.

Three paths allocate and all three must delete: removal, a cancelled BIND
dialog, and a cancelled CONFIGURE activity. The last two are the ones that get
missed, because nothing appeared on screen so there is nothing visible to clean
up.

**Persistence is nearly free when it arrives.** `Desklet.config` is a free-form
map, so a hosted widget is a desklet kind whose config holds its `appWidgetId`.
It inherits placement, resize, removal and the per-workspace grid with no new
storage. That is a second reason desklets went first, beyond the three in the
stub.

---

## D8 — ecosystem tiles

**Deliberately not built.** The kinds are trivial; the data source is the hard
part, and building the tile first means designing the interface twice. It would
also ship a desklet whose only reachable state today is "G Recovery not
installed", which is an advert for an unreleased app sitting on the user's
desktop. Worse than no tile.

### The one decision that belongs BEFORE G Recovery, not after

How one app in this ecosystem reads another's data shapes G Recovery's own
architecture. Deciding it afterwards means retrofitting.

| option | verdict |
|---|---|
| **ContentProvider, signature permission** | **recommended** |
| FileProvider + grants | awkward; grants are per-URI and per-session |
| Broadcast | push model; needs the other app running |
| AppWidget (D9) | the thing D9 exists to avoid |
| Shared userId | deprecated, breaks signing. No. |

**ContentProvider with `android:protectionLevel="signature"`.** Both apps carry
the same signing key, so no other app on the device can read it, there is no
user-facing permission prompt, and a read is a cheap cursor rather than a
running service.

Needs a scoped package-visibility entry on the launcher side:

```xml
<queries>
  <package android:name="com.mindhunter.g_recovery" />
</queries>
```

Scoped, like the existing `LAUNCHER` intent query. **Not** `QUERY_ALL_PACKAGES`
— the §7.6 rule holds.

### The constraint that matters most

**The provider exposes AGGREGATES ONLY.** Bytes free, last-backup timestamp,
whether the backup target is reachable, a count. Never a file list, never paths,
never what was backed up.

This ecosystem's entire pitch for G Recovery is that it is a data guardian and
that backups go to the user's own server. A launcher desklet has no business
holding file-level detail, and the moment the provider CAN return it, some
future tile will. Design the surface so the answer is impossible rather than
merely discouraged.

### Three states, not two

The tile needs to distinguish:

1. **not installed** — render nothing at all. Do not advertise.
2. **installed, never run** — "open G Recovery to set up"
3. **live** — the numbers

State 1 rendering nothing is the important one, and it is why this cannot ship
before G Recovery does: today every device is in state 1.

### When it unblocks

Phase E–G build G Recovery. D8 becomes: a `ContentProvider` there, a resolver
here, two desklet kinds, and the eight-step add-a-kind checklist in
`docs/theme_authoring.md`. No widget host, no PlatformView, no new storage.

The news feed (Phase H) is the same shape with a different authority.

---

## Phase D, as built

| item | state |
|---|---|
| D1 native stats + capability probe | done, debug screen ships |
| D2 desklet schema + pure engine | done, 50 tests |
| D3 clock across five shells | done |
| D4 edit mode + picker | done |
| D5 the free desklet set | done, replaces `conky_tile.dart` |
| D6 terminal command desklets | done, needs the tui_shell wiring |
| D7 schema contract | done, validator green on all six |
| D8 ecosystem tiles | blocked on G Recovery existing |
| D9 AppWidgetHost | deferred by choice, stub documents it |

Out-of-band, found along the way and fixed: the `clearing()` drop of
`drawerScrollStyle`, the `folderOrderCustom` hashCode asymmetry, and settings
being undiscoverable across three separate search surfaces.

Next thread is **T1, distro perfection**, which is now worth starting because
the desktop finally has something on it.
