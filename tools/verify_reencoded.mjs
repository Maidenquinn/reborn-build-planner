// JavaScript -> Lua -> JavaScript and Lua -> JavaScript checks, using the official planner's own decoder.
//   node tools/verify_reencoded.mjs <BYjmu0KK.js> <catalog dir> <tests dir>
// Inputs written by tests/lua/test_codec.lua: results/lua_reencoded.json, results/lua_origin.json; reference
// fixtures/codec/cross.json. Exit code 1 on any difference.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const [, , assetPath, catDir, testsDir] = process.argv;
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
const cross = JSON.parse(fs.readFileSync(path.join(testsDir, 'fixtures', 'codec', 'cross.json'), 'utf8'));
const reenc = JSON.parse(fs.readFileSync(path.join(testsDir, 'results', 'lua_reencoded.json'), 'utf8'));
const origin = JSON.parse(fs.readFileSync(path.join(testsDir, 'results', 'lua_origin.json'), 'utf8'));
let n = 0;
for (const r of reenc) {
  const orig = cross.cases.find((c) => c.id === r.id);
  assert.equal(r.code, orig.code, r.id + ': JS -> Lua -> JS code differs');
  assert.deepEqual(api.Ct(r.code, ctx).plan, orig.siteDecoded, r.id + ': site decodes the Lua code differently');
  n++;
}
for (const o of origin) {
  const got = api.Ct(o.code, ctx);
  assert.ok(got && got.plan, o.id + ': the official decoder refused a Lua-made code');
  o.expect.phases.forEach((ph) => { if (Array.isArray(ph.stats) && ph.stats.length === 0) ph.stats = {}; });   // the Lua test writer cannot tell {} from []
  assert.deepEqual(JSON.parse(JSON.stringify(got.plan)), o.expect, o.id + ': the official decoder reads something else than Lua intended');
  n++;
}
console.log('verified', n, 'codes with the official decoder (JS->Lua->JS:', reenc.length + ', Lua->JS:', origin.length + ')');
