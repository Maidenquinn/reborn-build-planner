"""Validate an RBP ZIP against the structural rules of Syiana/azs-addons.

No network requests; no game assets are generated or published. This is a
preflight structural check, not authorization to redistribute any data.
Usage: python -I tools/validate_index_zip.py path/to/RebornBuildPlanner-....zip
"""
from __future__ import annotations

import re
import sys
import zipfile
from pathlib import PurePosixPath

FOLDER = "RebornBuildPlanner"
FORBIDDEN = {".exe", ".dll", ".com", ".scr", ".pif", ".msi", ".bat", ".cmd",
             ".ps1", ".vbs", ".jar", ".sh", ".lnk", ".hta"}
RESERVED = {"con", "prn", "aux", "nul", *(f"com{i}" for i in range(1, 10)),
            *(f"lpt{i}" for i in range(1, 10))}
MAX_ZIP = 64 * 1024 * 1024
MAX_UNPACKED = 256 * 1024 * 1024


def validate(path: str) -> tuple[int, int]:
    with open(path, "rb") as inp:
        inp.seek(0, 2)
        if inp.tell() > MAX_ZIP:
            raise ValueError("ZIP exceeds 64 MiB")
    seen = set()
    found_toc = False
    total = 0
    count = 0
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            name = entry.filename
            if not name or "\\" in name or name.startswith("/") or "//" in name:
                raise ValueError(f"unsafe ZIP path: {name!r}")
            parts = name.rstrip("/").split("/")
            if any(x in ("", ".", "..") for x in parts) or len(parts) > 12:
                raise ValueError(f"unsafe ZIP path: {name!r}")
            if parts[0] != FOLDER or len(parts) < 2:
                raise ValueError(f"unexpected top-level content: {name!r}")
            for part in parts:
                if (part.rstrip(" .") != part or ":" in part or
                        not re.fullmatch(r"[A-Za-z0-9_.!()+ -]+", part)):
                    raise ValueError(f"Windows-incompatible ZIP path: {name!r}")
                if part.split(".")[0].lower() in RESERVED:
                    raise ValueError(f"reserved Windows filename: {name!r}")
            key = name.rstrip("/").casefold()
            if key in seen:
                raise ValueError(f"duplicate ZIP path: {name!r}")
            seen.add(key)
            if entry.is_dir():
                continue
            count += 1
            if count > 5000:
                raise ValueError("too many files")
            if PurePosixPath(name).suffix.lower() in FORBIDDEN:
                raise ValueError(f"executable content is forbidden: {name!r}")
            if entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                raise ValueError(f"unsupported compression: {name!r}")
            if entry.flag_bits & 1:
                raise ValueError(f"encrypted ZIP member: {name!r}")
            if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError(f"symlink is not allowed: {name!r}")
            total += entry.file_size
            if total > MAX_UNPACKED:
                raise ValueError("unpacked content exceeds 256 MiB")
            if name == FOLDER + "/" + FOLDER + ".toc":
                data = archive.read(entry).decode("utf-8-sig")
                match = re.search(r"^## Interface:\s*(.*)$", data, re.M)
                if not match or not any(v in {"11200", "30300"} for v in match.group(1).split()):
                    raise ValueError("TOC has unsupported Interface version")
                found_toc = True
        if not found_toc:
            raise ValueError("missing RebornBuildPlanner/RebornBuildPlanner.toc")
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity test failed")
    return count, total


if __name__ == "__main__":
    try:
        files, size = validate(sys.argv[1])
        print(f"azs-addons preflight: PASS ({files} files, {size} bytes unpacked)")
    except (IndexError, ValueError, OSError, zipfile.BadZipFile) as exc:
        print(f"azs-addons preflight: REFUSED ({exc})", file=sys.stderr)
        sys.exit(1)
