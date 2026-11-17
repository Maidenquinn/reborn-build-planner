"""Fetch the game's public data/v1 catalogue for PRIVATE testing/build workflows.
The game/site explicitly publishes data files for use in tools. Do not commit inputs.
No game executable, account data, or third-party repository code is used.
"""
import argparse
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

BASE = "https://azreborn.com/data/v1/"
FILES = ("index.json", "classes.json", "spells.json", "jewelry.json",
         "amulets.json", "legends.json", "i18n/frFR.json")
MAX_BYTES = 3_000_000

def fetch(name):
    if name not in FILES:
        raise ValueError("Not an approved catalogue file: " + name)
    req = Request(BASE + name, headers={"User-Agent": "RebornBuildPlanner-PrivateRecipe/1.0"})
    with urlopen(req, timeout=40) as response:
        data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise ValueError("File exceeds safe download size: " + name)
        return data

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=Path(".local/catalog/public-preview"))
    args = ap.parse_args()
    # Refuse a mixed-version snapshot; do not silently merge official data revisions.
    index_before = fetch("index.json")
    manifest = json.loads(index_before)
    if manifest.get("schema") != 1:
        raise ValueError("Unsupported official schema")
    for name in FILES[1:]:
        if name not in manifest.get("files", {}):
            raise ValueError("Missing catalogue entry in official index: " + name)
    payloads = {"index.json": index_before}
    for name in FILES[1:]:
        payloads[name] = fetch(name)
    index_after = fetch("index.json")
    if json.loads(index_before).get("content") != json.loads(index_after).get("content"):
        raise ValueError("Official catalogue changed mid-download; no files written")
    for name in FILES[1:]:
        json.loads(payloads[name])
    args.out.mkdir(parents=True, exist_ok=True)
    for name, data in payloads.items():
        path = args.out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print("Official public catalogue content:", manifest["content"])
    print("Files downloaded:", len(FILES), "to", args.out)
if __name__ == "__main__":
    main()
