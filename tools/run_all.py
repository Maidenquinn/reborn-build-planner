"""One command for every check of the project. Writes tests/results/last_run.txt.

  python -I tools/run_all.py [--native-root "<...>\\Interface\\AddOns"]

Every step ends as PASS, SKIPPED (a precondition is missing: the step did NOT run and proves nothing) or FAIL.
Exit code: 0 = all PASS, 1 = at least one FAIL, 3 = no FAIL but at least one SKIPPED. A skipped comparison is never green.

Local-only inputs (NOT versioned, see docs/PROVENANCE.md):
  RBP_CATALOG_DIR       directory holding the official data/v1 files (index.json, classes.json, spells.json, ...)
                        default: .local/catalog/384db000d5ac311d
  RBP_OFFICIAL_BUNDLE   path of the official planner bundle (BYjmu0KK.js), only for the optional JS<->Lua comparison
                        default: .local/reference/BYjmu0KK.js
Without the catalogue, GeneratedCatalog.lua is absent and the catalogue-dependent suites are SKIPPED; the standalone suites run.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PY = sys.executable
VENV = os.path.join(ROOT, ".devtools", "venv", "Scripts", "python.exe")
if not os.path.exists(VENV):
    VENV = os.path.join(ROOT, ".devtools", "venv", "bin", "python")
extra = ["--native-root", sys.argv[sys.argv.index("--native-root") + 1]] if "--native-root" in sys.argv else []
CAT = os.environ.get("RBP_CATALOG_DIR") or os.path.join(ROOT, ".local", "catalog", "384db000d5ac311d")
BUNDLE = os.environ.get("RBP_OFFICIAL_BUNDLE") or os.path.join(ROOT, ".local", "reference", "BYjmu0KK.js")
GEN = os.path.join(ROOT, "addon", "RebornBuildPlanner", "GeneratedCatalog.lua")
NODE = shutil.which("node")
log, state = [], {"fail": 0, "skip": 0, "pass": 0}


def run(name, cmd, skip_reason=None):
    if skip_reason:
        log.append("== %s: SKIPPED (%s)" % (name, skip_reason))
        state["skip"] += 1
        return
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = [l for l in (p.stdout + p.stderr).splitlines() if l.strip()]
    summary = [l for l in tail if "passed" in l or "FAIL" in l or "up to date" in l or "DIFFERS" in l or "verified" in l][-3:]
    if p.returncode == 3 and any(l.startswith("SKIPPED") for l in tail):
        log.append("== %s: SKIPPED (%s)" % (name, [l for l in tail if l.startswith("SKIPPED")][0][9:]))
        state["skip"] += 1
        return
    log.append("== %s: %s" % (name, "PASS" if p.returncode == 0 else "FAIL (exit %d)" % p.returncode))
    log.extend("   " + l for l in summary)
    if p.returncode != 0:
        state["fail"] += 1
        log.extend("   " + l for l in tail[-15:])
    else:
        state["pass"] += 1


have_cat_src = os.path.isdir(CAT)
if not os.path.exists(GEN) and have_cat_src:
    run("generate GeneratedCatalog.lua from local source", [PY, "-I", "tools/generate_catalog.py"])
no_cat = None if (os.path.exists(GEN) or have_cat_src) else "no catalogue: set RBP_CATALOG_DIR (docs/PROVENANCE.md)"
no_cat = no_cat if not os.path.exists(GEN) else None

run("catalogue up to date", [PY, "-I", "tools/generate_catalog.py", "--check"], no_cat or (None if have_cat_src else "catalogue source absent"))
run("original fantasy textures generated", [PY, "-I", "tools/make_ultimate_art.py", "addon_lab/RebornPlannerThemeLab/Media"])
run("textures up to date", [PY, "-I", "tools/make_textures.py", "addon_lab/RebornPlannerThemeLab/Media", "--check"])
run("jewelry extractor synthetic tests", [PY, "-I", "tests/py/test_jewelry_extractor.py"])
run("generator tests", [PY, "-I", "tests/py/test_generator.py"], no_cat or (None if have_cat_src else "catalogue source absent"))
run("Lot 0 suite", [PY, "-I", "tools/run_tests.py"] + extra, None if have_cat_src else "catalogue source absent")
if not os.path.exists(VENV):
    run("Lua 5.1 standalone suite", [], "isolated Lua 5.1 not installed (.devtools/venv + lupa)")
    run("Lua 5.1 catalogue suites", [], "isolated Lua 5.1 not installed")
else:
    run("Lua 5.1 standalone suite (no catalogue, no bundle)", [VENV, "tools/run_lua_tests.py", "test_standalone"])
    run("Lua 5.1 catalogue suites", [VENV, "tools/run_lua_tests.py"], no_cat)
js_reason = None
if not NODE:
    js_reason = "node not found"
elif not os.path.exists(BUNDLE):
    js_reason = "official bundle not provided: set RBP_OFFICIAL_BUNDLE (optional comparison)"
elif not have_cat_src:
    js_reason = "catalogue source absent"
elif no_cat or not os.path.exists(os.path.join(ROOT, "tests", "results", "lua_origin.json")):
    js_reason = "Lua catalogue suites did not run"
run("JS <-> Lua cross-check (official decoder)", [NODE or "node", "tools/verify_reencoded.mjs", BUNDLE, CAT, "tests"], js_reason)
log.append("== summary: %d PASS, %d SKIPPED, %d FAIL" % (state["pass"], state["skip"], state["fail"]))
text = "\n".join(log) + "\n"
os.makedirs(os.path.join(ROOT, "tests", "results"), exist_ok=True)
with open(os.path.join(ROOT, "tests", "results", "last_run.txt"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write(text)
sys.stdout.write(text)
sys.exit(1 if state["fail"] else (3 if state["skip"] else 0))