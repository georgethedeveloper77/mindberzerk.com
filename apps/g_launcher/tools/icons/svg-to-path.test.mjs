/**
 * Tests for the SVG primitive converter.
 *
 *   node tools/icons/svg-to-path.test.mjs [corpus-dir]
 *
 * The corpus half needs a directory of real SVGs. Point it at the icon set:
 *
 *   node tools/icons/svg-to-path.test.mjs "$HOME/Downloads/iconpacks/Arcticons-main/icons/white"
 *
 * Run against the FULL set before publishing a vector pack. The unit half
 * proves the maths; only the corpus half can tell you whether thirteen
 * thousand real drawings contain an element this does not understand, and a
 * missed element costs a stroke silently rather than throwing.
 */
import { svgToPaths, viewBoxOf, strokeWidthOf } from './svg-to-path.mjs';
import { readdirSync, readFileSync } from 'node:fs';

let pass=0, fail=0; const ok=(n,c,x='')=>c?pass++:(fail++,console.log('  FAIL',n,x));

// unit: primitives
const one = (svg) => svgToPaths(svg).paths[0];
ok('line converts',    one('<line x1="1" y1="2" x2="3" y2="4"/>')==='M1,2L3,4');
ok('circle is two arcs',(one('<circle cx="10" cy="10" r="5"/>').match(/A/g)||[]).length===2);
ok('circle starts at left', one('<circle cx="10" cy="10" r="5"/>').startsWith('M5,10'));
ok('rect square corners', one('<rect x="0" y="0" width="4" height="4"/>')==='M0,0H4V4H0Z');
ok('rect rounded uses arcs', (one('<rect x="0" y="0" width="8" height="8" rx="2"/>').match(/A/g)||[]).length===4);
ok('rx alone implies ry', one('<rect x="0" y="0" width="8" height="8" rx="2"/>').includes('2,2'));
ok('polyline converts', one('<polyline points="1,2 3,4 5,6"/>')==='M1,2L3,4L5,6');
ok('polygon closes',    one('<polygon points="1,2 3,4 5,6"/>').endsWith('Z'));
ok('path passes through', one('<path d="M1 1L2 2"/>')==='M1 1L2 2');
ok('degenerate circle is skipped', svgToPaths('<circle cx="1" cy="1" r="0"/>').paths.length===0);
ok('unknown element is reported', svgToPaths('<foo bar="1"/>').skipped.includes('foo'));
ok('svg/defs/style are not elements', svgToPaths('<svg><defs><style>.a{}</style></defs></svg>').skipped.length===0);

// the whole local corpus
const dir = process.argv[2] ?? '/tmp/arct';
let files=0, converted=0, totalPaths=0, skipped=[], boxes=new Set(), widths=new Set();
for (const f of readdirSync(dir).filter(x=>x.endsWith('.svg'))) {
  const svg = readFileSync(`${dir}/${f}`,'utf8');
  files++;
  const vb = viewBoxOf(svg); if (vb!==null) boxes.add(vb);
  widths.add(strokeWidthOf(svg));
  const { paths, skipped: sk } = svgToPaths(svg);
  if (paths.length>0) converted++;
  totalPaths += paths.length;
  skipped.push(...sk);
}
console.log(`\n  corpus: ${files} files, ${converted} produced paths, ${totalPaths} paths total`);
console.log(`  viewBoxes seen: ${[...boxes].join(', ')}`);
console.log(`  declared stroke widths: ${[...widths].map(w=>w===null?'none':w).join(', ')}`);
console.log(`  skipped elements: ${skipped.length? [...new Set(skipped)].join(', ') : 'none'}`);
ok('every file converted', converted===files, `${converted}/${files}`);
ok('nothing was skipped', skipped.length===0, skipped.join(','));
ok('one viewBox across the set', boxes.size===1, [...boxes].join(','));
ok('no zero stroke widths recorded', ![...widths].includes(0));
ok('average paths per icon is plausible', totalPaths/files>1 && totalPaths/files<20, String((totalPaths/files).toFixed(1)));
console.log(`\n  ${pass} passed, ${fail} failed`);
process.exit(fail?1:0);
