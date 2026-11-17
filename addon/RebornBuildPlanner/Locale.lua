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

-- Lets another module add its FR strings (English text is the key).
function Locale.Register(fr)
	for k, v in pairs(fr) do
		FR[k] = v;
	end
end

function Locale.SetLang(lang)
	Locale.lang = (lang == "frFR") and "frFR" or "enUS";
end

-- English text in, localized text out (English when no translation).
function Locale.T(text)
	if Locale.lang == "frFR" then
		return FR[text] or text;
	end
	return text;
end
