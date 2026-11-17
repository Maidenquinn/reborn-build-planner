"""Lot 0 test runner (Python standard library only; run with -I).

  python -I tools/run_tests.py [--native-root <...\\Interface\\AddOns>]

Suites: catalog-identity, grammar-port, synthetic scenarios, static anchors, codec golden (needs node).
What this proves: the contracts documented in docs/CONTRACTS.md are internally consistent and the cited
source lines still exist. What it does NOT prove: any behaviour of the real client (see VALIDATION_PLAN.md).
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CATALOG = os.path.join(ROOT, "tests", "fixtures", "catalog", "384db000d5ac311d")

spec = importlib.util.spec_from_file_location("lot0_model", os.path.join(HERE, "lot0_model.py"))
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)

passed = failed = 0
failures = []


def ok(cond, label):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        failures.append(label)
        print("  FAIL", label)


def subset(exp, got, path=""):
    """exp is a subset of got (dicts recursive, lists exact)."""
    if isinstance(exp, dict):
        if not isinstance(got, dict):
            return ["%s: expected object, got %r" % (path, got)]
        errs = []
        for k, v in exp.items():
            if k not in got:
                errs.append("%s.%s missing" % (path, k))
            else:
                errs += subset(v, got[k], path + "." + k)
        return errs
    return [] if exp == got else ["%s: expected %r, got %r" % (path, exp, got)]


# ------------------------------------------------------------------ 1. catalogue identity facts
def suite_catalog():
    print("[catalog-identity]")
    cat = M.Catalog(CATALOG)
    idx = cat.index
    ok(idx["content"] == "384db000d5ac311d" and idx["schema"] == 1, "index content/schema")
    for name, lst in (("spells.json", cat.spells), ("jewelry.json", cat.jewelry), ("amulets.json", cat.amulets),
                      ("legends.json", cat.legends), ("classes.json", cat.classes)):
        ok(idx["files"][name]["count"] == len(lst), "count " + name)
    ok(len({s["id"] for s in cat.spells}) == len(cat.spells), "spell ids unique")
    ok(len({s["key"] for s in cat.spells}) == len(cat.spells), "spell keys unique")
    ok(all(g["key"] == "legendary:" + g["spell"] for g in cat.legends), "legend key == legendary:<spell>")
    ok(len({g["key"] for g in cat.legends}) == len(cat.legends), "legend keys unique")
    # facts the contracts rely on
    icons = {}
    for j in cat.jewelry:
        icons.setdefault(j["icon"], []).append(j["key"])
    shared = {k: v for k, v in icons.items() if len(v) > 1}
    ok(shared == {"INV_Jewelry_Ring_15": ["accuria", "elementium_signet"]}, "jewelry icon sharing is exactly accuria/elementium_signet: %r" % shared)
    ok(len({j["name"] for j in cat.jewelry}) == len(cat.jewelry), "jewelry English names unique")
    heads = {}
    for g in cat.legends:
        heads.setdefault(g["head"], []).append(g["key"])
    ok(sum(1 for v in heads.values() if len(v) > 1) == 13 and max(len(v) for v in heads.values()) == 44, "legend heads shared (13 groups, largest 44)")
    names = {}
    for g in cat.legends:
        names.setdefault(g["name"], []).append((g["class"], g["key"]))
    homonyms = {k: sorted(v) for k, v in names.items() if len(v) > 1}
    ok(sorted(homonyms) == ["Eye of the Splitting Sky: Death Coil", "The Eternal Talisman: Metamorphosis"], "exactly two homonymous legend names")
    ok(all(len({c for c, _ in v}) == len(v) for v in homonyms.values()), "homonyms differ by class")
    ok(len({(g["class"], g["name"]) for g in cat.legends}) == len(cat.legends), "(class, full name) unique for legends")
    ok(not any(g["name"] in {a["name"] for a in cat.amulets} for g in cat.legends), "no legend name equals a fixed amulet name")
    flagged = {s["key"] for s in cat.spells if s["legendary"]}
    ok(flagged - {g["spell"] for g in cat.legends} == {"call_of_flame"}, "catalogue anomaly: call_of_flame flagged legendary but has no legends.json row")
    fr = M.Catalog(CATALOG, "frFR")
    ok(all(j["name"] in fr.tr for j in cat.jewelry) and all(a["name"] in fr.tr for a in cat.amulets), "frFR translates every jewelry/amulet name")
    ok(not any(g["head"] in fr.tr or g["name"] in fr.tr for g in cat.legends), "frFR has NO legend head/full name (legend names are unlocalised in the data)")
    ok(len({fr.loc(j["name"]) for j in cat.jewelry}) == len(cat.jewelry), "frFR jewelry names stay unique")


# ------------------------------------------------------------------ 2. grammar port edge cases
def suite_grammar():
    print("[grammar-port]")
    ok(M.parse_kv("a=1;b=x;c=") == {"a": 1, "b": "x", "c": ""}, "kv basic/number coercion")
    ok(M.parse_kv("my_key=5") == {"key": 5}, "kv: %w excludes underscore, so my_key=5 is read as key=5 (Core.lua:144)")
    ok(M.parse_kv("kind=spell;c=a,b;x=1")["c"] == "a,b", "kv stops a value at ';'")
    ok(M.parse_list("a,1,2,9,9", ["k", "n"]) == [{"k": "a", "n": 1}], "list: extra values beyond names are dropped (Core.lua:156)")
    ok(M.parse_list("a;;b", ["k"]) == [{"k": "a"}, {"k": "b"}], "list: empty rows skipped")
    ok(M.parse_list("", ["k"]) == [], "list: empty line = zero rows")
    ok(M.parse_list("a,,c", ["x", "y", "z"]) == [{"x": "a", "y": "", "z": "c"}], "list: empty middle value kept as empty string")
    ok(M.parse_list("a", ["x", "y"]) == [{"x": "a"}], "list: missing trailing field is nil (absent), not ''")
    c = M.parse_cards("kind=spell;bn=2;c=a,1,2,0,1,d1/b,2,1,1,0,d2")
    ok(len(c["cards"]) == 2 and c["cards"][1]["key"] == "b" and c["bn"] == 2, "cards: spell hand")
    c = M.parse_cards("kind=jewel;c=ring~x~i~n~e~d~o~ring")
    ok(c["cards"][0]["rarity"] == 0 and c["cards"][0]["slot"] == "ring", "cards: jewel rarity non numeric -> 0")


# ------------------------------------------------------------------ 3. synthetic scenarios
def run_scenario(path):
    doc = json.load(open(path, encoding="utf-8"))
    cat = M.Catalog(CATALOG, "enUS" if doc.get("clientLanguage") == "enUS" else doc["clientLanguage"])
    m = M.Model(cat)
    toks = {}
    for n, st in enumerate(doc["steps"], 1):
        op = st["op"]
        tag = "%s step %d" % (doc["id"], n)
        if op == "world_enter":
            m.world_enter(st.get("session"))
        elif op == "line":
            m.line(st["prefix"], st["msg"])
        elif op == "token":
            toks[st["name"]] = m.token()
        elif op == "check":
            errs = subset(st.get("expect", {}), m.view(), "view")
            ids = m.identities()
            for k, exp in st.get("identities", {}).items():
                errs += subset(exp, ids.get(k, {}), "id " + k) if k in ids else ["id %s absent" % k]
            for name, exp in st.get("tokens", {}).items():
                got = m.token_status(toks[name])
                if got != exp:
                    errs.append("token %s: expected %s got %s" % (name, exp, got))
            ok(not errs, tag + ": " + "; ".join(errs))
            # global invariants on every check
            if m.hand_valid():
                ok(m.lifecycle() == "CHOOSING", tag + ": hand_valid implies CHOOSING")
            ok(all(not v.get("countable") for k, v in ids.items() if k.startswith("gear")), tag + ": no gear identity countable while unverified")
            ok(all(not v.get("recommendable") for k, v in ids.items() if k.startswith("card") and m.cards.get("kind") == "jewel"), tag + ": no jewel card recommendable while unverified")
    return doc["id"]


def suite_scenarios():
    print("[synthetic scenarios]")
    files = sorted(glob.glob(os.path.join(ROOT, "tests", "fixtures", "synthetic", "*.json")))
    ok(len(files) >= 12, "at least 12 synthetic fixtures present (%d)" % len(files))
    for p in files:
        doc = json.load(open(p, encoding="utf-8"))
        ok(doc.get("provenance") == "reconstructed-from-code", os.path.basename(p) + " declares provenance")
        run_scenario(p)
    # the unverified policy flips only through an explicit flag
    cat = M.Catalog(CATALOG)
    m = M.Model(cat, jewel_identity_verified=True)
    m.world_enter("S1")
    m.line("AZSZONE", "run=r0000a001;class=warrior;hub=0")
    m.line("AZSRUN", "t=1;ph=choosing")
    m.line("AZSCARDS", "kind=jewel;c=new~1~INV_Jewelry_Ring_07~Quick Strike Ring~x~~~ring")
    ok(m.identities()["card[1]"]["recommendable"] is True, "verified flag enables a resolved jewel recommendation")
    m.line("AZSCARDS", "kind=jewel;c=new~1~INV_Jewelry_Ring_15~Unknown Ring~x~~~ring")
    ok(m.identities()["card[1]"]["recommendable"] is False, "even verified, an unresolved jewel is never recommended")


# ------------------------------------------------------------------ 4. static anchors
def suite_anchors(native_root):
    print("[static anchors]")
    spec2 = importlib.util.spec_from_file_location("check_anchors", os.path.join(HERE, "check_anchors.py"))
    A = importlib.util.module_from_spec(spec2)
    spec2.loader.exec_module(A)
    res = A.check(native_root, os.path.join(ROOT, "tests", "static_anchors.json"))
    for r in res:
        ok(r["ok"], "anchor %s %s:%s %s" % (r["id"], r["file"], r["line"], r.get("why", "")))
    print("  %d anchors checked in %s" % (len(res), native_root))


# ------------------------------------------------------------------ 5. codec golden
def suite_codec():
    print("[codec golden]")
    path = os.path.join(ROOT, "tests", "fixtures", "codec", "golden.json")
    ok(os.path.exists(path), "golden.json present")
    if not os.path.exists(path):
        return
    g = json.load(open(path, encoding="utf-8"))
    ok(g["source"]["asset"] == "BYjmu0KK.js" and g["catalog"] == "384db000d5ac311d", "golden provenance")
    import base64
    for v in g["vectors"]:
        code = v["code"]
        if not code.startswith("azsb1:"):
            continue
        raw = code[6:]
        arr = json.loads(base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)).decode("utf-8"))
        ok(arr == v["array"], "vector %s: python decodes to the same positional array the site emitted" % v["id"])
        ok("=" not in raw and "+" not in raw and "/" not in raw, "vector %s: base64url without padding" % v["id"])
    ids = {v["id"] for v in g["vectors"]}
    for need in ("empty_warrior", "four_phases_with_null", "holes_in_alternatives", "spells_and_banish", "unicode_notes", "stats_indexes", "legend_amulet"):
        ok(need in ids, "golden has vector " + need)
    ok(any(d["accepted"] is False for d in g["decodeCases"]) and any(d["accepted"] for d in g["decodeCases"]), "golden has accepted and rejected decode cases")


def main():
    native = None
    if "--native-root" in sys.argv:
        native = sys.argv[sys.argv.index("--native-root") + 1]
    else:
        for c in (r"H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\Interface\AddOns",):
            if os.path.isdir(c):
                native = c
    suite_catalog()
    suite_grammar()
    suite_scenarios()
    if native:
        suite_anchors(native)
    else:
        print("[static anchors] SKIPPED: no --native-root and the default install path is absent")
    suite_codec()
    print("\n%d assertions passed, %d failed" % (passed, failed))
    if failures:
        print("FAILED:", *failures, sep="\n  ")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
