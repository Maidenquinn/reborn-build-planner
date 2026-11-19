"""Offline tests for the independently authored jewelry extractor; no real executable needed."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("extract_jewelry_local", ROOT / "tools" / "extract_jewelry_local.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class LocalExtractionTests(unittest.TestCase):
    def test_synthetic_records(self):
        data = (
            b"MZ" + b"\x00"*10 +
            b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "damage"\nbase = 0.17\n'
            b'[[jewel]] key = "blackhand"\nslot = "trinket"\nbehavior = "crit_damage"\nbase = 0.195\n'
            b'[[amulet]] key = "mark_of_fordring"\neffects = []\n'
        )
        records = mod.read_records(data)
        self.assertEqual(records["accuria"], {"slot":"ring", "behavior":"damage", "base":0.17, "effects": [], "specials": []})
        self.assertEqual(records["blackhand"]["slot"], "trinket")
        self.assertEqual(len(records), 2)
        lua = mod.render(records, "a"*64)
        self.assertIn('["accuria"]', lua)
        self.assertIn("base = 0.17", lua)
        self.assertNotIn("mark_of_fordring", lua)
    def test_inline_record_with_specials_and_effect_pairs(self):
        raw = (b'[[jewel]] key = "accuria" slot = "ring" behavior = "damage" base = 0.17 '
               b'effects = [["damage",0.2],["max_health",0.05]] special = { echo = 0.15, jump = 2 }'
               b'[[jewel]] key = "blackhand" slot = "trinket" behavior = "crit_damage" base = 0.195')
        rows = mod.read_records(raw)
        self.assertEqual(rows["accuria"]["effects"], [("damage",0.2), ("max_health",0.05)])
        self.assertEqual(rows["accuria"]["specials"], [("echo",0.15), ("jump",2)])
        self.assertIn('effects = { { "damage", 0.2 }', mod.render(rows, "a"*64))

    def test_validate_exact_coverage(self):
        base = {"slot":"ring","behavior":"damage","base":0.17,"effects":[],"specials":[]}
        rows = {("j%d" % k): dict(base) for k in range(31)}
        catalogue = [{"key":k,"slot":"ring"} for k in rows]
        self.assertEqual(mod.validate(rows,catalogue), (31, []))
        reduced = dict(list(rows.items())[:-1])
        self.assertEqual(mod.validate(reduced, catalogue), (31, [list(rows)[-1]]))
        with self.assertRaises(ValueError):
            mod.validate(reduced, catalogue, require_complete=True)
        with self.assertRaises(ValueError):
            mod.validate(rows,catalogue+[{"key":"j0","slot":"ring"}])

    def test_repeated_record_conflict_fails(self):
        data = (b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "damage"\nbase = 0.17\n'
                b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "damage"\nbase = 0.19\n')
        with self.assertRaises(ValueError):
            mod.read_records(data)
    def test_unknown_behavior_excluded(self):
        data = b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "bad token"\nbase = 0.17\n'
        self.assertEqual(mod.read_records(data), {})


class PackagingSafetyTests(unittest.TestCase):
    def test_only_dedicated_output_is_allowed(self):
        import tempfile
        loader = importlib.util.spec_from_file_location("rbp_package", ROOT / "tools" / "package_addon.py")
        package = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(package)
        permitted = ROOT / "dist" / "ultimate-0.5.0-audit"
        self.assertEqual(Path(package.safe_output_path(permitted)), permitted.resolve())
        permitted_ci = ROOT / "dist" / "private-preview"
        self.assertEqual(Path(package.safe_output_path(permitted_ci)), permitted_ci.resolve())
        for unsafe in (ROOT, ROOT.parent, Path.home(),
                       ROOT / "addon", ROOT / "dist", ROOT / "dist" / "ordinary",
                       ROOT / "addon" / "RebornBuildPlanner"):
            with self.subTest(path=unsafe):
                with self.assertRaises(ValueError):
                    package.safe_output_path(unsafe)

if __name__=="__main__":
    unittest.main()
