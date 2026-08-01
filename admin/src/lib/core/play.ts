import 'server-only';

import type { PlayLite } from '@/lib/core/play-lite';

/**
 * WHAT PLAY ACTUALLY THINKS IS FOR SALE.
 *
 * The signed index says a pack costs `distro_garuda_dragonized`. Nothing in
 * this panel has ever checked whether that product exists in Play, whether it
 * is active, or whether it can be bought. It cannot: R2 and Play are separate
 * systems that agree only because a human typed the same string into both.
 *
 * They already disagree. `distro_garuda_dragonized` sits in Play Console with
 * ZERO active purchase options while its six siblings have one each, which
 * means the sku resolves to nothing at the billing client, `unlocked` comes
 * back false forever, and the pack shows a price nobody can pay. There is no
 * error anywhere in that chain - not on the device, not in the index, not in
 * the panel. It reads to a user as "the buy button does nothing".
 *
 * This file is the join that makes that visible.
 *
 * ─── ONE-TIME PRODUCTS, NOT `inappproducts` ─────────────────────────────────
 *
 * Play's older `inappproducts` API models a product as a single thing with a
 * `status` of active/inactive. The current model splits it: a `OneTimeProduct`
 * holds a list of PURCHASE OPTIONS, and it is the OPTION that carries the state
 * and the regional prices. That is exactly why the Console shows "1 active
 * purchase option" per product, and why a product can exist, look complete in a
 * list, and still be unsellable.
 *
 * So the product-level question ("does distro_kali exist?") and the sellable
 * question ("can anyone buy it?") are two different reads, and only the second
 * one matters. [PlayProduct.activeOptions] is the number that decides.
 *
 * ─── THE `legacyCompatible` TRAP ────────────────────────────────────────────
 *
 * `buyOption.legacyCompatible` marks the ONE purchase option per product that
 * older Play Billing flows can see. A product whose only active option is not
 * legacy-compatible is fully configured, sells perfectly in the new flow, and
 * returns nothing to a client querying the classic way. Surfaced rather than
 * judged, because which side of that line the launcher sits on depends on its
 * Billing library version, which this panel cannot see.
 *
 * ─── CREDENTIALS ────────────────────────────────────────────────────────────
 *
 * Token minting mirrors `remote-config.ts`: `google-auth-library`, already a
 * dependency, resolving Application Default Credentials. The difference is that
 * Play does not use IAM. The service account has to be invited in PLAY CONSOLE
 * under Users and permissions, with "View financial data" or at minimum app
 * access, and that is a separate grant from anything in Google Cloud. A 401
 * here almost always means that invitation was never sent, so the error says
 * so instead of "unauthorised".
 */

const PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const PLAY_HOST = 'https://androidpublisher.googleapis.com';

export type PurchaseOptionState =
  | 'STATE_UNSPECIFIED'
  | 'DRAFT'
  | 'ACTIVE'
  | 'INACTIVE'
  | 'INACTIVE_PUBLISHED';

export interface PlayPurchaseOption {
  purchaseOptionId: string;
  state: PurchaseOptionState | string;
  /** buy | rent | unknown. Everything sold here is a buy. */
  kind: 'buy' | 'rent' | 'unknown';
  /** True for the one option older Billing flows can see. */
  legacyCompatible: boolean;
  /** How many regions carry a price. Zero means priced nowhere. */
  pricedRegions: number;
  /** A representative price, formatted. US when present, else the first. */
  samplePrice: string | null;
}

export interface PlayProduct {
  productId: string;
  /** The en-US listing title, or the first listing, or null. */
  title: string | null;
  purchaseOptions: PlayPurchaseOption[];
  /** The number that decides whether anyone can buy this. */
  activeOptions: number;
}

export type PlayCatalogue =
  | { ok: true; packageName: string; products: PlayProduct[] }
  | { ok: false; packageName: string | null; error: string };

/** Play's Money: units is an int64 as a STRING, nanos is the fraction. */
interface Money {
  currencyCode?: string;
  units?: string;
  nanos?: number;
}

interface RawPurchaseOption {
  purchaseOptionId?: string;
  state?: string;
  buyOption?: { legacyCompatible?: boolean };
  rentOption?: unknown;
  regionalPricingAndAvailabilityConfigs?: {
    regionCode?: string;
    price?: Money;
    availability?: string;
  }[];
}

interface RawProduct {
  productId?: string;
  listings?: { languageCode?: string; title?: string }[];
  purchaseOptions?: RawPurchaseOption[];
}

async function accessToken(): Promise<string> {
  let GoogleAuth: typeof import('google-auth-library').GoogleAuth;
  try {
    ({ GoogleAuth } = await import('google-auth-library'));
  } catch {
    throw new Error('google-auth-library is not installed. Run `npm i google-auth-library`.');
  }

  // An explicit key wins over ADC. App Hosting's runtime account can be invited
  // to Play directly, but a dedicated publisher account is the more common
  // setup and this lets either work without a code change.
  const raw = process.env.PLAY_SERVICE_ACCOUNT?.trim();
  let auth: InstanceType<typeof GoogleAuth>;
  if (raw) {
    let parsed: { client_email?: string; private_key?: string };
    try {
      parsed = JSON.parse(raw) as { client_email?: string; private_key?: string };
    } catch {
      throw new Error('PLAY_SERVICE_ACCOUNT is set but is not valid JSON.');
    }
    if (!parsed.client_email || !parsed.private_key) {
      throw new Error('PLAY_SERVICE_ACCOUNT is missing client_email or private_key.');
    }
    auth = new GoogleAuth({
      scopes: [PLAY_SCOPE],
      credentials: {
        client_email: parsed.client_email,
        // Secret Manager and .env both mangle real newlines into the two
        // characters backslash-n. Left as-is, the JWT signs against a key that
        // does not parse and the failure is "invalid_grant", which names
        // nothing.
        private_key: parsed.private_key.replace(/\\n/g, '\n'),
      },
    });
  } else {
    auth = new GoogleAuth({ scopes: [PLAY_SCOPE] });
  }

  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) {
    throw new Error(
      'No service credentials for Play. Set PLAY_SERVICE_ACCOUNT, or grant the ' +
        'App Hosting service account access in Play Console under Users and permissions.',
    );
  }
  return token;
}

