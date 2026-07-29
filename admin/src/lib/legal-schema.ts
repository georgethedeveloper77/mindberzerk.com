/**
 * The legal document's shape and its rules, with no server dependencies.
 *
 * Split from `legal.ts` for the same reason `theme-spec.ts` is split from
 * `themes.ts`: the editor is a client component and must show the same problems
 * the publish will refuse on, live, as they are typed. Importing `legal.ts`
 * would drag `server-only` and the R2 client into the browser bundle.
 *
 * One definition of "is this publishable", two callers.
 */

export type DocKind = 'privacy' | 'terms';

export interface LegalDoc {
  /** Markdown. Rendered into the page template on publish. */
  privacy: string;
  terms: string;

  /**
   * Structural rather than left as a token in the prose, because these are the
   * two values that MUST be filled before Play accepts the listing, and a
   * placeholder buried in paragraph nine is a placeholder that ships.
   */
  contactEmail: string;
  jurisdiction: string;

  /** Unix seconds of the last publish. Display only. */
  updatedAt: number;
}

export type LegalDraft = Pick<LegalDoc, 'privacy' | 'terms' | 'contactEmail' | 'jurisdiction'>;

/**
 * What must be true before a legal page is allowed to go public.
 *
 * Returns every problem rather than the first, so the editor can list them all
 * and the publish button's disabled state has a visible reason next to it —
 * the same arrangement `writeSiteContent`'s broken-link check has.
 */
export function validate(doc: LegalDraft): string[] {
  const problems: string[] = [];

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(doc.contactEmail.trim())) {
    problems.push('A contact email is required. Play rejects a listing whose policy has no way to reach you.');
  }
  if (!doc.jurisdiction.trim()) {
    problems.push('A governing jurisdiction is required in the terms.');
  }
  if (doc.privacy.trim().length < 200) {
    problems.push('The privacy policy is too short to be a real one.');
  }
  if (doc.terms.trim().length < 200) {
    problems.push('The terms are too short to be real ones.');
  }

  // The two tokens the hand-written first draft carried. Cheap to check and
  // catastrophic to publish.
  for (const token of ['CONTACT_EMAIL', 'GOVERNING_JURISDICTION']) {
    if (doc.privacy.includes(token) || doc.terms.includes(token)) {
      problems.push(`${token} is still in the text.`);
    }
  }

  return problems;
}
