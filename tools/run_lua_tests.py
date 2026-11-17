"""Runs the Lua 5.1 suites (tests/lua) against the REAL addon files inside a client-like sandbox.

Interpreter: PUC Lua 5.1 embedded in `lupa` (module lupa.lua51), installed ONLY in the project's isolated
dev folder:  .devtools/venv  (see docs/REPORT_LOT1.md). It is a dev/test tool; nothing of it ships.
  .devtools\\venv\\Scripts\\python.exe tools\\run_lua_tests.py [SuiteName]
Exit code = number of failed assertions (0 = pass).
"""
import os
import sys

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.stderr.write("lupa (Lua 5.1) not found: use the project venv, see docs/REPORT_LOT1.md\n")
    sys.exit(99)

lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.ROOT = root.replace("\\", "/")
g.CATALOG_DIR = (os.environ.get("RBP_CATALOG_DIR") or os.path.join(root, ".local", "catalog", "384db000d5ac311d")).replace("\\", "/")
HAVE_CAT = os.path.exists(os.path.join(root, "addon", "RebornBuildPlanner", "GeneratedCatalog.lua"))
if not HAVE_CAT and len(sys.argv) <= 1:
    sys.argv.append("test_standalone")
    sys.stderr.write("SKIPPED: catalogue-dependent Lua suites (GeneratedCatalog.lua absent; see docs/PROVENANCE.md); running test_standalone only\n")
if len(sys.argv) > 1:
    g.ONLY = sys.argv[1]
with open(os.path.join(root, "tests", "lua", "run.lua"), encoding="utf-8") as fh:
    failed = lua.execute(fh.read())
sys.exit(int(failed or 0))
