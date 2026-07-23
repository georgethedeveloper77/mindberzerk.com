import { redirect } from 'next/navigation';

/**
 * The old publish route, kept as a redirect.
 *
 * It was bookmarked and it is in the mobile home-screen shortcut, so deleting it
 * would 404 the one page you open from a phone. Publishing is now per app; this
 * lands on the launcher, which is what the old route always meant.
 */
export default function LegacyPublishPage() {
  redirect('/apps/g-launcher/publish');
}
