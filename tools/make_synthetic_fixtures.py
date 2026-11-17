"""Regenerates tests/fixtures/synthetic/*.json (deterministic, no randomness, no personal data).
Run:  python -I tools/make_synthetic_fixtures.py
The JSON files are the reviewed artefacts; this script only keeps them reproducible.
"""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "fixtures", "synthetic")
H = ("Synthetic, anonymised, deterministic. RECONSTRUCTED FROM CODE (not a client capture). Line grammar per "
     "Core.lua/Cards.lua; field VALUES for AZSGEAR.bonus, the jewel card `mode` of a new ring/trinket, "
     "server-localised names and run ids are invented stand-ins for values still UNKNOWN (docs/CONTRACTS.md).")


def Z(run="r0000a001", cls="warrior", hub=0):
    return "run=%s;zone=elwynn;class=%s;hub=%d;dt=0;heroic=0;hero=Testhero" % (run, cls, hub)


def R(t, ph, extra=""):
    return "t=%d;ph=%s;lvl=2;sl=0;kills=%d;gold=40;rr=0;endless=0%s" % (t, ph, t, extra)


def L(p, m):
    return {"op": "line", "prefix": p, "msg": m}


def C(**k):
    d = {"op": "check"}
    d.update(k)
    return d


def W(**k):
    d = {"op": "world_enter"}
    d.update(k)
    return d


def T(n):
    return {"op": "token", "name": n}


TRINK = "trinket,2,x_synthetic,1,Spell_Nature_AbolishMagic,Earthstrike,+10% luck"
sc = {}
sc["01_hub_no_run"] = ("Hub without a run: AZS_RUN.ph may read 'playing' in a hub (Api.lua:215-216) yet there is no run", [
    W(session="S1"), C(expect={"lifecycle": "SYNCING"}),
    L("AZSZONE", "zone=stormwind;class=warrior;hub=1;hero=Testhero"), L("AZSRUN", "t=300;ph=playing;lvl=1"),
    C(expect={"lifecycle": "NO_RUN", "handValid": False})])
sc["02_fresh_run_start"] = ("Fresh run: SYNCING -> READY -> ACTIVE; class normalised; endless unknown vs false vs true", [
    W(session="S1"), L("AZSZONE", Z(cls="WARRIOR")),
    C(expect={"lifecycle": "SYNCING", "runId": "azs:r0000a001", "class": "warrior",
              "availability": {"spells": "UNKNOWN", "gear": "UNKNOWN", "cards": "UNKNOWN"}}),
    L("AZSRUN", "t=0;ph=ready;lvl=1;sl=0;kills=0;gold=0"),
    C(expect={"lifecycle": "READY", "runId": "azs:r0000a001", "endless": None}),
    L("AZSRUN", R(5, "playing")), C(expect={"lifecycle": "ACTIVE", "endless": False}),
    L("AZSRUN", R(900, "playing").replace("endless=0", "endless=1")), C(expect={"endless": True})])
sc["03_spell_acquired_then_upgraded"] = ("Spell acquired then upgraded: key+id resolution, live rank", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(60, "playing")),
    L("AZSSPELLS", "whirlwind,1680,1,0,6"),
    C(expect={"availability": {"spells": "KNOWN"}},
      identities={"spell[1]": {"status": "RESOLVED", "key": "whirlwind", "via": "key+id", "rank": 1}}),
    L("AZSSPELLS", "whirlwind,1680,2,0,6;execute,5308,1,0,8"),
    C(identities={"spell[1]": {"key": "whirlwind", "rank": 2}, "spell[2]": {"status": "RESOLVED", "key": "execute", "rank": 1}}),
    L("AZSSPELLS", "whirlwind,9999,2,0,6"), C(identities={"spell[1]": {"status": "CONFLICT", "key": None}}),
    L("AZSSPELLS", "zzz_fake,1,1,0,1"), C(identities={"spell[1]": {"status": "UNKNOWN", "key": None}}),
    L("AZSSPELLS", "death_coil,6789,1,0,6"), C(identities={"spell[1]": {"status": "OTHER_CLASS", "key": None}})])
