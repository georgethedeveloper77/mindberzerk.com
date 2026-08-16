import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /**
   * THE ARCHITECTURE DOCS ARE READ BY PATH AT RUNTIME, NOT IMPORTED.
   *
   * The standalone build copies files it can see being imported. `readFile` on
   * a path is invisible to that trace, so without this the docs directory is
   * simply absent in production and every architecture page reports "no
   * document yet" while the file sits happily in the repo.
   *
   * Keyed by route so only that page carries them.
   */
  outputFileTracingIncludes: {
    '/apps/[app]/architecture': ['./docs/**/*'],
  },

  experimental: {
    serverActions: {
      /**
       * A DRAFT SAVE IS BINARY, AND 1MB IS THE DEFAULT.
       *
       * Every draft in this panel travels through a Server Action carrying the
       * actual bytes: wallpapers, two logos, and up to thirty-nine composed
       * icons at 192px. A single webp wallpaper clears the default limit on its
       * own, and the failure is a red toast reading "Body exceeded 1 MB limit"
       * with the work still unsaved.
       *
       * 12mb rather than something larger, deliberately. This is a ceiling
       * against a runaway upload, not a target: the number should be high
       * enough that authoring a real distro never hits it and low enough that a
       * mistake still fails fast. A full icon pack of forty composed PNGs plus
       * a wallpaper lands around 2 to 4mb, so this leaves room for a pack twice
       * that size before anyone has to think about it again.
       *
       * PUBLISH IS UNAFFECTED and always was. That path is a route handler with
       * FormData, not a Server Action, which is why publishing large packs has
       * worked all along while saving a draft of the same pack did not.
       */
      bodySizeLimit: '12mb',
    },
  },
};

export default nextConfig;
