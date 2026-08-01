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
};

export default nextConfig;
