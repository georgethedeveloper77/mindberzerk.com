'use client';

import * as React from 'react';
import { ConsoleStyle } from '../theme-builder/console';
import { Breadcrumb, type Crumb } from './breadcrumb';

/**
 * The frame for a builder's content when it lives inside the site's <Shell>.
 *
 * It deliberately owns no background, no full-viewport height, and no sticky
 * chrome: Shell provides the rail, the mobile nav, and the padded, centred main
 * column. This just contributes the breadcrumb and a title row whose markup
 * matches ui.tsx's PageHead one-for-one, so a builder page reads like every
 * other page rather than a tool bolted on.
 */
export function BuilderShell({
  crumbs,
  title,
  meta,
  actions,
  children,
}: {
  crumbs: Crumb[];
  title: string;
  meta?: React.ReactNode;
  actions?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="tb-root">
      <ConsoleStyle />
      <Breadcrumb items={crumbs} />
      <div className="mb-4 flex flex-wrap items-center gap-x-3 gap-y-2">
        <h1 className="text-base font-semibold tracking-tight text-ink">{title}</h1>
        {meta && <span className="font-mono text-micro text-ink-3">{meta}</span>}
        {actions && <div className="ml-auto flex items-center gap-2">{actions}</div>}
      </div>
      {children}
    </div>
  );
}
