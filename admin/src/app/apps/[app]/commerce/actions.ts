'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { addManualProduct, removeManualProduct, type ManualProduct } from '@/lib/core/product-ids';
import { isAppId, type AppId } from '@/lib/core/registry';

/**
 * The panel's own list of product IDs.
 *
 * Adding one here does NOT create it in Play. Play products are created in Play
 * Console, permanently, and this list only decides what the panel's pickers
 * offer so that a permanent identifier is chosen from a list rather than typed
 * twice and hoped over.
 */

export type ProductListResult =
  | { ok: true; products: ManualProduct[] }
  | { ok: false; error: string };

export async function addProductIdAction(
  app: string,
  productId: string,
  note: string,
): Promise<ProductListResult> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };

  const result = await addManualProduct(app as AppId, productId, note);
  if (result.ok) revalidatePath(`/apps/${app}/commerce`);
  return result;
}

export async function removeProductIdAction(
  app: string,
  productId: string,
): Promise<ProductListResult> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) return { ok: false, error: 'Not authorised' };
    throw e;
  }
  if (!isAppId(app)) return { ok: false, error: `Unknown app '${app}'` };

  const result = await removeManualProduct(app as AppId, productId);
  if (result.ok) revalidatePath(`/apps/${app}/commerce`);
  return result;
}
