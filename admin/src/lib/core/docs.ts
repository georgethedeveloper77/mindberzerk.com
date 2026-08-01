import 'server-only';

import { readFile } from 'node:fs/promises';
import path from 'node:path';

/**
 * ARCHITECTURE DOCS, read off disk and split for rendering.
 *
 * ## Why a file and not a database
 *
 * A diagram that has drifted from the code is worse than no diagram, because it
 * is trusted. Keeping these as markdown IN THE REPO means a change shows up in
 * a diff beside the change it describes, and a stale one is visible in review.
 * Editing them through a textarea in this panel would create a second source of
 * truth that no pull request ever sees.
 *
 * So the panel RENDERS them and never writes them.
 *
 * ## Why they live under admin/
 *
 * App Hosting deploys the `admin/` directory. A doc at the repo root is outside
 * the build context, so it would work in `npm run dev` and 404 in production,
 * which is the worst kind of bug: correct on the machine where you test it.
 *
 * `next.config.ts` also names `docs/**` in `outputFileTracingIncludes`, because
 * the standalone build only copies files it can see being imported, and this
 * one is read by path at runtime.
 */

export type DocSegment =
  | { kind: 'markdown'; body: string }
  | { kind: 'mermaid'; code: string };

export interface ArchitectureDoc {
  segments: DocSegment[];
  /** Rendered under the title, so a reader knows how current this is. */
  bytes: number;
}

/**
 * Split a markdown file into prose and mermaid blocks.
 *
 * The two are rendered by different things: prose by the same markdown renderer
 * the legal pages use, diagrams by mermaid in the browser. Splitting here means
 * the client component receives a plain array and needs no parser of its own.
 */
export function splitDoc(source: string): DocSegment[] {
  const segments: DocSegment[] = [];
  const fence = /```mermaid\n([\s\S]*?)```/g;

  let last = 0;
  let match: RegExpExecArray | null;
  while ((match = fence.exec(source)) !== null) {
    const before = source.slice(last, match.index);
    if (before.trim()) segments.push({ kind: 'markdown', body: before });
    segments.push({ kind: 'mermaid', code: match[1] });
    last = match.index + match[0].length;
  }

  const rest = source.slice(last);
  if (rest.trim()) segments.push({ kind: 'markdown', body: rest });
  return segments;
}

/**
 * Read one app's architecture doc.
 *
 * Returns null when there is no file, which is a normal state rather than an
 * error: G Recovery has no doc yet and the page says so rather than throwing.
 * The app id is used as a path segment, so it must already have been validated
 * by `isAppId` before reaching here.
 */
export async function readArchitecture(app: string): Promise<ArchitectureDoc | null> {
  // `process.cwd()` is the admin directory in both dev and the standalone
  // build, which is why the doc lives under it.
  const file = path.join(process.cwd(), 'docs', app, 'architecture.md');
  try {
    const source = await readFile(file, 'utf8');
    return { segments: splitDoc(source), bytes: Buffer.byteLength(source, 'utf8') };
  } catch {
    return null;
  }
}