function formatMoney(m: Money | undefined): string | null {
  if (!m || !m.currencyCode) return null;
  const units = Number(m.units ?? '0');
  const nanos = Number(m.nanos ?? 0);
  if (!Number.isFinite(units)) return null;
  const value = units + nanos / 1e9;
  // Not Intl.NumberFormat: this renders on the server, and a currency the
  // server's locale data does not know throws rather than degrading. The code
  // beside the number is unambiguous and never surprises.
  return `${m.currencyCode} ${value.toFixed(2)}`;
}

function normalise(raw: RawProduct): PlayProduct | null {
  const productId = raw.productId;
  if (!productId) return null;

  const listings = raw.listings ?? [];
  const title =
    listings.find((l) => l.languageCode === 'en-US')?.title ??
    listings[0]?.title ??
    null;

  const purchaseOptions: PlayPurchaseOption[] = (raw.purchaseOptions ?? []).map((o) => {
    const configs = o.regionalPricingAndAvailabilityConfigs ?? [];
    const priced = configs.filter((c) => c.price?.currencyCode);
    const sample = priced.find((c) => c.regionCode === 'US') ?? priced[0];

    return {
      purchaseOptionId: o.purchaseOptionId ?? '(unnamed)',
      state: o.state ?? 'STATE_UNSPECIFIED',
      kind: o.buyOption ? 'buy' : o.rentOption ? 'rent' : 'unknown',
      legacyCompatible: o.buyOption?.legacyCompatible === true,
      pricedRegions: priced.length,
      samplePrice: formatMoney(sample?.price),
    };
  });

  return {
    productId,
    title,
    purchaseOptions,
    activeOptions: purchaseOptions.filter((o) => o.state === 'ACTIVE').length,
  };
}

/**
 * Every one-time product on an app, with its purchase options.
 *
 * NEVER THROWS. A panel screen whose job is to report a mismatch must not blank
 * itself because the reporting API is down; the caller renders `ok: false` as a
 * banner and still shows the index side of the join, which is the half that is
 * always readable. An unreachable Play is a different fact from "the sku does
 * not exist", and conflating them would invent the exact false alarm this file
 * was written to prevent.
 */
export async function listPlayProducts(packageName: string | null): Promise<PlayCatalogue> {
  if (!packageName) {
    return { ok: false, packageName: null, error: 'This app has no Android package name in the registry.' };
  }

  try {
    const token = await accessToken();
    const products: PlayProduct[] = [];
    let pageToken: string | undefined;

    // Bounded. Seven products today; a runaway token loop against a paid API is
    // not a failure mode worth leaving open for a page that renders on request.
    for (let page = 0; page < 10; page++) {
      const url = new URL(
        `${PLAY_HOST}/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/oneTimeProducts`,
      );
      url.searchParams.set('pageSize', '100');
      if (pageToken) url.searchParams.set('pageToken', pageToken);

      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
        cache: 'no-store',
      });

      if (res.status === 401 || res.status === 403) {
        return {
          ok: false,
          packageName,
          error:
            `Play refused the request (${res.status}). The service account needs to be invited in ` +
            'Play Console under Users and permissions, for this app. An IAM role is not enough.',
        };
      }
      if (res.status === 404) {
        return {
          ok: false,
          packageName,
          error: `Play has no app with package name '${packageName}'. Check lib/registry.ts.`,
        };
      }
      if (!res.ok) {
        return { ok: false, packageName, error: `Play returned ${res.status}: ${await res.text()}` };
      }

      const body = (await res.json()) as {
        oneTimeProducts?: RawProduct[];
        onetimeproducts?: RawProduct[];
        nextPageToken?: string;
      };

      // Both spellings accepted. The resource is documented as
      // `monetization.onetimeproducts` while its URL segment and JSON key are
      // `oneTimeProducts`; taking either costs one `??` and removes a class of
      // silent empty result that would read as "no products configured".
      const batch = body.oneTimeProducts ?? body.onetimeproducts ?? [];
      for (const p of batch) {
        const n = normalise(p);
        if (n) products.push(n);
      }

      pageToken = body.nextPageToken;
      if (!pageToken) break;
    }

    products.sort((a, b) => a.productId.localeCompare(b.productId));
    return { ok: true, packageName, products };
  } catch (e) {
    return { ok: false, packageName, error: (e as Error).message };
  }
}

/**
 * The catalogue in the shape the builders receive as a prop.
 *
 * Lives here rather than in play-lite so the full [PlayCatalogue] type never
 * has to be imported outside server code. Price comes from an ACTIVE option
 * only: a draft option's price is a number nobody can pay, and showing it
 * beside "not active" would read as a contradiction.
 */
export function playLite(c: PlayCatalogue): PlayLite {
  if (!c.ok) return { ok: false, error: c.error };
  return {
    ok: true,
    products: c.products.map((p) => {
      const active = p.purchaseOptions.filter((o) => o.state === 'ACTIVE');
      return {
        productId: p.productId,
        title: p.title,
        activeOptions: p.activeOptions,
        samplePrice: active.find((o) => o.samplePrice)?.samplePrice ?? null,
      };
    }),
  };
}
