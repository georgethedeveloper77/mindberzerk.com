/**
 * The legal documents' shape and rules, with no server dependencies.
 *
 * Split from `legal.ts` for the same reason `theme-spec.ts` is split from
 * `themes.ts`: the editor is a client component and must show the same problems
 * the publish will refuse on, live, as they are typed. Importing `legal.ts`
 * would drag `server-only` and the R2 client into the browser bundle.
 *
 * ## WHY THIS IS A COLLECTION NOW, AND NOT TWO FIELDS
 *
 * It used to be `{ privacy: string; terms: string }`. That shape cannot express
 * a children's policy, a cookie policy, a refund policy or an EULA, and every
 * one of those is a real thing a store or a jurisdiction can ask for. Adding a
 * third string field would have worked once and then been wrong again.
 *
 * So documents are a LIST, each with a slug, a title and a body. Two slugs are
 * required and cannot be deleted, `privacy` and `terms`, because Play refuses a
 * listing without them. Everything else is created when it is needed.
 *
 * The slug is the filename and the URL, so it is validated like a path segment
 * and it is IMMUTABLE once published: renaming a slug silently 404s a link that
 * a store, a search engine or a user already has. The editor enforces that by
 * not offering a rename; this file enforces it by validating the shape.
 */

export interface LegalDocument {
  /** Filename and URL segment. Lowercase, hyphenated, stable forever. */
  slug: string;
  /** Heading on the rendered page, and the label in the editor. */
  title: string;
  /** Markdown. Rendered into the page template on publish. */
  body: string;
}

export interface LegalDoc {
  documents: LegalDocument[];

  /**
   * Structural rather than left as tokens in the prose, because these are the
   * two values that MUST be filled before Play accepts a listing, and a
   * placeholder buried in paragraph nine is a placeholder that ships.
   */
  contactEmail: string;
  jurisdiction: string;

  /** Unix seconds of the last publish. Display only. */
  updatedAt: number;
}

export type LegalDraft = Pick<LegalDoc, 'documents' | 'contactEmail' | 'jurisdiction'>;

/** Cannot be deleted, and every entity has them. Play requires both. */
export const REQUIRED_SLUGS = ['privacy', 'terms'] as const;

export const SLUG_RE = /^[a-z][a-z0-9-]{1,40}$/;

export function isRequired(slug: string): boolean {
  return (REQUIRED_SLUGS as readonly string[]).includes(slug);
}

/**
 * Starting points for a new document.
 *
 * PROMPTS, NOT FILLER. Each is deliberately too short to pass validation on its
 * own, so a template cannot be published unread. The alternative, shipping
 * plausible complete prose, produces policies that describe a company that does
 * not exist, which is worse than having none.
 */
export interface DocTemplate {
  slug: string;
  title: string;
  body: string;
  /** One line in the picker, saying when this is the one you want. */
  when: string;
}

export const TEMPLATES: DocTemplate[] = [
  {
    slug: 'children',
    title: 'Children and families',
    when: 'Required if any app targets, or could appeal to, under 13s.',
    body: `## Who this covers

Describe which apps this applies to and the age range they are meant for.

## What is collected from a child

Say plainly what is collected, or that nothing is. If nothing is, say so first.

## Advertising and in-app purchases

Say whether either exists in the apps this covers, and how a parent controls them.

## How a parent reaches us

Describe how a parent asks what is held about their child and how it is deleted.`,
  },
  {
    slug: 'cookies',
    title: 'Cookies',
    when: 'Useful once the site sets anything beyond a first-party analytics cookie.',
    body: `## What this site sets

List every cookie by name, what it does, and how long it lasts.

## What third parties set

Name each one and link to their own policy.

## How to refuse them

Describe the browser controls and any in-page choice offered.`,
  },
  {
    slug: 'refunds',
    title: 'Refunds',
    when: 'Worth having once anything is sold, even through a store that handles it.',
    body: `## Who processes the payment

Say which store handles the transaction and whose refund policy governs it.

## What we can do directly

Describe what to write to us about, and what only the store can resolve.

## Time limits

State any window that applies.`,
  },
  {
    slug: 'accessibility',
    title: 'Accessibility',
    when: 'A short statement of what the apps support and where they fall short.',
    body: `## What is supported

Describe screen reader support, contrast, text scaling and any known limits.

## Reporting a problem

Describe how someone tells us an app is unusable for them.`,
  },
];

export function blankDocument(slug: string, title: string): LegalDocument {
  return {
    slug,
    title,
    body: `## Section

Write the first section here.`,
  };
}

/**
 * What must be true before these pages are allowed to go public.
 *
 * Returns every problem rather than the first, so the editor lists them all and
 * the publish button's disabled state has a visible reason beside it.
 *
 * The length floors differ on purpose. A privacy policy or terms that is under
 * 200 characters is not a real one. A supplementary document can legitimately
 * be short, so it gets a lower floor that still catches an untouched template.
 */
export function validate(doc: LegalDraft): string[] {
  const problems: string[] = [];

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(doc.contactEmail.trim())) {
    problems.push('A contact email is required. Play rejects a listing whose policy has no way to reach you.');
  }
  if (!doc.jurisdiction.trim()) {
    problems.push('A governing jurisdiction is required in the terms.');
  }

  for (const slug of REQUIRED_SLUGS) {
    if (!doc.documents.some((d) => d.slug === slug)) {
      problems.push(`The ${slug} document is required and is missing.`);
    }
  }

  const seen = new Set<string>();
  for (const d of doc.documents) {
    const label = d.title.trim() || d.slug;

    if (!SLUG_RE.test(d.slug)) {
      problems.push(`"${d.slug}" is not a usable filename. Lowercase letters, digits and hyphens.`);
    }
    if (seen.has(d.slug)) {
      problems.push(`Two documents share the slug "${d.slug}", so one would overwrite the other.`);
    }
    seen.add(d.slug);

    if (!d.title.trim()) {
      problems.push(`The document at /${d.slug} has no title.`);
    }

    const floor = isRequired(d.slug) ? 200 : 120;
    if (d.body.trim().length < floor) {
      problems.push(`${label} is too short to be a real document.`);
    }

    // The tokens a hand-written first draft carried. Cheap to check and
    // catastrophic to publish.
    for (const token of ['CONTACT_EMAIL', 'GOVERNING_JURISDICTION']) {
      if (d.body.includes(token)) problems.push(`${token} is still in ${label}.`);
    }
  }

  return problems;
}

/**
 * ── THE MIGRATION ────────────────────────────────────────────────────────
 *
 * Documents published under the old two-field shape must keep working. This is
 * called by the reader on anything that has no `documents` array, and it is
 * here rather than in `legal.ts` so the editor can be tested against it without
 * a bucket.
 *
 * It is deliberately tolerant: a document with neither field yields an empty
 * list, and the reader seeds from there.
 */
export function migrateLegacy(parsed: {
  privacy?: unknown;
  terms?: unknown;
}): LegalDocument[] {
  const out: LegalDocument[] = [];
  if (typeof parsed.privacy === 'string' && parsed.privacy.trim()) {
    out.push({ slug: 'privacy', title: 'Privacy Policy', body: parsed.privacy });
  }
  if (typeof parsed.terms === 'string' && parsed.terms.trim()) {
    out.push({ slug: 'terms', title: 'Terms of Use', body: parsed.terms });
  }
  return out;
}
