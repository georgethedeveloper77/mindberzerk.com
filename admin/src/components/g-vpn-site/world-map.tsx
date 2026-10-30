import { LiveLayer } from './live-layer';
import type { LiveSnapshot } from './live-types';
import { landDotsPath, MAP_HEIGHT, MAP_WIDTH } from './world';
import styles from './landing.module.css';

/**
 * The dotted world (static, computed on the server) with the live layer laid
 * exactly over it: server markers that show a flag card on hover or tap, our
 * own servers, and the visitor's routes.
 */
export function WorldMap({ live, className = '' }: { live: LiveSnapshot; className?: string }) {
  return (
    <div className={`${styles.map} ${className}`}>
      <svg viewBox={`0 0 ${MAP_WIDTH} ${MAP_HEIGHT}`} className={styles.mapDots} aria-hidden>
        <path className={styles.dots} d={landDotsPath()} />
      </svg>
      <LiveLayer initial={live} />
    </div>
  );
}
