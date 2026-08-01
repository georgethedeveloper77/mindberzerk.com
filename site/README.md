# mindberzerk.com

The public studio site. Next.js on Firebase App Hosting, same stack as `admin/`,
but a separate app: it never touches R2 credentials, the signing key, or any
publish route. It reads two public CDN objects and relays one email.

## What renders from where

- Hero copy, the featured order, and the stats row come from
  `https://cdn.mindberzerk.com/site/content.json`, published by the panel's
  Site content screen. Fetches revalidate every 5 minutes, so a publish shows
  up without a deploy. When the object is missing or unreachable the seed
  renders, mirroring the panel's own fallback.
- App names, blurbs, marks, tints and states come from `src/lib/registry.ts`,
  a VERBATIM copy of `admin/src/lib/registry.ts`. Edit the two together and
  keep them byte-identical; `diff` between them should always be empty. Adding
  an app to the site is a registry row plus, if featured, one id in the panel's
  Site content screen.
- The stat whose value is the literal `auto` becomes the count of `theme` packs
  in the live index at `${CDN_BASE_URL}/cdn/index.json`. If that is not where
  the index lives on the bucket, set `SITE_INDEX_URL` rather than editing code.
  When the index cannot be read, the row is dropped, never a placeholder.

## Contact form

`/api/contact` relays over the studio's Plesk SMTP. Create these five secrets in
Secret Manager and grant the App Hosting service account access:

| Secret | Example |
| --- | --- |
| `SITE_SMTP_HOST` | `mail.mindberzerk.com` |
| `SITE_SMTP_PORT` | `465` |
| `SITE_SMTP_USER` | `info@mindberzerk.com` |
| `SITE_SMTP_PASS` | the mailbox password |
| `SITE_CONTACT_TO` | `info@mindberzerk.com` |

Until they exist the route answers 503 and the form shows a mailto fallback to
`NEXT_PUBLIC_CONTACT_EMAIL`, so the section works on day one. Cloud Run permits
outbound 465 and 587; only port 25 is blocked, and nothing here uses it.

## Analytics

Set `NEXT_PUBLIC_GA_MEASUREMENT_ID` to a GA4 id and the gtag script renders;
leave it unset and no analytics code exists on the page at all. This is the
data source the admin dashboard's visitor panels will read once that phase
lands.

## Known caveats, deliberate

- The catalogue lists the seven registry apps, by decision. The other store
  apps join as registry rows when the registry grows.
- `tryst` and `fructa` carry internal placeholder blurbs in the registry
  ("Separate Firebase project. Listed here, administered elsewhere.") and the
  site renders blurbs verbatim. Edit those two blurb strings in
  `admin/src/lib/registry.ts` to public copy, mirror the file here, and the
  cards fix themselves.
- Footer legal links are absent until the studio legal phase publishes the
  documents; a link to a page that does not exist yet helps nobody.
- Store badges are drawn SVG, not the official bitmap assets, keeping the
  no-uploaded-images rule. Swap the two glyph components in
  `src/components/chrome.tsx` if brand-exact badges are ever required.

## Local

```
npm install
npm run dev
```

`npm run typecheck` runs the same `tsc --noEmit` gate the deliverable was
checked with.
