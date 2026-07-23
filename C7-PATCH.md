# C7 patch — wire the flat-path gate into the existing pack route

`flat-check.ts` is new. It needs three lines in your existing
`admin/src/app/api/publish/pack/route.ts`, which is otherwise untouched.

## 1. Import, with the other lib imports at the top

```ts
import { checkThemePackFlat } from '@/lib/flat-check';
```

## 2. The gate

Insert it AFTER the `files.length === 0` check (the "a pack with no payload"
guard) and BEFORE `const live = await readLiveIndex(app)`. At that point every
file is collected and validated for traversal, and nothing has been read off the
bucket yet, so a rejection here costs nothing.

```ts
  // ── C7: a theme pack must be flat ──────────────────────────────────────────
  // PackPaths.installedFile resolves a downloaded asset as
  // packs/<packId>/<filename> and refuses any filename with a slash. So a
  // theme.json pointing at wallpapers/x.webp or assets/themes/… resolves
  // against nothing once downloaded and the theme silently falls back to
  // Ubuntu. Refuse it here, where the fix is one message instead of a support
  // thread. Only themes; brand and hero packs are already flat by construction.
  if (packType === 'theme') {
    const flat = checkThemePackFlat(files);
    if (!flat.ok) {
      return NextResponse.json(
        {
          error:
            'theme.json references assets a downloaded pack cannot resolve. A ' +
            'downloaded pack is one flat directory, so every asset must be a ' +
            'bare filename: ' +
            flat.problems.map((p) => `"${p.ref}" should be "${p.flat}"`).join('; ') +
            '. Flatten the files and the theme.json together.',
        },
        { status: 400 },
      );
    }
  }
```

## Why this is the whole of C7's panel half

The earlier plan said "PackInfo returns an install path, and asset resolution
goes through it". Reading `PackApi_g.kt` and `PackPaths.kt` shows that was wrong
in two ways:

- `PackInfo` deliberately omits any path. Its doc comment: a screen that knows
  the CDN path is one that could be tempted to fetch it, so it ships the
  presentation subset only. The panel neither has nor needs a device path.
- The launcher already resolves downloaded assets through
  `PackPaths.installedFile`, flatly. There is no launcher change waiting on the
  panel. The only gap was the panel letting an unresolvable theme through, and
  this closes it.

So C7 is done once this patch lands. No launcher work, no PackInfo change.
