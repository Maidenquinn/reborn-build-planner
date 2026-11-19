-- Minimal FR/EN strings for the domain layer (issue messages, default phase labels). English is the
-- fallback and the key. No widget text here: the UI lots add their own.
local ADDON, ns = ...;
ns = ns or {};
local Locale = { lang = "enUS" };
ns.Locale = Locale;

local FR = {
	["Unknown catalogue key"] = "Clé de catalogue inconnue",
	["Key belongs to another class"] = "La clé appartient à une autre classe",
	["Key is not valid for this list"] = "La clé ne convient pas à cette liste",
	["Duplicate entry"] = "Entrée en double",
	["Spell is both wanted and banished"] = "Sort à la fois souhaité et banni",
	["Same piece used in several slots"] = "Même pièce dans plusieurs emplacements",
	["Too many entries"] = "Trop d'entrées",
	["Invalid value"] = "Valeur invalide",
	["Catalogue version differs"] = "Version de catalogue différente",
	["Early Game"] = "Début de partie",
	["Mid Game"] = "Milieu de partie",
	["End Game"] = "Fin de partie",
	["Endless"] = "Sans fin",
	["Unknown class"] = "Classe inconnue",
};

-- Selection is independent from available translated dictionaries. Unsupported languages
-- are selectable, and fall back per-string to English rather than pretending to be translated.
Locale.LANGUAGES = {
  { code = "auto", label = "Automatic" },
  { code = "enUS", label = "English" },
  { code = "plPL", label = "Polski" },
  { code = "csCZ", label = "Čeština" },
  { code = "deDE", label = "Deutsch" },
  { code = "ptBR", label = "Português (Brasil)" },
  { code = "esES", label = "Español" },
  { code = "frFR", label = "Français" },
  { code = "roRO", label = "Română" },
  { code = "trTR", label = "Türkçe" },
  { code = "ruRU", label = "Русский" },
  { code = "ukUA", label = "Українська" },
  { code = "zhCN", label = "简体中文" },
  { code = "jaJP", label = "日本語" },
  { code = "koKR", label = "한국어" },
}
local supported = {}
for _, item in ipairs(Locale.LANGUAGES) do supported[item.code] = item; end
Locale.dict = { frFR = FR }
Locale.selected = "auto"

-- Supports an independent localized dictionary later without changing UI code.
function Locale.RegisterLanguage(code, strings)
  if not supported[code] or code == "auto" or type(strings) ~= "table" then return false end
  if not Locale.dict[code] then Locale.dict[code] = {} end
  for k, v in pairs(strings) do
    if type(k) == "string" and type(v) == "string" and v ~= "" then
      Locale.dict[code][k] = v
    end
  end
  return true
end

function Locale.Register(fr)
  return Locale.RegisterLanguage("frFR", fr)
end

function Locale.IsSupportedSelection(code)
  return supported[code] ~= nil
end

function Locale.SetLang(code)
  if not supported[code] then code = "auto" end
  Locale.selected = code
  local actual = code
  if code == "auto" then
    actual = type(GetLocale) == "function" and GetLocale() or "enUS"
  end
  Locale.lang = supported[actual] and actual or "enUS"
  return Locale.lang
end

function Locale.Selection()
  return Locale.selected or "auto"
end

function Locale.Label(code)
  return supported[code] and supported[code].label or supported.auto.label
end

function Locale.T(key)
  local dict = Locale.dict[Locale.lang]
  return dict and dict[key] or key
end
