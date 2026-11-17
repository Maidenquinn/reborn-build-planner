"""Builds the installable recette package in a SEPARATE folder (never the game install).

  python -I tools/package_addon.py [--out DIR]

Output (default: ../reborn-build-planner-recette-lot3):
  RebornBuildPlanner/                         the addon folder, exactly the files the .toc lists plus the .toc
  RebornBuildPlanner-<version>-recette.zip    the same folder zipped (extract into Interface\\AddOns)
  RECETTE_CLIENT_LOT3_1.md, UPDATE_FROM_0.3.0.md, RECETTE_CLIENT_LOT3.md   recette + update guide
  SHA256SUMS.txt                              checksums of every packaged file
Refuses to run if the .toc lists a missing file or the addon folder holds a file the .toc does not list.
"""
import hashlib
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "addon", "RebornBuildPlanner")


def main(argv):
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "..", "reborn-build-planner-recette-lot3-1")
    out = os.path.normpath(out)
    toc_path = os.path.join(SRC, "RebornBuildPlanner.toc")
    toc = open(toc_path, encoding="utf-8").read()
    files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    present = sorted(os.listdir(SRC))
    missing = [f for f in files if not os.path.exists(os.path.join(SRC, f))]
    extra = [f for f in present if f not in files and f != "RebornBuildPlanner.toc"]
    if missing or extra:
        sys.stderr.write("REFUSED: toc lists missing %r, folder holds unlisted %r\n" % (missing, extra))
        return 2
    if os.path.exists(out):
        shutil.rmtree(out)
    dest = os.path.join(out, "RebornBuildPlanner")
    os.makedirs(dest)
    for f in files + ["RebornBuildPlanner.toc"]:
        shutil.copyfile(os.path.join(SRC, f), os.path.join(dest, f))
    for doc in ("RECETTE_CLIENT_LOT3_1.md", "UPDATE_FROM_0.3.0.md", "RECETTE_CLIENT_LOT3.md"):
        shutil.copyfile(os.path.join(ROOT, "docs", doc), os.path.join(out, doc))
    zpath = os.path.join(out, "RebornBuildPlanner-%s-recette.zip" % version)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(files + ["RebornBuildPlanner.toc"]):
            z.write(os.path.join(dest, f), "RebornBuildPlanner/" + f)
    sums = []
    for base, _, names in sorted(os.walk(out)):
        for n in sorted(names):
            p = os.path.join(base, n)
            if n != "SHA256SUMS.txt":
                sums.append("%s  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), os.path.relpath(p, out).replace("\\", "/")))
    with open(os.path.join(out, "SHA256SUMS.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(sums) + "\n")
    print("packaged %d files, version %s -> %s" % (len(files) + 1, version, out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
