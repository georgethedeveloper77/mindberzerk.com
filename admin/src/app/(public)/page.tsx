import { Catalogue } from '@/components/site/catalogue';
import { Contact } from '@/components/site/contact';
import { Featured } from '@/components/site/featured';
import { Footer, Nav, StoreBadges } from '@/components/site/chrome';
import { readPublishedSite, resolvePublicFeatured, resolvePublicStats, splitHeadline } from '@/lib/site-public';
import { REGISTRY, appMeta } from '@/lib/registry';

/**
 * The landing. Everything the panel publishes is read at the top and handed
 * down; everything else renders from the vendored registry. Revalidated on the
 * fetch layer (5 minutes), so a publish from the panel shows up without a
 * deploy and without this page opting out of static rendering.
 */

export default async function Landing() {
  const content = await readPublishedSite();
  const featured = resolvePublicFeatured(content.featured);
  const stats = await resolvePublicStats(content.stats);
  const { plain, accent } = splitHeadline(content.hero.headline);

  // The next-generation band reads its two rows from the registry so name and
  // blurb edits land here too. Falling back to filtering keeps this from
  // rendering empty if either id is ever renamed.
  const nextApps = [appMeta('g-launcher'), appMeta('g-recovery')].filter(
    (a): a is NonNullable<typeof a> => !!a,
  );

  return (
    <div id="top">
      <Nav />

      <header
        className="relative overflow-hidden"
        style={{
          background:
            'radial-gradient(900px 520px at 10% -10%, var(--color-site-lav) 0%, transparent 60%), radial-gradient(900px 560px at 96% 6%, var(--color-site-peach) 0%, transparent 58%), var(--color-site-page)',
        }}
      >
        <div className="mx-auto grid max-w-[1180px] items-center gap-14 px-7 pb-20 pt-16 lg:grid-cols-[1fr_0.98fr] lg:pb-[92px] lg:pt-20">
          <div>
            {content.hero.eyebrow && (
              <p className="mb-4 inline-block rounded-full border-[1.5px] border-site-line bg-site-card px-3.5 py-1.5 text-[12.5px] font-bold text-site-ink-3">
                {content.hero.eyebrow}
              </p>
            )}
            <h1 className="text-[clamp(38px,4.8vw,58px)] font-bold leading-[1.12]">
              {plain}
              {accent && <span className="text-site-accent"> {accent}</span>}
            </h1>
            <p className="mt-5 max-w-[50ch] text-lg leading-relaxed">{content.hero.lede}</p>
            <div className="mt-8">
              <StoreBadges />
            </div>
          </div>
          <Featured apps={featured} />
        </div>

        {stats.length > 0 && (
          <div className="mx-auto max-w-[1180px] px-7 pb-16">
            <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
              {stats.map((s) => (
                <div key={s.label} className="rounded-[20px] border border-site-line bg-site-card p-5 shadow-site-soft">
                  <span className="block font-site-display text-[28px] font-bold tracking-tight text-site-ink">{s.value}</span>
                  <span className="mt-0.5 block text-[13px] font-semibold text-site-ink-3">{s.label}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </header>

      <section id="apps" className="py-20 lg:py-24">
        <div className="mx-auto max-w-[1180px] px-7">
          <div className="mb-11 max-w-[660px]">
            <h2 className="text-[clamp(30px,3.6vw,42px)] font-bold">Everything we ship.</h2>
            <p className="mt-3.5 text-[17px] leading-relaxed">
              Apps and games across Google Play and the App Store, each built to do one job properly.
            </p>
          </div>
          <Catalogue apps={REGISTRY} />
        </div>
      </section>

      {nextApps.length > 0 && (
        <section id="next" className="pb-20 lg:pb-24">
          <div className="mx-auto max-w-[1180px] px-7">
            <div className="grid overflow-hidden rounded-[30px] bg-[#1c1526] text-[#b9aecf] shadow-[0_24px_60px_rgba(28,21,38,0.25)] lg:grid-cols-2">
              <div className="flex flex-col justify-center p-8 sm:p-14">
                <h2 className="text-[clamp(28px,3vw,36px)] font-bold text-white">What we are building next.</h2>
                <p className="mt-4 max-w-[44ch] text-base leading-relaxed">
                  The next generation of Mindberzerk apps holds itself to a stricter standard, and it
                  starts with these two.
                </p>
                <div className="mt-6 flex flex-wrap gap-x-5 gap-y-2 text-[13.5px] font-semibold text-[#d5cbe8]">
                  {['No ads', 'One-time purchases', 'Your data on your hardware'].map((vow) => (
                    <span key={vow} className="inline-flex items-center gap-1.5">
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#a688ff" strokeWidth="2" strokeLinecap="round" aria-hidden>
                        <path d="M2 7.5l3 3 7-7" />
                      </svg>
                      {vow}
                    </span>
                  ))}
                </div>
              </div>
              <div className="flex flex-col justify-center gap-4 p-8 sm:p-11">
                {nextApps.map((a) => (
                  <div key={a.id} className="flex items-start gap-4 rounded-[18px] border border-white/10 bg-white/5 p-5">
                    <span
                      aria-hidden
                      className="grid size-[42px] shrink-0 place-items-center rounded-[13px] font-site-display text-sm font-extrabold text-white"
                      style={{ background: `linear-gradient(140deg, ${a.tint}, color-mix(in srgb, ${a.tint} 55%, #000))` }}
                    >
                      {a.mark}
                    </span>
                    <div className="min-w-0">
                      <h3 className="text-[16.5px] font-semibold text-white">{a.name}</h3>
                      <p className="mt-1 text-[13.5px] leading-relaxed">{a.blurb}</p>
                    </div>
                    <span className="ml-auto shrink-0 rounded-full bg-[rgba(166,136,255,0.18)] px-2.5 py-1 text-[10.5px] font-bold uppercase tracking-wider text-[#c9b4ff]">
                      {a.state === 'live' ? 'Live' : a.state === 'build' ? 'In development' : 'Planned'}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>
      )}

      <section id="contact" className="pb-24">
        <div className="mx-auto max-w-[1180px] px-7">
          <Contact />
        </div>
      </section>

      <Footer />
    </div>
  );
}
