"""Lot 0 reference model (executable specification, NOT client proof).

Everything here is a RECONSTRUCTION from the native Lua sources, cited in docs/CONTRACTS.md:
  - grammar port       : AzerothSurvivors/Core.lua ParseKV/ParseList, Cards.lua AZSCARDS handler
  - run-id port        : AzerothSurvivorsAPI/Api.lua AZS_API_RunId and its AZSZONE/AZSRUN handlers
  - identity resolver  : catalogue (public data/v1 snapshot) vs the fields the native lines carry
  - lifecycle reducer  : the state machine of docs/CONTRACTS.md section 3
It runs with the Python standard library only. It never touches the game install.
The final addon must re-implement this in Lua 5.1; these tests pin the intended behaviour.
"""
import json
import os
import re

# ----------------------------------------------------------------------------- Lua-faithful bits

_NUM = re.compile(r"^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\s*$")
_HEX = re.compile(r"^\s*[+-]?0[xX][0-9a-fA-F]+\s*$")


def lua_tonumber(v):
    """Lua 5.1 tonumber on a string: None when it does not read as a number."""
    if not isinstance(v, str):
        return v
    if _HEX.match(v):
        return int(v.strip(), 16)
    if _NUM.match(v):
        f = float(v)
        return int(f) if f == int(f) and abs(f) < 2 ** 53 and "." not in v and "e" not in v.lower() else f
    return None


def parse_kv(msg):
    """Core.lua:142 ParseKV: gmatch("(%w+)=([^;]*)"); %w has no underscore; number where it parses."""
    t = {}
    for m in re.finditer(r"([A-Za-z0-9]+)=([^;]*)", msg):
        n = lua_tonumber(m.group(2))
        t[m.group(1)] = m.group(2) if n is None else n
    return t


def parse_list(msg, names):
    """Core.lua:151 ParseList: rows split by ';' (empty skipped), values by ',', only len(names) kept."""
    rows = []
    for entry in re.findall(r"[^;]+", msg):
        row = {}
        vals = (entry + ",").split(",")[:-1]
        for i, v in enumerate(vals):
            if i >= len(names):
                break
            n = lua_tonumber(v)
            row[names[i]] = v if n is None else n
        rows.append(row)
    return rows


JEWEL_FIELDS = ["mode", "rarity", "icon", "name", "effect", "detail", "note", "slot"]
SPELL_CARD_FIELDS = ["key", "spell", "rank", "rarity", "new", "lines"]
GEAR_FIELDS = ["slot", "rarity", "bonus", "amount", "icon", "name", "text"]
SPELL_FIELDS = ["key", "spell", "rank", "cd", "cdmax"]


def parse_cards(msg):
    """Cards.lua:1455-1489 AZSCARDS handler."""
    f = parse_kv(msg)
    m = re.search(r";c=(.*)$", msg)
    c = m.group(1) if m else ""
    if f.get("kind") == "jewel":
        cards = []
        for entry in re.findall(r"[^/]+", c):
            row = {}
            for i, v in enumerate((entry + "~").split("~")[:-1]):
                if i < len(JEWEL_FIELDS):
                    n = JEWEL_FIELDS[i]
                    row[n] = (lua_tonumber(v) or 0) if n == "rarity" else v
            cards.append(row)
        f["cards"] = cards
    else:
        f["cards"] = parse_list(c.replace("/", ";"), SPELL_CARD_FIELDS)
    return f


# ----------------------------------------------------------------------------- Api.lua run id port

class ApiRunId:
    """Api.lua:60-106. `session` models SESSION = time() at load: a /reload starts it over."""

    def __init__(self, session):
        self.session = session
        self.runs = 0
        self.zone_new = False
        self.last_clock = None
        self.server_run = None

    def current(self):
        if self.server_run:
            return "azs:" + self.server_run
        if self.runs == 0:
            return None
        return "azs:%s:%d" % (self.session, self.runs)

    def on_zone(self, zone):
        rid = str(zone.get("run", ""))
        self.server_run = rid if re.match(r"^r[0-9a-fA-F]+$", rid) else None
        self.zone_new = True

    def on_run(self, run):
        t = run.get("t")
        if isinstance(t, (int, float)):
            back = self.last_clock is not None and t < self.last_clock
            if self.runs == 0 or (self.zone_new and back) or (self.last_clock is not None and t + 5 < self.last_clock):
                self.runs += 1
            self.zone_new = False
            self.last_clock = t


