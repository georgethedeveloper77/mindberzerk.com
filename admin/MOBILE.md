# The admin panel as a mobile dashboard

```bash
cd admin
npm i fflate
rm -f src/app/components/sign-out.tsx   # the Shell owns sign-out now
npm run dev
```

Then open it on your phone at the Network address the dev server prints.

## The constraint that shaped everything

**`webkitdirectory` does not work on mobile browsers.** Not on iOS Safari, not
on Android Chrome. It does not error either — the picker just offers individual
files and the directory tree is silently lost. For a pack that is fatal: the
relative paths ARE part of the signed manifest, and the device resolves
`wallpapers/bg.webp` by exactly that string.

So there are two input shapes, and the mode is chosen by **feature detection**,
not a user-agent sniff:

| Mode | Where | How |
|---|---|---|
| Folder | desktop | `webkitdirectory`, one file per path |
| Zip | everywhere | one archive, unpacked server-side with `fflate` |

Both converge on the same `files` array before anything is signed, so there is
one validation path and one signing path regardless of how the bytes arrived.

The zip handler strips a single wrapping folder, because right-clicking a folder
on macOS produces one and typing `zip -r` from inside the folder does not. It
also drops `__MACOSX/` and `.DS_Store`, which would otherwise land in the signed
manifest and be downloaded by every device forever.

`pack.meta.json` is stripped from both paths. It is publishing metadata that
`publish-all.mjs` reads; the panel takes the same values from the form fields.

## Mobile details that only show up on a real device

- **`viewportFit: 'cover'` plus `env(safe-area-inset-bottom)`.** Without both,
  the bottom nav sits under the iPhone home indicator and the primary navigation
  is partly untappable.
- **`text-base` on inputs, not `text-sm`.** iOS Safari zooms the whole page when
  focusing an input under 16px, and it never zooms back out. Desktop gets
  `sm:text-sm`.
- **`inputMode="numeric"`** on version fields, so the number pad appears instead
  of QWERTY.
- **Sticky submit.** The form is taller than a phone screen, and a publish button
  you have to scroll to find is one people stop trusting.
- **`min-h-[100dvh]`, not `100vh`.** `vh` on mobile Safari includes the address
  bar that is about to collapse.

## Layout

Bottom nav below `md`, left rail above it. Same links, same component — a top
bar on a phone puts every tap at the far end of the thumb's reach, and a bottom
bar on a laptop is a phone app in a browser.

The pack list is **cards on mobile, table on desktop**. A five-column table at
390px either scrolls sideways, where nobody finds the last column, or truncates
the pack id, which is the one thing you need to read.

Publishing moved to `/publish` rather than sitting under the list. On a phone
they cannot share a screen without one becoming a scroll-past, and it keeps the
list a fast read-only view you can open to check something.

## Not built yet

`/bundles` is in the nav and has no page. That is the next one: editing the
`entitlements` block, which is currently only editable by hand in
`backend/content/g-launcher/entitlements.json`.
