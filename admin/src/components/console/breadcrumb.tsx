'use client';

import * as React from 'react';
import Link from 'next/link';

export interface Crumb {
  label: string;
  href?: string;
}

/**
 * The trail that makes a page feel like part of a site rather than a standalone
 * tool. Uses the panel's own tokens (ink-3 for the trail, ink for the current
 * page) so it matches the rail and PageHead exactly. The last crumb is the
 * current page and is not a link.
 */
export function Breadcrumb({ items }: { items: Crumb[] }) {
  return (
    <nav aria-label="Breadcrumb" className="mb-3 flex flex-wrap items-center gap-x-1.5 gap-y-1 font-mono text-micro text-ink-3">
      {items.map((it, i) => (
        <React.Fragment key={`${it.label}-${i}`}>
          {i > 0 && <span className="text-ink-3/50">/</span>}
          {it.href ? (
            <Link href={it.href} className="transition hover:text-ink">
              {it.label}
            </Link>
          ) : (
            <span className="text-ink" aria-current="page">
              {it.label}
            </span>
          )}
        </React.Fragment>
      ))}
    </nav>
  );
}
