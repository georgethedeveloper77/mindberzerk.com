/**
 * Public copy for mindberzerk.com/g-vpn.
 *
 * English only in this first release. Everything visible lives here as data,
 * so the app's other seven locales arrive as sibling objects without touching
 * a component. Claims are limited to what the shipping Android build does:
 * Pro and G Servers join this file when Pro is on sale. Store links are not
 * here: they come from Remote Config (see site-config.ts), so a store appears
 * when its link is set in the admin Config screen, never as a placeholder.
 */

import type { IconName } from './icons';

export const GVPN_PACKAGE = 'com.mindberzerk.gvpn';

/** Fallbacks when Remote Config is unreadable or a key was never set. */
export const DEFAULT_PLAY_URL = `https://play.google.com/store/apps/details?id=${GVPN_PACKAGE}`;
export const DEFAULT_MIN_ANDROID = '7.0';

/** The app's own artwork, copied from apps/g_vpn/assets/brand into public/. */
export const MARK_SRC = '/g-vpn/mark.png';
export const ICON_SRC = '/g-vpn/icon-512.png';
export const PRIVACY_URL = 'https://cdn.mindberzerk.com/site/legal/g-vpn/privacy.html';
export const TERMS_URL = 'https://cdn.mindberzerk.com/site/legal/g-vpn/terms.html';

/**
 * The same Worker the app's "Am I protected?" check calls. It answers from
 * Cloudflare request metadata only and stores nothing.
 */
export const WHOAMI_URL = 'https://gvpn-whoami.mindberzerk.workers.dev';

export type Tone = 'brand' | 'good' | 'violet' | 'bad';

export interface Card {
  icon: IconName;
  title: string;
  body: string;
  tone?: Tone;
}

export interface ServerOption {
  tag: string;
  tone: Tone;
  protocols: string;
  title: string;
  body: string;
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
  return text.replaceAll('{min}', minAndroid);
}

export interface Faq {
  q: string;
  a: string;
}

export const COPY = {
  meta: {
    title: 'G VPN: free VPN and network tools for Android',
    description:
      'Free VPN servers, your own WireGuard servers, and the tools to see who is on your Wi-Fi, what is blocked and how fast you really are. No account, no ads.',
  },
  nav: [
    { label: 'Features', href: '#features' },
    { label: 'Tools', href: '#tools' },
    { label: 'Download', href: '#download' },
    { label: 'Questions', href: '#faq' },
  ],
  download: 'Download free',
  hero: {
    title: 'See your network. Then secure it.',
    sub: 'Free servers or your own. Plus the tools to see who is on your Wi-Fi, what is blocked and how fast you really are.',
    secondary: 'See the tools',
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
  trust: [
    { icon: 'noAccount', title: 'No account', body: 'Open it and connect. No email, no sign-up.' },
    { icon: 'noAds', title: 'No ads', body: 'No ad SDK in the app at all.' },
    { icon: 'gift', title: 'Everything free', body: 'Every server and every tool.' },
    { icon: 'globe', title: 'In 8 languages', body: 'Including Arabic and Persian, right to left.' },
  ] satisfies Card[],
  servers: {
    heading: 'Choose how you connect',
    options: [
      {
        tag: 'FREE',
        tone: 'good',
        protocols: 'OpenVPN · SSTP',
        title: 'Free servers',
        body: 'Volunteer servers from the VPN Gate project in dozens of countries, ranked by speed and stability so the best one is first.',
      },
      {
        tag: 'YOURS',
        tone: 'violet',
        protocols: 'WireGuard',
        title: 'Your own server',
        body: 'Connect to your router, VPS or home server. Scan its QR code or open a config file.',
      },
    ] satisfies ServerOption[],
    features: [
      { title: 'Shield', body: 'Blocks known malware and phishing sites' },
      { title: 'Auto-connect', body: 'Protects you on public Wi-Fi' },
      { title: 'Pause', body: 'From the notification or the Quick Settings tile' },
      { title: 'App rules', body: 'Let banking apps go direct' },
    ],
  },
  tools: {
    heading: 'Know your network',
    items: [
      { icon: 'gauge', title: 'Speed test', body: 'Download, upload and video quality' },
      { icon: 'pulse', title: 'Ping', body: 'Live response time and jitter' },
      { icon: 'devices', title: 'Devices', body: 'Who is on your Wi-Fi' },
      { icon: 'wifi', title: 'Wi-Fi safety', body: 'Is this network safe to use?' },
      { icon: 'star', title: 'Provider ratings', body: 'How your internet provider compares' },
      { icon: 'alert', title: 'Data breaches', body: 'What leaked lately, and your passwords', tone: 'bad' },
      { icon: 'blocked', title: "What's blocked", body: 'Sites blocked on this network' },
      { icon: 'bell', title: 'Alerts', body: 'New devices, unsafe Wi-Fi, a weekly report' },
    ] satisfies Card[],
  },
  platforms: {
    heading: 'Get G VPN',
  },
  faq: {
    heading: 'Questions',
    items: [
      {
        q: 'Is G VPN free?',
        a: 'Yes. Every server and every tool is free, with no account and no ads.',
      },
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
        a: "Some networks block VPNs too. Try a different free server or protocol, or open Tools, What's blocked to see what this network stops.",
      },
      {
        q: 'Which phones does it work on?',
        a: 'Any phone or tablet with Android {min} or later.',
      },
    ] satisfies Faq[],
  },
  footer: {
    by: 'G VPN by Mindberzerk',
    privacy: 'Privacy',
    terms: 'Terms',
    studio: 'mindberzerk.com',
  },
};
