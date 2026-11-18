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

function M.Evaluate(build, phaseIndex, snapshot)
  local output = { inRun = false, known = false, spells = {}, jewelry = {}, achieved = 0, total = 0, offered = {} };
  if type(build) ~= "table" or type(build.phases) ~= "table" then return output end
  local phase = build.phases[phaseIndex or 1];
  if type(phase) ~= "table" then return output end
  snapshot = type(snapshot) == "table" and snapshot or {};
  output.inRun = snapshot.inRun == true;
  output.known = output.inRun and snapshot.spellsKnown == true;
  local state = { known = output.known, spells = spellMap(snapshot.spells) };
  for _, goal in ipairs(phase.spells or {}) do
    local status, reason = BM.EvaluateGoal(goal, state);
    local later = has(phase.banishAfter, goal.key);
    local acquired = state.spells[goal.key] ~= nil and output.known;
    output.spells[#output.spells + 1] = {
      key = goal.key, status = status, reason = reason, acquired = acquired,
      after = later, remindAfter = later and acquired or false,
      rank = type(state.spells[goal.key]) == "number" and state.spells[goal.key] or nil
    };
    output.total = output.total + 1;
    if status == BM.STATUS.ACHIEVED then output.achieved = output.achieved + 1 end
  end
  -- Only an unambiguous stable catalog key permits an equipment match.
  -- AZS_GEAR can carry text/slot but not an identity: never guess by icon or display name.
  local equipped = {};
  local unidentified = false;
  if output.inRun and snapshot.gearKnown then
    for _, item in ipairs(snapshot.gear or {}) do
      if type(item) == "table" and type(item.key) == "string" and item.key ~= "" then
        equipped[item.key] = true;
      elseif type(item) == "table" then
        unidentified = true; -- never infer absence from unidentified game rows
      end
    end
  end
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
        output.jewelry[#output.jewelry + 1] = { key = key, group = kind, slot = i, state = stateName };
      end
    end
  end
  return output;
end

-- Report a proposed card only when game phase, offer kind and stable key are known.
-- "banishAfter" means wanted until acquired, never immediate avoidance.
function M.CardHint(build, phaseIndex, snapshot, card)
  if not build or not snapshot or snapshot.inRun ~= true then return nil end
  if not snapshot.cards then return nil end
  if type(card) ~= "table" or type(card.key) ~= "string" then return nil end
  local ph = build.phases and build.phases[phaseIndex or 1];
  if not ph then return nil end
  local kind = snapshot.cards.kind;
  if kind == "jewel" or kind == "amulet" then
    -- Only exact stable keys. Absence of a card key is not interpreted.
    for _, listName in ipairs({ "rings", "trinkets", "amulets" }) do
      local list = ph[listName] or {};
      local main = listName == "amulets" and 1 or 2;
      for i, key in ipairs(list) do
        if card.key == key and key ~= "" then
          local slot = listName == "rings" and "ring" or
            (listName == "trinkets" and "trinket" or "amulet");
          if card.slot == nil or card.slot == slot then
            return i <= main and "wanted" or "alternative", i
          end
        end
      end
    end
    return nil
  end
  if kind ~= "spell" then return nil end
  if has(ph.banish, card.key) then return "avoid" end
  local wanted;
  for i, goal in ipairs(ph.spells or {}) do
    if goal.key == card.key then wanted = i; break end
  end
  if not wanted then return nil end
  local after = has(ph.banishAfter, card.key);
  local owned = spellMap(snapshot.spells)[card.key] ~= nil;
  if after and snapshot.spellsKnown and owned then return "banish_after", wanted end
  return "wanted", wanted
end

return M;