sc["04_trinket_clear_identity"] = ("Worn trinket whose slot+name+icon match exactly one catalogue piece: HEURISTIC, never countable until the client proves the identity", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(120, "playing")), L("AZSGEAR", TRINK),
    C(expect={"availability": {"gear": "KNOWN"}},
      identities={"gear[1]": {"status": "HEURISTIC", "key": "earthstrike", "via": "slot+name+icon", "countable": False}})])
sc["05_trinket_ambiguous"] = ("Ambiguous worn rings: shared icon, locale/catalogue drift, conflicting name/icon, unknown name. A shared icon alone never yields a key", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(120, "playing")),
    L("AZSGEAR", "ring,1,x_synthetic,1,INV_Jewelry_Ring_15,Anneau inconnu,+5% damage;"
                 "ring,1,x_synthetic,1,INV_Jewelry_Ring_15,Band of Accuria,+5% damage;"
                 "ring,1,x_synthetic,1,INV_Jewelry_Ring_15,Elementium Signet,+5% damage;"
                 "ring,1,x_synthetic,1,INV_Jewelry_Ring_07,Band of Accuria,+5% damage"),
    C(identities={
        "gear[1]": {"status": "UNKNOWN", "key": None, "icon_candidates": ["accuria", "elementium_signet"]},
        "gear[2]": {"status": "HEURISTIC", "key": "accuria", "icon_shared_with": ["elementium_signet"], "countable": False},
        "gear[3]": {"status": "HEURISTIC", "key": "elementium_signet", "icon_shared_with": ["accuria"]},
        "gear[4]": {"status": "CONFLICT", "key": None}})])
for tag, cls, key in (("warlock", "warlock", "legendary:death_coil"),
                      ("deathknight", "deathknight", "legendary:dk_death_coil"), ("unknown_class", "", "")):
    ident = ({"status": "HEURISTIC", "key": key, "via": "class+full-name", "rank": 2} if key else
             {"status": "AMBIGUOUS", "key": None, "candidates": ["legendary:death_coil", "legendary:dk_death_coil"], "rank": 2})
    sc["06_legendary_homonyms_" + tag] = (
        "Legendaries sharing the full name 'Eye of the Splitting Sky: Death Coil' (and the icon) across classes: class decides, no class = AMBIGUOUS; head/icon never used", [
            W(session="S1"), L("AZSZONE", Z(cls=cls)), L("AZSRUN", R(200, "playing")),
            L("AZSGEAR", "amulet,4,x_synthetic,2,INV_Jewelry_Necklace_16,Eye of the Splitting Sky: Death Coil,+20% damage"),
            C(identities={"gear[1]": ident})])
sc["07_amulet_with_amount"] = ("Fixed amulet: amount is the amulet rank (Gear.lua:84), class-filtered, rarity cross-checked; amount 0 is unknown, not 1", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(200, "playing")),
    L("AZSGEAR", "amulet,4,x_synthetic,3,INV_Jewelry_Necklace_18,Warglaives of Azzinoth,+15% damage"),
    C(identities={"gear[1]": {"status": "HEURISTIC", "key": "warglaives", "via": "class+name", "rank": 3}}),
    L("AZSGEAR", "amulet,4,x_synthetic,0,INV_Jewelry_Necklace_18,Warglaives of Azzinoth,+15% damage"),
    C(identities={"gear[1]": {"key": "warglaives", "rank": None}}),
    L("AZSGEAR", "amulet,4,x_synthetic,1,INV_Jewelry_Necklace_18,Shadowmourne,+15% damage"),
    C(identities={"gear[1]": {"status": "UNKNOWN", "key": None}})])
SPELLHAND = ("kind=spell;lvl=3;rr=2;rc=50;sk=10;bn=2;sl=2;slm=6;"
             "c=whirlwind,1680,1,0,1,d12:0:12/execute,5308,2,1,0,d8:12:20/dash_1,0,1,0,1,x0:0:0")
JEWELHAND = ("kind=jewel;src=cache;rr=1;rc=30;sk=15;c="
             "new~1~INV_Jewelry_Ring_07~Quick Strike Ring~+5% damage~~~ring/"
             "grow~2~Spell_Nature_AbolishMagic~Earthstrike~+10% luck~luck=10=15=u~Upgrade~trinket/"
             "amulet~4~INV_Jewelry_Necklace_18~Warglaives of Azzinoth~+15% damage~~Replaces X for good~amulet/"
             "gold~0~INV_Misc_Coin_01~Gold~+50 gold~~~")
