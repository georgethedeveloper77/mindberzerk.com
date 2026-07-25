/**
 * The shared console kit, one import for the whole panel.
 *
 *   import { C, cssColor, ConsoleStyle, ToastProvider, useToast, Skeleton, Button } from '@/components/console';
 *
 * Tokens and the base ConsoleStyle live in the theme-builder module (where they
 * were first authored) and are re-exported here so there is one canonical place
 * to reach for them. As pages migrate onto this kit, the two component roots
 * collapse into one.
 */

export { C, cssColor, ConsoleStyle } from '../theme-builder/console';
export { Breadcrumb, type Crumb } from './breadcrumb';
export { BuilderShell } from './builder-shell';
export {
  ToastProvider,
  useToast,
  KitStyle,
  Skeleton,
  SkeletonText,
  SkeletonCard,
  Button,
} from './feedback';