# ----------------------------------------------------------------------------- catalogue

class Catalog:
    def __init__(self, root, lang="enUS"):
        def load(n):
            with open(os.path.join(root, n), encoding="utf-8") as fh:
                return json.load(fh)
        self.index = load("index.json")
        self.content = self.index["content"]
        self.classes = load("classes.json")
        self.spells = load("spells.json")
        self.jewelry = load("jewelry.json")
        self.amulets = load("amulets.json")
        self.legends = load("legends.json")
        self.tr = {}
        if lang != "enUS":
            p = os.path.join(root, "i18n", lang + ".json")
            if os.path.exists(p):
                self.tr = load(os.path.join("i18n", lang + ".json"))
        self.lang = lang
        self.spell_by_key = {s["key"]: s for s in self.spells}
        self.class_keys = {c["key"] for c in self.classes}
        self.class_by_token = {c["token"]: c["key"] for c in self.classes}
        self.rarity_names = ["common", "uncommon", "rare", "epic", "legendary", "pvp", "exotic", "mythic"]

    def loc(self, english):
        return self.tr.get(english, english)

    def norm_class(self, raw):
        """Class as AZS_ZONE.class / UnitClass token / catalogue key -> catalogue key (or None)."""
        if not isinstance(raw, str) or not raw:
            return None
        low = raw.lower()
        if low in self.class_keys:
            return low
        return self.class_by_token.get(raw.upper())


# ----------------------------------------------------------------------------- identity resolver

def _res(status, key=None, via=None, reason=None, **extra):
    d = {"status": status, "key": key, "via": via, "reason": reason}
    d.update(extra)
    return d


def resolve_spell(cat, cls, key, spell_id):
    """Spell known (AZS_SPELLS row) or offered (spell card): key plus spell id cross-check."""
    sid = spell_id if isinstance(spell_id, (int, float)) else None
    s = cat.spell_by_key.get(key) if isinstance(key, str) else None
    if s is not None:
        if cls is not None and s["class"] != cls:
            return _res("OTHER_CLASS", reason="spell belongs to " + s["class"])
        if sid is not None and sid != s["id"]:
            return _res("CONFLICT", reason="key and spell id disagree")
        return _res("RESOLVED", s["key"], "key+id" if sid is not None else "key")
    if sid is not None:
        hits = [x for x in cat.spells if x["id"] == sid and (cls is None or x["class"] == cls)]
        if len(hits) == 1:
            return _res("RESOLVED", hits[0]["key"], "id", reason="server key not in catalogue (drift)")
    if isinstance(key, str) and key.startswith("dash_"):
        return _res("NOT_CATALOGUE", reason="dash card, takes no spell slot")
    return _res("UNKNOWN", reason="key and id not in catalogue")


def _rank(v):
    return int(v) if isinstance(v, (int, float)) and v >= 1 and v == int(v) else None


def resolve_jewel(cat, slot, name, icon):
    """Ring/trinket by (slot, localized name); icon only corroborates, never identifies."""
    if slot not in ("ring", "trinket"):
        return _res("UNKNOWN", reason="slot is not ring/trinket")
    cands = [j for j in cat.jewelry if j["slot"] == slot and cat.loc(j["name"]) == name]
    if len(cands) == 1:
        j = cands[0]
        if icon and icon != j["icon"]:
            return _res("CONFLICT", reason="name matches %s but icon differs" % j["key"])
        sharers = [x["key"] for x in cat.jewelry if x["icon"] == j["icon"] and x["key"] != j["key"]]
        return _res("HEURISTIC", j["key"], "slot+name+icon", icon_shared_with=sharers)
    if len(cands) > 1:
        return _res("AMBIGUOUS", reason="several catalogue pieces share slot+name",
                    candidates=sorted(c["key"] for c in cands))
    by_icon = sorted(x["key"] for x in cat.jewelry if x["slot"] == slot and icon and x["icon"] == icon)
    return _res("UNKNOWN", reason="no catalogue name match (locale or catalogue drift)", icon_candidates=by_icon)


