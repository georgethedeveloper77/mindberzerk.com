# Admin panel and public site, architecture

One Next.js application on Firebase App Hosting serves two audiences from one
origin: `mindberzerk.com` for anyone, and the console behind a UID allowlist.

Everything below is Mermaid inside markdown, on purpose. It renders on GitHub,
it shows up in a diff when it changes, and there is no exported image to go
quietly out of date.

Read the three in order. The first says what the code is, the second says what
it runs on, the third says what moves between them.

---

## 1. Component architecture

What lives where, after the `lib/` reorganisation.

```mermaid
graph TD
    subgraph routes["Routes, admin/src/app"]
        PUB["(public)/<br/>the landing at /"]
        SIGNIN["admin/<br/>sign in"]
        DASH["dashboard/<br/>studio overview"]
        SLEGAL["legal/studio/<br/>studio terms and privacy"]
        SITE["site/<br/>site content editor"]
        APPS["apps/[app]/<br/>distros, icons, packs,<br/>commerce, bundles, config,<br/>analytics, legal, registry"]
        API["api/<br/>contact, auth/session,<br/>config, publish/*"]
    end

    subgraph shells["Two frames, transitional"]
        SOFT["components/studio/shell<br/>soft, light and dark"]
        DARK["app/components/shell<br/>console, dark only"]
    end

    subgraph libs["Libraries, admin/src/lib"]
        CORE["core/<br/>r2, sign, auth, registry,<br/>catalogue, publish-core,<br/>listing, orphans, play,<br/>commerce, skus, analytics"]
        STUDIO["studio/<br/>site-content, site-public,<br/>site-traffic, site-apps,<br/>legal, legal-schema"]
        GL["g-launcher/<br/>theme-spec, themes,<br/>distro-publish, icon-pack,<br/>hero-pack, bulk-icons,<br/>flat-check, app-registry"]
        GR["g-recovery/<br/>empty, waiting"]
    end

    PROXY["proxy.ts<br/>redirect only, not a gate"]

    PROXY -.->|"no cookie, not public"| SIGNIN
    PUB --> SOFT
    DASH --> SOFT
    SLEGAL --> DARK
    SITE --> DARK
    APPS --> DARK

    PUB --> STUDIO
    DASH --> STUDIO
    DASH --> CORE
    SLEGAL --> STUDIO
    SITE --> STUDIO
    APPS --> GL
    APPS --> CORE
    API --> CORE
    API --> STUDIO

    STUDIO --> CORE
    GL --> CORE
    GR -.-> CORE

    classDef empty stroke-dasharray: 5 5;
    class GR empty;
```

**The one rule the folders encode.** Arrows point down: `g-launcher` and
`studio` may use `core`, and `core` may use neither. The day `core` imports
something out of `g-launcher`, the split has stopped meaning anything, and
G Recovery starts inheriting launcher concepts it does not have.

**The two shells are a to-do, not a design.** The dashboard is soft and
everything else is the dark console, so clicking into an app crosses a visible
seam. The restyle closes it by making `--color-surface-*` and `--color-ink*`
mode-aware in `globals.css`, which converts every screen without editing a
screen file, after which one of these two files is deleted.

**`proxy.ts` is a redirect, never a boundary.** It runs on the Edge runtime,
which cannot run firebase-admin, so it can see whether a cookie exists and
nothing more. Every route and server component that touches the signing key,
R2, or anything non-public calls `requireAdmin()` itself.

---

## 2. Infrastructure

What runs where, and which secret unlocks it.

```mermaid
graph LR
    subgraph google["Google Cloud, project mindberzerk-3eaf5"]
        AH["App Hosting<br/>Cloud Run<br/>mindberzerk.com"]
        SM["Secret Manager"]
        FA["Firebase Auth<br/>Google sign-in"]
        RC["Remote Config<br/>cdn_base_url"]
        GA["GA4 property<br/>G-8RHHEN2X07"]
        BQ["BigQuery export<br/>not enabled"]
    end

    subgraph cf["Cloudflare"]
        R2["R2 bucket<br/>mindberzerk-cdn"]
        CDN["cdn.mindberzerk.com"]
    end

    subgraph external["Outside"]
        PLAY["Google Play<br/>billing and Console API"]
        ASC["App Store Connect"]
        PLESK["Plesk SMTP<br/>info@mindberzerk.com"]
        DEV["Devices<br/>G Launcher"]
    end

    BROWSER["A visitor"] --> AH
    ADMIN["George"] --> AH

    AH -->|"read at build and request"| SM
    AH -->|"verify session"| FA
    AH -->|"S3 API, currently rejected"| R2
    AH -->|"read published JSON"| CDN
    AH -->|"Data API, property id not set"| GA
    AH -->|"SMTP 465, secrets not set"| PLESK
    AH -->|"Play API, 403"| PLAY
    AH -->|"publish key"| RC

    R2 --> CDN
    CDN -->|"index.json, packs, legal html"| DEV
    DEV -->|"purchases"| PLAY
    GA -.->|"daily export"| BQ
    BQ -.->|"launcher funnels"| AH

    ADMIN -.->|"links out from the dashboard"| ASC

    classDef broken stroke:#c0392b,stroke-width:2px;
    classDef off stroke-dasharray: 5 5;
    class R2,PLAY broken;
    class BQ,ASC off;
```

**Secrets, and what each one costs if it leaks.** `pack-signing-key` is the
ed25519 private half whose public counterpart is compiled into every shipped
APK; if it reaches a browser, every signature in the ecosystem is worthless and
the fix is a Play release plus a key rotation on every device. `admin-uids` is
an allowlist rather than a role check, and a credential rather than a setting,
because this panel can write to the CDN every installed launcher trusts. None
of them carries a `NEXT_PUBLIC_` prefix, which is the single mistake that would
make the whole scheme decorative.

