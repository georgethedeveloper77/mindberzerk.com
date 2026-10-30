/**
 * Stroke icons for the G VPN landing, drawn on a 24px grid and coloured by
 * `currentColor`. Decorative everywhere they are used, so always aria-hidden.
 */

const PATHS = {
  power: (
    <>
      <path d="M12 3v8" />
      <path d="M6.3 6.6a8 8 0 1 0 11.4 0" />
    </>
  ),
  check: <path d="M5 12l5 5 9-10" />,
  chevron: <path d="M6 9l6 6 6-6" />,
} as const;

export type IconName = keyof typeof PATHS;

interface IconProps {
  name: IconName;
  size?: number;
  strokeWidth?: number;
  className?: string;
  /** Filled glyphs ignore the stroke. */
  filled?: boolean;
}

export function Icon({ name, size = 24, strokeWidth = 1.8, className, filled = false }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={filled ? 'currentColor' : 'none'}
      stroke={filled ? 'none' : 'currentColor'}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      {PATHS[name]}
    </svg>
  );
}
