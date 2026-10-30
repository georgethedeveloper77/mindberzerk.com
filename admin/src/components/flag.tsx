import Image from 'next/image';

/**
 * A country flag from public/flags (flag-icons, MIT, the same set the G VPN
 * app ships in assets/flags; licence beside the files). 4:3, keyed by ISO
 * 3166-1 alpha-2. Renders nothing for a code that is not two letters, so a
 * blank or malformed country never shows a broken image.
 *
 * `unoptimized`: the files are already 96x72 PNGs of a few hundred bytes, so
 * the optimizer would only add a round trip.
 */
export function Flag({ code, width = 20, className = '' }: { code: string; width?: number; className?: string }) {
  if (!/^[A-Za-z]{2}$/.test(code)) return null;
  return (
    <Image
      src={`/flags/${code.toLowerCase()}.png`}
      alt=""
      width={width}
      height={Math.round((width * 3) / 4)}
      unoptimized
      className={`inline-block shrink-0 rounded-[3px] object-cover ${className}`}
    />
  );
}
