"""Read-only extraction of jewelry metadata from a locally installed Reborn executable.

This is an original parser for factual game metadata; it never opens, executes,
patches or redistributes the game. All outputs are local-only and optional.
The entire extraction is rejected if identities/slots differ from the supplied
official data/v1/jewelry.json. No output is written on failure.
"""
import argparse
import hashlib
import json
import math
import re
import tempfile
from pathlib import Path

RECORD = re.compile(r'\[\[([a-z_]+)\]\]\s*key\s*=\s*"([a-z0-9_]+)"')
NEXT = re.compile(r'\[\[[a-z_]+\]\]|(?:base|tbc|wotlk|cata)/[a-zA-Z0-9_./-]+\.toml')
NAME_FIELD = re.compile(r'(?m)^\s*(slot|behavior)\s*=\s*"([a-z_]+)"\s*$')
NUMBER = re.compile(r'(?m)^\s*base\s*=\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)\s*$')
SAFE_ID = re.compile(r'^[a-z][a-z0-9_]{0,60}$')
MAX_SPAN = 12000
MAX_BYTES = 500_000_000

def numeric(value):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
        raise ValueError("invalid finite numeric effect")
    if abs(value) > 1e6:
        raise ValueError("effect out of bounds")
    return float(value)

def payload(body, key):
    """Read an explicitly bracketed one-line array, no code execution."""
    match = re.search(r'(?m)^\s*' + re.escape(key) + r'\s*=\s*(\[[^\r\n]*\])\s*$', body)
    if not match:
        return []
    value = match.group(1)
    # Factual embedded arrays use [{ effect = 0.1 }, ...], not strict JSON.
    # Convert only identifier keys, then parse as JSON; never eval/load.
    value = re.sub(r'([,{]\s*)([a-z_]+)\s*=', r'\1"\2":', value)
    result = json.loads(value)
    if not isinstance(result, list) or len(result) > 50:
        raise ValueError("invalid effects list")
    pairs = []
    for part in result:
        if not isinstance(part, dict) or len(part) != 1:
            raise ValueError("unsupported effect object")
        k, v = next(iter(part.items()))
        if not SAFE_ID.fullmatch(k):
            raise ValueError("unsafe effect name")
        pairs.append((k, numeric(v)))
    return pairs

def specials(body):
    match = re.search(r'(?m)^\s*special\s*=\s*\{([^}\r\n]{0,3000})\}', body)
    if not match:
        return []
    pairs = []
    for part in match.group(1).split(","):
        if not part.strip():
            continue
        m = re.fullmatch(
            r'\s*([a-z_]+)\s*=\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)\s*',
            part)
        if not m or not SAFE_ID.fullmatch(m.group(1)):
            raise ValueError("invalid special property")
        pairs.append((m.group(1), numeric(float(m.group(2)))))
    return pairs

def read_records(data):
    # Executable resources may concatenate records without newlines.
    text = data.decode("utf-8", errors="replace")
    out = {}
    for m in RECORD.finditer(text):
        if m.group(1) != "jewel":
            continue
        body = text[m.end():m.end() + MAX_SPAN]
        end = NEXT.search(body)
        if end:
            body = body[:end.start()]
        fields = dict(NAME_FIELD.findall(body))
        slot, behavior = fields.get("slot"), fields.get("behavior")
        if slot not in ("ring", "trinket") or not behavior or not SAFE_ID.fullmatch(behavior):
            continue
        n = NUMBER.search(body)
        if not n:
            continue
        base = numeric(float(n.group(1)))
        rec = {
            "slot": slot, "behavior": behavior, "base": base,
            "effects": payload(body, "effects"),
            "specials": specials(body),
        }
        key = m.group(2)
        if key in out and out[key] != rec:
            raise ValueError("conflicting metadata for key " + key)
        out[key] = rec
    return out

def quoted(value):
    return json.dumps(value, ensure_ascii=False)

def format_number(n):
    return format(n, ".12g")

def lua_pairs(pairs):
    return "{ " + ", ".join(
        "{ " + quoted(k) + ", " + format_number(v) + " }" for k, v in pairs
    ) + " }"

def render(records, digest):
    lines = [
        "-- Generated from the locally installed game. Never commit or redistribute.",
        "-- Source executable SHA-256: " + digest,
        "local ADDON, ns = ...",
        "ns.GeneratedJewelryMechanics = {",
        "  source = " + quoted(digest) + ",",
        "  items = {",
    ]
    for key, row in sorted(records.items()):
        lines.append(
            "    [" + quoted(key) + "] = { slot = " + quoted(row["slot"])
            + ", behavior = " + quoted(row["behavior"])
            + ", base = " + format_number(row["base"])
            + ", effects = " + lua_pairs(row.get("effects", []))
            + ", specials = " + lua_pairs(row.get("specials", [])) + " },"
        )
    return "\n".join(lines + ["  },", "}", ""])

def validate(records, catalogue):
    if not isinstance(catalogue, list):
        raise ValueError("jewelry.json is not an array")
    expected = {}
    for row in catalogue:
        if not isinstance(row, dict):
            raise ValueError("invalid jewelry catalog row")
        key, slot = row.get("key"), row.get("slot")
        if not isinstance(key, str) or not SAFE_ID.fullmatch(key) or slot not in ("ring", "trinket"):
            raise ValueError("unexpected key/slot in official catalog")
        if key in expected:
            raise ValueError("duplicate official catalog key")
        expected[key] = slot
    if len(expected) < 30:
        raise ValueError("official jewelry catalog unexpectedly small")
    if set(records) != set(expected):
        missing = sorted(set(expected)-set(records))
        unexpected = sorted(set(records)-set(expected))
        raise ValueError("incomplete jewelry extraction: missing=%r unexpected=%r" % (missing[:12], unexpected[:12]))
    for key, item in records.items():
        if item["slot"] != expected[key]:
            raise ValueError("wrong slot for " + key)
    return len(expected)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--exe", type=Path, required=True)
    ap.add_argument("--catalog", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    if not args.exe.is_file() or not args.catalog.is_file():
        ap.error("missing locally installed exe or official jewelry.json")
    if args.exe.stat().st_size > MAX_BYTES:
        ap.error("executable exceeds extraction size limit")
    data = args.exe.read_bytes()
    if data[:2] != b"MZ":
        ap.error("not a Windows executable")
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    records = read_records(data)
    count = validate(records, catalog)
    encoded = render(records, hashlib.sha256(data).hexdigest())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Atomic replace: never leave an incomplete output on parse/validation failures.
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", newline="\n",
                                     dir=args.out.parent, prefix=".jewelry-", delete=False) as fh:
        fh.write(encoded)
        temp = Path(fh.name)
    temp.replace(args.out)
    print("PASS: extracted %d/%d validated jewelry definitions to %s" %
          (len(records), count, args.out))

if __name__ == "__main__":
    main()
