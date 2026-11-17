"""Offline catalogue generator: data/v1 snapshot -> addon/RebornBuildPlanner/GeneratedCatalog.lua

  python -I tools/generate_catalog.py [--data DIR] [--out FILE] [--report FILE] [--check]

Deterministic (no clock, no random, source order kept, maps sorted), Lua 5.1 syntax, pure data.
Refuses (exit 2/3, nothing written, existing output untouched) on an unsupported schema or any structural
error. Semantic anomalies are reported as warnings and recorded in the output; no data is invented and the
source JSON is never modified. Official keys are preserved; names and icons are never used as identifiers.
"""
import hashlib
import json
import os
import re
import sys

GENERATOR_VERSION = 1
SUPPORTED_SCHEMA = 1
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DEFAULT_DATA = os.path.join(ROOT, "tests", "fixtures", "catalog", "384db000d5ac311d")
DEFAULT_OUT = os.path.join(ROOT, "addon", "RebornBuildPlanner", "GeneratedCatalog.lua")
DEFAULT_REPORT = os.path.join(ROOT, "tests", "results", "catalog_report.txt")

REQUIRED = ["classes.json", "spells.json", "jewelry.json", "amulets.json", "legends.json"]
LANGS = ["frFR"]            # translations embedded (EN is the fallback and the key)
RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "pvp", "exotic", "mythic"]
SLOTS = ["ring", "trinket"]


class Refused(Exception):
    def __init__(self, code, msg):
        Exception.__init__(self, msg)
        self.code = code


def load(data, name):
    with open(os.path.join(data, name), encoding="utf-8") as fh:
        return json.load(fh)


