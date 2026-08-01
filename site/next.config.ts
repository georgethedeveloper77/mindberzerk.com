import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // The site renders from CDN JSON and the vendored registry. No images from
  // remote hosts, no rewrites, nothing clever.
};

export default nextConfig;
