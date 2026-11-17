// Generates tests/fixtures/codec/golden.json by RUNNING the site's own encoder/decoder (the public
// planner asset, snapshot 2026-11-17) in Node on synthetic plans. Deterministic: no clock, no random.
//   node tools/gen_codec_golden.mjs <planner-asset BYjmu0KK.js> <catalog dir> <out golden.json>
// The extracted fragment is the contiguous slice from `Z={spells:` to `var wt=...;` plus function Oe
// (class context builder). It is evaluated in a Function scope; nothing is installed or fetched.
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
if ([iZ, iWt, iOe, iKe].some((i) => i < 0)) throw new Error('asset layout changed: codec fragment not found');
const frag = s.slice(iOe, iKe) + 'var ' + s.slice(iZ, iEnd);
const api = new Function(frag + ';return {Oe,Z,Ye,Qe,Xe,et,ht,wt,St,Ct,ft,mt};')();
const load = (n) => JSON.parse(fs.readFileSync(path.join(catDir, n), 'utf8'));
const data = { classes: load('classes.json'), spells: load('spells.json'), jewelry: load('jewelry.json'),
  amulets: load('amulets.json'), legends: load('legends.json'), sets: [], caps: [] };
const ctx = (cls) => api.Oe(data, cls);
const blank = (cls, name = '') => api.et(cls, name);
const enc = (arr) => api.ft.enc(JSON.stringify(arr));
const phase = (o) => Object.assign({ label: '', spells: [], banish: [], rings: ['', '', '', ''], trinkets: ['', '', '', ''], amulets: ['', '', '', ''], stats: {}, notes: '', link: '' }, o);
const labels = ['Early Game', 'Mid Game', 'End Game', 'Endless'];
const mk = (cls, name, talents, ph) => { const p = blank(cls, name); p.talents = talents; ph.forEach((x, i) => { p.phases[i] = Object.assign(phase({ label: labels[i] }), x, { label: x && x.label !== undefined ? x.label : labels[i] }); }); return p; };

const W = 'warrior';
const plans = [
  ['empty_warrior', 'Nothing set: code is just the header', mk(W, '', '', [])],
  ['spells_and_banish', 'Six spells + three distinct banishes in phase 0', mk(W, 'WW', '', [{ spells: ['whirlwind', 'execute', 'cleave', 'rend', 'bloodthirst', 'shockwave'], banish: ['battle_shout', 'demo_shout', 'bloodrage'] }])],
  ['four_phases_with_null', 'Phase 0 and 3 used; phases 1 and 2 empty are serialised as null (inner), nothing trailing', mk(W, 'Four', '', [{ spells: ['cleave'] }, {}, {}, { notes: 'late' }])],
  ['holes_in_alternatives', 'Empty strings are kept inside rings/trinkets/amulets so main vs alternative positions survive', mk(W, 'Holes', '', [{ rings: ['accuria', '', 'quick_strike', ''], trinkets: ['', 'earthstrike', '', 'hoj'], amulets: ['', '', 'warglaives', ''] }])],
  ['legend_amulet', 'Legendary amulet identifier is the catalogue legends key (legendary:<spell>)', mk(W, 'Leg', '', [{ amulets: ['legendary:cleave', 'warglaives', '', ''] }])],
  ['stats_indexes', 'Stats are [index, value] pairs, index 0-based in the site order damage..gold', mk(W, 'Stats', '', [{ stats: { damage: 50, crit: 12.34, gold: 5 } }])],
  ['unicode_notes', 'Accents, emoji (surrogate pair), newline, custom label, link', mk(W, 'Guerrier été ⚔️', '10203-000-0110', [{ label: 'Début', spells: ['execute'], notes: 'Ligne 1\nLigne 2 😀', link: 'https://azreborn.com/planner/warrior' }])],
  ['default_label_blank', 'A label equal to the default is serialised as an empty first field', mk(W, 'Lbl', '', [{ label: 'Early Game', spells: ['rend'] }])],
];
const vectors = plans.map(([id, description, plan]) => {
  const code = api.wt(plan);
  return { id, description, plan: { name: plan.name, cls: plan.cls, talents: plan.talents, phases: plan.phases }, code, array: JSON.parse(api.ft.dec(code.slice(6))) };
});