sc["08_hand_spells_and_jewels"] = ("A level-up hand (spells + one dash card), then a treasure hand (ring, grown worn trinket, amulet, gold): jewel cards are never recommendable while identity is unverified", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(300, "playing")), L("AZSGEAR", TRINK),
    L("AZSRUN", R(305, "choosing")), L("AZSCARDS", SPELLHAND),
    C(expect={"lifecycle": "CHOOSING", "handValid": True, "hands": {"kind": "spell", "count": 3, "bn": 2}},
      identities={"card[1]": {"status": "RESOLVED", "key": "whirlwind", "is_new": True, "resulting_rank": 1, "recommendable": True},
                  "card[2]": {"key": "execute", "is_new": False, "resulting_rank": 2},
                  "card[3]": {"status": "NOT_CATALOGUE", "key": None, "recommendable": False}}),
    L("AZSRUN", R(310, "playing")), L("AZSCARDS", "kind=spell;c="),
    C(expect={"lifecycle": "ACTIVE", "handValid": False}),
    L("AZSRUN", R(320, "choosing")), L("AZSCARDS", JEWELHAND),
    C(expect={"lifecycle": "CHOOSING", "handValid": True, "hands": {"kind": "jewel", "count": 4, "bn": None}},
      identities={"card[1]": {"status": "HEURISTIC", "key": "quick_strike", "recommendable": False},
                  "card[2]": {"key": "earthstrike", "links_worn": ["gear[1]"], "recommendable": False},
                  "card[3]": {"status": "HEURISTIC", "key": "warglaives", "recommendable": False},
                  "card[4]": {"status": "NOT_CATALOGUE"}})])
sc["09_banishes_remaining"] = ("Banishes left (`bn`) exist on spell hands only; absent on jewel hands = unknown, not 0; always as the current hand reports it", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(300, "choosing")),
    L("AZSCARDS", "kind=spell;bn=2;rr=1;c=whirlwind,1680,1,0,1,x"), C(expect={"hands": {"bn": 2}}),
    L("AZSCARDS", "kind=spell;bn=1;rr=1;c=execute,5308,1,0,1,x"), C(expect={"hands": {"bn": 1}}),
    L("AZSCARDS", "kind=spell;bn=0;rr=1;c=cleave,845,1,0,1,x"), C(expect={"hands": {"bn": 0}}),
    L("AZSCARDS", "kind=jewel;src=cursed;c=new~1~INV_Jewelry_Ring_07~Quick Strike Ring~x~~~ring"), C(expect={"hands": {"bn": None}})])
sc["10_reroll_changes_hand"] = ("Reroll: every AZSCARDS line is a new hand; a token of the previous hand is STALE_HAND; the empty closing line kills the last one", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(300, "choosing")),
    L("AZSCARDS", "kind=spell;bn=2;rr=2;c=whirlwind,1680,1,0,1,x/execute,5308,1,0,1,x"), T("t1"),
    C(tokens={"t1": "OK"}),
    L("AZSCARDS", "kind=spell;bn=2;rr=1;c=cleave,845,1,0,1,x/rend,772,1,0,1,x"), T("t2"),
    C(tokens={"t1": "STALE_HAND", "t2": "OK"}),
    L("AZSCARDTIP", "i=1;text=tip"), C(tokens={"t2": "OK"}),
    L("AZSCARDS", "kind=spell;c="),
    C(expect={"lifecycle": "CHOOSING_NO_HAND", "handValid": False}, tokens={"t2": "STALE_HAND"})])
