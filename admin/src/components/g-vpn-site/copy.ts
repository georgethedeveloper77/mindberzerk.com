/**
 * Public copy for mindberzerk.com/gvpn.
 *
 * English only in this release. Everything visible lives here as data, so
 * the app's other seven locales arrive as sibling objects without touching a
 * component. Claims are limited to what the shipping Android build does: Pro
 * and G Servers join this file when Pro is on sale. Store links are not here:
 * they come from Remote Config (see site-config.ts), and live numbers come
 * from the servers Worker (see live-servers.ts).
 */

export const GVPN_PACKAGE = 'com.mindberzerk.gvpn';

/** Fallbacks when Remote Config is unreadable or a key was never set. */
export const DEFAULT_PLAY_URL = `https://play.google.com/store/apps/details?id=${GVPN_PACKAGE}`;
export const DEFAULT_MIN_ANDROID = '7.0';

export const PRIVACY_URL = 'https://cdn.mindberzerk.com/site/legal/g-vpn/privacy.html';
export const TERMS_URL = 'https://cdn.mindberzerk.com/site/legal/g-vpn/terms.html';
export const CONTACT_EMAIL = 'info@mindberzerk.com';

/**
 * The same Worker the app's "Am I protected?" check calls. It answers from
 * Cloudflare request metadata only and stores nothing.
 */
export const WHOAMI_URL = 'https://gvpn-whoami.mindberzerk.workers.dev';

/** lib/g-vpn/world-map.json: equirectangular, latitude 80 to -56. */
export const MAP_PROJECTION = { width: 1200, height: 560, north: 80, south: -56 } as const;

/** The app's own artwork, from apps/g_vpn/assets/brand and screenshots. */
export const MARK_SRC = '/gvpn/mark.png';
export const ICON_SRC = '/gvpn/icon-512.png';

export interface Screen {
  src: string;
  alt: string;
  caption: string;
}

/** Real phone screenshots, cropped from the Play listing artwork. */
export const SCREENS = {
  home: { src: '/gvpn/screens/01.webp', alt: 'G VPN connected to a free server in South Korea', caption: 'Private browsing in one tap' },
  country: { src: '/gvpn/screens/02.webp', alt: 'G VPN browsing from Frankfurt, Germany', caption: 'Browse from any country' },
  servers: { src: '/gvpn/screens/03.webp', alt: 'Free servers in Thailand ranked by speed', caption: 'Free servers, ranked by speed' },
  tools: { src: '/gvpn/screens/04.webp', alt: 'The Tools tab with a Wi-Fi safety warning', caption: 'Know if your Wi-Fi is safe' },
  rules: { src: '/gvpn/screens/05.webp', alt: 'Rules for Shield, auto-connect and apps', caption: 'Protection that runs itself' },
} satisfies Record<string, Screen>;

/** Screen width the 600px screenshots are drawn at. */
export const SCREEN_RATIO = { width: 600, height: 1354 };

export type Tone = 'brand' | 'good' | 'violet' | 'bad';

export interface Card {
  title: string;
  body: string;
}

export interface KeyCard extends Card {
  protocols?: string;
}

export type Tool = Card;

export interface Step {
  title: string;
  body: string;
}

export interface Faq {
  q: string;
  a: string;
}

export type StoreId = 'play' | 'appstore' | 'windows' | 'macos';

/** A store the page offers: its link comes from Remote Config. */
export interface StoreLink {
  id: StoreId;
  href: string;
}

/** Brand wording per store, as each store's own badge says it. */
export const STORE_COPY: Record<StoreId, { name: string; kicker: string; label: string; requirement: string }> = {
  play: { name: 'Google Play', kicker: 'GET IT ON', label: 'Google Play', requirement: 'Android {min} or later' },
  appstore: { name: 'App Store', kicker: 'Download on the', label: 'App Store', requirement: 'iPhone and iPad' },
  windows: { name: 'Windows', kicker: 'Download for', label: 'Windows', requirement: 'Windows 10 and 11' },
  macos: { name: 'macOS', kicker: 'Download for', label: 'macOS', requirement: 'Apple silicon and Intel' },
};

/** Fills the `{min}` slot with the minimum Android version. */
export function withMinAndroid(text: string, minAndroid: string): string {
  return text.split('{min}').join(minAndroid);
}

