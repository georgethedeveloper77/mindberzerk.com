import 'server-only';

/**
 * PHASE C11 - Remote Config, scoped to what the launcher actually reads.
 *
 * ## Token minting is self-contained here, on purpose
 *
 * This needs a Google OAuth access token for the Remote Config REST API.
 * `auth.ts` handles SESSION verification - the admin's Google sign-in - which is
 * a different credential: the user's identity, not the service's. Rather than
 * assume auth.ts exposes a service-token helper it may not have, this mints its
 * own via `google-auth-library`, already present transitively, which picks up
 * the App Hosting service account through Application Default Credentials. If
 * auth.ts later grows a shared `serviceToken(scopes)`, swap [accessToken] for
 * it; nothing else here changes.
 *
 * ## THE SCOPE IS THE POINT
 *
 * An earlier mock of this screen had six feature gates and three kill switches.
 * Reading the source, the launcher consumes exactly ONE Remote Config value:
 * `cdn_base_url`, read on the Flutter side and written to a file for the
 * headless worker (`CdnConfig`). The gates in the mock - `drawer_cube_enabled`,
 * `verbose_boot_default` and the rest - are per-theme prefs stored on device.
 * There is no RC key behind them, so a panel toggle would write a parameter
 * nothing fetches and report a change that never happens.
 *
 * `minAppVersion` is likewise NOT a global key. It lives per-pack inside the
 * signed index (`CdnIndex`), and `PackDownloader` enforces it there. Managing it
 * here would be a second, unsigned source of truth for a value the device only
 * trusts from the signature.
 *
 * So this file manages the keys that exist, and [KNOWN_KEYS] is the allowlist.
 * Adding a key here without the launcher reading it is the mistake this scope
 * exists to prevent, so each entry records where it is consumed.
 *
 * ## Writes are concurrency-safe or they are refused
 *
 * Remote Config has one template per project, shared with anyone else who edits
 * it in the Firebase console. The REST API hands out an ETag with the template
 * and refuses a write whose ETag is stale. This module surfaces that: a publish
 * carries the ETag it read, and a 409 from Google becomes "someone changed the
 * template, reload" rather than a silent overwrite of their change.
 *
 * ## One template, all apps
 *
 * Remote Config is per Firebase PROJECT, and five apps share one project. So a
 * key here is visible to every app unless it is gated by an RC condition. That
 * is why `cdn_base_url` is the launcher's and nobody else's by convention, and
 * why this panel shows the owning app beside each key rather than pretending the
 * template is per-app.
 */

export interface RcKey {
  key: string;
  /** Human note: what reads it and what it does. Shown in the UI. */
  readBy: string;
  /** The app that owns it, for the shared-template caveat. */
  app: string;
  /** Validation for the value, run before a write is allowed. */
  validate: (value: string) => string | null;
}

/**
 * THE ALLOWLIST. A key not here cannot be edited by this panel. Grows only when
 * the launcher grows a reader for it.
 */
export const KNOWN_KEYS: RcKey[] = [
  {
    key: 'cdn_base_url',
    readBy: 'Flutter side, written to .index/base_url for PackSyncWorker (CdnConfig)',
    app: 'g-launcher',
    validate: (v) => {
      // Mirror CdnConfig.baseUrl exactly: anything not plainly https in
      // 12..200 chars is ignored on device, so refuse it here rather than
      // publish a value every phone will silently drop back to default.
      if (!v.startsWith('https://')) return 'Must start with https:// or the device ignores it.';
      if (v.length < 12 || v.length > 200) return 'Must be 12 to 200 characters.';
      return null;
    },
  },
];

export function knownKey(key: string): RcKey | undefined {
  return KNOWN_KEYS.find((k) => k.key === key);
}

interface RcParameter {
  defaultValue?: { value: string };
  valueType?: string;
  description?: string;
}

interface RcTemplate {
  parameters?: Record<string, RcParameter>;
  version?: { versionNumber?: string; updateTime?: string; updateUser?: { email?: string } };
}

export interface RcState {
  etag: string;
  /** Only the keys this panel manages, joined with their catalogue metadata. */
  managed: {
    key: string;
    value: string | null;
    readBy: string;
    app: string;
  }[];
  /** Keys present in the template that this panel does NOT manage. Shown, not editable. */
  foreign: { key: string; value: string | null }[];
  versionNumber: string | null;
  updatedBy: string | null;
  updateTime: string | null;
}

function projectId(): string {
  const id =
    process.env.GCP_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    process.env.FIREBASE_PROJECT_ID;
  if (!id) throw new Error('GCP_PROJECT is not set.');
  return id;
}

const RC_SCOPE = 'https://www.googleapis.com/auth/firebase.remoteconfig';

