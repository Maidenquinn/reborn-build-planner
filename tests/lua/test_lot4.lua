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
  test("lot4: legendary amulet offered and equipped with official title variants", function()
    local cat={data={jewelry={},amulets={},legends={{
      key="legend_am",name="Ultimate Amulet",head="Ultimate Amulet",spell="whirlwind",
      class="hunter"
    }}}}
    function cat:Get(kind,key)
      if kind=="spell" and key=="whirlwind" then return {key=key,name="Aimed Shot"} end
      if kind=="amulet" and key=="legend_am" then return self.data.legends[1] end
    end
    function cat:Name(kind,key,lang)
      if kind=="spell" then return "Visée" end
      if kind=="amulet" then return "Amulette ultime : Visée" end
      return key
    end
    function cat:CheckKey(list,key,class)
      if list=="amulets" and class=="hunter" and key=="legend_am" then return "ok" end
      return "wrongclass"
    end
    local b={class="hunter",phases={{spells={},rings={},trinkets={},amulets={"legend_am"}}}}
    local offer={inRun=true,cards={kind="jewel",cards={{slot="amulet",name="Ultimate Amulet · Aimed Shot"}}}}
    eq(T.CardHint(b,1,offer,offer.cards.cards[1],cat,"frFR"),"wanted")
    eq(T.OfferHasGoal(b,1,offer,cat,"frFR"),true)
    local state={inRun=true,gearKnown=true,gear={{slot="amulet",name="Ultimate Amulet: Aimed Shot"}}}
    local p=T.Evaluate(b,1,state,cat,"frFR")
    eq(p.jewelry[1].state,"EQUIPPED")
    eq(p.jewelry[1].equippedRow.name,"Ultimate Amulet: Aimed Shot")
    state.gear={{slot="amulet",name="Another amulet"}}
    p=T.Evaluate(b,1,state,cat,"frFR")
    eq(p.jewelry[1].state,"UNKNOWN")
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
  test("capture: complete run creates preview with exact learned ranks and session bans", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local snap={inRun=true,spellsKnown=true,gearKnown=true,bannedKnown=true,
      spells={{key="whirlwind",rank=3},{key="rend",rank=2}},
      banned={execute=true},gear={}}
    local build,err,report=ns.CaptureBuild.Prepare(snap,"warrior",cat,"enUS","My Run")
    ok(build~=nil,"valid run should prepare")
    eq(err,nil)
    if build then
      eq(build.phases[1].spells[1],{key="whirlwind",mode="rank",rank=3})
      eq(build.phases[1].spells[2],{key="rend",mode="rank",rank=2})
      eq(build.phases[1].banish,{"execute"})
      eq(build.name,"My Run")
      eq(#build.phases,4)
    end
    eq(report.spells,2)
    eq(report.bans,1)
  end)
  test("capture: not in run and snapshots not received cannot create a build", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local a,err=ns.CaptureBuild.Prepare({inRun=false,spellsKnown=true,gearKnown=true},"warrior",cat,"enUS")
    eq(a,nil);eq(err,"NOT_IN_RUN")
    a,err=ns.CaptureBuild.Prepare({inRun=true,spellsKnown=true,gearKnown=false},"warrior",cat,"enUS")
    eq(a,nil);eq(err,"SNAPSHOT_INCOMPLETE")
  end)
  test("capture: refuses over-limit spells instead of silently dropping any", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local keys={"whirlwind","execute","cleave","rend","bloodthirst","shockwave","shield_slam"}
    local spells={}
    for _,key in ipairs(keys) do spells[#spells+1]={key=key,rank=1} end
    local build,err,report=ns.CaptureBuild.Prepare(
      {inRun=true,spellsKnown=true,gearKnown=true,spells=spells,gear={}},
      "warrior",cat,"enUS")
    eq(build,nil);eq(err,"TOO_MANY_SPELLS")
    eq(report.spells,7)
  end)
  test("capture: ignores unidentified gear and warns instead of guessing", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local build,err,report=ns.CaptureBuild.Prepare(
      {inRun=true,spellsKnown=true,gearKnown=true,spells={{key="whirlwind",rank=1}},
        gear={{name="Unidentified item",slot="ring"}}},
      "warrior",cat,"enUS")
    ok(build~=nil)
    eq(err,nil)
    eq(report.unknownGear,1)
    if build then eq(build.phases[1].rings,{"","","",""}) end
  end)

  test("capture: exact native legendary key maps to official amulet", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local legend=cat.data.legends and cat.data.legends[1]
    ok(legend~=nil,"catalog has legendary amulets")
    if not legend then return end
    local gear={slot="amulet",key="legend_"..legend.spell,name="Native legend name"}
    eq(T.ResolveEquipment(gear,cat,"enUS",legend.class),legend.key)
    local snapshot={inRun=true,spellsKnown=true,gearKnown=true,spells={
      {key=legend.spell,rank=1}},gear={gear},bannedKnown=false}
    local build,err,report=ns.CaptureBuild.Prepare(snapshot,legend.class,cat,"enUS","Captured legendary")
    eq(err,nil);ok(build~=nil)
    if build then eq(build.phases[1].amulets[1],legend.key) end
    eq(report.amulets,1)
  end)
  test("capture: item title is tried when native name is not an official name", function()
    local cat=ns.Catalog.New(ns.GeneratedCatalog)
    local legend=cat.data.legends[1]
    local gear={slot="legendary",name="Generic amulet",title=legend.name}
    eq(T.ResolveEquipment(gear,cat,"enUS",legend.class),legend.key)
  end)
  test("capture: ban confirmations survive reload for the same server run only", function()
    local globals={AZS_ZONE={run="server-run-a"},AZS_CARDS={
      kind="spell",bn=2,cards={{key="execute"}}}}
    local one=H.loadAddon({globals=globals})
    local cat=one.Catalog.New(one.GeneratedCatalog)
    one.storage=one.Storage.Open(nil,{catalog=cat})
    one.Runtime.Note("AZSZONE")
    one.Runtime.ObserveBanishCommand("AZSCMD","banish 1")
    globals.AZS_CARDS={kind="spell",bn=1,cards={{key="rend"}}}
    one.Runtime.Note("AZSCARDS")
    eq(one.Runtime.bans.execute,true)
    local saved=one.storage:GetSetting("captureBanJournal")
    eq(saved.run,"server-run-a");eq(saved.spells.execute,true)
    local two=H.loadAddon({globals=globals})
    two.storage=two.Storage.Open(one.storage.db,{catalog=cat})
    two.Runtime.Note("AZSZONE")
    eq(two.Runtime.bans.execute,true,"reload retains observed confirmed ban")
    globals.AZS_ZONE.run="server-run-b"
    two.Runtime.Note("AZSZONE")
    eq(two.Runtime.bans.execute,nil,"a new run does not inherit old bans")
  end)
  test("capture: invalid ban command never appears as confirmed", function()
    local globals={AZS_ZONE={run="server-run-b"},AZS_CARDS={
      kind="spell",bn=3,cards={{key="execute"}}}}
    local one=H.loadAddon({globals=globals})
    one.storage=one.Storage.Open(nil,{catalog=one.Catalog.New(one.GeneratedCatalog)})
    one.Runtime.Note("AZSZONE")
    one.Runtime.ObserveBanishCommand("WRONG","banish 1")
    one.Runtime.ObserveBanishCommand("AZSCMD","banish 1")
    globals.AZS_CARDS={kind="spell",bn=3,cards={{key="rend"}}}
    one.Runtime.Note("AZSCARDS")
    eq(one.Runtime.bans.execute,nil,"unchanged ban count is not a confirmed ban")
  end)

  -- Regressions for in-game French jewelry and English planner UI (Mage/Paladin).
  local function multilingualCatalog()
    local data={meta={schema=1,content="gear-i18n-test"},
      classes={
        {key="mage",token="MAGE",name="Mage",spells={"frostbolt"}},
        {key="paladin",token="PALADIN",name="Paladin",spells={"holy_light"}}
      },
      spells={
        {key="frostbolt",class="mage",name="Frostbolt"},
        {key="holy_light",class="paladin",name="Holy Light"}
      },
      jewelry={
        {key="ring_accuria",name="Band of Accuria",slot="ring"},
        {key="mark_chosen",name="Mark of the Chosen",slot="trinket"},
        {key="trinket_horde",name="Insignia of the Horde",slot="trinket"}
      },
      amulets={},
      legends={
        {key="legendary:frostbolt",class="mage",spell="frostbolt",
          name="Amulet of the Inferno: Frostbolt",head="Amulet of the Inferno"},
        {key="legendary:holy_light",class="paladin",spell="holy_light",
          name="Eternal Talisman: Holy Light",head="Eternal Talisman"}
      },
      i18n={frFR={
        ["Mark of the Chosen"]="Marque des élus",
        ["Band of Accuria"]="Bague d'Accuria",
        ["Insignia of the Horde"]="Insigne de la Horde",
        ["Frostbolt"]="Éclair de givre",
        ["Holy Light"]="Lumière sacrée"
      }}
    }
    return assert(ns.Catalog.New(data))
  end
  test("mage: equipped French ring and trinket count as owned with English planner UI",function()
    local cat=multilingualCatalog()
    local b=assert(BM.New({id="mage-test",name="Mage Frost",class="mage"},cat))
    b.phases[1].rings[1]="ring_accuria"
    b.phases[1].trinkets[1]="mark_chosen"
    local snap={inRun=true,spellsKnown=true,gearKnown=true,
      spells={{key="frostbolt",rank=1}},
      gear={{slot="ring",name="Bague d'Accuria"},
        {slot="trinket",name="Marque des élus"}}}
    local p=T.Evaluate(b,1,snap,cat,"enUS")
    eq(p.jewelry[1].state,"EQUIPPED")
    eq(p.jewelry[2].state,"EQUIPPED")
    eq(p.jewelry[2].equippedRow.name,"Marque des élus")
  end)
  test("mage: jewelry choice is wanted in native French while planner uses English",function()
    local cat=multilingualCatalog()
    local b=assert(BM.New({id="mage-offer",name="Mage",class="mage"},cat))
    b.phases[1].trinkets[1]="mark_chosen"
    local snap={inRun=true,cards={kind="jewel",cards={
      {name="Marque des élus",slot="trinket"},
      {name="Unknown jewelry",slot="trinket"}}}}
    eq(T.CardHint(b,1,snap,snap.cards.cards[1],cat,"enUS"),"wanted")
    eq(T.OfferHasGoal(b,1,snap,cat,"enUS"),true)
    -- Generic slot labels in the cards packet may not carry ring/trinket type.
    snap.cards.cards[1].slot="jewel"
    eq(T.CardHint(b,1,snap,snap.cards.cards[1],cat,"enUS"),"wanted")
  end)
  test("mage: native AZS_L names work when generated locale entry is absent",function()
    local cat=multilingualCatalog()
    cat.i18n.frFR["Mark of the Chosen"]=nil
    local native={["Mark of the Chosen"]="Marque des élus"}
    local b=assert(BM.New({id="mage-native",name="Mage",class="mage"},cat))
    b.phases[1].trinkets[1]="mark_chosen"
    local snap={inRun=true,gearKnown=true,nativeNames=native,
      gear={{name="Marque des élus",slot="trinket"}}}
    eq(T.Evaluate(b,1,snap,cat,"enUS").jewelry[1].state,"EQUIPPED")
    snap.cards={kind="jewel",cards={{name="Marque des élus"}}}
    eq(T.CardHint(b,1,snap,snap.cards.cards[1],cat,"enUS"),"wanted")
  end)
  test("mage: Capture Run derives ring/trinket slot from catalogue when AZSGEAR omits slot",function()
    local cat=multilingualCatalog()
    local snap={inRun=true,spellsKnown=true,gearKnown=true,
      spells={{key="frostbolt",rank=1}},
      gear={{name="Bague d'Accuria"},{name="Marque des élus"}}}
    local b,err,report=ns.CaptureBuild.Prepare(snap,"mage",cat,"enUS","Mage Run")
    eq(err,nil);ok(b~=nil)
    if b then
      eq(b.phases[1].rings[1],"ring_accuria")
      eq(b.phases[1].trinkets[1],"mark_chosen")
    end
    eq(report.unknownGear,0)
  end)
  test("mage and paladin: legendary amulets captured from localized base/spell names",function()
    local cat=multilingualCatalog()
    local cases={
      {class="mage",spell="frostbolt",key="legendary:frostbolt",
        name="Amulette de l'Inferno: Éclair de givre",
        gameNames={["Amulet of the Inferno"]="Amulette de l'Inferno"}},
      {class="paladin",spell="holy_light",key="legendary:holy_light",
        name="Talisman éternel: Lumière sacrée",
        gameNames={["Eternal Talisman"]="Talisman éternel"}}
    }
    for _,c in ipairs(cases) do
      local snap={inRun=true,spellsKnown=true,gearKnown=true,
        nativeNames=c.gameNames,
        spells={{key=c.spell,rank=1}},
        gear={{name=c.name,slot="legendary"}}}
      local b,err,report=ns.CaptureBuild.Prepare(snap,c.class,cat,"enUS",c.class)
      eq(err,nil);ok(b~=nil)
      if b then eq(b.phases[1].amulets[1],c.key) end
      eq(report.amulets,1)
    end
  end)
  test("jewelry: ambiguous localized names and mismatched class/slot are never guessed",function()
    local cat=multilingualCatalog()
    cat.data.jewelry[#cat.data.jewelry+1]={
      key="another_mark",slot="trinket",name="Other Mark"}
    cat.jewels.another_mark=cat.data.jewelry[#cat.data.jewelry]
    cat.i18n.frFR["Other Mark"]="Marque des élus"
    eq(T.ResolveEquipment({name="Marque des élus",slot="trinket"},cat,"enUS","mage"),nil)
    eq(T.ResolveEquipment({key="mark_chosen",slot="ring"},cat,"enUS","mage"),nil)
    eq(T.ResolveEquipment({key="legendary:holy_light",slot="amulet"},cat,"enUS","mage"),nil)
  end)

end
