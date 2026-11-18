-- Lot 4 regressions: read-only snapshot semantics and card recommendations.
-- These tests use the actual addon modules; they do not claim client-side rendering.
return function(H)
  local ns = H.loadAddon()
  local T, BM = ns.LiveTracker, ns.BuildModel
  local eq, ok, test = H.eq, H.ok, H.test
  local build = { phases = { {
    spells = { {key="whirlwind",mode="acquire"}, {key="rend",mode="rank",rank=3} },
    banish = { "execute" },
    banishAfter = { "whirlwind" },
    rings = { "ring_a" }, trinkets = {}, amulets = {}
  } } }
  test("lot4: no AZSSPELLS means UNKNOWN rather than missing", function()
    local p=T.Evaluate(build,1,{inRun=true,spellsKnown=false,spells={}})
    eq(p.spells[1].status,BM.STATUS.UNKNOWN)
    eq(p.spells[2].status,BM.STATUS.UNKNOWN)
  end)
  test("lot4: acquired spell and exact rank", function()
    local p=T.Evaluate(build,1,{inRun=true,spellsKnown=true,
      spells={{key="whirlwind",rank=1},{key="rend",rank=2}}})
    eq(p.spells[1].status,BM.STATUS.ACHIEVED)
    eq(p.spells[1].remindAfter,true)
    eq(p.spells[2].status,BM.STATUS.PENDING)
    eq(p.spells[2].rank,2)
  end)
  test("lot4: unidentified jewelry must not be marked missing", function()
    local p=T.Evaluate(build,1,{inRun=true,spellsKnown=false,
      gearKnown=true,gear={{slot="ring",name="ambiguous"}}})
    eq(p.jewelry[1].state,"UNKNOWN")
    local good=T.Evaluate(build,1,{inRun=true,gearKnown=true,
      gear={{key="ring_a"}}})
    eq(good.jewelry[1].state,"EQUIPPED")
  end)
  test("lot4: jewelry offers use exact keys for jewel/ring/trinket/amulet", function()
    local gearBuild={phases={{spells={},banish={},
      rings={"ring_a","ring_b","ring_alt"},
      trinkets={"trinket_a","trinket_b"},
      amulets={"amulet_a","amulet_alt"}}}
    local function hint(kind,key,slot)
      local snap={inRun=true,cards={kind=kind}}
      return T.CardHint(gearBuild,1,snap,{key=key,slot=slot})
    end
    eq(hint("jewel","ring_a","ring"),"wanted")
    eq(hint("jewel","ring_alt","ring"),"alternative")
    eq(hint("ring","ring_a"),"wanted")
    eq(hint("trinket","trinket_a"),"wanted")
    eq(hint("amulet","amulet_a"),"wanted")
    eq(hint("amulet","amulet_alt"),"alternative")
    eq(hint("ring","trinket_a"),nil)
    eq(hint("trinket","ring_a"),nil)
    eq(hint("jewel","ring_a","trinket"),nil)
    eq(hint("ring","unknown"),nil)
    eq(T.CardHint(gearBuild,1,{inRun=true,cards={kind="ring"}},{name="ring_a"}),nil)
  end)
  test("lot4: banish-after waits for spell synchronization", function()
    local unknown={inRun=true,spellsKnown=false,cards={kind="spell"},spells={}}
    eq(T.CardHint(build,1,unknown,{key="whirlwind"}),nil)
    local acquired={inRun=true,spellsKnown=true,cards={kind="spell"},
      spells={{key="whirlwind",rank=1}}}
    eq(T.CardHint(build,1,acquired,{key="whirlwind"}),"banish_after")
    local new={inRun=true,spellsKnown=true,cards={kind="spell"},spells={}}
    eq(T.CardHint(build,1,new,{key="whirlwind"}),"wanted")
    eq(T.CardHint(build,1,new,{key="execute"}),"avoid")
  end)
end