**Currently broken, marked red.** R2's S3 token is rejected on every probe,
which blocks the panel but not publishing, since `wrangler` uses account OAuth
on a different auth path. The Play Console API returns 403 until the service
account invite is accepted.

**Not switched on, marked dashed.** The BigQuery export, which is what
`lib/core/analytics.ts` needs for launcher funnels and retention. App Store
Connect is a link target only; nothing reads it.

---

## 3. Data flow

Four flows, because they have genuinely different shapes and different
consequences when they fail.

### 3a. Publishing a pack, the signed path

The only flow a phone verifies.

```mermaid
sequenceDiagram
    actor A as George
    participant P as Panel
    participant S as core/sign
    participant R as R2
    participant C as CDN
    participant D as Device

    A->>P: pick a folder or zip, fill metadata
    P->>P: flat-check, version must increase
    P->>S: signPack, manifest over exact bytes
    S-->>P: manifest.json plus manifest.sig
    P->>R: upload payload, manifest, signature
    P->>R: read live index.json
    P->>S: signIndex, generatedAt must increase
    S-->>P: index.json plus index.sig
    P->>R: write both
    R->>C: served at cdn.mindberzerk.com
    D->>C: fetch index.json and index.sig
    D->>D: verify ed25519 against PackKeys.ACCEPTED_HEX
    D->>C: fetch the pack
    D->>D: verify manifest, then install
```

**The invariants that bite.** The signature covers the exact serialised bytes,
so a manifest that is parsed, modified and re-stringified verifies in the editor
and fails with BadSignature on every device. `generatedAt` must exceed what is
live, which is what stops a stale edge or a replay hiding an update forever. A
`theme.json` whose `id` differs from its `packId` inherits the bundled theme's
preferences bucket and silently fails to apply its wallpaper.

### 3b. Site content, the unsigned path

No device reads this, so nothing is signed.

```mermaid
sequenceDiagram
    actor A as George
    participant E as /site editor
    participant W as studio/site-content
    participant R as R2
    participant C as CDN
    participant L as The landing at /
    actor V as A visitor

    A->>E: hero copy, featured order, stats
    E->>W: POST /api/publish/site
    W->>W: featured ids must be real registry apps
    W->>R: whole-file write, site/content.json
    R->>C: served
    V->>L: GET /
    L->>C: fetch site/content.json
    L->>C: fetch cdn/index.json for the auto stat
    C-->>L: both, or neither
    L-->>V: rendered, seed content if either read failed
```

**Why the landing reads the CDN rather than R2.** The panel writes with S3
credentials that are currently rejected. A public page must render anyway, and
should be cacheable at the edge, so it reads the same document over the public
CDN with no credential involved. One writer, two readers, two audiences.

### 3c. Legal documents, markdown in and HTML out

```mermaid
graph LR
    ED["Editor<br/>markdown in a textarea"] --> VAL["legal-schema/validate<br/>same function both sides"]
    VAL --> API["api/publish/legal<br/>isLegalId gate"]
    API --> W["studio/legal/writeLegal"]
    W --> MD["core/markdown<br/>escapes everything first"]
    MD --> TPL["page template<br/>Ubuntu faces, print stylesheet"]
    TPL --> H1["privacy.html"]
    TPL --> H2["terms.html"]
    W --> SRC["the json source"]
    H1 --> R2["R2, then CDN"]
    H2 --> R2
    SRC --> R2
    R2 --> REV["A Play reviewer<br/>and a person deciding<br/>whether to trust you"]
```

**Source is written last, deliberately.** If the HTML writes fail halfway, the
stored source still describes what is live rather than what was intended, and
pressing publish again is a clean retry.

**Four ids, one pipeline.** `studio`, `g-launcher`, `g-recovery` and any future
app render through the same template. `studio` is reserved rather than an app,
so `APPS` stays a closed tuple and nothing else starts treating the studio as
something with a bucket prefix.

### 3d. Contact, the one write that leaves the estate

```mermaid
graph LR
    V["Visitor fills the form"] --> H{"honeypot filled?"}
    H -->|yes| OK200["200, nothing sent"]
    H -->|no| RL{"rate limit,<br/>5 per 10 minutes"}
    RL -->|over| R429["429"]
    RL -->|under| CFG{"all five<br/>SMTP secrets set?"}
    CFG -->|no| R503["503, form falls back<br/>to a mailto link"]
    CFG -->|yes| SMTP["Plesk SMTP, port 465<br/>from the authenticated mailbox,<br/>replyTo the visitor"]
    SMTP --> INBOX["info@mindberzerk.com"]
```

**Degrades rather than breaks.** A missing secret must not read as a user
error, so an unconfigured route answers 503 and the section keeps working
through a mailto link. Cloud Run permits outbound 465 and 587; only port 25 is
blocked, and nothing here uses it.

---

## Keeping this honest

A diagram that has drifted is worse than no diagram, because it is trusted.
Three habits keep it true:

- When a `lib/` file changes bucket, edit section 1 in the same commit.
- When a secret or a service is added, edit section 2 in the same commit.
- When a flow gains a step that can fail, edit section 3, and say what the
  failure looks like rather than only that it can happen.

Per-app documents live beside this one as `docs/<app>/architecture.md`, with the
same three sections. The launcher's will differ most in section 3, where the
interesting flows are on-device rather than in a browser: pack verification,
the icon cache fingerprint, and the preference buckets a theme resolves through.
