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
        self.assertEqual(records["accuria"], {"slot":"ring", "behavior":"damage", "base":0.17})
        self.assertEqual(records["blackhand"]["slot"], "trinket")
        self.assertEqual(len(records), 2)
        lua = mod.render(records, "a"*64)
        self.assertIn('["accuria"]', lua)
        self.assertIn("base = 0.17", lua)
        self.assertNotIn("mark_of_fordring", lua)
    def test_repeated_record_conflict_fails(self):
        data = (b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "damage"\nbase = 0.17\n'
                b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "damage"\nbase = 0.19\n')
        with self.assertRaises(ValueError):
            mod.read_records(data)
    def test_unknown_behavior_excluded(self):
        data = b'[[jewel]] key = "accuria"\nslot = "ring"\nbehavior = "bad token"\nbase = 0.17\n'
        self.assertEqual(mod.read_records(data), {})

if __name__=="__main__":
    unittest.main()
