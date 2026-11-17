// Cross-check corpus for the Lua codec, produced by RUNNING the official planner's own encoder/decoder (the
// snapshot asset, unchanged on 2026-11-17 per its SHA-256) on deterministic pseudo-random plans.
//   node tools/gen_codec_cross.mjs <BYjmu0KK.js> <catalog dir> <out cross.json>
// Does not touch tests/fixtures/codec/golden.json (the reference fixtures stay as they were).
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';

const [, , assetPath, catDir, outPath] = process.argv;
const s = fs.readFileSync(assetPath, 'utf8');
const iZ = s.indexOf('Z={spells:{main:6');
const iWt = s.indexOf('var wt=');
const iEnd = s.indexOf(';', iWt) + 1;
const iOe = s.indexOf('function Oe(e,t){');
const iKe = s.indexOf('var ke=[', iOe);
const frag = s.slice(iOe, iKe) + 'var ' + s.slice(iZ, iEnd);
const api = new Function(frag + ';return {Oe,Z,Qe,Xe,et,ht,wt,Ct,ft};')();
const load = (n) => JSON.parse(fs.readFileSync(path.join(catDir, n), 'utf8'));
const data = { classes: load('classes.json'), spells: load('spells.json'), jewelry: load('jewelry.json'), amulets: load('amulets.json'), legends: load('legends.json'), sets: [], caps: [] };
const ctx = (cls) => api.Oe(data, cls);

// deterministic PRNG (mulberry32)
let seed = 20261117;
const rnd = () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const sample = (a, n) => { const c = [...a]; const o = []; while (o.length < n && c.length) o.push(c.splice(Math.floor(rnd() * c.length), 1)[0]); return o; };

const NAMES = ['Guerrier', 'WW', 'Build été à ça', '⚔️ Fury', 'Maître 😀 du jeu', '战士构筑', '  padded name  ', 'Quote "x" and \\ slash', ''];
const NOTES = ['', 'Priorité aux sorts', 'Ligne 1\nLigne 2\r\nLigne 3', 'tab\there', 'ctl\u0001\u001f end', 'sep para x', 'emoji 😀👍 done', 'quote " backslash \\ slash / done', 'é'.repeat(40)];
const LINKS = ['', 'https://azreborn.com/planner/warrior', 'http://example.com/a?b=c#d', 'HTTPS://Example.COM/x', 'https://sub.example.org:8080/p'];
const LABELS = ['', '', 'Début', 'Mid', 'Final 😀', 'Early Game', 'End Game'];
const TAL = ['', '', '10203-000-0110', '5-0-0', '0-0-0-0'];
const labels = api.Xe;

function slots(list, n) {
  const out = Array(n).fill('');
  const ks = sample(list, Math.floor(rnd() * (n + 1)));
  const pos = sample([...Array(n).keys()], ks.length);
  ks.forEach((k, i) => { out[pos[i]] = k; });
  return out;
}

function phasePlan(c, p) {
  const ph = { label: pick(LABELS) || labels[p], spells: [], banish: [], rings: Array(4).fill(''), trinkets: Array(4).fill(''), amulets: Array(4).fill(''), stats: {}, notes: '', link: '' };
  if (rnd() < 0.25) return ph;   // empty phase (null in the code unless custom label)
  const keys = c.spells.map((x) => x.key);
  ph.spells = sample(keys, Math.floor(rnd() * 7));
  ph.banish = sample(keys.filter((k) => !ph.spells.includes(k)), Math.floor(rnd() * 4));
  ph.rings = slots(c.rings.map((x) => x.key), 4);
  ph.trinkets = slots(c.trinkets.map((x) => x.key), 4);
  ph.amulets = slots([...c.amulets, ...c.legends].map((x) => x.key), 4);
  api.Qe.forEach((q) => { if (rnd() < 0.3) ph.stats[q.key] = Math.round((1 + rnd() * 400) * 10) / 10; });
  ph.notes = pick(NOTES);
  ph.link = pick(LINKS);
  return ph;
}

