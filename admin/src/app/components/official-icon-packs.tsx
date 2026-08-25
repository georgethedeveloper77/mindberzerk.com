'use client';

import { useState } from 'react';

import { BASE_PACK_ID, DISTRO_RECIPES, missingSkus } from '@/lib/g-launcher/distro-recipes';
import { planPublish } from '@/lib/g-launcher/derived-pack';

/**
 * THE FOURTEEN OFFICIAL ICON PACKS, AND ONE BUTTON.
 *
 * ─── WHY THERE IS NO FORM ───────────────────────────────────────────────────
 *
 * Every other publishing screen in this panel is a form, because every other
 * pack has content to author. These have none: a derived pack is a colour and a
 * pointer at `arcticons-line`, the colours are the distros' own brand values,
 * and they live in `distro-recipes.ts` where changing one changes a shipped
 * product rather than a draft.
 *
 * So this is a catalogue and a button. The most useful thing it can do is show
 * the state of all fourteen at once, because the failure worth catching is not
 * in any one pack: it is a missing Play product, which publishes fine and then
 * shows a permanent Buy button on something nothing can charge for.
 */

interface Published {
  packId: string;
  version: number;
  sku: string;
}

/** What the CDN currently says about a pack. Absent means never published. */
export interface LiveState {
  version: number;
  listed: boolean;
}

