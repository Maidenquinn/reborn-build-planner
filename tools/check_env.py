"""Reports which interpreters/tools exist for Lot 0 testing. Changes nothing, installs nothing.
   python -I tools/check_env.py
The client embeds Lua 5.1 (3.3.5a). A modern Lua is NOT equivalent: only a 5.1/LuaJIT interpreter may be used
as an approximation, and only the real client counts as proof.
"""
import shutil
import subprocess
import sys

rows = []
for name in ("lua", "lua5.1", "lua51", "luajit", "luac", "luacheck", "node", "python", "git"):
    p = shutil.which(name)
    ver = ""
    if p and name in ("lua", "lua5.1", "lua51", "luajit", "node"):
        try:
            ver = subprocess.run([p, "-v" if name != "node" else "--version"], capture_output=True, text=True, timeout=10)
            ver = (ver.stdout or ver.stderr).strip().splitlines()[0]
        except Exception as e:  # pragma: no cover
            ver = "error: %s" % e
    rows.append((name, p or "ABSENT", ver))
for r in rows:
    print("%-9s %-60s %s" % r)
has_lua51 = any(r[1] != "ABSENT" and ("5.1" in r[2] or "LuaJIT" in r[2]) for r in rows if r[0] in ("lua", "lua5.1", "lua51", "luajit"))
import os
venv = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".devtools", "venv", "Scripts", "python.exe")
lupa = ""
if os.path.exists(venv):
    r = subprocess.run([venv, "-c", "from lupa.lua51 import LuaRuntime as R; print(R().eval('_VERSION'))"], capture_output=True, text=True)
    lupa = r.stdout.strip() or "venv present, lupa not importable"
print("\nLua 5.1 on PATH:", "YES" if has_lua51 else "NO")
print("Isolated dev interpreter (.devtools/venv, lupa):", lupa or "NOT INSTALLED (docs/REPORT_LOT1.md explains how)")
print("python", sys.version.split()[0])
