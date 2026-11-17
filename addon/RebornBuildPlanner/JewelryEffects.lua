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
