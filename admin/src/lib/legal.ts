import 'server-only';

import { getObject, putObject } from './r2';
import { esc, renderMarkdown } from './markdown';
import { validate, type DocKind, type LegalDoc } from './legal-schema';
import { appMeta, isAppId, type AppId } from './registry';

/**
 * PHASE C13 — the per-app legal pages, as markdown this panel writes.
 *
 * ## Why these are NOT part of site-content.ts
 *
 * `site/content.json` is the PUBLISHER's homepage: a hero, a stat strip, and an
 * ordered set of registry ids. One document for the whole portfolio, and it
 * deliberately stores no prose about any individual app because the registry
 * already holds that.
 *
 * A privacy policy is the opposite shape. It is per app and it is specific:
 * G Launcher's names SET_WALLPAPER, an accessibility service and three analytics
 * events; G Recovery's will name storage access and a home server it uploads to.
 * Folding them into one document would mean one of the two is wrong, and being
 * wrong in a privacy policy is a different class of mistake from being wrong in
 * a marketing headline.
 *
 * Same track as site content otherwise: unsigned, whole-file writes, no index,
 * no `generatedAt`. A phone never reads these; Google and a person do.
 *
 * ## Markdown in, HTML out
 *
 * The editor holds MARKDOWN and publish renders it into a fixed template. Three
 * reasons, in order of how badly each would have hurt:
 *
 *  1. A textarea containing raw HTML is one paste away from serving broken or
 *     hostile markup at a public URL that Google has on file. The renderer
 *     escapes everything before it does anything else, so the worst a bad edit
 *     can produce is ugly text.
 *  2. The chrome stays identical across apps and across edits. G Recovery's
 *     policy will look like G Launcher's because neither of them owns its
 *     layout.
 *  3. A legal page is read once, under duress, by someone deciding whether to
 *     trust you. Headings, lists and one callout is the whole vocabulary it
 *     needs, and a full markdown library would be a dependency carrying a parser
 *     far larger than the subset in use.
 *
 * ## Three objects per app
 *
 *   site/legal/<app>.json          the SOURCE. What the editor reads.
 *   site/legal/<app>/privacy.html  rendered. What Play checks.
 *   site/legal/<app>/terms.html    rendered.
 *
 * The HTML is generated, never edited, and is overwritten wholesale on every
 * publish. Editing it in the bucket would be lost on the next save, which is why
 * there is no path in this panel that offers to.
 */

export { validate, type DocKind, type LegalDoc, type LegalDraft } from './legal-schema';

/**
 * ── THE RESERVED STUDIO ID ───────────────────────────────────────────────
 *
 * mindberzerk.com needs its own terms and privacy, separate from every app's.
 * The site collects things no app does (a contact form, web analytics) and
 * collects nothing an app does, so folding it into one of theirs would make
 * that one wrong, which is the same argument that split these documents from
 * `site/content.json` in the first place.
 *
 * TWO WAYS TO DO IT, and this is the cheaper one by a wide margin. A separate
 * module beside `site-content.ts` would duplicate the reader, the writer, the
 * validator, the markdown renderer and the entire HTML template, and the second
 * copy of a template drifts from the first the first time one is edited.
 * Reserving an id instead means the studio's documents are rendered by the same
 * `page()` that renders G Launcher's, published to the same layout, and served
 * from the same place. One pipeline, one more caller.
 *
 * `studio` cannot collide with a route segment: `APPS` is a closed tuple and
 * `isAppId` refuses anything outside it, so no app can ever be given this id.
 */
export type LegalId = AppId | 'studio';

export const STUDIO_ID = 'studio' as const;

/** Every id that has a legal document, studio first. */
export const LEGAL_IDS: LegalId[] = [STUDIO_ID, 'g-launcher', 'g-recovery'];

export function isLegalId(value: string): value is LegalId {
  return value === STUDIO_ID || isAppId(value);
}

/** Display name for any legal id. The studio is not in the app registry. */
export function legalName(id: LegalId): string {
  if (id === STUDIO_ID) return 'Mindberzerk';
  return appMeta(id)?.name ?? id;
}

const sourceKey = (app: LegalId) => `site/legal/${app}.json`;
const pageKey = (app: LegalId, doc: DocKind) => `site/legal/${app}/${doc}.html`;