def resolve_amulet(cat, cls, name, rarity, amount):
    """Fixed amulet (classes filter) or legendary:<spell>; never by head nor icon."""
    fixed = [a for a in cat.amulets if cat.loc(a["name"]) == name and (not a["classes"] or cls is None or cls in a["classes"])]
    legend = [g for g in cat.legends if g["name"] == name and (cls is None or g["class"] == cls)]
    rank = _rank(amount)
    if len(fixed) + len(legend) == 0:
        return _res("UNKNOWN", reason="no full-name match (legend names are not in i18n)", rank=rank)
    if len(fixed) + len(legend) > 1:
        return _res("AMBIGUOUS", reason="homonyms; class unknown" if cls is None else "several matches", rank=rank,
                    candidates=sorted([a["key"] for a in fixed] + [g["key"] for g in legend]))
    if fixed:
        a = fixed[0]
        idx = cat.rarity_names.index(a["rarity"]) if a["rarity"] in cat.rarity_names else None
        if isinstance(rarity, (int, float)) and idx is not None and int(rarity) != idx:
            return _res("CONFLICT", reason="rarity differs from catalogue", rank=rank)
        return _res("HEURISTIC", a["key"], "class+name", rank=rank)
    g = legend[0]
    if isinstance(rarity, (int, float)) and int(rarity) != 4:
        return _res("CONFLICT", reason="legendary entry but rarity != 4", rank=rank)
    return _res("HEURISTIC", g["key"], "class+full-name", rank=rank)


def gear_identity(cat, cls, row):
    slot = row.get("slot")
    if slot == "amulet":
        r = resolve_amulet(cat, cls, row.get("name"), row.get("rarity"), row.get("amount"))
    else:
        r = resolve_jewel(cat, slot, row.get("name"), row.get("icon"))
    r["countable"] = False  # jewel_identity_verified is False until VALIDATION CLIENT P-J1/P-J2 passes
    return r


# ----------------------------------------------------------------------------- lifecycle model

UNKNOWN, EMPTY, KNOWN = "UNKNOWN", "EMPTY", "KNOWN"
HAND_PHASES = ("choosing",)  # to confirm on the client (protocol P-C1)


