// Lot 3.1 probe: how does the OFFICIAL planner decoder (the site's own bundled code, tests/fixtures/codec/reference)
// treat six wanted spells of which three are also in the banish list?
//   node tools/site_overlap_probe.mjs <BYjmu0KK.js> <catalog dir>
// Prints the decoded plan. No network, no writes.
import fs from 'node:fs';
import path from 'node:path';

const [, , assetPath, catDir] = process.argv;
const s = fs.readFileSync(assetPath, 'utf8');
const iZ = s.indexOf('Z={spells:{main:6');
const iWt = s.indexOf('var wt=');
const iEnd = s.indexOf(';', iWt) + 1;
const iOe = s.indexOf('function Oe(e,t){');
const iKe = s.indexOf('var ke=[', iOe);
const api = new Function(s.slice(iOe, iKe) + 'var ' + s.slice(iZ, iEnd) + ';return {Oe,Ct};')();
const load = (n) => JSON.parse(fs.readFileSync(path.join(catDir, n), 'utf8'));
const data = { classes: load('classes.json'), spells: load('spells.json'), jewelry: load('jewelry.json'), amulets: load('amulets.json'), legends: load('legends.json'), sets: [], caps: [] };
const ctx = (cls) => api.Oe(data, cls);

const six = ['whirlwind', 'execute', 'cleave', 'rend', 'bloodthirst', 'shockwave'];
const arr = [1, 'Six-3avoid', 'warrior', '', ['', six, ['rend', 'bloodthirst', 'shockwave'], []]];
const code = 'azsb1:' + Buffer.from(JSON.stringify(arr)).toString('base64url');
const got = api.Ct(code, ctx);
const ph = got && got.plan && got.plan.phases && got.plan.phases[0];
console.log(JSON.stringify({ code, spells: ph && ph.spells, banish: ph && ph.banish }));