export function OfficialIconPacks({
  app,
  live,
}: {
  app: string;
  /**
   * Keyed by pack id, read from the signed index by the page.
   *
   * Passed in rather than fetched here: this is a client component and the page
   * already holds a verified index, so fetching again would be a second read of
   * a document the server just parsed, and it would be unauthenticated.
   */
  live: Record<string, LiveState>;
}) {
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{
    published: Published[];
    granted: string[];
    totalBytes: number;
    missingSkus: string[];
    hidBase: boolean;
  } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const plan = planPublish();
  const missing = missingSkus();

  async function publish() {
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const res = await fetch('/api/publish/official-icons', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ app }),
      });
      const body = await res.json();
      if (!res.ok) {
        setError(body.error ?? `Publish failed with ${res.status}.`);
        return;
      }
      setResult(body);
    } catch (e) {
      // The network, not the server. Distinguished because the two need
      // different next steps and "Publish failed" covers both uselessly.
      setError(`Could not reach the server: ${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="rounded-[18px] border border-site-line bg-site-card p-3 shadow-site-soft sm:p-4">
      <div className="mb-1 flex flex-wrap items-baseline gap-x-3">
        <h2 className="text-[13px] font-medium">Official icon packs</h2>
        <span className="text-[11.5px] text-site-ink-3">
          {DISTRO_RECIPES.length} distros, one set of drawings
        </span>
      </div>

      <p className="mb-3 text-[11.5px] leading-relaxed text-site-ink-3">
        Each pack is a colour and a pointer at <code>arcticons-line</code>, which
        carries the 13,622 drawings all of them share. There is no art to upload:
        all fourteen together are {(plan.totalBytes / 1024).toFixed(1)} KB.
      </p>

      {missing.length > 0 ? (
        <div className="mb-3 rounded-[10px] bg-site-plan-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-plan">
          <b>
            {missing.length} of {DISTRO_RECIPES.length} have no Play product yet.
          </b>{' '}
          They will publish and work, but nothing can charge for them until the
          product exists in Play Console. A device shows a Buy button that does
          nothing, and there is no error anywhere to explain it.
        </div>
      ) : null}

      <div className="mb-3 flex flex-col gap-1">
        {DISTRO_RECIPES.map((r) => {
          const done = result?.published.find((p) => p.packId === r.packId);
          const state = live[r.packId];
          return (
            <div
              key={r.packId}
              className="flex items-center gap-3 rounded-[10px] border border-site-line px-3 py-2"
            >
              <span
                className="h-5 w-5 shrink-0 rounded-[6px]"
                style={{ background: r.compose.tint ?? '#000' }}
                aria-hidden
              />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[12.5px]">{r.iconName}</span>
                <span className="block truncate font-mono text-[10px] text-site-ink-3">
                  {r.packId}
                </span>
              </span>
              <span
                className="hidden shrink-0 font-mono text-[10.5px] sm:block"
                style={{
                  color: r.skuLive
                    ? 'var(--color-site-ink-3)'
                    : 'var(--color-site-plan)',
                }}
                title={r.skuLive ? 'live in Play' : 'not created in Play yet'}
              >
                {r.sku}
                {r.skuLive ? '' : ' *'}
              </span>
              {/* The version this pack is at NOW, or what it just moved to.
                  Blank when it has never been published, rather than v0: a pack
                  that does not exist and a pack at version zero are different
                  things and only one of them is true. */}
              <span className="w-16 shrink-0 text-right font-mono text-[10.5px]">
                {done ? (
                  <span className="text-site-ok">v{done.version}</span>
                ) : state ? (
                  <span className="text-site-ink-3">v{state.version}</span>
                ) : (
                  <span className="text-site-ink-3">not yet</span>
                )}
              </span>
            </div>
          );
        })}
      </div>

      {/* ── THE BASE PACK MUST NOT BE ON THE SHELF ────────────────────────
          `arcticons-line` is the geometry all fourteen point at. Listed, it
          appears on the icons screen as a fifteenth pack with 13,622 drawings
          and no colour: nobody would choose it and it explains nothing.

          It is a dependency, not a product. The list toggle on the pack itself
          is what hides it, and this says so rather than silently flipping it,
          because a publish quietly changing what users can see is not something
          this screen should do on its own. */}
      {live[BASE_PACK_ID] && live[BASE_PACK_ID].listed && !result?.hidBase ? (
        <div className="mb-3 rounded-[10px] bg-site-plan-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-plan">
          <b>{BASE_PACK_ID} is listed on device.</b> It carries the drawings these
          fourteen share and has no colour of its own, so it shows up as a
          fifteenth pack nobody would pick. Publishing hides it automatically;
          if it is still here afterwards the bucket could not be written and the
          toggle below is the fallback.
        </div>
      ) : null}

      {/* Confirmed rather than assumed. `setListed` can refuse on an unreadable
          bucket, and the publish still succeeds in that case, so silence here
          would mean the base is quietly still on the shelf. */}
      {result?.hidBase ? (
        <div className="mb-3 rounded-[10px] bg-site-ok-soft px-3 py-2 text-[11.5px] leading-relaxed text-site-ok">
          {BASE_PACK_ID} is now hidden from the storefront. Users see the
          fourteen named packs and nothing else.
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          onClick={() => void publish()}
          disabled={busy}
          className="rounded-lg bg-site-accent px-3 py-1.5 text-[12.5px] font-semibold text-white disabled:opacity-50"
        >
          {busy ? 'Publishing' : `Publish all ${DISTRO_RECIPES.length}`}
        </button>

        {error ? (
          <span className="text-[11.5px] leading-relaxed text-site-plan">{error}</span>
        ) : result ? (
          <span className="text-[11.5px] leading-relaxed text-site-ok">
            Published {result.published.length}.
            {result.granted.length > 0
              ? ` ${new Set(result.granted).size} distro purchases now include their icons.`
              : ''}
          </span>
        ) : (
          <span className="text-[11.5px] leading-relaxed text-site-ink-3">
            Republishes every pack at the next version. Safe to run again;
            nothing else in the catalogue is touched.
          </span>
        )}
      </div>

      {/* ─── THE CREDIT HAS TO BE VISIBLE SOMEWHERE ──────────────────────
          CC BY-SA requires attribution to travel with the work, and these
          fourteen ARE the work as far as a user is concerned. The pack NAME
          does not have to say Arcticons, and it does not: a user sees "Kali
          Icons". The credit belongs where credits live.

          Every derived pack carries it in its `attribution` field, so it ships
          whether or not any screen shows it. This line is the reminder that a
          field nothing renders is not attribution. */}
      <p className="mt-3 border-t border-site-line pt-2 text-[11px] leading-relaxed text-site-ink-3">
        Drawings by Arcticons (Donnnno), CC BY-SA 4.0. Every pack carries this in
        its manifest; it also needs to appear under Legal, because a credit
        nothing renders is not a credit. Users never see the name on the pack:
        each is called after its distro.
      </p>

      {result && result.missingSkus.length > 0 ? (
        <p className="mt-2 font-mono text-[10.5px] leading-relaxed text-site-plan">
          create in Play: {result.missingSkus.join(', ')}
        </p>
      ) : null}
    </section>
  );
}
