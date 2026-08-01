/**
 * The markdown subset the legal pages are written in.
 *
 * ─── NO `server-only` HERE, DELIBERATELY ────────────────────────────────────
 *
 * Same reasoning as `skus.ts` and `registry.ts`: the editor is a client
 * component and previews what it is about to publish. If the preview used a
 * different renderer from the publish, the preview would be a decoration rather
 * than a guarantee — which is the same argument `site-form` makes for resolving
 * featured cards through the registry instead of restating them.
 *
 * One function, two callers, and they cannot disagree.
 *
 * ─── ESCAPE FIRST, ALWAYS ───────────────────────────────────────────────────
 *
 * Everything below operates on already-escaped text. That ordering is what makes
 * this safe by construction rather than by remembering to sanitise at the end,
 * and it is why the worst a bad edit can produce is ugly text rather than markup
 * on a public URL Google has on file.
 */

// ─── the markdown subset ─────────────────────────────────────────────────────

/**
 * Escape FIRST, always. Every other function here operates on already-escaped
 * text, which is what makes the renderer safe by construction rather than by
 * remembering to sanitise at the end.
 */
export function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * A link target we are willing to emit.
 *
 * `javascript:` is the reason this exists. The escape pass above does not touch
 * the inside of `](...)`, so without this check a link in the editor could
 * become an executable one on a page we serve.
 */
function safeHref(raw: string): string | null {
  const href = raw.trim();
  if (/^https?:\/\/[^\s]+$/i.test(href)) return href;
  if (/^mailto:[^\s]+$/i.test(href)) return href;
  // Sibling pages only: ./privacy.html, ./terms.html.
  if (/^\.\/[a-z0-9._-]+$/i.test(href)) return href;
  return null;
}

/**
 * Inline spans, applied to escaped text.
 *
 * KNOWN AND ACCEPTED: the href pattern stops at the first `)`, so a target
 * containing one truncates. For a valid target that never happens — http, https,
 * mailto and sibling `.html` links do not contain parens — and for an invalid
 * one such as `javascript:alert(1)` the link is rejected anyway and a stray `)`
 * is left in the text. Ugly, visible in the preview, and cheaper than a
 * balanced-paren parser nobody will exercise.
 */
function inline(s: string): string {
  return s
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (whole, text: string, href: string) => {
      const ok = safeHref(href);
      // An unsafe or malformed target degrades to the visible text rather than
      // vanishing, so a typo is obvious in the preview instead of silent.
      return ok ? `<a href="${ok}">${text}</a>` : text;
    })
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>');
}

/**
 * Markdown to HTML, for the subset a legal page needs.
 *
 * Blocks are separated by a blank line. Supported:
 *
 *   ## heading            a section
 *   ### heading           a sub-heading
 *   > text                the callout box
 *   - item                a list
 *   ``` name — meaning    the mono listing, used for the permission table
 *   anything else         a paragraph, single newlines collapsed to spaces
 *
 * Deliberately NOT supported: raw HTML, images, tables, footnotes. Each would be
 * another shape to style and another way for an edit to break the page, and none
 * of them belongs in a document whose job is to be read once and understood.
 */
export function renderMarkdown(md: string): string {
  const blocks = md.replace(/\r\n/g, '\n').trim().split(/\n{2,}/);
  const out: string[] = [];

  for (const raw of blocks) {
    const block = raw.trim();
    if (!block) continue;

    // The mono listing. Each line splits on an em dash into a term and its
    // meaning; a line without one renders as a bare term.
    if (block.startsWith('```')) {
      const lines = block
        .split('\n')
        .filter((l) => !l.trim().startsWith('```'))
        .filter((l) => l.trim());
      const items = lines.map((l) => {
        const [term, ...rest] = l.split(' — ');
        const meaning = rest.join(' — ').trim();
        return meaning
          ? `<span class="row"><b>${inline(esc(term.trim()))}</b><span>${inline(esc(meaning))}</span></span>`
          : `<span class="row"><b>${inline(esc(l.trim()))}</b></span>`;
      });
      out.push(`<div class="listing">${items.join('')}</div>`);
      continue;
    }

    if (block.startsWith('### ')) {
      out.push(`<h3>${inline(esc(block.slice(4).trim()))}</h3>`);
      continue;
    }
    if (block.startsWith('## ')) {
      out.push(`<h2>${inline(esc(block.slice(3).trim()))}</h2>`);
      continue;
    }

    if (block.startsWith('> ')) {
      const text = block
        .split('\n')
        .map((l) => l.replace(/^>\s?/, ''))
        .join(' ');
      out.push(`<div class="callout"><p>${inline(esc(text))}</p></div>`);
      continue;
    }

    if (block.startsWith('- ')) {
      const items = block
        .split('\n')
        .filter((l) => l.trim().startsWith('- '))
        .map((l) => `<li>${inline(esc(l.trim().slice(2)))}</li>`);
      out.push(`<ul>${items.join('')}</ul>`);
      continue;
    }

    out.push(`<p>${inline(esc(block.split('\n').join(' ')))}</p>`);
  }

  return out.join('\n');
}