# ------------------------------------------------------------------ validation
def validate(data):
    errors, warnings, notes = [], [], []
    try:
        index = load(data, "index.json")
    except (OSError, ValueError) as e:
        raise Refused(3, "index.json unreadable: %s" % e)
    if not isinstance(index, dict) or "schema" not in index or "content" not in index or "files" not in index:
        raise Refused(3, "index.json lacks schema/content/files")
    if index["schema"] != SUPPORTED_SCHEMA:
        raise Refused(2, "unsupported catalogue schema %r (this generator supports %d)" % (index["schema"], SUPPORTED_SCHEMA))
    if not re.match(r"^[0-9a-f]{8,64}$", str(index["content"])):
        raise Refused(3, "index.content is not a hex hash: %r" % (index["content"],))
    tables = {}
    for name in REQUIRED:
        meta = index["files"].get(name)
        if meta is None:
            errors.append("index.json does not list required file %s" % name)
            continue
        path = os.path.join(data, name)
        if not os.path.exists(path):
            errors.append("required file %s missing on disk" % name)
            continue
        try:
            rows = load(data, name)
        except ValueError as e:
            errors.append("%s is not valid JSON: %s" % (name, e))
            continue
        if not isinstance(rows, list):
            errors.append("%s is not an array" % name)
            continue
        if meta.get("count") != len(rows):
            errors.append("%s: index says %r rows, file has %d" % (name, meta.get("count"), len(rows)))
        want = set(meta.get("fields", []))
        for i, r in enumerate(rows):
            if not isinstance(r, dict):
                errors.append("%s[%d] is not an object" % (name, i))
                continue
            miss = want - set(r)
            extra = set(r) - want
            if miss:
                errors.append("%s[%d] (%s) lacks fields %s" % (name, i, r.get("key"), sorted(miss)))
            if extra:
                warnings.append("%s[%d] (%s) has fields not listed in the index: %s" % (name, i, r.get("key"), sorted(extra)))
        tables[name] = rows
    for name, meta in sorted(index["files"].items()):
        if name not in REQUIRED and not name.startswith("i18n/"):
            notes.append("%s listed by the index (%s rows) but not used by Lot 1" % (name, meta.get("count")))
    if errors:
        return index, tables, errors, warnings, notes, {}

    def uniq(rows, field, label):
        seen = {}
        for r in rows:
            v = r[field]
            if not isinstance(v, str) or v == "":
                errors.append("%s: %s is not a non-empty string (%r)" % (label, field, v))
            elif v in seen:
                errors.append("%s: duplicate %s %r" % (label, field, v))
            seen[v] = r
        return seen

    classes = uniq(tables["classes.json"], "key", "classes")
    spells = uniq(tables["spells.json"], "key", "spells")
    jewelry = uniq(tables["jewelry.json"], "key", "jewelry")
    amulets = uniq(tables["amulets.json"], "key", "amulets")
    legends = uniq(tables["legends.json"], "key", "legends")
    if len(classes) != 12:
        warnings.append("catalogue holds %d classes (the snapshot of 2026-11-17 had 12); code must not hard-code the count" % len(classes))
    ids = {}
    for s in tables["spells.json"]:
        if not isinstance(s["id"], int):
            errors.append("spell %s: id is not an integer" % s["key"])
        elif s["id"] in ids:
            errors.append("spells %s and %s share spell id %d" % (ids[s["id"]], s["key"], s["id"]))
        ids[s["id"]] = s["key"]
        if s["class"] not in classes:
            errors.append("spell %s references unknown class %r" % (s["key"], s["class"]))
        if not isinstance(s["legendary"], bool):
            errors.append("spell %s: legendary is not a boolean" % s["key"])
    for c in tables["classes.json"]:
        for k in c["spells"]:
            if k not in spells:
                errors.append("class %s lists unknown spell %r" % (c["key"], k))
            elif spells[k]["class"] != c["key"]:
                errors.append("class %s lists spell %s that belongs to %s" % (c["key"], k, spells[k]["class"]))
    for j in tables["jewelry.json"]:
        if j["slot"] not in SLOTS:
            errors.append("jewelry %s: unknown slot %r" % (j["key"], j["slot"]))
    for a in tables["amulets.json"]:
        if a["rarity"] not in RARITIES:
            errors.append("amulet %s: unknown rarity %r" % (a["key"], a["rarity"]))
        for cl in a["classes"]:
            if cl not in classes:
                errors.append("amulet %s references unknown class %r" % (a["key"], cl))
    for g in tables["legends.json"]:
        if g["spell"] not in spells:
            errors.append("legend %s references unknown spell %r" % (g["key"], g["spell"]))
        else:
            if g["key"] != "legendary:" + g["spell"]:
                errors.append("legend %s: key is not legendary:<spell>" % g["key"])
            if spells[g["spell"]]["class"] != g["class"]:
                errors.append("legend %s: class %s differs from its spell's class %s" % (g["key"], g["class"], spells[g["spell"]]["class"]))
        if g["class"] not in classes:
            errors.append("legend %s references unknown class %r" % (g["key"], g["class"]))
    for k in set(spells) & set(jewelry) | set(spells) & set(amulets) | set(jewelry) & set(amulets):
        warnings.append("key %r exists in more than one catalogue kind (allowed: lists are typed)" % k)
    for k in set(legends) & (set(spells) | set(jewelry) | set(amulets)):
        errors.append("legend key %r collides with another kind" % k)

    anomalies = []
    legend_spells = {g["spell"] for g in tables["legends.json"]}
    for s in tables["spells.json"]:
        if s["legendary"] and s["key"] not in legend_spells:
            anomalies.append({"code": "LEGENDARY_FLAG_WITHOUT_LEGEND", "key": s["key"], "class": s["class"],
                              "detail": "spells.json marks %s legendary but legends.json has no legendary:%s row; no amulet is invented" % (s["key"], s["key"])})
    homonyms = {}
    for g in tables["legends.json"]:
        homonyms.setdefault(g["name"], []).append(g["key"])
    homonyms = {n: v for n, v in homonyms.items() if len(v) > 1}
    for n, v in sorted(homonyms.items()):
        warnings.append("legend full name %r is shared by %s (classes differ; identity needs name+class)" % (n, v))
    shared = {}
    for kind, rows in (("jewelry", tables["jewelry.json"]), ("amulets", tables["amulets.json"]), ("legends", tables["legends.json"])):
        for r in rows:
            shared.setdefault(r["icon"], []).append(r["key"])
    shared = {i: v for i, v in shared.items() if len(v) > 1}
    heads = {}
    for g in tables["legends.json"]:
        heads.setdefault(g["head"], []).append(g["key"])
    shared_heads = {h: len(v) for h, v in heads.items() if len(v) > 1}
    for a in anomalies:
        warnings.append("%s: %s" % (a["code"], a["detail"]))
    info = {"anomalies": anomalies, "homonyms": homonyms, "sharedIcons": shared, "sharedHeads": shared_heads}
    return index, tables, errors, warnings, notes, info


