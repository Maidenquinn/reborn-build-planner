"""Read-only, original extractor of Reborn jewelry facts from a locally owned game executable.

Output is OPTIONAL local GeneratedJewelryMechanics.lua, never committed. No injected code,
no disassembly, no networking, no alteration of the executable, no game assets distributed.
The format is independently parsed and every record validated against jewelry.json.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

KEY = re.compile(r'^[a-z0-9_]+$')
REC = re.compile(r'\[\[(jewel|amulet)\]\]\s*key\s*=\s*"([a-z0-9_]+)"')
FIELD = re.compile(r'\b([a-z_]+)\s*=\s*"([^"\r\n]*)"')
NUMBER = re.compile(r'\bbase\s*=\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)')
BOUNDARY = re.compile(r'\[\[(?:jewel|amulet|spell|legend)\]\]|(?:base|tbc|wotlk|cata)/[a-zA-Z0-9_./-]+\.toml')
SAFE_BEHAVIOR = re.compile(r'^[a-z_]{1,40}$')

def read_records(blob):
    text = blob.decode("utf-8", errors="replace")
    out = {}
    matches = list(REC.finditer(text))
    for i, m in enumerate(matches):
        start = m.end()
        stop = min(len(text), start + 10000)
        if i + 1 < len(matches):
            stop = min(stop, matches[i + 1].start())
        body = text[start:stop]
        cut = BOUNDARY.search(body)
        if cut:
            body = body[:cut.start()]
        if m.group(1) != "jewel":
            continue
        key = m.group(2)
        # The same source can appear more than once embedded in the executable.
        fields = dict(FIELD.findall(body))
        slot = fields.get("slot")
        behavior = fields.get("behavior")
        base = NUMBER.search(body)
        if slot not in ("ring", "trinket") or not behavior or not SAFE_BEHAVIOR.fullmatch(behavior):
            continue
        if base is None:
            continue
        value = float(base.group(1))
        if not (-1e6 < value < 1e6):
            continue
        record = {"slot": slot, "behavior": behavior, "base": value}
        if key in out and out[key] != record:
            raise ValueError("Conflicting repeated source record for " + key)
        out[key] = record
    return out

def quoted(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def format_number(n):
    return format(n, ".12g")

def render(records, digest):
    rows = [
        "-- Generated from a LOCAL copy of Reborn; do not redistribute without checking rights.",
        "-- Source executable SHA-256: " + digest,
        "local ADDON, ns = ...",
        "ns.GeneratedJewelryMechanics = {",
        "  source = " + quoted(digest) + ",",
        "  items = {"
    ]
    for key, rec in sorted(records.items()):
        rows.append("    [" + quoted(key) + "] = { slot = " + quoted(rec["slot"])
                    + ", behavior = " + quoted(rec["behavior"])
                    + ", base = " + format_number(rec["base"]) + " },")
    rows += ["  },", "}", ""]
    return "\n".join(rows)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--exe", required=True, type=Path, help="Local game executable (read-only)")
    ap.add_argument("--catalog", required=True, type=Path, help="Official data/v1/jewelry.json (local)")
    ap.add_argument("--out", required=True, type=Path, help="Output Lua file (in local addon copy)")
    args = ap.parse_args()
    if not args.exe.is_file() or not args.catalog.is_file():
        ap.error("Both the executable and jewelry.json must already exist locally")
    data = args.exe.read_bytes()
    if data[:2] != b"MZ":
        ap.error("Not a Windows game executable")
    records = read_records(data)
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    expected = {x["key"]: x["slot"] for x in catalog}
    for k, v in records.items():
        if k not in expected or v["slot"] != expected[k]:
            ap.error("Source/catalog mismatch: " + k)
    missing = sorted(set(expected) - set(records))
    if missing or len(records) < 30:
        ap.error("Extraction incomplete; no output written. Missing keys: " + ", ".join(missing[:12]))
    result = render(records, hashlib.sha256(data).hexdigest())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(result, encoding="utf-8", newline="\n")
    print("OK: %d locally sourced jewelry records -> %s" % (len(records), args.out))

if __name__ == "__main__":
    main()