/**
 * An OAuth access token for the service account, scoped to Remote Config.
 *
 * `google-auth-library` resolves Application Default Credentials, which on App
 * Hosting is the runtime service account - no key file. That account needs the
 * Firebase Remote Config Admin role, granted once in IAM.
 *
 * A MISSING CREDENTIAL THROWS A CLEAN MESSAGE, not a bare ReferenceError. The
 * earlier cut referenced this function without defining it, so the config page
 * surfaced "accessToken is not defined" - a JS internal leaking to an admin. The
 * message here names the actual fix instead.
 */
async function accessToken(): Promise<string> {
  let GoogleAuth: typeof import('google-auth-library').GoogleAuth;
  try {
    ({ GoogleAuth } = await import('google-auth-library'));
  } catch {
    throw new Error(
      'google-auth-library is not installed. Run `npm i google-auth-library`.',
    );
  }
  const auth = new GoogleAuth({ scopes: [RC_SCOPE] });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) {
    throw new Error(
      'no service credentials. Grant the App Hosting service account the ' +
        'Firebase Remote Config Admin role.',
    );
  }
  return token;
}

const RC_HOST = 'https://firebaseremoteconfig.googleapis.com';

/**
 * Read the live template plus its ETag.
 *
 * The service account needs the Firebase Remote Config Admin role.
 */
export async function readRemoteConfig(): Promise<RcState> {
  const token = await accessToken();
  const res = await fetch(`${RC_HOST}/v1/projects/${projectId()}/remoteConfig`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!res.ok) {
    throw new Error(`Remote Config read failed: ${res.status} ${await res.text()}`);
  }

  // The ETag is in the header, not the body, and the write API requires it
  // verbatim. Missing it means no safe write is possible, so that is an error
  // rather than a blank string that would later 400.
  const etag = res.headers.get('etag');
  if (!etag) throw new Error('Remote Config returned no ETag; cannot edit safely.');

  const template = (await res.json()) as RcTemplate;
  const params = template.parameters ?? {};

  const managed = KNOWN_KEYS.map((k) => ({
    key: k.key,
    value: params[k.key]?.defaultValue?.value ?? null,
    readBy: k.readBy,
    app: k.app,
  }));

  const managedKeys = new Set(KNOWN_KEYS.map((k) => k.key));
  const foreign = Object.entries(params)
    .filter(([key]) => !managedKeys.has(key))
    .map(([key, p]) => ({ key, value: p.defaultValue?.value ?? null }));

  return {
    etag,
    managed,
    foreign,
    versionNumber: template.version?.versionNumber ?? null,
    updatedBy: template.version?.updateUser?.email ?? null,
    updateTime: template.version?.updateTime ?? null,
  };
}

/**
 * Write one managed key, preserving everything else in the template.
 *
 * READ, MERGE, WRITE, exactly like the index: the whole template is fetched,
 * the one parameter is replaced, and the lot is put back with the ETag. Writing
 * only the changed parameter is not an option the API offers - a publish
 * replaces the whole template - so anything not carried across is deleted, which
 * is why foreign keys are read and re-sent untouched.
 */
export async function writeRemoteConfigKey(
  key: string,
  value: string,
  etag: string,
): Promise<{ ok: true; versionNumber: string | null } | { ok: false; error: string; stale?: boolean }> {
  const meta = knownKey(key);
  if (!meta) return { ok: false, error: `${key} is not a managed key.` };

  const invalid = meta.validate(value);
  if (invalid) return { ok: false, error: invalid };

  const token = await accessToken();

  // Re-read immediately before writing so foreign keys are current, not from a
  // page render that may be minutes old.
  const current = await fetch(`${RC_HOST}/v1/projects/${projectId()}/remoteConfig`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!current.ok) return { ok: false, error: `Re-read failed: ${current.status}` };
  const freshEtag = current.headers.get('etag') ?? etag;
  const template = (await current.json()) as RcTemplate;

  // If the template moved between the page render and now, refuse rather than
  // clobber whoever changed it. The UI turns this into "reload and retry".
  if (freshEtag !== etag) {
    return {
      ok: false,
      stale: true,
      error: 'The template changed since this page loaded. Reload to see the current values.',
    };
  }

  template.parameters = template.parameters ?? {};
  template.parameters[key] = {
    defaultValue: { value },
    valueType: 'STRING',
    description: meta.readBy,
  };

  const res = await fetch(`${RC_HOST}/v1/projects/${projectId()}/remoteConfig`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=UTF-8',
      // The ETag is what makes this a compare-and-swap. '*' would force the
      // write and defeat the whole safety property, so it is never used.
      'If-Match': etag,
    },
    body: JSON.stringify(template),
  });

  if (res.status === 409) {
    return { ok: false, stale: true, error: 'Someone else published first. Reload and retry.' };
  }
  if (!res.ok) {
    return { ok: false, error: `Publish failed: ${res.status} ${await res.text()}` };
  }

  const written = (await res.json()) as RcTemplate;
  return { ok: true, versionNumber: written.version?.versionNumber ?? null };
}