const L = (arr) => 'azsb1:' + enc(arr);
const full = (arr) => [1, ...arr];
const okOf = (r) => r !== null;
const run = (id, description, input) => { const r = api.Ct(input, ctx); return { id, description, input, accepted: okOf(r), result: r }; };
const good = vectors.find((v) => v.id === 'spells_and_banish').code;
const goodPayload = good.slice(6);
const dec = [
  run('valid_colon_prefix', 'canonical code', good),
  run('valid_dot_prefix', 'azsb1. prefix is accepted too', 'azsb1.' + goodPayload),
  run('valid_no_prefix', 'bare payload is accepted', goodPayload),
  run('url_p', 'URL with ?p= (class is inside the payload)', 'https://azreborn.com/planner/warrior?p=' + goodPayload),
  run('url_b_talents_only', 'URL with ?b= returns talents only', 'https://azreborn.com/planner/warrior?b=10203-000-0110'),
  run('url_without_params', 'URL with neither p nor b is rejected', 'https://azreborn.com/planner/warrior'),
  run('bare_talents', 'digits and dashes with at least one dash = talents only', '10203-000-0110'),
  run('bad_base64', 'not base64', 'azsb1:!!!!'),
  run('wrong_version', 'root version 2', L([2, 'x', W, ''])),
  run('unknown_class', 'class not in catalogue', L([1, 'x', 'nosuchclass', ''])),
  run('not_array', 'JSON object', 'azsb1:' + api.ft.enc('{"a":1}')),
  run('other_class_spell_dropped', 'death_coil is a warlock spell: dropped silently on a warrior', L(full(['x', W, '', ['', ['whirlwind', 'death_coil']]]))),
  run('duplicate_spells_collapse', 'duplicate spell key kept once', L(full(['x', W, '', ['', ['whirlwind', 'whirlwind', 'execute']]]))),
  run('banish_overlap_dropped', 'a banish already in spells is dropped', L(full(['x', W, '', ['', ['whirlwind'], ['whirlwind', 'rend']]]))),
  run('seventh_spell_dropped', 'more than 6 spells: extra dropped', L(full(['x', W, '', ['', ['whirlwind', 'execute', 'cleave', 'rend', 'bloodthirst', 'shockwave', 'shield_slam']]]))),
  run('ring_in_trinket_slot', 'a ring key in trinkets becomes an empty hole', L(full(['x', W, '', ['', [], [], [], ['accuria', 'earthstrike']]]))),
  run('duplicate_ring_hole', 'duplicate ring: the second occurrence becomes a hole, position kept', L(full(['x', W, '', ['', [], [], ['accuria', 'accuria', 'quick_strike']]]))),
  run('legend_of_other_class', 'legendary key of another class is dropped to a hole', L(full(['x', W, '', ['', [], [], [], [], ['legendary:death_coil', 'warglaives']]]))),
  run('stats_rounding_and_cap', 'stats: >0 finite only, rounded to 1 decimal, capped 999', L(full(['x', W, '', ['', [], [], [], [], [], [[0, 12.34], [1, -5], [2, 5000], [99, 3], [4, 'a']]]]))),
  run('extra_phase_ignored', 'a fifth phase is ignored', L(full(['x', W, '', ['', ['rend']], null, null, null, ['', ['cleave']]]))),
  run('name_truncated_60', 'name cut to 60 UTF-16 units', L([1, 'n'.repeat(80), W, ''])),
  run('notes_truncated_2000', 'notes cut to 2000 UTF-16 units', L(full(['x', W, '', ['', [], [], [], [], [], [], 'z'.repeat(2500)]]))),
  run('link_non_http_dropped', 'non-http link is dropped', L(full(['x', W, '', ['', [], [], [], [], [], [], '', 'javascript:alert(1)']]))),
  run('talents_invalid_chars', 'talents with letters become empty', L([1, 'x', W, '12a-3'])),
  run('label_over_24', 'label cut to 24 characters', L(full(['x', W, '', ['L'.repeat(40)]]))),
];
const out = {
  source: { asset: path.basename(assetPath), sha256: crypto.createHash('sha256').update(s).digest('hex'), note: 'public planner asset snapshot 2026-11-17; functions mt/ht/yt/St/Ct/wt, constants Z/Qe/Xe' },
  catalog: JSON.parse(fs.readFileSync(path.join(catDir, 'index.json'), 'utf8')).content,
  generatedBy: 'tools/gen_codec_golden.mjs',
  constants: { root: 1, slots: api.Z, statOrder: api.Qe.map((x) => x.key), defaultLabels: api.Xe },
  vectors, decodeCases: dec,
};
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(out, null, 1) + '\n');
console.log('vectors', vectors.length, 'decodeCases', dec.length, 'accepted', dec.filter((d) => d.accepted).length);
