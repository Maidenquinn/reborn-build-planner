-- CaptureBuild: turn one live, read-only game snapshot into a NEW planner build.
-- Never changes the game and never guesses identities or silently truncates goals.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.CaptureBuild = M;
local BM = ns.BuildModel;

local function info()
  return {spells=0, rings=0, trinkets=0, amulets=0, bans=0,
    unknownGear=0, unknownSpells=0, overflow=nil, bansComplete=false};
end
local function fail(code, report)
  return nil, code, report;
end
local function validSpell(catalog,key,class)
  if type(key)~="string" or key=="" then return false end
  if not catalog then return false end
  return catalog:Get("spell",key)~=nil and catalog:CheckKey("spells",key,class)=="ok";
end
local function gearGroup(item,key,catalog)
  if catalog:Get("amulet",key) then return "amulets" end
  local jewel=catalog:Get("jewel",key)
  -- Slot belongs to the trusted catalog entry. The game can omit item.slot
  -- or use a generic "jewel" label; never drop a resolved equipped item.
  if jewel and jewel.slot=="ring" then return "rings" end
  if jewel and jewel.slot=="trinket" then return "trinkets" end
  return nil
end

-- Returns (prepared build, nil, report) or (nil, error_code, report).
-- No disk writes here; caller must explicitly confirm through Storage:Add.
function M.Prepare(snapshot, class, catalog, lang, name)
  local report=info();
  if not snapshot or snapshot.inRun~=true then return fail("NOT_IN_RUN",report) end
  if not snapshot.spellsKnown or not snapshot.gearKnown then return fail("SNAPSHOT_INCOMPLETE",report) end
  if not catalog or not catalog:IsClass(class) then return fail("UNKNOWN_CLASS",report) end
  local build=BM.New({id="capture-preview",name=name or "Captured run",class=class},catalog);
  if not build then return fail("INVALID_BUILD",report) end
  local phase=build.phases[1];
  local seen={};
  for _,item in ipairs(snapshot.spells or {}) do
    if type(item)=="table" and validSpell(catalog,item.key,class) and not seen[item.key] then
      seen[item.key]=true;
      local rank=tonumber(item.rank);
      local goal={key=item.key,mode="acquire"};
      if rank and rank>=1 and rank==math.floor(rank) and rank<=BM.LIMITS.maxRank then
        goal={key=item.key,mode="rank",rank=rank};
      end
      phase.spells[#phase.spells+1]=goal;
    else
      report.unknownSpells=report.unknownSpells+1;
    end
  end
  report.spells=#phase.spells;
  if #phase.spells>BM.LIMITS.spells then
    report.overflow="spells";
    return fail("TOO_MANY_SPELLS",report);
  end
  -- Game ban state is only what RBP observed and confirmed in THIS live run.
  -- Never mark an unobserved ban as known, or infer banishment from absence.
  report.bansComplete=snapshot.bannedKnown==true;
  if snapshot.bannedKnown and type(snapshot.banned)=="table" then
    local keys={};
    for key,on in pairs(snapshot.banned) do
      if on==true and validSpell(catalog,key,class) then keys[#keys+1]=key end
    end
    table.sort(keys);
    for _,key in ipairs(keys) do
      if seen[key] then
        phase.banishAfter[#phase.banishAfter+1]=key;
      else
        phase.banish[#phase.banish+1]=key;
      end
    end
    report.bans=#phase.banish+#phase.banishAfter;
    if #phase.banish>BM.LIMITS.banish or #phase.banishAfter>BM.LIMITS.banishAfter then
      report.overflow="banish";
      return fail("TOO_MANY_BANS",report);
    end
  end
  local used={};
  for _,item in ipairs(snapshot.gear or {}) do
    local key=ns.LiveTracker.ResolveEquipment(item,catalog,lang,class,nil,snapshot.nativeNames);
    local group=key and gearGroup(item,key,catalog) or nil;
    if group and not used[key] and catalog:CheckKey(group,key,class)=="ok" then
      used[key]=true;
      local slots=phase[group];
      local pos=nil;
      for i=1,#slots do if slots[i]=="" then pos=i;break end end
      if not pos then report.overflow=group;return fail("TOO_MANY_GEAR",report) end
      slots[pos]=key;
      report[group]=report[group]+1;
    else
      report.unknownGear=report.unknownGear+1;
    end
  end
  if report.spells==0 and report.rings+report.trinkets+report.amulets==0 then
    return fail("NOTHING_IDENTIFIED",report);
  end
  local validation=BM.Validate(build,catalog);
  if not validation.ok or not validation.clean then return fail("INVALID_BUILD",report) end
  return build,nil,report;
end
return M;
