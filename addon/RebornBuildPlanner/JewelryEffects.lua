-- Read-only display adapter for jewelry metadata extracted locally from the installed game.
-- No addon-to-addon dependency, no code execution, no tooltip parsing and no gameplay actions.
local ADDON, ns = ...
local E = {}
ns.JewelryEffects = E
local labels = {
  damage = {"Dégâts", "Damage"}, cooldown = {"Réduction des temps de recharge", "Cooldown reduction"},
  crit_damage = {"Bonus de dégâts critiques", "Critical damage bonus"},
  crit = {"Chance de critique", "Critical strike chance"},
  max_health = {"Santé maximale", "Maximum health"}, reduction_and_health = {"Réduction et santé", "Reduction and health"},
  reduction = {"Réduction des dégâts", "Damage reduction"}, lifesteal = {"Vol de vie", "Lifesteal"},
  speed = {"Vitesse", "Speed"}, regen = {"Régénération", "Regeneration"},
  gold = {"Or", "Gold"}, luck = {"Chance", "Luck"}, echo = {"Répétition de sort", "Repeat spell"},
  area = {"Zone d'effet", "Area"},
  pickup = {"Rayon de ramassage", "Pickup radius"}, kill_heal = {"Soins après élimination", "Heal on kill"},
  lives = {"Vies supplémentaires", "Additional lives"},
}
-- Percentages represent base catalog coefficients only, BEFORE rarity or upgrade multipliers.
-- Special/conditional behaviors are deliberately excluded from this set.
local SHARE = {
  damage = true, cooldown = true, crit_damage = true, crit = true,
  max_health = true, reduction = true, lifesteal = true, speed = true,
  gold = true, luck = true, echo = true, area = true, pickup = true,
}
local RAW = { regen = true, kill_heal = true, lives = true }
local function number(n, fr)
  local v = string.format("%.5g", n)
  return fr and v:gsub("%.", ",") or v
end
local function field(g, key)
  if type(g) ~= "table" then return nil end
  for _, row in ipairs(g.jewels or {}) do
    if type(row) == "table" and row.key == key then return row end
  end
end
function E.MetadataStatus()
  local records = ns.GeneratedJewelryMechanics and ns.GeneratedJewelryMechanics.items or {}
  local n = 0
  if type(records) == "table" then
    for _, item in pairs(records) do
      if type(item) == "table" and type(item.base) == "number" then n = n + 1 end
    end
  end
  local runtime = type(AZS_GEN) == "table" and type(AZS_GEN.jewels) == "table" or false
  return n, runtime
end
function E.Lookup(key, slot)
  if type(key) ~= "string" or type(slot) ~= "string" then return nil end
  local generated = ns.GeneratedJewelryMechanics
  local record = generated and generated.items and generated.items[key]
  if record and record.slot == slot and type(record.base) == "number" and type(record.behavior) == "string" then
    return record, "local"
  end
  -- Runtime data may expose richer fields in a newer client; do not invent absent fields.
  local row = field(AZS_GEN, key)
  if row and row.slot == slot and type(row.base) == "number" and type(row.behavior) == "string" then
    return row, "runtime"
  end
end
function E.Sections(key, slot, french)
  local row, origin = E.Lookup(key, slot)
  if not row then return nil end
  local fr = french == true
  local pair = labels[row.behavior]
  local label = pair and pair[fr and 1 or 2] or row.behavior
  local source = origin == "runtime"
    and (fr and "Catalogue natif AZS_GEN" or "Native AZS_GEN catalogue")
    or (fr and "Métadonnées extraites du client local" or "Locally extracted client metadata")
  local isShare = SHARE[row.behavior]
  local isRaw = RAW[row.behavior]
  local base = number(isShare and row.base * 100 or row.base, fr)
  local value = isShare and (base .. (fr and " %" or "%")) or base
  local amountLabel = isShare and (fr and "Coefficient de base" or "Base coefficient")
    or (isRaw and (fr and "Valeur de base" or "Base value")
      or (fr and "Paramètre interne (effet conditionnel)" or "Internal parameter (conditional effect)"))
  local caution = fr and
    "Avant rareté et améliorations. Ce n'est pas la valeur effective pendant une partie."
    or "Before rarity and upgrades. Not the actual in-run value."
  return {
    { title = fr and "Effet identifié" or "Identified effect", lines = { { text = label } } },
    { title = amountLabel, lines = {
      { text = value },
      { text = caution, tone = "dim" }
    } },
    { title = fr and "Origine" or "Source", lines = { { text = source, tone = "dim" } } }
  }
end

-- The game exposes owned jewelry as AZS_GEAR snapshots. It does NOT supply
-- a reliable catalog key: match only when name + slot resolve to ONE unique
-- official catalog entry. Shared icons and approximate names are never enough.
-- Read only at inspection time: the game replaces its snapshot tables.
local function available()
  local ph = AZS_GetPhase and AZS_GetPhase() or (AZS_RUN and AZS_RUN.ph)
  if ph == nil or ph == "ready" or ph == "ended" then return false end
  if AZS_ZONE and tonumber(AZS_ZONE.hub) == 1 then return false end
  return type(AZS_GEAR) == "table"
end
local function matchUnique(catalog, key, slot, display)
  if not catalog or type(display) ~= "string" or display == "" then return false end
  local list = slot == "ring" and "rings" or "trinkets"
  local found, n = {}, 0
  for _, lang in ipairs({ "enUS", "frFR" }) do
    for _, e in ipairs(catalog:FindByName(list, display, lang)) do
      if not found[e.key] then found[e.key] = true; n = n + 1 end
    end
  end
  return n == 1 and found[key] == true
end
function E.LiveSections(catalog, key, slot, french)
  if not available() or (slot ~= "ring" and slot ~= "trinket") then return nil end
  for _, worn in ipairs(AZS_GEAR) do
    if type(worn) == "table" and worn.slot == slot and
       type(worn.text) == "string" and worn.text ~= "" and
       #worn.text <= 2048 and matchUnique(catalog, key, slot, worn.name) then
      return {
        { title = french and "Actuellement équipé (texte du jeu)" or "Currently equipped (game text)",
          lines = { { text = worn.text } } }
      }
    end
  end
end