export interface LegalState {
  doc: LegalDoc;
  exists: boolean;
  /** Present but unparseable. Refuse to overwrite, same rule as the index. */
  corrupt: boolean;
  /** Why the bucket could not be read. Distinct from `exists: false`. */
  unreachable?: string;
}

// ─── the page ────────────────────────────────────────────────────────────────

/**
 * The shell every legal page renders into.
 *
 * Ubuntu and Ubuntu Mono, which is the one deliberate choice here: they are the
 * faces the product itself ships, so the page reads as the same thing as the app
 * rather than a generic legal template someone bought. Everything else is
 * restraint on purpose — this is read by a Play reviewer and by somebody
 * deciding whether to trust a launcher, and both want to find one section fast.
 *
 * Includes a print stylesheet. People do print these.
 */
function page(opts: {
  title: string;
  appName: string;
  pkg: string;
  updatedAt: number;
  body: string;
  otherHref: string;
  otherLabel: string;
}): string {
  const date = new Date(opts.updatedAt * 1000).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(opts.title)} — ${esc(opts.appName)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Ubuntu:wght@300;400;500;700&family=Ubuntu+Mono:wght@400;700&display=swap" rel="stylesheet">
<style>
  :root{--bg:#0b0d10;--surface:#14171c;--line:#232830;--ink:#e8eaed;--ink-2:#a8aeb8;--ink-3:#6e7681;--accent:#e95420}
  *{box-sizing:border-box}
  html{-webkit-text-size-adjust:100%}
  body{margin:0;background:var(--bg);color:var(--ink-2);font-family:Ubuntu,system-ui,sans-serif;font-weight:300;font-size:16px;line-height:1.65}
  .wrap{max-width:46rem;margin:0 auto;padding:4rem 1.5rem 6rem}
  header{border-bottom:1px solid var(--line);padding-bottom:2rem;margin-bottom:2.5rem}
  .eyebrow{font-family:"Ubuntu Mono",ui-monospace,monospace;font-size:.8125rem;letter-spacing:.08em;text-transform:uppercase;color:var(--accent);margin:0 0 .75rem}
  h1{font-size:clamp(2rem,6vw,2.75rem);line-height:1.1;font-weight:400;color:var(--ink);margin:0 0 .75rem;letter-spacing:-.02em}
  .meta{font-family:"Ubuntu Mono",monospace;font-size:.8125rem;color:var(--ink-3);margin:0}
  h2{font-size:1.25rem;font-weight:500;color:var(--ink);margin:2.5rem 0 .75rem;letter-spacing:-.01em}
  h3{font-size:1rem;font-weight:500;color:var(--ink);margin:1.75rem 0 .375rem}
  h2+p,h2+ul,h2+.listing,h2+.callout,h3+p,h3+ul{margin-top:0}
  p{margin:0 0 1rem}
  a{color:var(--accent);text-decoration-thickness:1px;text-underline-offset:2px}
  strong{color:var(--ink);font-weight:500}
  code{font-family:"Ubuntu Mono",monospace;font-size:.9em;color:var(--ink)}
  ul{margin:0 0 1rem;padding-left:1.25rem}
  li{margin-bottom:.5rem}
  .callout{background:var(--surface);border:1px solid var(--line);border-left:2px solid var(--accent);border-radius:6px;padding:1.25rem 1.5rem;margin:1.25rem 0}
  .callout p{margin:0}
  .listing{background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:1.25rem;margin:0 0 1rem;font-family:"Ubuntu Mono",ui-monospace,monospace;font-size:.875rem;line-height:1.5;overflow-x:auto}
  .listing .row{display:block;margin-bottom:1rem}
  .listing .row:last-child{margin-bottom:0}
  .listing b{display:block;color:var(--accent);font-weight:700;white-space:nowrap}
  .listing span{display:block;color:var(--ink-3)}
  footer{border-top:1px solid var(--line);margin-top:4rem;padding-top:1.5rem;font-family:"Ubuntu Mono",monospace;font-size:.8125rem;color:var(--ink-3)}
  footer a{color:var(--ink-3)}
  @media print{
    body{background:#fff;color:#000}
    .callout,.listing{background:#fff}
    h1,h2,h3,strong,code{color:#000}
    .eyebrow,.listing b,a{color:#000}
  }
</style>
</head>
<body>
<div class="wrap">
<header>
  <p class="eyebrow">${esc(opts.appName)}</p>
  <h1>${esc(opts.title)}</h1>
  <p class="meta">Last updated: ${esc(date)}${opts.pkg ? ` &nbsp;·&nbsp; ${esc(opts.pkg)}` : ''}</p>
</header>
${opts.body}
<footer>
  <a href="${esc(opts.otherHref)}">${esc(opts.otherLabel)}</a> &nbsp;·&nbsp;
  <a href="https://mindberzerk.com">mindberzerk.com</a>
</footer>
</div>
</body>
</html>
`;
}

// ─── seeds ───────────────────────────────────────────────────────────────────

/**
 * G Launcher's policy, written against its actual manifest.
 *
 * Every permission here appears in `AndroidManifest.xml`, and every event named
 * is one of the three declared in `lib/core/analytics.dart`. That is the point:
 * a policy that can be checked against the source is worth more than one that
 * covers every eventuality in case.
 */
const G_LAUNCHER_PRIVACY = `G Launcher is a home screen replacement for Android, published by Mindberzerk. This policy describes exactly what the app collects, what it sends anywhere, and why it asks for each permission. It is written to be checkable: every permission listed below appears in the app's manifest, and every event listed below is declared in one file in the source.

> There are no adverts, and no data is sold or shared with advertisers. The app does not ask for your location, contacts, messages, call log, camera or microphone. It does not create an account and does not know who you are.

## What stays on your device

Almost everything. The following is written to storage that only G Launcher can read, and is never transmitted:

- Your settings for each distro: grid size, dock position, icon shape, labels, gestures.
- Folders you create in the app drawer, and apps you choose to hide.
- Which wallpaper you picked, and the file path of any photo you chose as one. The photo itself is never copied or uploaded.
- Theme and icon packs you download, and a record of which is applied.
- How often you open each app, used to order the dock and suggestions. This is a count on your device and is never sent anywhere.

Uninstalling the app deletes all of it. Clearing the app's storage in Android Settings does the same without uninstalling.

## What leaves your device

### Anonymous usage events

G Launcher uses Google Firebase Analytics. The app sends three events of its own, and nothing else:

- **setup_home_role** — that you reached the step asking to make G Launcher your home screen, which attempt it was, and whether you granted it.
- **setup_complete** — that you finished first-time setup, and which distro you chose.
- **theme_selected** — that a distro was applied, and which one.

None of these contains your name, your email, your location, or any list of your installed apps. Firebase itself also collects a standard set of information alongside them, which we do not control: a randomly generated app instance identifier, your device model, Android version, and approximate country derived from your IP address. Google's handling of that is covered by the [Google Privacy Policy](https://policies.google.com/privacy).

### Downloading themes and icon packs

When you install a theme or icon pack, the app makes an HTTPS request to **cdn.mindberzerk.com**. Like any web server, it records the request: the file requested, the time, your IP address, and the app's user agent. No account is involved and the request carries nothing identifying you. Downloaded packs are cryptographically signed and verified on your device before anything is loaded from them.

### Purchases

Paid themes and icon packs are sold through Google Play's billing system. Google handles the payment; G Launcher never sees your card details, billing address or Google account. The app receives only the list of product identifiers you own, so it knows which packs to unlock.

## Your installed apps

A launcher has to know which apps are on your phone in order to draw them. G Launcher does **not** request Android's broad \`QUERY_ALL_PACKAGES\` permission. It declares a narrow list of queries instead, which limits what it can see to:

- apps that have a launcher icon, so they can be listed and opened;
- apps that provide home screen widgets;
- apps that provide icon packs in the Nova, ADW, Apex, Tesla, Lawnchair or GO formats, so they can be offered in the icon picker;
- a browser, so links opened from the app can be handed to it.

That list never leaves your device.

## The accessibility service

G Launcher includes an optional accessibility service. It is **off by default** and does nothing unless you turn it on yourself in Android Settings.

Its only purpose is to perform actions you have configured as gestures — for example pulling down the notification shade or locking the screen when you swipe. Android offers no other way for an app to do those things. The service does not read the content of your screen, does not record what you type, and sends nothing anywhere. Turning it off in Android Settings disables it immediately; the gestures bound to it simply stop working.

## Permissions, and what each is for

\`\`\`
INTERNET — Download themes and icon packs, and send the usage events above.
SET_WALLPAPER — Apply a wallpaper when you pick one or when a distro is applied.
RECEIVE_BOOT_COMPLETED — Restart scheduled wallpaper rotation after the phone reboots.
EXPAND_STATUS_BAR — Open the notification shade from a gesture.
VIBRATE — Haptic feedback when you press and hold an icon.
POST_NOTIFICATIONS — Requested only if there is something to show you. Declining changes nothing else.
com.android.vending.BILLING — Purchase paid themes through Google Play.
\`\`\`

There is no permission here for storage, location, contacts, camera, microphone, phone state or SMS, because the app does none of those things.

## Children

G Launcher is not directed at children and does not knowingly collect information from anyone under 13.

## Your choices

- **Delete everything.** Uninstall the app, or clear its storage in Android Settings. All local settings, folders and downloaded packs are removed.
- **Reset the analytics identifier.** This can be reset from Android Settings under Privacy, then Ads.
- **Ask about your data.** Because the app holds nothing that identifies you, there is normally nothing to retrieve or delete on our side. If you believe otherwise, write to the address below and we will answer.

## Changes

If this policy changes, the date at the top changes with it, and the previous version is replaced here. Material changes will also be described in the app's release notes on Google Play.`;

const G_LAUNCHER_TERMS = `These terms cover your use of G Launcher, published by Mindberzerk, and of the themes and icon packs available inside it. Installing or using the app means you accept them. If you do not, uninstall the app.

## The app

G Launcher is free. You may use it on any device you control, for as long as you like. Every feature of the launcher itself is free and always will be: nothing is held back behind a paid tier.

You may not resell the app, redistribute modified copies of it, or remove or work around the signature checks it performs on downloaded content.

## Themes and icon packs

Some themes and icon packs are sold as one-time purchases through Google Play. A purchase grants you a personal, non-transferable licence to use that content inside G Launcher on devices signed in to the Google account that bought it. It does not transfer ownership of the artwork, and it does not grant the right to extract, redistribute or resell it.

Content is delivered over the internet after purchase and is verified on your device before use. Purchases restore automatically when you sign in on a new device; there is also a Restore purchases action in the app's settings.

## Payments and refunds

Purchases are processed by Google Play, not by us. Google's terms apply to the transaction, and refunds are handled under [Google Play's refund policy](https://support.google.com/googleplay/answer/2479637). If something you bought does not work, write to us first — we would rather fix it than have you chase a refund.

These are one-time purchases. There is no subscription and nothing renews.

## Trademarks and third-party names

> G Launcher is not affiliated with, endorsed by, or sponsored by any of the projects whose desktops it imitates.

The app offers themes that resemble well-known Linux desktop environments. Those names and marks belong to their respective owners: Ubuntu and Yaru are trademarks of Canonical Ltd; KDE and Plasma are trademarks of KDE e.V.; GNOME is a trademark of the GNOME Foundation; other distribution and desktop names are trademarks of their respective projects. They are used here only to describe which desktop a theme resembles, which is a factual description and not a claim of association.

Fonts, icons and other assets shipped with the app are used under their own licences, which are listed in the app under Settings, then Licences.

## Icon packs made by other people

G Launcher can read icon packs installed as separate apps, including ones exported from Icon Pack Studio. Those packs are not ours. They are covered by whatever licence their author granted you, we make no representation about them, and support for them is with their author.

## The accessibility service

G Launcher includes an optional accessibility service used solely to perform gestures you configure, such as opening the notification shade or locking the screen. It is off unless you enable it, it reads no screen content, and it sends nothing anywhere. See the [Privacy Policy](./privacy.html) for detail.

## No warranty

The app is provided as it is, without warranty of any kind. A launcher replaces your home screen, and while we test on real devices we cannot promise it behaves identically on every Android version and manufacturer skin. If it does not work on your phone, uninstall it and your previous home screen returns.

## Limitation of liability

To the extent the law allows, Mindberzerk is not liable for indirect or consequential loss arising from your use of the app. Where liability cannot be excluded, it is limited to the amount you paid for the content in question, or nothing where the app was free. Nothing here limits rights you have under consumer law that cannot be waived.

## Changes and ending this agreement

These terms may change; the date at the top changes with them and the previous version is replaced here. You can end this agreement at any time by uninstalling the app. We may suspend access to paid content if it is being redistributed or if the signature checks are being circumvented.`;

/**
 * THE STUDIO'S OWN DOCUMENTS, written against what mindberzerk.com actually
 * does and nothing else.
 *
 * The same checkability rule as G Launcher's policy: every collection named
 * here corresponds to something in the site's source. The site runs one
 * analytics script, has one form, sets no cookies of its own, and has no
 * accounts. A studio policy that hedged about "partners" and "affiliates" would
 * be describing a company that does not exist.
 *
 * These are a STARTING DRAFT, not legal advice. Read them before publishing;
 * the editor refuses to publish until a contact address and a jurisdiction are
 * filled in, which are the two things nobody can guess for you.
 */
const STUDIO_PRIVACY = `This policy covers the website at mindberzerk.com, published by Mindberzerk. It does not cover the apps: each app has its own privacy policy describing what that app collects, linked from its page on this site and from its store listing.

> This site has no accounts, no logins and no advertising. It does not sell or share anything with advertisers. It sets no cookies of its own.

## What the site collects

### Anonymous usage measurement

The site uses Google Analytics to count visits and see which pages people read. This records a randomly generated identifier, the pages you viewed, the site or search that sent you, your device type and browser, and an approximate location derived from your IP address. Google truncates the IP address and does not store it in the reports we see. Google Analytics sets its own cookies to recognise a returning browser within a session. None of it names you, and none of it is combined with anything else.

You can opt out entirely with Google's [browser add-on](https://tools.google.com/dlpage/gaoptout), or with any content blocker, and the site works exactly the same without it.

### The contact form

If you send a message, we receive what you typed: your name, your email address and the body of the message, plus which of the three subjects you picked. It is delivered to our own mailbox over an encrypted connection and is not passed to any third party. Your address is used to reply to you and for nothing else. Messages are kept while the conversation is useful and deleted when it is not.

The form applies a rate limit, which briefly holds your network address in memory to count recent submissions. Nothing about that is written to disk or retained.

### Server logs

Like any web server, ours records requests: the page requested, the time, your IP address and your browser's user agent. These are operational records used to keep the site running and to investigate abuse. They are not used to build a profile of you.

## What the site does not collect

There is no account to create, no newsletter, no tracking pixel from an advertiser, no session replay, no fingerprinting, and no data broker anywhere in this. The site does not ask for your location, and it holds no payment information: everything sold by Mindberzerk is sold through Google Play or the App Store, which handle payment themselves and never pass us your card details.

## Who processes what

- **Google Analytics**, for the usage measurement above, under the [Google Privacy Policy](https://policies.google.com/privacy).
- **Google Cloud**, which hosts the site and holds the server logs.
- **Our own mail server**, which receives contact form messages.

That is the complete list. Nothing else receives anything from this site.

## Your rights

Depending on where you live you may have the right to ask what we hold about you, to have it corrected, to have it deleted, or to object to it being processed. Because this site holds almost nothing that identifies you, the honest answer is usually that there is nothing to retrieve. If you have written to us, we hold that correspondence, and you can ask us to delete it at any time using the address below.

## Children

This site is not directed at children and does not knowingly collect information from anyone under 13.

## Changes

If this policy changes, the date at the top changes with it and the previous version is replaced here.`;

const STUDIO_TERMS = `These terms cover your use of the website at mindberzerk.com, published by Mindberzerk. They do not cover the apps: each app has its own terms, linked from its page here and from its store listing. Using this site means you accept these terms.

## What this site is

A description of the software Mindberzerk publishes, and a way to contact us. Nothing is sold here. Every purchase happens inside Google Play or the App Store, under their terms, and the links here simply take you to those listings.

## Accuracy

We describe our apps as accurately as we can, including which are shipped and which are still being built. Descriptions of unreleased software are statements of intent rather than promises, and features can change or be dropped before release. Where this site and a store listing disagree, the store listing is the one that governs what you are actually installing.

## Your content

If you send us a message, you keep whatever rights you have in it. You give us permission to read it and reply, which is the whole of what we do with it. Do not send confidential material through the form; email is not a secure channel and the form is not covered by any confidentiality agreement.

Unsolicited product ideas are a difficult category. If you send one, you accept that we may already be working on something similar and that receiving your message creates no obligation to you and no claim over anything we ship.

## Our content

The text, layout, logos and artwork on this site belong to Mindberzerk. You may link to any page, quote a reasonable extract with attribution, and take screenshots for reviews or reporting. You may not copy the site wholesale, present it as your own, or use the Mindberzerk name or marks in a way that suggests we endorse you.

Other names and marks that appear here belong to their owners and are used descriptively. Google Play and the Google Play logo are trademarks of Google LLC. App Store is a trademark of Apple Inc. Mindberzerk is not affiliated with, endorsed by, or sponsored by either.

## Links out

This site links to Google Play, the App Store and other places we do not control. We are not responsible for what those pages say or do, and their terms apply once you are there.

## Availability

The site is provided as it is, without warranty of any kind. We do not promise it is always reachable, and we may change or remove any part of it at any time.

## Limitation of liability

To the extent the law allows, Mindberzerk is not liable for indirect or consequential loss arising from your use of this site. Nothing here limits rights you have under consumer law that cannot be waived, and nothing here limits liability for death, personal injury or fraud.

## Changes

These terms may change; the date at the top changes with them and the previous version is replaced here.`;

/**
 * Everything that is not G Launcher starts from a skeleton, not from a copy.
 *
 * Copying G Launcher's policy would be worse than starting blank: it names
 * permissions another app does not have, and a policy that overstates what you
 * collect is as wrong as one that understates it. The headings are the ones Play
 * expects; the prose is deliberately a prompt rather than filler that could be
 * published by accident.
 */
function skeleton(name: string): { privacy: string; terms: string } {
  return {
    privacy: `${name} is published by Mindberzerk. This policy describes what the app collects, what it sends anywhere, and why it asks for each permission.

## What stays on your device

Describe what is written to app-private storage and never transmitted.

## What leaves your device

Describe every network call the app makes and what it carries.

## Permissions, and what each is for

\`\`\`
PERMISSION — What it is used for, in one sentence.
\`\`\`

## Children

${name} is not directed at children and does not knowingly collect information from anyone under 13.

## Your choices

Describe how someone deletes their data.

## Changes

If this policy changes, the date at the top changes with it.`,
    terms: `These terms cover your use of ${name}, published by Mindberzerk.

## The app

Describe the licence to use the app.

## Payments and refunds

Describe anything sold, and point at Google Play's refund policy.

## No warranty

The app is provided as it is, without warranty of any kind.

## Limitation of liability

To the extent the law allows, Mindberzerk is not liable for indirect or consequential loss arising from your use of the app.

## Changes and ending this agreement

You can end this agreement at any time by uninstalling the app.`,
  };
}

function seed(app: LegalId): LegalDoc {
  const name = legalName(app);
  const body =
    app === STUDIO_ID
      ? { privacy: STUDIO_PRIVACY, terms: STUDIO_TERMS }
      : app === 'g-launcher'
        ? { privacy: G_LAUNCHER_PRIVACY, terms: G_LAUNCHER_TERMS }
        : skeleton(name);

  return {
    privacy: body.privacy,
    terms: body.terms,
    contactEmail: '',
    jurisdiction: '',
    updatedAt: 0,
  };
}

// ─── read and write ──────────────────────────────────────────────────────────

export async function readLegal(app: LegalId): Promise<LegalState> {
  // Same guard as readLiveIndex and readSiteContent: this is called from a page
  // and `getObject` rethrows anything that is not a missing key, so a credential
  // problem would render as a stack trace where a sentence belongs.
  let bytes: Buffer | null;
  try {
    bytes = await getObject(sourceKey(app));
  } catch (e) {
    return {
      doc: seed(app),
      exists: false,
      corrupt: false,
      unreachable: (e as Error).message || 'The bucket could not be read.',
    };
  }
  if (!bytes) return { doc: seed(app), exists: false, corrupt: false };

  try {
    const parsed = JSON.parse(bytes.toString('utf8')) as Partial<LegalDoc>;
    const s = seed(app);
    // Field by field with seed fallbacks, so a document written by an older
    // version of this panel still opens rather than throwing.
    return {
      doc: {
        privacy: typeof parsed.privacy === 'string' ? parsed.privacy : s.privacy,
        terms: typeof parsed.terms === 'string' ? parsed.terms : s.terms,
        contactEmail: String(parsed.contactEmail ?? ''),
        jurisdiction: String(parsed.jurisdiction ?? ''),
        updatedAt: Number(parsed.updatedAt) || 0,
      },
      exists: true,
      corrupt: false,
    };
  } catch {
    return { doc: seed(app), exists: true, corrupt: true };
  }
}

/**
 * Render and publish both pages, plus the source.
 *
 * SOURCE LAST, deliberately. If the HTML writes fail halfway, the source still
 * describes what is live rather than what was meant to be, and pressing publish
 * again is a clean retry. The reverse order would leave the editor claiming a
 * state the bucket does not have.
 */
export async function writeLegal(
  app: LegalId,
  next: Omit<LegalDoc, 'updatedAt'>,
): Promise<{ ok: true; updatedAt: number } | { ok: false; error: string }> {
  const problems = validate(next);
  if (problems.length > 0) return { ok: false, error: problems.join(' ') };

  const name = legalName(app);
  // The studio has no package, and the template already omits the field when it
  // is blank, so this is the whole of the difference at publish time.
  const pkg = appMeta(app)?.pkg ?? '';
  const updatedAt = Math.floor(Date.now() / 1000);

  const contact = `## Contact

Mindberzerk  
[${next.contactEmail}](mailto:${next.contactEmail})`;

  const governing = `## Governing law

These terms are governed by the laws of ${next.jurisdiction}, without affecting any mandatory consumer protections in the country where you live.`;

  const privacyHtml = page({
    title: 'Privacy Policy',
    appName: name,
    pkg,
    updatedAt,
    body: renderMarkdown(`${next.privacy}\n\n${contact}`),
    otherHref: './terms.html',
    otherLabel: 'Terms of Use',
  });

  const termsHtml = page({
    title: 'Terms of Use',
    appName: name,
    pkg,
    updatedAt,
    body: renderMarkdown(`${next.terms}\n\n${governing}\n\n${contact}`),
    otherHref: './privacy.html',
    otherLabel: 'Privacy Policy',
  });

  // Five minutes, NOT immutable. `putObject` marks most objects immutable for a
  // year because pack paths carry a version; these do not, and a year-stale
  // privacy policy is a compliance problem rather than an inconvenience.
  await putObject(pageKey(app, 'privacy'), Buffer.from(privacyHtml, 'utf8'), 'text/html; charset=utf-8');
  await putObject(pageKey(app, 'terms'), Buffer.from(termsHtml, 'utf8'), 'text/html; charset=utf-8');

  const doc: LegalDoc = { ...next, updatedAt };
  await putObject(sourceKey(app), Buffer.from(JSON.stringify(doc, null, 2), 'utf8'), 'application/json');

  return { ok: true, updatedAt };
}

// ─── status, for the dashboard ───────────────────────────────────────────────

export interface LegalStatus {
  id: LegalId;
  name: string;
  /** A document has been published at least once. */
  published: boolean;
  updatedAt: number;
  /** The bucket could not be read, so `published` says nothing. */
  unknown: boolean;
}

/**
 * Every legal document's state, for the dashboard's Legal panel.
 *
 * READS ARE INDEPENDENT AND FAILURES ARE LOCAL. This runs on the one screen you
 * open to discover something is broken, so one unreadable document must not
 * take the panel with it. An unreadable one reports `unknown: true`, and the
 * caller renders that as its own state rather than as "not written", because
 * those are different facts and only one of them is a task.
 */
export async function readLegalStatuses(): Promise<LegalStatus[]> {
  return Promise.all(
    LEGAL_IDS.map(async (id) => {
      const name = legalName(id);
      try {
        const state = await readLegal(id);
        if (state.unreachable) {
          return { id, name, published: false, updatedAt: 0, unknown: true };
        }
        return {
          id,
          name,
          // `exists` alone is not published: a document can be stored with
          // updatedAt 0 by an older path. The timestamp is what the publish
          // writes, so it is what "published" means.
          published: state.exists && state.doc.updatedAt > 0,
          updatedAt: state.doc.updatedAt,
          unknown: state.corrupt,
        };
      } catch {
        return { id, name, published: false, updatedAt: 0, unknown: true };
      }
    }),
  );
}

/** Where the published pages are served. Shown in the editor, pasted into Play. */
export function publicUrl(app: LegalId, doc: DocKind): string {
  const base = (process.env.CDN_BASE_URL ?? 'https://cdn.mindberzerk.com').replace(/\/+$/, '');
  return `${base}/${pageKey(app, doc)}`;
}
