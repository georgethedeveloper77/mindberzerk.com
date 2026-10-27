'use server';

import { requireAdmin } from '@/lib/core/auth';

import { PROVIDERS_BASE, type ProviderEdit } from './providers';

/**
 * Saves one provider's display details to the Worker. Runs on the server:
 * the admin token never reaches the browser, and the caller is checked
 * here, not trusted from the page.
 */
export async function saveProvider(asn: number, edit: ProviderEdit): Promise<{ ok: boolean; message: string }> {
  await requireAdmin();
  const token = process.env.GVPN_ADMIN_TOKEN;
  if (!token) return { ok: false, message: 'GVPN_ADMIN_TOKEN is not set' };
  if (!Number.isInteger(asn) || asn <= 0) return { ok: false, message: 'Unknown provider' };
  try {
    const res = await fetch(`${PROVIDERS_BASE}/admin/providers/${asn}`, {
      method: 'PUT',
      cache: 'no-store',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(edit),
    });
    if (!res.ok) return { ok: false, message: `Worker answered ${res.status}` };
    return { ok: true, message: 'Saved. Phones see it on their next check.' };
  } catch (e) {
    return { ok: false, message: (e as Error).message };
  }
}
