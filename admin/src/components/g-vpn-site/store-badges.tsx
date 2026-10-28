import { STORE_COPY, type StoreId } from './copy';

/**
 * Store branding: each store's own logo and badge, drawn as SVG so the page
 * ships no third-party bitmaps. Badges follow the stores' published layout
 * (black pill, logo, small kicker over the store name).
 */

function PlayLogo({ size }: { size: number }) {
  return (
    <svg width={size} height={(size * 26) / 24} viewBox="0 0 24 26" aria-hidden>
      <path fill="#00D7FE" d="M1.2.8l12.1 12.1L1.2 25c-.3-.3-.4-.7-.4-1.2V2c0-.5.1-.9.4-1.2z" />
      <path fill="#00F076" d="M17.4 8.8l-4.1 4.1L1.2.8C1.6.4 2.3.3 3 .7z" />
      <path fill="#FF3A44" d="M13.3 12.9l4.1 4.1L3 25.1c-.7.4-1.4.3-1.8-.1z" />
      <path fill="#FFD500" d="M17.4 8.8l4.5 2.6c1.2.7 1.2 2.3 0 3L17.4 17l-4.1-4.1z" />
    </svg>
  );
}

function AppleLogo({ size }: { size: number }) {
  return (
    <svg width={size} height={(size * 22) / 19} viewBox="0 0 19 22" fill="currentColor" aria-hidden>
      <path d="M15.6 11.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.9C5.7 6 4.1 7 3.2 8.5c-1.9 3.2-.5 8 1.3 10.6.9 1.3 1.9 2.7 3.3 2.6 1.3-.1 1.8-.8 3.4-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.2-2.6.7-1 1-2 1.4-3-3-1.1-3.6-3.4-3.6-4.5zM13.2 3.9c.7-.9 1.2-2.1 1.1-3.3-1 0-2.3.7-3 1.5-.7.8-1.3 2-1.1 3.2 1.1.1 2.3-.6 3-1.4z" />
    </svg>
  );
}

function WindowsLogo({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" aria-hidden>
      <path fill="#F25022" d="M0 0h10.4v10.4H0z" />
      <path fill="#7FBA00" d="M11.6 0H22v10.4H11.6z" />
      <path fill="#00A4EF" d="M0 11.6h10.4V22H0z" />
      <path fill="#FFB900" d="M11.6 11.6H22V22H11.6z" />
    </svg>
  );
}

/** The store's own logo, in its brand colours (Apple's follows the text). */
export function StoreLogo({ store, size = 24 }: { store: StoreId; size?: number }) {
  switch (store) {
    case 'play':
      return <PlayLogo size={size} />;
    case 'windows':
      return <WindowsLogo size={size} />;
    case 'appstore':
    case 'macos':
      return <AppleLogo size={size} />;
  }
}

/** A store badge linking to the listing or download. */
export function StoreBadge({ store, href, large = false }: { store: StoreId; href: string; large?: boolean }) {
  const copy = STORE_COPY[store];
  return (
    <a
      href={href}
      aria-label={`${copy.kicker} ${copy.label}`}
      className={`inline-flex items-center gap-3 rounded-xl border border-[#a6a6a6] bg-black text-white transition hover:bg-[#1f1f1f] ${
        large ? 'min-h-14 px-5' : 'min-h-12 px-4'
      }`}
    >
      <StoreLogo store={store} size={large ? 24 : 21} />
      <span className="text-start leading-tight">
        <span className={`block font-medium ${store === 'play' ? 'uppercase tracking-wide' : ''} ${large ? 'text-[11px]' : 'text-[10px]'}`}>
          {copy.kicker}
        </span>
        <span className={`block font-semibold tracking-tight ${large ? 'text-xl' : 'text-[17px]'}`}>{copy.label}</span>
      </span>
    </a>
  );
}
