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
import subprocess
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "addon", "RebornBuildPlanner")


def safe_output_path(raw):
    """Never recursively delete any project, game, parent, or user directory."""
    from pathlib import Path
    root = Path(ROOT).resolve()
    output = Path(raw).resolve()
    forbidden = {root, root.parent, Path.home().resolve(),
                 Path.home().resolve().parent, Path(ROOT).anchor and Path(Path(ROOT).anchor)}
    forbidden = {p for p in forbidden if p}
    if output in forbidden or output == root or output in root.parents:
        raise ValueError("Unsafe output path: cannot replace a project/parent/home directory")
    # Only allow a dedicated dist child or the historic explicitly named recipe.
    if output.parent != root / "dist" and output.parent != root.parent:
        raise ValueError("Output directory must be a direct child of dist/ or project parent")
    if not output.name.startswith(("ultimate-", "private-preview", "reborn-build-planner-recette-")):
        raise ValueError("Output directory name must be a dedicated recipe folder")
    # Symbolic links and junctions can make seemingly safe paths point elsewhere.
    if output.is_symlink() or output.parent.is_symlink():
        raise ValueError("Output directory or parent must not be a symbolic link")
    return str(output)


def main(argv):
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "..", "reborn-build-planner-recette-lot3-5b")
    out = safe_output_path(out)
    toc_path = os.path.join(SRC, "RebornBuildPlanner.toc")
    toc = open(toc_path, encoding="utf-8").read()
    files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    present = sorted(os.listdir(SRC))
    missing = [f for f in files if not os.path.exists(os.path.join(SRC, f))]
    extra = [f for f in present if f not in files and f not in ("RebornBuildPlanner.toc", "Media")]
    if missing or extra:
        sys.stderr.write("REFUSED: toc lists missing %r, folder holds unlisted %r\n" % (missing, extra))
        return 2
    # Optional read-only extraction of jewelry effect metadata from the user's own installation.
    # The generated file stays local; no third-party tables are committed or fetched.
    exe = os.environ.get("RBP_GAME_EXE")
    catalogue = os.environ.get("RBP_CATALOG_DIR")
    if exe:
        if not catalogue:
            sys.stderr.write("REFUSED: RBP_GAME_EXE needs RBP_CATALOG_DIR (local data/v1 folder)\\n")
            return 2
        args = [sys.executable, os.path.join(ROOT, "tools", "extract_jewelry_local.py"),
                "--exe", exe, "--catalog", os.path.join(catalogue, "jewelry.json"),
                "--out", os.path.join(ROOT, ".local", "generated", "GeneratedJewelryMechanics.lua")]
        if subprocess.run(args, cwd=ROOT).returncode != 0:
            sys.stderr.write("REFUSED: local jewelry extraction failed; package not produced\\n")
            return 2
    if os.path.exists(out):
        # Only replace a previous *completed* output from our own packager.
        # An arbitrary directory with a coincidentally accepted name, or a
        # half-written build, must never be recursively deleted.
        marker = os.path.join(out, "SHA256SUMS.txt")
        installed = os.path.join(out, "RebornBuildPlanner", "RebornBuildPlanner.toc")
        if not os.path.isfile(marker) or not os.path.isfile(installed):
            raise ValueError("Output exists but is not a completed RBP recipe; choose a fresh -OutputDir")
        shutil.rmtree(out)
    dest = os.path.join(out, "RebornBuildPlanner")
    os.makedirs(dest)
    for f in files + ["RebornBuildPlanner.toc"]:
        shutil.copyfile(os.path.join(SRC, f), os.path.join(dest, f))
    # Overlay local-only mechanics in the PACKAGE, never modify tracked source.
    if exe:
        local_mechanics = os.path.join(ROOT, ".local", "generated", "GeneratedJewelryMechanics.lua")
        shutil.copyfile(local_mechanics, os.path.join(dest, "GeneratedJewelryMechanics.lua"))
    # Original fantasy UI assets: regenerate locally if absent, never fetch third-party assets.
    lab_media = os.path.join(ROOT, "addon_lab", "RebornPlannerThemeLab", "Media")
    needed = ("ultimate_corner.tga", "ultimate_crest.tga", "ultimate_titlebar.tga", "ultimate_panel.tga", "ultimate_fav_on.tga", "ultimate_fav_off.tga", "ultimate_class_monk.tga", "ultimate_class_dh.tga")
    if not all(os.path.isfile(os.path.join(lab_media, n)) for n in needed):
        print("Generating original fantasy textures (build-time Pillow required)")
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "make_ultimate_art.py"), lab_media], check=True)
    media_dest = os.path.join(dest, "Media")
    os.makedirs(media_dest, exist_ok=True)
    for n in os.listdir(lab_media):
        if n.lower().endswith(".tga"):
            shutil.copyfile(os.path.join(lab_media, n), os.path.join(media_dest, n))

    for doc in ("RECETTE_LAB_V2_LOT3_5B.md", "TEXTURES_INVENTORY.md", "COMPAT_CLIENT_LOT3_5B.md", "RECETTE_LAB_LOT3_5.md", "UPDATE_FROM_0.4.2.md", "DIAGNOSTIC_RENDU.md", "GLOSSARY_FR.md", "RECETTE_CLIENT_LOT3_4.md", "UPDATE_FROM_0.4.1.md", "API_PROPOSAL_JEWELRY.md", "RECETTE_CLIENT_LOT3_3.md", "UPDATE_FROM_0.4.0.md", "RECETTE_CLIENT_LOT3_2.md", "UPDATE_FROM_0.3.1.md", "INSTALL.md", "CHANGELOG.md", "DESCRIPTION_SOURCES.md", "RECETTE_CLIENT_LOT3_1.md", "UPDATE_FROM_0.3.0.md", "RECETTE_CLIENT_LOT3.md"):
        shutil.copyfile(os.path.join(ROOT, "docs", doc), os.path.join(out, doc))
    # visual lab (separate addon; Theme.lua is the planner's own file)
    lab_src = os.path.join(ROOT, "addon_lab", "RebornPlannerThemeLab")
    if os.path.isdir(lab_src):
        lab_dest = os.path.join(out, "RebornPlannerThemeLab")
        os.makedirs(lab_dest)
        for f in ("RebornPlannerThemeLab.toc", "Lab.lua"):
            shutil.copyfile(os.path.join(lab_src, f), os.path.join(lab_dest, f))
        shutil.copyfile(os.path.join(SRC, "Theme.lua"), os.path.join(lab_dest, "Theme.lua"))
        media_src, media_dest = os.path.join(lab_src, "Media"), os.path.join(lab_dest, "Media")
        os.makedirs(media_dest)
        tgas = sorted(f for f in os.listdir(media_src) if f.endswith(".tga"))
        for f in tgas:
            shutil.copyfile(os.path.join(media_src, f), os.path.join(media_dest, f))
        with zipfile.ZipFile(os.path.join(out, "RebornPlannerThemeLab-0.4.3-proto2.zip"), "w", zipfile.ZIP_DEFLATED) as z:
            for f in ("RebornPlannerThemeLab.toc", "Theme.lua", "Lab.lua"):
                z.write(os.path.join(lab_dest, f), "RebornPlannerThemeLab/" + f)
            for f in tgas:
                z.write(os.path.join(media_dest, f), "RebornPlannerThemeLab/Media/" + f)
    zpath = os.path.join(out, "RebornBuildPlanner-%s-recette.zip" % version)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, names in os.walk(dest):
            for name in sorted(names):
                pth = os.path.join(base, name)
                z.write(pth, os.path.relpath(pth, out).replace("\\", "/"))
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
