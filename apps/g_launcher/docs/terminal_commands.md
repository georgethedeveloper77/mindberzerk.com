# The terminal command layer

Companion to `docs/theme_authoring.md`. Same job: the checklists that stop a
field being added in seven of eight places.

## 1. Two surfaces, one table

There are two terminals and they have different jobs.

**The TUI shell** (`lib/shells/tui_shell.dart`) is a launcher. Type two letters,
press enter, an app opens. Output is a live desklet in a persisted pane, which
is why it has no scrollback and should not get one: a desklet is already live
and already persisted, and the pane renderer is the one the graphical desktops
use.

**The Terminal app** is a terminal. It is a `DrawerItem` like Settings, so it
appears on gnome, plasma, tiling and aqua distros, none of which run the TUI
shell. Kali is `shell: gnome`. Without that entry a Kali user has no terminal.

A command belongs to the launcher, not to either screen. `settings` means the
same thing typed at either prompt, so the table lives once in
`lib/features/terminal/command_registry.dart` and each surface asks for its own
slice through `CommandSurface`. Dispatch stays per surface, because pushing a
route and writing a desklet are things only the TUI shell can do.

This is the argument `drawer_items.dart` already makes for
`launcherSettingsAliases`, kept as data beside the items so the terminal's table
and the drawer search agree on the vocabulary. One more surface, same
conclusion.

## 2. The table holds what runs today

Not what is planned. A command that autocompletes and then does nothing is worse
than a command that is absent, because from the outside the two look identical
and only one of them is a bug you can report.

`ps` is the precedent, and it predates the registry: Android does not expose
other processes to a sandboxed app, so rather than print a fabricated list the
command does not exist and `top` stands in for it. Commands land in the table
when their backend lands.

## 3. Why Dart and not JSON

Themes are data because a palette needs no code, which is the whole reason a new
distro ships over the CDN without a Play release. A command is the opposite:
every one needs a handler, so a CDN could never add one. A JSON registry buys
nothing and costs a drift surface between the table and the switch that
dispatches it.

Theme **aliases** are still data, correctly. An alias binds a name to a
`CommandAction` that already exists, which a pack author can do without new
code. `CommandAction.id` is the wire name for that binding, which is why
renaming an id orphans every pack that used it and renaming the enum constant
costs nothing.

## 4. Checklists

### Adding a command, FIVE places

1. `TerminalRegistry.all` in `command_registry.dart`. Position matters:
   `matching` walks this list, so declaration order is row order on screen.
2. A `CommandAction`, if it does something no existing action covers. Adding one
   breaks the switch in `TerminalCommands.run` until handled, which is the
   point.
3. `TerminalCommands.run`, to dispatch the new action on the TUI shell.
4. The Terminal app's dispatcher, when it exists, or set `surfaces` so the
   command does not claim a surface that cannot run it.
5. `test/features/terminal/command_registry_test.dart`. The integrity tests
   catch a duplicate name and a spawn kind the theme schema does not enumerate,
   but a new command's own behaviour needs its own case.

### Adding a spawn command, TWO extra places

6. The kind must exist in the desklet layer.
7. The kind must be in `kindId` in `schema/theme.schema.json`, or the desklet is
   placeable by command and invisible in the picker. There is a test for this,
   and it holds a transcribed copy of that enum: update both.

### Changing a description

The match list collapses rows by description, so two commands describing
themselves identically render as one row. Today that is `df` and `du`, both
"Storage, live", and there is a test asserting it. Give `du` its own wording and
that test fails, which is deliberate: the change is then a decision rather than
a side effect on the flagship screen.

## 5. Not yet done

**i18n.** Descriptions are English literals. The key would be
`terminal.cmd.<name>.summary`, but wiring it needs the miss behaviour of
`Translations.t` confirmed first. A lookup that returns the key on a miss would
put `terminal.cmd.free.summary` on the flagship screen in every language that
has not been translated.

**The hint line.** `TerminalRegistry.hintLine` exists and `tui_shell.dart` still
holds its own string literal. Replace the literal in `_Hint` and add the import.
The two had already drifted by one command, which is why the line moved into the
table.

**Entitlement.** `CommandTier` is presentation only, exactly like
`ThemeSpec.tier`. Real entitlement stays where `entitlements.dart` says it
stays: once, natively, in `CdnIndex.isUnlocked`. When `terminal_pro` ships it is
a sku attached in the signed index like any other, and no Dart code derives what
it unlocks.
