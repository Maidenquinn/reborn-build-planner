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
  test("lot4: unique official equipped jewelry name resolves and duplicate stays unknown", function()
    local cat={data={jewelry={
      {key="ring_a",slot="ring",name="Blooddrinker"},
      {key="ring_b",slot="ring",name="Twin"},
      {key="ring_c",slot="ring",name="Twin"}} ,amulets={},legends={}}}
    function cat:Get(kind,key)
      for _,v in ipairs(self.data.jewelry) do if v.key==key and kind=="jewel" then return v end end
    end
    function cat:Name(kind,key,lang)
      local v=self:Get(kind,key);return v and v.name or key
    end
    function cat:CheckKey(list,key,class) return "ok" end
    local b={class="hunter",phases={{spells={},rings={"ring_a","ring_b"},trinkets={},amulets={}}}}
    local snap={inRun=true,gearKnown=true,gear={{slot="ring",name="Blooddrinker"}}}
    local p=T.Evaluate(b,1,snap,cat,"enUS")
    eq(p.jewelry[1].state,"EQUIPPED")
    eq(p.jewelry[2].state,"MISSING")
    snap.gear={{slot="ring",name="Twin"}}
    p=T.Evaluate(b,1,snap,cat,"enUS")
    eq(p.jewelry[1].state,"UNKNOWN")
    eq(p.jewelry[2].state,"UNKNOWN")
  end)
  test("lot4: outside-build owned spells, jewelry and confirmed bans", function()
    local plan={class="hunter",phases={{
      spells={{key="whirlwind",mode="acquire"}},
      rings={"ring_a","ring_alt"},trinkets={},amulets={}
    }}}
    local snap={inRun=true,spellsKnown=true,gearKnown=true,bannedKnown=true,
      spells={{key="whirlwind",rank=2},{key="execute",rank=3},{key="rend",rank=1}},
      gear={{key="ring_a"},{key="ring_out"}},banned={rend=true}}
    local p=T.Evaluate(plan,1,snap)
    eq(p.spells[1].rank,2)
    eq(#p.outsideSpells,1)
    eq(p.outsideSpells[1].key,"execute")
    eq(#p.outsideJewelry,1)
    eq(p.outsideJewelry[1].key,"ring_out")
    eq(#p.banishedSpells,1)
    eq(p.banishedSpells[1].key,"rend")
    eq(p.jewelry[1].state,"EQUIPPED")
    snap.spellsKnown=false;snap.gearKnown=false
    p=T.Evaluate(plan,1,snap)
    eq(#p.outsideSpells,0)
    eq(#p.outsideJewelry,0)
  end)
  test("lot4: future phase targets are not labeled outside build", function()
    local b={class="hunter",phases={
      {spells={{key="whirlwind",mode="acquire"}},rings={"ring_a"},trinkets={},amulets={}},
      {spells={{key="execute",mode="acquire"}},rings={"ring_future"},trinkets={},amulets={}}
    }}
    local p=T.Evaluate(b,1,{inRun=true,spellsKnown=true,gearKnown=true,
      spells={{key="execute",rank=1}},gear={{key="ring_future"}}})
    eq(#p.outsideSpells,0)
    eq(#p.outsideJewelry,0)
  end)
  test("lot4: jewelry offers use exact keys for jewel/ring/trinket/amulet", function()
    local gearBuild={phases={{spells={},banish={},
      rings={"ring_a","ring_b","ring_alt"},
      trinkets={"trinket_a","trinket_b"},
      amulets={"amulet_a","amulet_alt"}}}}
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
  test("lot4: official unique accessory names resolve without false matches", function()
    local c={data={jewelry={
      {key="ring_a",slot="ring",name="Anneau alpha"},
      {key="ring_b",slot="ring",name="Anneau double"},
      {key="ring_c",slot="ring",name="Anneau double"},
      {key="trinket_a",slot="trinket",name="Bijou alpha"}}},
      amulets={},legends={}}
    function c:Get(kind,key)
      for _,r in ipairs(self.data.jewelry) do if r.key==key and kind=="jewel" then return r end end
    end
    function c:Name(kind,key,lang)
      local item=self:Get(kind,key);return item and item.name or key
    end
    function c:CheckKey(list,key,class) return "ok" end
    local b={class="warrior",phases={{rings={"ring_a","ring_b","ring_c"},trinkets={"trinket_a"},amulets={}}}}
    local offer={inRun=true,cards={kind="jewel",cards={{name="Anneau alpha",slot="ring"},{name="Anneau double",slot="ring"}}}}
    eq(T.CardHint(b,1,offer,offer.cards.cards[1],c,"frFR"),"wanted")
    eq(T.CardHint(b,1,offer,offer.cards.cards[2],c,"frFR"),nil)
    eq(T.OfferHasGoal(b,1,offer,c,"frFR"),true)
    eq(T.CardHint(b,1,offer,{name="Anneau alpha",slot="trinket"},c,"frFR"),nil)
    local unknown={inRun=true,cards={kind="jewel",cards={{name="unlisted"}}}}
    eq(T.OfferHasGoal(b,1,unknown,c,"frFR"),nil)
    local emptyMatch={inRun=true,cards={kind="jewel",cards={{key="trinket_a"}}}}
    eq(T.OfferHasGoal(b,1,emptyMatch,c,"frFR"),true)
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
