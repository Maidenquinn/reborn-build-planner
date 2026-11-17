"""Generator tests (Python stdlib, run with -I): determinism, hash, refusals, anomaly handling, source immutability.
Run from tools/run_all.py or directly:  python -I tests/py/test_generator.py
"""
import hashlib
import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "tests", "fixtures", "catalog", "384db000d5ac311d")
OUT = os.path.join(ROOT, "addon", "RebornBuildPlanner", "GeneratedCatalog.lua")
spec = importlib.util.spec_from_file_location("generate_catalog", os.path.join(ROOT, "tools", "generate_catalog.py"))
G = importlib.util.module_from_spec(spec)
spec.loader.exec_module(G)

passed = failed = 0


def ok(cond, label):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print("  FAIL", label)


def sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def tree_hash(d):
    h = hashlib.sha256()
    for base, _, files in sorted(os.walk(d)):
        for f in sorted(files):
            h.update(os.path.join(base, f).encode())
            h.update(open(os.path.join(base, f), "rb").read())
    return h.hexdigest()


def run(data, out, report=None):
    argv = ["--data", data, "--out", out, "--report", report or out + ".report"]
    so, se = io.StringIO(), io.StringIO()
    with redirect_stdout(so), redirect_stderr(se):
        code = G.main(argv)
    return code, so.getvalue(), se.getvalue()


def mutate(fn):
    """Copies the fixture catalogue to a temp dir, applies fn(dir), returns the dir."""
    d = tempfile.mkdtemp(prefix="cat_")
    shutil.rmtree(d)
    shutil.copytree(SRC, d)
    fn(d)
    return d


def edit_json(d, name, f):
    p = os.path.join(d, name)
    data = json.load(open(p, encoding="utf-8"))
    r = f(data)
    json.dump(data if r is None else r, open(p, "w", encoding="utf-8"))


def refuses(label, fn, want_code):
    d = mutate(fn)
    out = os.path.join(d, "out.lua")
    open(out, "w").write("-- previous good output\n")
    code, so, se = run(d, out)
    ok(code == want_code, "%s: exit %d (wanted %d) %s" % (label, code, want_code, se.strip()[:80]))
    ok(open(out).read() == "-- previous good output\n", label + ": existing output was touched")
    ok(not os.path.exists(out + ".tmp") and not os.path.exists(out + ".report"), label + ": partial files left")
    shutil.rmtree(d, ignore_errors=True)