export const COPY = {
  meta: {
    title: 'G VPN: free VPN and network tools for Android',
    description:
      'Free VPN servers ranked by speed, your own WireGuard servers, and the tools to see who is on your Wi-Fi, what is blocked and how fast you really are. No account, no ads.',
  },
  nav: [
    { label: 'Features', href: '#features' },
    { label: 'Your IP', href: '#exposed' },
    { label: 'Tools', href: '#tools' },
    { label: 'How it works', href: '#how' },
    { label: 'Questions', href: '#faq' },
  ],
  hero: {
    eyebrow: 'Free VPN and network tools',
    title: 'See your network.',
    accent: 'Then secure it.',
    sub: 'Free servers ranked by speed, or your own. Plus the tools to see who is on your Wi-Fi, what is blocked and how fast you really are.',
    secondary: 'See what sites see',
  },
  stats: {
    live: 'Live',
    servers: 'Free',
    countries: 'Countries',
    tools: 'Tools',
    languages: 'Languages',
    languageCount: 8,
  },
  /** The marker card on the map. */
  map: {
    free: '{count} free server',
    freePlural: '{count} free servers',
    ours: 'Our server',
    online: 'Online',
    offline: 'Offline',
  },
  keys: {
    label: 'Key features',
    items: [
      {
        title: 'Free servers, fastest first',
        body: 'VPN Gate servers in dozens of countries, ranked by speed and uptime.',
        protocols: 'OpenVPN · SSTP',
      },
      {
        title: 'Know your network',
        body: 'Speed, ping, devices on your Wi-Fi, open ports and leaked passwords.',
      },
      {
        title: 'Your own server',
        body: 'Router, VPS or home server. Scan its QR code or open the config.',
        protocols: 'WireGuard',
      },
    ] satisfies KeyCard[],
  },
  exposed: {
    eyebrow: 'What sites see',
    heading: 'Every site you open sees this.',
    body: 'Your IP gives away your city and your internet provider. Tap the button to see what changes when G VPN is on.',
    points: [
      { lead: 'New address.', text: 'Sites see the server, not you.' },
      { lead: 'Encrypted Wi-Fi.', text: "Public networks can't read your traffic." },
      { lead: 'Shield.', text: 'Known malware and phishing sites never load.' },
    ],
  },
  demo: {
    off: 'Not protected',
    connecting: 'Connecting',
    on: 'Protected',
    tapOn: 'Tap to connect',
    tapOff: 'Tap to disconnect',
    ipLabel: 'IP',
    locationLabel: 'Location',
    /** A VPN Gate server, the kind the free tier connects to. */
    serverIp: '219.100.37.xx',
    serverLocation: 'Japan',
  },
  why: {
    eyebrow: 'Why G VPN',
    heading: 'Private by design, free by default.',
    aside: 'No sign-up, no ad SDK, nothing to pay for. The whole app works the moment it opens.',
    items: [
      { title: 'No account', body: 'Open it and connect. No email, no sign-up.' },
      { title: 'No ads', body: 'There is no ad SDK in the app at all.' },
      { title: 'Shield', body: 'Blocks known malware and phishing sites.' },
      { title: 'Auto-connect', body: 'Turns itself on when you join public Wi-Fi.' },
    ] satisfies Card[],
  },
  tools: {
    eyebrow: 'Network tools',
    heading: 'Know your network.',
    aside: 'The checks a network engineer would run, one tap each.',
    items: [
      { title: 'Speed test', body: 'Download, upload and video quality' },
      { title: 'Ping', body: 'Live response time and jitter' },
      { title: 'Service status', body: 'Is an app reachable or blocked here?' },
      { title: 'Traceroute', body: 'Every stop on the way to a site' },
      { title: 'Devices', body: 'Who is on your Wi-Fi' },
      { title: 'Router check', body: 'Ports your devices opened' },
      { title: 'Open ports', body: 'Risky ports on a device or server' },
      { title: 'Password check', body: 'Has it been leaked?' },
    ] satisfies Tool[],
  },
  how: {
    eyebrow: 'How it works',
    heading: 'Protected in three taps.',
    aside: 'No setup, no account. Install and connect.',
    steps: [
      { title: 'Install G VPN', body: 'Free, with nothing to sign up for.' },
      { title: 'Pick a server', body: 'The fastest free server is already first. Or add your own.' },
      { title: 'Tap connect', body: 'Your address changes and your Wi-Fi traffic is encrypted.' },
    ] satisfies Step[],
  },
  screens: {
    eyebrow: 'Inside the app',
    heading: 'Made to be read at a glance.',
  },
  faq: {
    eyebrow: 'Questions',
    heading: 'Answers before you install.',
    items: [
      { q: 'Is G VPN free?', a: 'Yes. Every server and every tool is free, with no account and no ads.' },
      {
        q: 'Who runs the free servers?',
        a: 'Volunteers in the VPN Gate project, not us. G VPN tests and ranks them so you get a fast, stable one, but treat them like any public network: use HTTPS sites.',
      },
      {
        q: 'Can I use my own server?',
        a: 'Yes. Any WireGuard config works: a router, a VPS or a home server. Scan its QR code or open the file.',
      },
      {
        q: 'Why does a site still not open?',
        a: 'Some networks block VPNs too. Try another free server or protocol, or open Tools, Service status to see what this network stops.',
      },
      {
        q: 'Will it slow my internet down?',
        a: 'A little, like any VPN. Servers are ranked by measured speed, and the built-in speed test shows the difference.',
      },
      { q: 'Which phones does it work on?', a: 'Any phone or tablet with Android {min} or later.' },
    ] satisfies Faq[],
  },
  cta: {
    eyebrow: 'Free to download',
    /** Used instead when exactly one store is offered. */
    eyebrowOneStore: 'Free on {store}',
    heading: 'See your network. Then secure it.',
    body: 'Install G VPN, tap connect, and check what your Wi-Fi is hiding.',
  },
  footer: {
    about: 'Free VPN servers, your own WireGuard servers and the tools to check either.',
    columns: {
      product: 'Product',
      support: 'Support',
      studio: 'Mindberzerk',
    },
    privacy: 'Privacy',
    terms: 'Terms',
    help: 'Help',
    studioSite: 'mindberzerk.com',
    moreApps: 'More apps',
    copyright: '© 2026 Mindberzerk',
    by: 'G VPN by Mindberzerk',
  },
};
