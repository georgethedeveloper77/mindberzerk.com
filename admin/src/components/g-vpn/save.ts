import type { Overrides } from '@/lib/g-vpn/servers';

/** Saves overrides (optional) and refreshes the list through the panel route. */
export async function saveAndRefresh(overrides?: Overrides): Promise<{ ok: boolean; message: string }> {
  try {
    const res = await fetch('/api/g-vpn', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(overrides ? { action: 'save', overrides } : { action: 'refresh' }),
    });
    const body = (await res.json().catch(() => ({}))) as { servers?: number; error?: string };
    return res.ok
      ? { ok: true, message: `Live: ${body.servers ?? 0} servers listed` }
      : { ok: false, message: body.error ?? `Failed (${res.status})` };
  } catch (e) {
    return { ok: false, message: (e as Error).message };
  }
}
