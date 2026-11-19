-- LiveTracker: pure, read-only interpretation of a snapshot supplied by the Reborn API.
-- No game globals, SavedVariables, polling, automation, or mutation.
local ADDON, ns = ...;
ns = ns or {};
local M = {};
ns.LiveTracker = M;
local BM = ns.BuildModel;

local function has(list, key)
  for _, v in ipairs(list or {}) do if v == key then return true end end
  return false;
end

local function spellMap(raw)
  local out = {};
  if type(raw) ~= "table" then return out end
  for _, v in ipairs(raw) do
    if type(v) == "table" and type(v.key) == "string" then
      local n = tonumber(v.rank);
      if n == nil then out[v.key] = true
      elseif n > 0 then out[v.key] = n end
    end
  end
  return out;
end

-- The client may transmit legendary amulets as an unkeyed item with
-- "<head>: <spell>" or "<head> · <spell>". Resolve names by strict complete
-- equality after removing presentation-only color codes. Never guess by icon.
local function plainName(value)
  if type(value)~="string" then return nil end
  local text=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    :gsub("^%s+",""):gsub("%s+$","");
  return text~="" and text or nil;
end
local function validItemSlot(slot,listName)
  if slot==nil or slot=="" or slot=="unknown" then return true end
  local alias={ring="rings",rings="rings",trinket="trinkets",trinkets="trinkets",
    amulet="amulets",amulets="amulets",legendary="amulets",legend="amulets"};
  return alias[slot]==listName;
end
local function exactItemName(catalog,entry,kind,gameName,lang)
  local query=plainName(gameName);if not query then return false end
  local names={};
  local function put(name) local v=plainName(name);if v then names[v]=true end end
  put(entry.name);put(catalog:Name(kind,entry.key,lang));
  put(catalog:Name(kind,entry.key,"enUS"));
  if kind=="amulet" and entry.spell then
    -- ASR legendary item cards can use their base name, or base + spell
    -- with either separator. The class constraint is checked by the caller.
    local spell=entry.spell;
    local sp=catalog:Get("spell",spell);
    local bases={entry.name,entry.head,catalog:Name(kind,entry.key,lang)};
    local suffixes={spell,sp and sp.name,sp and catalog:Name("spell",spell,lang),
      sp and catalog:Name("spell",spell,"enUS")};
    for _,base in ipairs(bases) do
      if type(base)=="string" then
        put(base);
        for _,suffix in ipairs(suffixes) do
          if type(suffix)=="string" then
            put(base..": "..suffix);put(base.." · "..suffix);
          end
        end
      end
    end
  end
  return names[query]==true;
end
local function resolveEquipment(item,catalog,lang,class,offerKind)
  if type(item)~="table" then return nil end
  if type(item.key)=="string" and item.key~="" then
    if not catalog then return item.key end
    if catalog:Get("jewel",item.key) or catalog:Get("amulet",item.key) then return item.key end
  end
  if not catalog or not catalog.data then return nil end
  local query=item.name or item.title;
  if not plainName(query) then return nil end
  local found=nil;
  for _,listName in ipairs({"rings","trinkets","amulets"}) do
    local forced=offerKind=="ring" and "rings" or offerKind=="trinket" and "trinkets"
      or offerKind=="amulet" and "amulets" or nil;
    if (not forced or forced==listName) and validItemSlot(item.slot,listName) then
      local kind=listName=="amulets" and "amulet" or "jewel";
      local pools=listName=="amulets" and {catalog.data.amulets or {},catalog.data.legends or {}}
        or {catalog.data.jewelry or {}};
      for _,pool in ipairs(pools) do for _,entry in ipairs(pool) do
        if entry.key and (not catalog.CheckKey or catalog:CheckKey(listName,entry.key,class)=="ok")
          and exactItemName(catalog,entry,kind,query,lang) then
          if found and found~=entry.key then return nil end
          found=entry.key;
        end
      end end
    end
  end
  return found;
end
local function equippedKey(item,catalog,lang,class)
  return resolveEquipment(item,catalog,lang,class);
end

