/**
 * Stroke icons for the G VPN landing, drawn on a 24px grid and coloured by
 * `currentColor`. Decorative everywhere they are used, so always aria-hidden.
 */

const PATHS = {
  noAccount: (
    <>
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6" />
      <path d="M3 3l18 18" />
    </>
  ),
  noAds: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="3" />
      <path d="M3 5l18 14" />
    </>
  ),
  gift: (
    <>
      <rect x="3.5" y="9" width="17" height="11.5" rx="2" />
      <path d="M2.5 9h19M12 9v11.5" />
      <path d="M12 9c-1.5-3.5-5.5-4.5-5.5-2S10 9 12 9zM12 9c1.5-3.5 5.5-4.5 5.5-2S14 9 12 9z" />
    </>
  ),
  globe: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9s1.3-6.3 3.8-9z" />
    </>
  ),
  gauge: (
    <>
      <path d="M4 17a8 8 0 1 1 16 0" />
      <path d="M12 17l4-6" />
    </>
  ),
  pulse: <path d="M3 12h4l3-7 4 14 3-7h4" />,
  devices: (
    <>
      <rect x="2" y="4" width="14" height="10" rx="2" />
      <rect x="17" y="8" width="5" height="12" rx="1.5" />
      <path d="M6 18h6" />
    </>
  ),
  wifi: (
    <>
      <path d="M2 9a15 15 0 0 1 20 0" />
      <path d="M5.5 12.5a10 10 0 0 1 13 0" />
      <path d="M9 16a5 5 0 0 1 6 0" />
      <circle cx="12" cy="19.5" r="0.8" />
    </>
  ),
  star: <path d="M12 3l2.7 5.6 6.1.8-4.5 4.2 1.1 6-5.4-2.9-5.4 2.9 1.1-6-4.5-4.2 6.1-.8z" />,
  alert: (
    <>
      <path d="M12 3l9.5 17h-19z" />
      <path d="M12 10v4M12 17.2v.1" />
    </>
  ),
  blocked: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M5.6 5.6l12.8 12.8" />
    </>
  ),
  bell: (
    <>
      <path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z" />
      <path d="M10 21h4" />
    </>
  ),
  power: (
    <>
      <path d="M12 3v8" />
      <path d="M6.3 6.6a8 8 0 1 0 11.4 0" />
    </>
  ),
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