sc["11_reload_globals_empty"] = ("/reload mid-hand: native tables restart empty and the server re-sends in documented order; UNKNOWN until each line arrives, EMPTY only by an explicit empty line; same server run id survives, old tokens do not", [
    W(session="S1"), L("AZSZONE", Z()), L("AZSRUN", R(300, "choosing")), L("AZSSPELLS", "whirlwind,1680,1,0,6"),
    L("AZSGEAR", TRINK), L("AZSCARDS", "kind=spell;bn=2;c=execute,5308,1,0,1,x"), T("pre"), C(tokens={"pre": "OK"}),
    W(session="S2"),
    C(expect={"lifecycle": "SYNCING", "handValid": False, "runId": None,
              "availability": {"spells": "UNKNOWN", "gear": "UNKNOWN", "cards": "UNKNOWN"}}, tokens={"pre": "STALE_NO_RUN"}),
    L("AZSZONE", Z()), C(expect={"lifecycle": "SYNCING"}),
    L("AZSRUN", R(301, "choosing")),
    C(expect={"lifecycle": "CHOOSING_NO_HAND", "runId": "azs:r0000a001",
              "availability": {"spells": "UNKNOWN", "gear": "UNKNOWN", "cards": "UNKNOWN"}}),
    L("AZSSPELLS", ""), C(expect={"availability": {"spells": "EMPTY", "gear": "UNKNOWN"}}),
    L("AZSSPELLS", "whirlwind,1680,1,0,6"), L("AZSGEAR", TRINK),
    L("AZSCARDS", "kind=spell;bn=2;c=execute,5308,1,0,1,x"),
    C(expect={"lifecycle": "CHOOSING", "handValid": True,
              "availability": {"spells": "KNOWN", "gear": "KNOWN", "cards": "KNOWN"}}, tokens={"pre": "STALE_EPOCH"})])
sc["11b_reload_old_server_run_id"] = ("Old server (AZSZONE run=1): the client-counted id embeds the session, so a /reload yields a DIFFERENT id: treated as a new run, run-scoped overrides are lost (degraded, documented)", [
    W(session="S1"), L("AZSZONE", "run=1;zone=elwynn;class=warrior;hub=0"), L("AZSRUN", R(300, "playing")),
    C(expect={"runId": "azs:S1:1"}),
    W(session="S2"), L("AZSZONE", "run=1;zone=elwynn;class=warrior;hub=0"), L("AZSRUN", R(301, "playing")),
    C(expect={"runId": "azs:S2:1"})])
sc["12_new_run_transition"] = ("Run ends (dead + AZSEND) then a new run: ids change, copies of the old run (gear, spells, hand) are never reused, tokens die; AZS_END is never a run marker", [
    W(session="S1"), L("AZSZONE", Z("r0000a001")), L("AZSRUN", R(600, "playing")), L("AZSSPELLS", "whirlwind,1680,3,0,6"),
    L("AZSGEAR", TRINK), L("AZSRUN", R(601, "choosing")), L("AZSCARDS", "kind=spell;bn=1;c=execute,5308,1,0,1,x"), T("old"),
    L("AZSRUN", R(650, "dead")), L("AZSEND", "result=dead;t=650"),
    C(expect={"lifecycle": "ENDED", "handValid": False}, tokens={"old": "STALE_NO_RUN"}),
    L("AZSZONE", Z("r0000b002")), L("AZSRUN", "t=0;ph=ready;lvl=1;sl=0;kills=0;gold=0"),
    C(expect={"lifecycle": "READY", "runId": "azs:r0000b002", "handValid": False,
              "availability": {"spells": "UNKNOWN", "gear": "UNKNOWN", "cards": "UNKNOWN"}}),
    L("AZSRUN", R(3, "playing")), C(expect={"lifecycle": "ACTIVE"}, tokens={"old": "STALE_RUN"}),
    T("new"), L("AZSRUN", R(400, "choosing")),
    C(expect={"lifecycle": "CHOOSING_NO_HAND"}, tokens={"new": "STALE_STATE"})])
sc["13_old_server_new_run_via_clock"] = ("Old server: a new run is guessed when the run clock starts again after an AZSZONE (Api.lua:93)", [
    W(session="S1"), L("AZSZONE", "run=1;zone=elwynn;class=warrior;hub=0"), L("AZSRUN", R(900, "playing")),
    C(expect={"runId": "azs:S1:1"}),
    L("AZSZONE", "run=1;zone=elwynn;class=warrior;hub=0"), L("AZSRUN", R(2, "ready")), C(expect={"runId": "azs:S1:2"})])

os.makedirs(OUT, exist_ok=True)
for k, (desc, steps) in sc.items():
    doc = {"id": k, "description": desc, "provenance": "reconstructed-from-code", "warning": H,
           "catalog": "384db000d5ac311d", "clientLanguage": "enUS", "steps": steps}
    with open(os.path.join(OUT, k + ".json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
print(len(sc), "fixtures written")
