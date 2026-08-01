'use client';

import { useEffect, useRef, useState } from 'react';

import type { DocSegment } from '@/lib/core/docs';

/**
 * Render an architecture doc: prose as HTML, diagrams as mermaid.
 *
 * ## Mermaid runs in the browser, and only on this route
 *
 * It is a large dependency, so it is imported dynamically inside the effect
 * rather than at module scope. No other screen pays for it, and this one pays
 * only after the page is interactive.
 *
 * ## Diagrams are rendered ONE AT A TIME, by id
 *
 * `mermaid.render` returns an SVG string for one definition, which is exactly
 * what is wanted here: React owns the container and mermaid never touches the
 * DOM around it. The alternative, `mermaid.run` scanning for `.mermaid` nodes,
 * fights React over the same elements and leaves stale SVGs behind on a
 * re-render.
 *
 * ## A DIAGRAM THAT DOES NOT PARSE SHOWS ITS SOURCE
 *
 * Not a blank space and not an error boundary. A broken diagram is usually a
 * one-character mistake in the definition, so showing the definition next to
 * the message is what makes it fixable. The page must also survive it: one bad
 * block should not take the other five with it.
 */

interface Rendered {
  svg?: string;
  error?: string;
}

export function ArchitectureView({
  segments,
  html,
}: {
  segments: DocSegment[];
  /** Prose pre-rendered on the server, index-aligned with `segments`. */
  html: Record<number, string>;
}) {
  const [rendered, setRendered] = useState<Record<number, Rendered>>({});

  /**
   * THE MODE IS READ HERE, NOT PASSED IN. Light or dark is decided in the
   * browser, from a stored choice or a media query, so the server cannot know
   * it. Mermaid bakes colours into the SVG it produces, so a diagram rendered
   * for the wrong mode is a white slab on a dark page until something forces a
   * re-render.
   *
   * Starts null so nothing renders against a guess, and re-renders on a theme
   * change because the toggle mutates `data-theme` on <html>.
   */
  const [dark, setDark] = useState<boolean | null>(null);

  useEffect(() => {
    const read = () => {
      const set = document.documentElement.dataset.theme;
      if (set === 'light' || set === 'dark') return set === 'dark';
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    };
    setDark(read());

    const observer = new MutationObserver(() => setDark(read()));
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onMedia = () => setDark(read());
    media.addEventListener('change', onMedia);

    return () => {
      observer.disconnect();
      media.removeEventListener('change', onMedia);
    };
  }, []);
  // Guards against a second pass overwriting the first when the effect reruns.
  const runId = useRef(0);

  useEffect(() => {
    // Wait for the mode. One extra frame beats a diagram in the wrong palette.
    if (dark === null) return;
    const run = ++runId.current;
    let cancelled = false;

    (async () => {
      let mermaid: typeof import('mermaid').default;
      try {
        mermaid = (await import('mermaid')).default;
      } catch {
        if (!cancelled) {
          setRendered({ [-1]: { error: 'The mermaid package is not installed.' } });
        }
        return;
      }

      mermaid.initialize({
        startOnLoad: false,
        // `base` plus explicit variables rather than the built-in dark theme:
        // the built-in one carries its own palette and would be the only thing
        // on this page not using the panel's.
        theme: 'base',
        securityLevel: 'strict',
        themeVariables: dark
          ? {
              background: '#15111d',
              primaryColor: '#241a3f',
              primaryTextColor: '#f3effa',
              primaryBorderColor: '#3a2f57',
              lineColor: '#857c96',
              secondaryColor: '#1d1828',
              tertiaryColor: '#1d1828',
              fontFamily: 'var(--font-site-sans)',
            }
          : {
              background: '#ffffff',
              primaryColor: '#eee9fd',
              primaryTextColor: '#17101f',
              primaryBorderColor: '#c9bcf5',
              lineColor: '#837b91',
              secondaryColor: '#f1eef7',
              tertiaryColor: '#f1eef7',
              fontFamily: 'var(--font-site-sans)',
            },
      });

      const next: Record<number, Rendered> = {};
      for (let i = 0; i < segments.length; i++) {
        const seg = segments[i];
        if (seg.kind !== 'mermaid') continue;
        try {
          const { svg } = await mermaid.render(`arch-${run}-${i}`, seg.code);
          next[i] = { svg };
        } catch (e) {
          next[i] = { error: (e as Error).message ?? 'This diagram did not parse.' };
        }
      }
      if (!cancelled && run === runId.current) setRendered(next);
    })();

    return () => {
      cancelled = true;
    };
  }, [segments, dark]);

  return (
    <div className="flex flex-col gap-4">
      {rendered[-1]?.error && (
        <p className="rounded-[14px] bg-site-plan-soft px-4 py-3 text-[13px] leading-relaxed text-site-plan">
          {rendered[-1].error}
        </p>
      )}

      {segments.map((seg, i) =>
        seg.kind === 'markdown' ? (
          <div
            key={i}
            className="arch-prose text-[13.5px] leading-relaxed text-site-ink-2"
            dangerouslySetInnerHTML={{ __html: html[i] ?? '' }}
          />
        ) : (
          <figure
            key={i}
            className="overflow-x-auto rounded-[18px] border border-site-line bg-site-card p-5 shadow-site-soft"
          >
            {rendered[i]?.svg ? (
              <div className="mx-auto w-fit" dangerouslySetInnerHTML={{ __html: rendered[i].svg! }} />
            ) : rendered[i]?.error ? (
              <>
                <p className="mb-3 rounded-xl bg-site-plan-soft px-3 py-2.5 text-[12px] leading-relaxed text-site-plan">
                  This diagram did not parse. {rendered[i].error}
                </p>
                <pre className="overflow-x-auto rounded-xl bg-site-sunk p-3 font-mono text-[11.5px] leading-relaxed text-site-ink-3">
                  {seg.code}
                </pre>
              </>
            ) : (
              <p className="py-6 text-center font-mono text-[11.5px] text-site-ink-3">
                drawing the diagram
              </p>
            )}
          </figure>
        ),
      )}
    </div>
  );
}
