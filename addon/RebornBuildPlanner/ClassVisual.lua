-- Read-only class visuals for library rows: Blizzard class atlas when available,
-- original fallback to the official game catalogue spell icon for newer classes.
-- Identifiers remain stable class keys, never localized display names.
local ADDON, ns = ...
local V = {}
ns.ClassVisual = V
local colors = {
  warrior={0.78,0.61,0.43}, paladin={0.96,0.55,0.73},
  hunter={0.67,0.83,0.45}, rogue={1.00,0.96,0.41},
  priest={1.00,1.00,1.00}, deathknight={0.77,0.12,0.23},
  shaman={0.00,0.44,0.87}, mage={0.41,0.80,0.94},
  warlock={0.58,0.51,0.79}, monk={0.00,1.00,0.60},
  druid={1.00,0.49,0.04}, demonhunter={0.64,0.19,0.79}
}
-- WoW 3.3.5 4x4 class texture atlas; the live CLASS_ICON_TCOORDS
-- takes precedence, permitting clients with extended class assets.
local cells = {
  WARRIOR={0,0}, MAGE={1,0}, ROGUE={2,0}, DRUID={3,0},
  HUNTER={0,1}, SHAMAN={1,1}, PRIEST={2,1}, WARLOCK={3,1},
  PALADIN={0,2}, DEATHKNIGHT={1,2}
}
function V.Color(key)
  local c = colors[key] or {0.83,0.87,0.94}
  return c[1], c[2], c[3]
end
function V.Icon(key, catalog)
  -- Reborn's WoW 3.3.5 class atlas has no monk/demon-hunter tiles.
  -- Use our two original assets before any atlas or unreliable spell fallback.
  if key == "monk" then
    return "Interface\\AddOns\\RebornBuildPlanner\\Media\\ultimate_class_monk",0.02,0.98,0.02,0.98
  elseif key == "demonhunter" then
    return "Interface\\AddOns\\RebornBuildPlanner\\Media\\ultimate_class_dh",0.02,0.98,0.02,0.98
  end
  local rec = catalog and catalog.classes and catalog.classes[key]
  local token = rec and rec.token and string.upper(rec.token) or string.upper(key or "")
  local live = type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[token]
  if type(live) == "table" and #live >= 4 then
    return "Interface\\WorldStateFrame\\Icons-Classes", live[1],live[2],live[3],live[4]
  end
  local cell = cells[token]
  if cell then
    local x,y=cell[1]*0.25,cell[2]*0.25
    return "Interface\\WorldStateFrame\\Icons-Classes",x,x+0.25,y,y+0.25
  end
  -- Older atlas does not necessarily contain monk/demon hunter.
  -- Use the icon of that class' first official spell instead of a wrong crest.
  local first=rec and rec.spells and rec.spells[1]
  local spell=first and catalog.spells and catalog.spells[first]
  if spell and type(spell.icon)=="string" and spell.icon~="" then
    return "Interface\\Icons\\"..spell.icon,0.07,0.93,0.07,0.93
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark",0.07,0.93,0.07,0.93
end
return V
