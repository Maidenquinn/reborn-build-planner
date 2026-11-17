"""One command for every check of the project (Lots 0 and 1). Writes tests/results/last_run.txt.

  python -I tools/run_all.py [--native-root "<...>\\Interface\\AddOns"]

Steps: catalogue up to date (--check) · generator tests · Lot 0 suite (Python/Node) · Lua 5.1 suites · JS<->Lua codec cross-check.
The Lua step needs the isolated dev interpreter (.devtools/venv, lupa/Lua 5.1); without it the step is reported
as SKIPPED and the exit code is 3 (PASS CONDITIONAL), never silently green.
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

steps = [
    ("catalogue up to date", [PY, "-I", "tools/generate_catalog.py", "--check"]),
    ("generator tests", [PY, "-I", "tests/py/test_generator.py"]),
    ("Lot 0 suite", [PY, "-I", "tools/run_tests.py"] + extra),
]
lua_step = ("Lua 5.1 suites", [VENV, "tools/run_lua_tests.py"])
NODE = shutil.which("node")
REF = os.path.join("tests", "fixtures", "codec", "reference", "BYjmu0KK.js")
js_step = ("JS <-> Lua cross-check (official decoder)", [NODE or "node", "tools/verify_reencoded.mjs", REF, os.path.join("tests", "fixtures", "catalog", "384db000d5ac311d"), "tests"])
log, bad, skipped = [], 0, 0
for name, cmd in steps + [lua_step, js_step]:
    if name == js_step[0] and (not NODE or not os.path.exists(os.path.join(ROOT, "tests", "results", "lua_origin.json"))):
        log.append("== %s: SKIPPED (node or Lua results missing)" % name)
        skipped += 1
        continue
    if name == lua_step[0] and not os.path.exists(VENV):
        log.append("== %s: SKIPPED (isolated Lua 5.1 not installed; see docs/REPORT_LOT1.md)" % name)
        skipped += 1
        continue
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = [l for l in (p.stdout + p.stderr).splitlines() if l.strip()]
    summary = [l for l in tail if "passed" in l or "FAIL" in l or "up to date" in l or "DIFFERS" in l or "verified" in l][-3:]
    log.append("== %s: %s" % (name, "PASS" if p.returncode == 0 else "FAIL (exit %d)" % p.returncode))
    log += ["   " + l for l in summary]
    if p.returncode != 0:
        bad += 1
        log += ["   " + l for l in tail[-15:]]
text = "\n".join(log) + "\n"
os.makedirs(os.path.join(ROOT, "tests", "results"), exist_ok=True)
with open(os.path.join(ROOT, "tests", "results", "last_run.txt"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write(text)
sys.stdout.write(text)
sys.exit(1 if bad else (3 if skipped else 0))
