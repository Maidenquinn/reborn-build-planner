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
  local expected = ns.GeneratedJewelryMechanics and ns.GeneratedJewelryMechanics.expected
  return n, runtime, (type(expected) == "number" and expected >= n) and expected or nil
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
-- Player-first summary: plain meaning of a known base coefficient, never a guessed
-- current rarity/rank stat. Unknown/conditional behaviors remain explicitly unresolved.
local SUMMARY = {
  lifesteal = { "des dégâts que tu infliges te soignent.", "of the damage you deal heals you." },
  damage = { "de dégâts supplémentaires.", "extra damage." },
  cooldown = { "de temps de recharge en moins.", "shorter cooldowns." },
  crit_damage = { "de dégâts critiques supplémentaires.", "extra critical hit damage." },
  crit = { "de chances de coup critique.", "critical strike chance." },
  max_health = { "de points de vie maximum supplémentaires.", "extra maximum health." },
  reduction = { "de dégâts reçus en moins.", "less incoming damage." },
  speed = { "de vitesse supplémentaire.", "more speed." },
  gold = { "d'or supplémentaire.", "more gold." },
  luck = { "de chance supplémentaire.", "more luck." },
  pickup = { "de rayon de ramassage supplémentaire.", "more pickup radius." },
  area = { "de zone d'effet supplémentaire.", "larger area of effect." },
}
function E.Simple(key, slot, french)
  local row = E.Lookup(key, slot)
  if not row then return nil end
  local fr = french == true
  local desc = SUMMARY[row.behavior]
  if desc and type(row.base) == "number" then
    local pct = number(row.base * 100, fr) .. (fr and " %" or "%")
    return {
      text = pct .. " " .. desc[fr and 1 or 2],
      note = fr and "Valeur de base : le bonus reel depend de la rarete et des ameliorations."
        or "Base value: actual bonus depends on rarity and upgrades."
    }
  end
  return {
    text = fr and "Effet special : consulte la description dans le jeu."
      or "Special effect: check the in-game description.",
    note = fr and "Les donnees locales ne precisent pas la formule complete."
      or "The local data does not specify the full formula."
  }
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
  local simple = E.Simple(key, slot, fr)
  local result = {
    { title = fr and "CE QUE FAIT CET OBJET" or "WHAT THIS ITEM DOES", lines = {
      { text = simple and simple.text or label, tone = "ok" },
      { text = simple and simple.note or caution, tone = "dim" }
    } },
    { title = fr and "VALEUR DE REFERENCE" or "REFERENCE VALUE", lines = {
      { text = label .. " : " .. value },
      { text = caution, tone = "dim" }
    } },
  }
  local function appendPairs(input, title, isSpecial)
    if type(input) ~= "table" or #input == 0 then return end
    local lines = {}
    for _, pair in ipairs(input) do
      if type(pair) == "table" and type(pair[1]) == "string" and type(pair[2]) == "number" and
         pair[2] == pair[2] and #lines < 16 then
        local fieldName = pair[1]
        local translated = labels[fieldName]
        local name = translated and translated[fr and 1 or 2] or fieldName
        -- Only stat shares have documented percentage semantics. Special parameters
        -- are implementation-dependent and must not be displayed as run bonuses.
        local pct = (not isSpecial) and SHARE[fieldName]
        local rendered = number(pct and pair[2] * 100 or pair[2], fr)
        lines[#lines+1] = { text = name .. ": " .. rendered .. (pct and (fr and " %" or "%") or "") }
      end
    end
    if #lines > 0 then
      if isSpecial then
        lines[#lines+1] = { text = fr and
          "Paramètres de mécanique ; leur interprétation dépend du jeu." or
          "Mechanics parameters; interpretation depends on the game.", tone = "dim" }
      end
      result[#result+1] = { title = title, lines = lines }
    end
  end
  appendPairs(row.effects, fr and "Autres effets déclarés" or "Other declared effects", false)
  appendPairs(row.specials, fr and "Effets conditionnels" or "Conditional effects", true)
  result[#result+1] = { title = fr and "Origine" or "Source", lines = { { text = source, tone = "dim" } } }
  return result
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
        { title = french and "BONUS ACTUEL DANS LA PARTIE" or "CURRENT BONUS IN THIS RUN",
          lines = { { text = worn.text, tone = "ok" } } }
      }
    end
  end
end