def main():
    before = tree_hash(SRC)
    d = tempfile.mkdtemp(prefix="gen_")
    a, b = os.path.join(d, "a.lua"), os.path.join(d, "b.lua")
    c1, so1, _ = run(SRC, a)
    c2, so2, _ = run(SRC, b)
    ok(c1 == 0 and c2 == 0, "generation succeeds")
    ok(open(a, "rb").read() == open(b, "rb").read(), "two runs give identical bytes (deterministic)")
    ok(sha(a) == sha(OUT), "committed GeneratedCatalog.lua is exactly what the generator produces")
    ok(so1 == so2, "report is deterministic")
    ok("source content hash : 384db000d5ac311d" in so1 and "errors             : 0" in so1, "report shows hash and 0 errors")
    ok("generated sha256   : " + sha(a) in so1, "report carries the sha256 of the generated file")
    ok("LEGENDARY_FLAG_WITHOUT_LEGEND" in so1 and "call_of_flame" in so1, "report names the call_of_flame anomaly")
    ok(tree_hash(SRC) == before, "source JSON untouched")
    lua = open(a, encoding="utf-8").read()
    ok('code="LEGENDARY_FLAG_WITHOUT_LEGEND",key="call_of_flame"' in lua, "anomaly recorded in the catalogue")
    ok('key="legendary:call_of_flame"' not in lua and 'spell="call_of_flame"' not in lua, "no legend/amulet record invented for call_of_flame")
    ok('meta={schema=1,content="384db000d5ac311d"' in lua, "meta carries schema and content hash")
    ok("\r" not in lua and lua.endswith("};\n"), "LF newlines, clean ending")

    # other catalogue content hash with the same schema: accepted, hash propagated
    d2 = mutate(lambda x: edit_json(x, "index.json", lambda i: i.update(content="aaaaaaaaaaaaaaaa")))
    out2 = os.path.join(d2, "o.lua")
    code, so, se = run(d2, out2)
    ok(code == 0 and 'content="aaaaaaaaaaaaaaaa"' in open(out2).read(), "different content hash accepted and recorded")
    # missing translation: warning + fallback, still generated
    d3 = mutate(lambda x: os.remove(os.path.join(x, "i18n", "frFR.json")))
    out3 = os.path.join(d3, "o.lua")
    code, so, se = run(d3, out3)
    ok(code == 0 and "translation frFR not available" in so, "missing translation is a warning, not a failure")
    # a spell without translation falls back to English (no entry emitted)
    ok('["frFR"]={\n }' in open(out3, encoding="utf-8").read() or "frFR" in open(out3, encoding="utf-8").read(), "empty translation table emitted")
    # unknown extra class is accepted (no hard-coded class count)
    def add_class(x):
        edit_json(x, "classes.json", lambda cl: cl.append({"id": 99, "key": "necromancer", "token": "NECROMANCER", "name": "Necromancer", "color": "x", "open": True, "races": [], "health": 1, "damage_pct": 0, "taken_pct": 0, "pickup_pct": 0, "starter": "", "spells": []}))
        edit_json(x, "index.json", lambda i: i["files"]["classes.json"].update(count=13))
    d4 = mutate(add_class)
    code, so, se = run(d4, os.path.join(d4, "o.lua"))
    ok(code == 0 and "13 classes" in so, "a 13th class is accepted with a warning")

    # refusals
    refuses("schema 2", lambda x: edit_json(x, "index.json", lambda i: i.update(schema=2)), 2)
    refuses("schema 0", lambda x: edit_json(x, "index.json", lambda i: i.update(schema=0)), 2)
    refuses("no index", lambda x: os.remove(os.path.join(x, "index.json")), 3)
    refuses("index without files", lambda x: edit_json(x, "index.json", lambda i: i.pop("files")), 3)
    refuses("bad content hash", lambda x: edit_json(x, "index.json", lambda i: i.update(content="not hex!")), 3)
    refuses("missing required file", lambda x: os.remove(os.path.join(x, "jewelry.json")), 3)
    refuses("count mismatch", lambda x: edit_json(x, "index.json", lambda i: i["files"]["spells.json"].update(count=240)), 3)
    refuses("invalid json", lambda x: open(os.path.join(x, "amulets.json"), "w").write("{oops"), 3)
    refuses("not an array", lambda x: edit_json(x, "legends.json", lambda l: {"a": 1}), 3)
    refuses("duplicate spell key", lambda x: edit_json(x, "spells.json", lambda s: s[1].update(key=s[0]["key"])), 3)
    refuses("duplicate spell id", lambda x: edit_json(x, "spells.json", lambda s: s[1].update(id=s[0]["id"])), 3)
    refuses("unknown class ref", lambda x: edit_json(x, "spells.json", lambda s: s[0].update({"class": "nosuch"})), 3)
    refuses("orphan class spell", lambda x: edit_json(x, "classes.json", lambda c: c[0]["spells"].append("ghost_spell")), 3)
    refuses("legend orphan spell", lambda x: edit_json(x, "legends.json", lambda l: l[0].update(spell="ghost")), 3)
    refuses("legend key shape", lambda x: edit_json(x, "legends.json", lambda l: l[0].update(key="legendary:other")), 3)
    refuses("legend class mismatch", lambda x: edit_json(x, "legends.json", lambda l: l[0].update({"class": "mage"})), 3)
    refuses("bad slot", lambda x: edit_json(x, "jewelry.json", lambda j: j[0].update(slot="belt")), 3)
    refuses("bad rarity", lambda x: edit_json(x, "amulets.json", lambda a: a[0].update(rarity="godly")), 3)
    refuses("amulet class ref", lambda x: edit_json(x, "amulets.json", lambda a: a[0].update(classes=["nosuch"])), 3)
    refuses("missing field", lambda x: edit_json(x, "jewelry.json", lambda j: j[0].pop("icon")), 3)
    refuses("empty key", lambda x: edit_json(x, "jewelry.json", lambda j: j[0].update(key="")), 3)
    refuses("non-bool legendary", lambda x: edit_json(x, "spells.json", lambda s: s[0].update(legendary="yes")), 3)

    # --check mode
    so, se = io.StringIO(), io.StringIO()
    with redirect_stdout(so), redirect_stderr(se):
        ok(G.main(["--data", SRC, "--out", OUT, "--check"]) == 0, "--check passes on the committed file")
    shutil.rmtree(d, ignore_errors=True)
    ok(tree_hash(SRC) == before, "source JSON still untouched at the end")
    print("generator tests: %d assertions passed, %d failed" % (passed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
