'use server';

import { revalidatePath } from 'next/cache';

import { NotAuthorised, requireAdmin } from '@/lib/core/auth';
import { addManualProduct, removeManualProduct, type ManualProduct } from '@/lib/core/product-ids';
import { isAppId, type AppId } from '@/lib/core/registry';
import {
  repairEntitlements,
  type EntitlementRepair,
} from '@/lib/g-launcher/repair-entitlements';

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

/**
 * Repair every entitlement's grants from the catalogue.
 *
 * ─── HERE, NOT IN THE DISTROS ACTIONS ───────────────────────────────────────
 *
 * I first put this beside `republishDistroAction`, which was the wrong file for
 * two reasons. The fault is catalogue-wide rather than per distro, and this
 * module is the one that already gates on `requireAdmin` for every export; the
 * distros actions gate differently, and an operation that rewrites a signed
 * index should not be the one place where that differs.
 *
 * It is also the page that already says `unlocks nothing` in its own words, so
 * the button belongs beside the warning describing what it fixes.
 *
 * ─── `deleteOrphans` DEFAULTS OFF, AND SHOULD STAY A DELIBERATE ACT ─────────
 *
 * Removing an entitlement is the one operation here that takes access away.
 * `distro_kali_2024` and `distro_pop_os_2204` are orphans only because their
 * Play products were replaced, and anyone who bought under the old id loses
 * their grant the moment the entry goes.
 */
export async function repairEntitlementsAction(
  app: string,
  deleteOrphans = false,
): Promise<EntitlementRepair> {
  try {
    await requireAdmin();
  } catch (e) {
    if (e instanceof NotAuthorised) {
      return { changes: [], orphans: [], ok: false, error: 'Not authorised' };
    }
    throw e;
  }
  if (!isAppId(app)) {
    return { changes: [], orphans: [], ok: false, error: 'Unknown app' };
  }

  const out = await repairEntitlements(app as AppId, { deleteOrphans });
  if (out.ok && out.changes.length > 0) {
    revalidatePath(`/apps/${app}/commerce`);
    revalidatePath(`/apps/${app}/distros`);
    revalidatePath(`/apps/${app}/icons`);
  }
  return out;
}
