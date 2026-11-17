"""Verifies that every source line cited in docs/CONTRACTS.md still exists where claimed.

  python -I tools/check_anchors.py --native-root "<...>\\Interface\\AddOns"          # check
  python -I tools/check_anchors.py --native-root "<...>" --emit                     # (re)compute line numbers

tests/static_anchors.json: [{id, file (relative to AddOns), pattern (regex), line (1-based), nth (default 1), claim}]
Read-only on the game install.
"""
import json
import os
import re
import sys


def _lines(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().split("\n")


def check(native_root, anchors_path, emit=False):
    with open(anchors_path, encoding="utf-8") as fh:
        anchors = json.load(fh)
    out = []
    cache = {}
    for a in anchors:
        p = os.path.join(native_root, *a["file"].split("/"))
        if p not in cache:
            cache[p] = _lines(p) if os.path.exists(p) else None
        lines = cache[p]
        r = {"id": a["id"], "file": a["file"], "line": a.get("line"), "ok": False}
        if lines is None:
            r["why"] = "file missing"
            out.append(r)
            continue
        rx = re.compile(a["pattern"])
        hits = [i + 1 for i, t in enumerate(lines) if rx.search(t)]
        nth = a.get("nth", 1)
        if emit:
            if len(hits) >= nth:
                a["line"] = hits[nth - 1]
                r["line"] = a["line"]
                r["ok"] = True
            else:
                r["why"] = "pattern not found"
        else:
            r["ok"] = a.get("line") in hits
            if not r["ok"]:
                r["why"] = "pattern at %r, claimed %r" % (hits[:5], a.get("line"))
        out.append(r)
    if emit:
        with open(anchors_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(anchors, fh, indent=1, ensure_ascii=False)
            fh.write("\n")
    return out


if __name__ == "__main__":
    root = sys.argv[sys.argv.index("--native-root") + 1]
    here = os.path.dirname(os.path.abspath(__file__))
    res = check(root, os.path.join(here, "..", "tests", "static_anchors.json"), "--emit" in sys.argv)
    bad = [r for r in res if not r["ok"]]
    for r in res:
        print("OK  " if r["ok"] else "FAIL", r["id"], r["file"], r["line"], r.get("why", ""))
    print("%d anchors, %d failing" % (len(res), len(bad)))
    sys.exit(1 if bad else 0)