const cases = [];
for (let i = 0; i < 60; i++) {
  const cls = data.classes[i % data.classes.length].key;
  const c = ctx(cls);
  const plan = api.et(cls, pick(NAMES));
  plan.talents = pick(TAL);
  plan.phases = [0, 1, 2, 3].map((p) => phasePlan(c, p));
  const code = api.wt(plan);
  const dec = api.Ct(code, ctx);
  cases.push({ id: 'rnd' + String(i).padStart(2, '0'), plan: { name: plan.name, cls: plan.cls, talents: plan.talents, phases: plan.phases }, code, siteDecoded: dec && dec.plan ? dec.plan : null });
}
// raw decimals: only the ENCODER is compared (the site's decoder rounds to one decimal)
const raw = api.et('warrior', 'decimals');
raw.phases[0].stats = { damage: 0.1 + 0.2, crit: 12.34, area: 1 / 3, gold: 999, speed: 0.000001, armor: 100 };
raw.phases[0].spells = ['whirlwind'];
const rawCode = api.wt(raw);
const encoderOnly = [{ id: 'decimals', plan: { name: raw.name, cls: raw.cls, talents: raw.talents, phases: raw.phases }, code: rawCode }];

const numbers = [0, -0, 1, 100, 0.1, 0.5, 12.5, 0.1 + 0.2, 1 / 3, 4.35, 999.9, 1e21, 1e-6, 1e-7, 123456789012345680000, 1.5e300, 5e-324, 2 ** 53, 0.000123, 1e20, 12345.6789, -0.5];
const numberCorpus = numbers.map((n) => ({ value: n, text: JSON.stringify(n), isNegZero: Object.is(n, -0) }));
const strings = ['plain', 'quote " here', 'back \\ slash', 'ctl \u0001\u0002\u001f', 'nl\n cr\r tab\t bs\b ff\f', 'del \u007f', 'sep    ', 'éè 战 😀', '/slash/'];
const stringCorpus = strings.map((x) => ({ value: x, json: JSON.stringify(x) }));
const utf16 = ['abc', 'éé', '😀', 'a😀b', '😀😀😀', '战士', 'x'.repeat(70)].map((x) => {
  const slices = {};
  [0, 1, 2, 3, 5, 60].forEach((k) => { slices[k] = Buffer.from(new TextEncoder().encode(x.slice(0, k))).toString('base64'); });
  return { text: Buffer.from(new TextEncoder().encode(x)).toString('base64'), length: x.length, slices };
});
const spaces = ['  a  ', ' a ', '﻿a', ' a　', '​a​', '\u0085a', '\ta\n', 'a b', ''].map((x) => ({ text: Buffer.from(new TextEncoder().encode(x)).toString('base64'), trimmed: Buffer.from(new TextEncoder().encode(x.trim())).toString('base64') }));
const links = ['https://a.b/c', 'http://x', 'ftp://a.b', 'javascript:alert(1)', 'https://', 'http://a b', 'https://exa mple.com', 'HTTP://A.B', 'https://a.b:99999', 'https://a.b:8080/x', 'http://[::1]/x', 'https://?x', 'https:///x', 'https://u:p@h.com/x', 'https://a.b/é'].map((x) => {
  let ok = /^https?:\/\/[^\s]+$/i.test(x);
  if (ok) { try { ok = new URL(x).protocol.startsWith('http'); } catch { ok = false; } }
  return { link: x, accepted: ok };
});
const out = {
  source: { asset: path.basename(assetPath), sha256: crypto.createHash('sha256').update(s).digest('hex') },
  catalog: JSON.parse(fs.readFileSync(path.join(catDir, 'index.json'), 'utf8')).content,
  generatedBy: 'tools/gen_codec_cross.mjs', seed: 20261117, cases, encoderOnly, numberCorpus, stringCorpus, utf16, spaces, links,
};
fs.writeFileSync(outPath, JSON.stringify(out, null, 1) + '\n');
console.log('cases', cases.length, 'accepted by site', cases.filter((c) => c.siteDecoded).length, 'links ok', links.filter((l) => l.accepted).length + '/' + links.length);