class Model:
    def __init__(self, cat, session="S1", jewel_identity_verified=False):
        self.cat = cat
        self.verified = jewel_identity_verified
        self.session = session
        self.api = ApiRunId(session)
        self.epoch = 0
        self.tokens = {}
        self._reset_epoch()

    # -- epoch / run scoping -------------------------------------------------
    def _reset_epoch(self):
        self.zone = None
        self.run = None
        self.spells = None
        self.gear = None
        self.cards = None
        self.hand_seq = 0
        self.hand_run = None
        self.hand_epoch = None
        self.data_run = {}   # prefix -> runId it was received under
        self.run_id = None
        self.ended_run = None

    def world_enter(self, session=None):
        """Our own load or PLAYER_ENTERING_WORLD: native tables restart empty after /reload."""
        if session is not None:
            self.session = session
            self.api = ApiRunId(session)
        self.epoch += 1
        self._reset_epoch()

    def _new_run(self, rid):
        self.run_id = rid
        self.spells = self.gear = self.cards = None   # never carry the previous run's copies
        self.data_run = {}
        self.hand_seq += 1                            # any old hand token dies
        self.ended_run = None

    def line(self, prefix, msg):
        if prefix == "AZSZONE":
            self.zone = parse_kv(msg)
            self.api.on_zone(self.zone)
        elif prefix == "AZSRUN":
            self.run = parse_kv(msg)
            self.api.on_run(self.run)
        elif prefix == "AZSSPELLS":
            self.spells = parse_list(msg, SPELL_FIELDS)
            self.data_run["spells"] = self.api.current()
        elif prefix == "AZSGEAR":
            self.gear = parse_list(msg, GEAR_FIELDS)
            self.data_run["gear"] = self.api.current()
        elif prefix == "AZSCARDS":
            self.cards = parse_cards(msg)
            self.hand_seq += 1                        # a new line is always a new hand (reroll, next, reload resend)
            self.hand_run, self.hand_epoch = self.api.current(), self.epoch
            self.data_run["cards"] = self.api.current()
        elif prefix == "AZSCARDTIP":
            return                                    # attaches to the current hand; no identity change
        elif prefix == "AZSEND":
            if self.api.current():
                self.ended_run = self.api.current()
            return
        rid = self.api.current()
        if rid != self.run_id and prefix in ("AZSZONE", "AZSRUN"):
            self._new_run(rid)   # run identity changed: drop every run-scoped copy and kill old tokens

    # -- derived views -------------------------------------------------------
    def _avail(self, name, value):
        if value is None or self.data_run.get(name) != self.run_id or self.run_id is None:
            return UNKNOWN
        return KNOWN if (value if name != "cards" else value.get("cards")) else EMPTY

    def availability(self):
        return {"spells": self._avail("spells", self.spells), "gear": self._avail("gear", self.gear),
                "cards": self._avail("cards", self.cards)}

    def hand_valid(self):
        if self.cards is None or not self.cards.get("cards"):
            return False
        return (self.lifecycle() == "CHOOSING" and self.hand_run == self.run_id and self.hand_epoch == self.epoch)

    def lifecycle(self):
        if self.zone is None:
            return "SYNCING" if self.epoch > 0 else "OFFLINE"
        if self.zone.get("hub") == 1:
            return "NO_RUN"
        if self.run is None or "ph" not in self.run or self.run_id is None:
            return "SYNCING"
        ph = self.run["ph"]
        if ph in ("dead", "victory") or (self.ended_run is not None and self.ended_run == self.run_id):
            return "ENDED"
        if ph == "ready":
            return "READY"
        if ph in HAND_PHASES:
            ok = (self.cards is not None and self.cards.get("cards") and self.hand_run == self.run_id
                  and self.hand_epoch == self.epoch)
            return "CHOOSING" if ok else "CHOOSING_NO_HAND"
        if ph in ("playing", "paused"):
            return "ACTIVE"
        return "SYNCING"

    def class_key(self):
        return self.cat.norm_class((self.zone or {}).get("class"))

    def endless(self):
        """Run.lua:151,179 reads AZS_RUN.endless == 1; `endl` is the original's field, unused here."""
        v = (self.run or {}).get("endless")
        return None if v is None else v == 1

    # -- advice tokens -------------------------------------------------------
    def token(self):
        return {"run": self.run_id, "epoch": self.epoch, "hand": self.hand_seq, "life": self.lifecycle()}

    def token_status(self, tok):
        if self.lifecycle() in ("NO_RUN", "SYNCING", "OFFLINE", "ENDED"):
            return "STALE_NO_RUN"
        if tok["run"] != self.run_id:
            return "STALE_RUN"
        if tok["epoch"] != self.epoch:
            return "STALE_EPOCH"
        if tok["hand"] != self.hand_seq:
            return "STALE_HAND"
        if tok["life"] != self.lifecycle():
            return "STALE_STATE"   # e.g. "what to look for" advice must not survive into a card choice
        return "OK"

    # -- identities ----------------------------------------------------------
    def identities(self):
        cat, cls = self.cat, self.class_key()
        out = {}
        for i, s in enumerate(self.spells or []):
            r = resolve_spell(cat, cls, s.get("key"), s.get("spell"))
            r["rank"] = _rank(s.get("rank"))
            out["spell[%d]" % (i + 1)] = r
        for i, g in enumerate(self.gear or []):
            out["gear[%d]" % (i + 1)] = gear_identity(cat, cls, g)
        hand = (self.cards or {})
        for i, c in enumerate(hand.get("cards", [])):
            if hand.get("kind") == "jewel":
                mode = c.get("mode")
                slot = c.get("slot")
                if mode == "amulet" or slot == "amulet":
                    r = resolve_amulet(cat, cls, c.get("name"), c.get("rarity"), None)
                elif mode == "gold":
                    r = _res("NOT_CATALOGUE", reason="gold card")
                else:
                    r = resolve_jewel(cat, slot, c.get("name"), c.get("icon"))
                if mode in ("grow", "empower"):
                    worn = [j for j, g in enumerate(self.gear or []) if g.get("slot") == slot and g.get("name") == c.get("name")]
                    r["links_worn"] = ["gear[%d]" % (j + 1) for j in worn]
                r["recommendable"] = bool(self.verified and r["status"] in ("RESOLVED", "HEURISTIC"))
            else:
                r = resolve_spell(cat, cls, c.get("key"), c.get("spell"))
                r["resulting_rank"] = _rank(c.get("rank"))
                r["is_new"] = c.get("new") == 1
                r["recommendable"] = r["status"] == "RESOLVED"
            out["card[%d]" % (i + 1)] = r
        return out

    def view(self):
        h = self.cards or {}
        return {"lifecycle": self.lifecycle(), "runId": self.run_id, "epoch": self.epoch, "handSeq": self.hand_seq,
                "handValid": self.hand_valid(), "availability": self.availability(), "class": self.class_key(),
                "endless": self.endless(), "hands": {"kind": h.get("kind"), "bn": h.get("bn"), "count": len(h.get("cards", []))}}