def translations(data, index, tables, warnings, notes):
    out = {}
    names = set()
    for fn in REQUIRED[:4]:
        for r in tables[fn]:
            names.add(r["name"])
    for lang in LANGS:
        rel = "i18n/%s.json" % lang
        path = os.path.join(data, rel)
        if rel not in index["files"] or not os.path.exists(path):
            warnings.append("translation %s not available: names fall back to English" % lang)
            out[lang] = {}
            continue
        tr = load(data, rel)
        if not isinstance(tr, dict):
            raise Refused(3, "%s is not an object" % rel)
        picked = {n: tr[n] for n in sorted(names) if isinstance(tr.get(n), str) and tr[n] != "" and tr[n] != n}
        missing = sorted(n for n in names if n not in tr)
        out[lang] = picked
        notes.append("%s: %d of %d catalogue names translated, %d without entry (English fallback)" % (lang, len(picked), len(names), len(missing)))
        lg = [g["name"] for g in tables["legends.json"]]
        if not any(n in tr for n in lg):
            warnings.append("%s: legendary names/heads have no translation anywhere in the data; they stay English" % lang)
    return out


# ------------------------------------------------------------------ Lua emission
def q(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif o < 32 or o == 127:
            out.append("\\%03d" % o)
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lv(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        return q(v)
    raise TypeError(type(v))


def rec(pairs):
    return "{" + ",".join("%s=%s" % (k, lv(v)) for k, v in pairs) + "}"


def arr(values):
    return "{" + ",".join(lv(v) for v in values) + "}"


def mapof(d, valfn):
    return "{\n" + "".join("  [%s]=%s,\n" % (q(k), valfn(d[k])) for k in sorted(d)) + " }"


def build_lua(index, tables, tr, info, warnings):
    T = tables
    counts = {n[:-5]: len(T[n]) for n in REQUIRED}
    body = []
    body.append("classes={\n" + "".join(" " + rec([("key", c["key"]), ("token", c["token"]), ("id", c["id"]), ("name", c["name"])])[:-1]
                                         + ",spells=" + arr(c["spells"]) + "},\n" for c in T["classes.json"]) + "}")
    body.append("spells={\n" + "".join(" " + rec([("key", s["key"]), ("class", s["class"]), ("id", s["id"]), ("name", s["name"]),
                                                   ("icon", s["icon"]), ("legendary", s["legendary"])]) + ",\n" for s in T["spells.json"]) + "}")
    body.append("jewelry={\n" + "".join(" " + rec([("key", j["key"]), ("slot", j["slot"]), ("name", j["name"]), ("icon", j["icon"])]) + ",\n" for j in T["jewelry.json"]) + "}")
    body.append("amulets={\n" + "".join(" " + rec([("key", a["key"]), ("rarity", a["rarity"]), ("name", a["name"]), ("icon", a["icon"])])[:-1]
                                         + ",classes=" + arr(a["classes"]) + "},\n" for a in T["amulets.json"]) + "}")
    body.append("legends={\n" + "".join(" " + rec([("key", g["key"]), ("spell", g["spell"]), ("class", g["class"]), ("name", g["name"]),
                                                    ("head", g["head"]), ("icon", g["icon"])]) + ",\n" for g in T["legends.json"]) + "}")
    byclass = {}
    for g in T["legends.json"]:
        byclass.setdefault(g["class"], []).append(g["key"])
    amul = {}
    for c in T["classes.json"]:
        amul[c["key"]] = [a["key"] for a in T["amulets.json"] if not a["classes"] or c["key"] in a["classes"]]
    jslot = {s: [j["key"] for j in T["jewelry.json"] if j["slot"] == s] for s in SLOTS}
    body.append("index={\n legendsByClass=%s,\n amuletsByClass=%s,\n jewelryBySlot=%s,\n homonyms=%s,\n sharedIcons=%s,\n}" % (
        mapof(byclass, arr), mapof(amul, arr), mapof(jslot, arr), mapof(info["homonyms"], arr), mapof(info["sharedIcons"], arr)))
    body.append("i18n={\n" + "".join(" [%s]=%s,\n" % (q(l), mapof(tr[l], q)) for l in sorted(tr)) + "}")
    body.append("anomalies={\n" + "".join(" " + rec([("code", a["code"]), ("key", a["key"]), ("class", a["class"]), ("detail", a["detail"])]) + ",\n" for a in info["anomalies"]) + "}")
    text = ",\n".join(body)
    body_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()
    head = ("-- GENERATED FILE: do not edit. tools/generate_catalog.py v%d from data/v1 content %s (schema %d).\n"
            "-- Pure data, Lua 5.1, deterministic. Names/icons are display data, never identifiers; keys are the official ones.\n"
            "local ADDON, ns = ...;\nns = ns or {};\n" % (GENERATOR_VERSION, index["content"], index["schema"]))
    meta = "meta={schema=%d,content=%s,generator=%d,bodySha256=%s,counts=%s}" % (
        index["schema"], q(index["content"]), GENERATOR_VERSION, q(body_hash), "{" + ",".join("%s=%d" % (k, counts[k]) for k in sorted(counts)) + "}")
    full = head + "ns.GeneratedCatalog = {\n" + meta + ",\n" + text + ",\n};\n"
    return full, body_hash, counts


def generate(data):
    index, tables, errors, warnings, notes, info = validate(data)
    if errors:
        raise Refused(3, "structural errors:\n  " + "\n  ".join(errors))
    tr = translations(data, index, tables, warnings, notes)
    lua, body_hash, counts = build_lua(index, tables, tr, info, warnings)
    report = ["Catalogue generation report", "===========================",
              "source content hash : %s" % index["content"], "schema              : %d (generator %d)" % (index["schema"], GENERATOR_VERSION)]
    for k in sorted(counts):
        report.append("  %-9s %d" % (k, counts[k]))
    raw = lua.encode("utf-8")
    report += ["generated bytes    : %d" % len(raw), "generated sha256   : %s" % hashlib.sha256(raw).hexdigest(),
               "body sha256        : %s" % body_hash,
               "translated names   : %s" % ", ".join("%s=%d" % (l, len(tr[l])) for l in sorted(tr)),
               "errors             : 0", "warnings           : %d" % len(warnings)]
    report += ["  W " + w for w in warnings]
    report += ["notes              : %d" % len(notes)] + ["  N " + n for n in notes]
    report += ["anomalies recorded in the catalogue (%d):" % len(info["anomalies"])] + ["  A %s %s" % (a["code"], a["key"]) for a in info["anomalies"]]
    report += ["shared icons groups: %d ; shared legend heads: %d groups (largest %d)" % (
        len(info["sharedIcons"]), len(info["sharedHeads"]), max(info["sharedHeads"].values()) if info["sharedHeads"] else 0)]
    return raw, "\n".join(report) + "\n"


def main(argv):
    def opt(name, default):
        return argv[argv.index(name) + 1] if name in argv else default
    data, out, rep = opt("--data", DEFAULT_DATA), opt("--out", DEFAULT_OUT), opt("--report", DEFAULT_REPORT)
    try:
        raw, report = generate(data)
    except Refused as e:
        sys.stderr.write("REFUSED (%d): %s\n" % (e.code, e))
        return e.code
    if "--check" in argv:
        same = os.path.exists(out) and open(out, "rb").read() == raw
        print("catalogue up to date" if same else "catalogue DIFFERS from regenerated output")
        return 0 if same else 1
    for path, content in ((out, raw), (rep, report.encode("utf-8"))):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "wb") as fh:
            fh.write(content)
        os.replace(tmp, path)
    sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