function M.Evaluate(build, phaseIndex, snapshot, catalog, lang)
  local output = { inRun = false, known = false, spells = {}, jewelry = {}, outsideSpells = {}, outsideJewelry = {}, banishedSpells = {}, achieved = 0, total = 0, offered = {} };
  if type(build) ~= "table" or type(build.phases) ~= "table" then return output end
  local phase = build.phases[phaseIndex or 1];
  if type(phase) ~= "table" then return output end
  snapshot = type(snapshot) == "table" and snapshot or {};
  output.inRun = snapshot.inRun == true;
  output.known = output.inRun and snapshot.spellsKnown == true;
  local state = { known = output.known, spells = spellMap(snapshot.spells) };
  local wantedSpells={};
  for _,buildPhase in ipairs(build.phases or {}) do
    for _,goal in ipairs(buildPhase.spells or {}) do if type(goal.key)=="string" then wantedSpells[goal.key]=true end end
  end
  for _, goal in ipairs(phase.spells or {}) do
    local status, reason = BM.EvaluateGoal(goal, state);
    local later = has(phase.banishAfter, goal.key);
    local acquired = state.spells[goal.key] ~= nil and output.known;
    local confirmedBan=snapshot.banned and snapshot.banned[goal.key]==true;
    output.spells[#output.spells + 1] = {
      key = goal.key, status = status, reason = reason, acquired = acquired,
      after = later, remindAfter = later and acquired and not confirmedBan or false, banished=confirmedBan,
      rank = type(state.spells[goal.key]) == "number" and state.spells[goal.key] or nil,
      targetRank = goal.mode=="rank" and goal.rank or nil
    };
    output.total = output.total + 1;
    if status == BM.STATUS.ACHIEVED then output.achieved = output.achieved + 1 end
  end
  -- Ban status is confirmed only after the game acknowledges a ban command.
  -- Ranks remain independent: a previously acquired spell can also be banned.
  if output.inRun and snapshot.bannedKnown and type(snapshot.banned)=="table" then
    for key,value in pairs(snapshot.banned) do
      if value==true and type(key)=="string" then
        output.banishedSpells[#output.banishedSpells+1]={key=key,rank=type(state.spells[key])=="number" and state.spells[key] or nil};
      end
    end
    table.sort(output.banishedSpells,function(a,b)return a.key<b.key end);
  end
  if output.known then
    for key,rank in pairs(state.spells) do
      if not wantedSpells[key] and not (snapshot.banned and snapshot.banned[key]) then
        output.outsideSpells[#output.outsideSpells+1]={key=key,rank=type(rank)=="number" and rank or nil};
      end
    end
    table.sort(output.outsideSpells,function(a,b)return a.key<b.key end);
  end
  -- Only an unambiguous stable catalog key permits an equipment match.
  -- AZS_GEAR can carry text/slot but not an identity: never guess by icon or display name.
  local equipped = {};
  local unidentified = false;
  local wantedJewelry={};
  for _,buildPhase in ipairs(build.phases or {}) do
    for _,kind in ipairs({"rings","trinkets","amulets"}) do
      for _,key in ipairs(buildPhase[kind] or {}) do if type(key)=="string" and key~="" then wantedJewelry[key]=true end end
    end
  end
  if output.inRun and snapshot.gearKnown then
    for _, item in ipairs(snapshot.gear or {}) do
      if type(item)=="table" then
        local key=equippedKey(item,catalog,lang,build.class);
        if key then
          equipped[key]=item;
          if not wantedJewelry[key] then
            local kind=(catalog and catalog:Get("amulet",key)) and "amulet" or "jewel";
            output.outsideJewelry[#output.outsideJewelry+1]={key=key,kind=kind,equippedRow=item};
          end
        else unidentified=true end -- never infer absence from unidentified game rows
      end
    end
  end
  table.sort(output.outsideJewelry,function(a,b)return a.key<b.key end);
  for _, kind in ipairs({ "rings", "trinkets", "amulets" }) do
    local values = phase[kind] or {};
    local main = kind == "amulets" and 1 or 2;
    for i = 1, main do
      local key = values[i];
      if type(key) == "string" and key ~= "" then
        local stateName = equipped[key] and "EQUIPPED" or
          ((not output.inRun or not snapshot.gearKnown or unidentified) and "UNKNOWN" or "MISSING");
        -- An explicitly selected alternative can also satisfy a main slot.
        if stateName ~= "EQUIPPED" then
          for j = main + 1, #values do
            if equipped[values[j]] then stateName = "ALTERNATIVE"; break end
          end
        end
        output.jewelry[#output.jewelry + 1] = { key = key, group = kind, slot = i, state = stateName,
          equippedRow = equipped[key] };
      end
    end
  end
  return output;
end

-- Report a proposed card only when game phase, offer kind and stable key are known.
-- "banishAfter" means wanted until acquired, never immediate avoidance.
-- The client sometimes supplies an accessory name instead of a catalog key.
-- Only accept an exact, UNIQUE official name for the current class and slot;
-- never compare icons, descriptions or partial names.
local function resolvedAccessoryKey(card,kind,catalog,class,lang)
  return resolveEquipment(card,catalog,lang,class,kind);
end

function M.CardHint(build, phaseIndex, snapshot, card, catalog, lang)
  if not build or not snapshot or snapshot.inRun ~= true then return nil end
  if not snapshot.cards then return nil end
  if type(card) ~= "table" then return nil end
  local ph = build.phases and build.phases[phaseIndex or 1];
  if not ph then return nil end
  local kind = snapshot.cards.kind;
  if kind == "jewel" or kind == "amulet" or kind == "ring" or kind == "trinket" then
    local cardKey=resolvedAccessoryKey(card,kind,catalog,build.class,lang);
    if not cardKey then return nil end
    for _, listName in ipairs({ "rings", "trinkets", "amulets" }) do
      local list = ph[listName] or {};
      local main = listName == "amulets" and 1 or 2;
      for i, key in ipairs(list) do
        if cardKey == key and key ~= "" then
          local slot = listName == "rings" and "ring" or
            (listName == "trinkets" and "trinket" or "amulet");
          local offeredSlot = card.slot;
          if not offeredSlot then
            if kind == "ring" then offeredSlot="ring"
            elseif kind == "trinket" then offeredSlot="trinket"
            elseif kind == "amulet" then offeredSlot="amulet" end
          end
          if offeredSlot == nil or offeredSlot == slot then
            return i <= main and "wanted" or "alternative", i
          end
        end
      end
    end
    return nil
  end
  if kind ~= "spell" or type(card.key)~="string" then return nil end
  if has(ph.banish, card.key) then return "avoid" end
  local wanted;
  for i, goal in ipairs(ph.spells or {}) do
    if goal.key == card.key then wanted = i; break end
  end
  if not wanted then return nil end
  local after = has(ph.banishAfter, card.key);
  local owned = spellMap(snapshot.spells)[card.key] ~= nil;
  -- Before AZSSPELLS has arrived we cannot tell whether a wanted-and-later-
  -- banished spell is already owned. Display no hint rather than a misleading
  -- green recommendation.
  if after and not snapshot.spellsKnown then return nil end
  if after and owned then return "banish_after", wanted end
  return "wanted", wanted
end


-- Return false rather than recommending reroll when the offer cannot be
-- identified reliably. Avoid/banish-after are not selectable build goals.
function M.OfferHasGoal(build,phaseIndex,snapshot,catalog,lang)
  local offer=snapshot and snapshot.cards;
  if not build or not snapshot or not offer or snapshot.inRun~=true or type(offer.cards)~="table" or #offer.cards==0 then
    return nil
  end
  local kind=offer.kind;
  if kind~="spell" and kind~="jewel" and kind~="amulet" and kind~="ring" and kind~="trinket" then return nil end
  local known=0;
  for _,card in ipairs(offer.cards) do
    if type(card)=="table" then
      local identified=false;
      if kind=="spell" then
        identified=type(card.key)=="string" and
          (not catalog or catalog:Get("spell",card.key)~=nil);
      else
        identified=resolvedAccessoryKey(card,kind,catalog,build.class,lang)~=nil;
      end
      if identified then
        known=known+1;
        local hint=M.CardHint(build,phaseIndex,snapshot,card,catalog,lang);
        if hint=="wanted" or hint=="alternative" then return true end
      end
    end
  end
  if known<#offer.cards then return nil end
  return false
end

return M;
