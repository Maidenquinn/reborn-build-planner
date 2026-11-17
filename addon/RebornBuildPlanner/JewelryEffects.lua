-- Read-only display adapter for jewelry metadata extracted locally from the installed game.
-- No addon-to-addon dependency, no code execution, no tooltip parsing and no gameplay actions.
local ADDON, ns = ...
local E = {}
ns.JewelryEffects = E
local labels = {
  damage = {"Bonus de dégâts", "Damage bonus"}, cooldown = {"Réduction des temps de recharge", "Cooldown reduction"},
  crit_damage = {"Bonus de dégâts critiques", "Critical damage bonus"},
  crit = {"Chance de critique", "Critical strike chance"},
  max_health = {"Santé maximale", "Maximum health"}, reduction_and_health = {"Réduction et santé", "Reduction and health"},
  reduction = {"Réduction des dégâts", "Damage reduction"}, lifesteal = {"Vol de vie", "Lifesteal"},
  speed = {"Vitesse", "Speed"}, regen = {"Régénération", "Regeneration"},
  gold = {"Or", "Gold"}, luck = {"Chance", "Luck"}, echo = {"Répétition de sort", "Repeat spell"},
  area = {"Zone d'effet", "Area"}, cooldown = {"Réduction du temps de recharge", "Cooldown reduction"},
  pickup = {"Rayon de ramassage", "Pickup radius"}, kill_heal = {"Soins après élimination", "Heal on kill"},
  lives = {"Vies supplémentaires", "Additional lives"},
}
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
  local base = string.format("%.8g", row.base)
  if fr then base = base:gsub("%.", ",") end
  return {
    { title = fr and "Effet identifié" or "Identified effect", lines = { { text = label } } },
    { title = fr and "Valeur de base" or "Base value", lines = {
      { text = base },
      { text = fr and "Échelle interne du jeu ; ce n'est pas le bonus réel de la partie." or
        "Game internal scale; not the actual bonus during a run.", tone = "dim" }
    } },
    { title = fr and "Origine" or "Source", lines = { { text = source, tone = "dim" } } }
  }
end
