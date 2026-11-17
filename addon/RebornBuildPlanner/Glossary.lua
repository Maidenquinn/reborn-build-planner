-- French titles of the legendary amulets (Lot 3.5). SEPARATE from the official translations.
--
-- Facts (audit of the published data, content 384db000d5ac311d): i18n/frFR.json translates spell names, rings, trinkets and
-- the 22 fixed amulets, but NOT the 21 "heads" (the part of a legendary's title before the spell name: "Eye of the Splitting
-- Sky: Cleave"). The game's own text for them is English. The entries below are COMMUNITY PROPOSALS written for this addon,
-- not official translations. They are keyed by the English head (the data's own `head` field), never by a legendary's key:
-- the storage and the builds only ever hold `legendary:<spell>`, so this table can change without touching any saved data.
-- A head that is not listed falls back to the English head. The French title of a legend is composed deterministically:
--     <community head> ": " <spell name translated by i18n/frFR.json, else English>
-- and an official translation of a whole title, if the game's data ever carries one, wins over everything here.
local ADDON, ns = ...;
ns = ns or {};
local G = { ORIGIN = "community" };
ns.Glossary = G;

G.frFR = {
	["The Eternal Talisman"] = "Le Talisman éternel",
	["Eye of the Splitting Sky"] = "Œil du Ciel fendu",
	["Medallion of the Bladestorm"] = "Médaillon de la Tempête de lames",
	["Heart of the Earthshaker"] = "Cœur du Secoueur de terre",
	["Pendant of the Plague"] = "Pendentif de la Peste",
	["Amulet of the Inferno"] = "Amulette du Brasier",
	["Breath of the Black Dragon"] = "Souffle du Dragon noir",
	["Charm of the Fated Hour"] = "Charme de l'Heure fatidique",
	["Stormcaller's Amulet"] = "Amulette de l'Invocateur de tempête",
	["The Legionlord's Medallion"] = "Médaillon du Seigneur de la Légion",
	["The Reaper's Amulet"] = "Amulette du Faucheur",
	["Talisman of the Tempest"] = "Talisman de la Tempête",
	["Amulet of the Ancients"] = "Amulette des Anciens",
	["Earthshatter Seal"] = "Sceau brise-terre",
	["Emberwake Pendant"] = "Pendentif du Sillage de braise",
	["Winter's Embrace"] = "Étreinte de l'hiver",
	["Cinderheart Pendant"] = "Pendentif Cœur de cendre",
	["Eye of the Tempest"] = "Œil de la Tempête",
	["Magmaheart Pendant"] = "Pendentif Cœur de magma",
	["Cinderlash Pendant"] = "Pendentif Fouet de cendre",
	["Eye of Leotheras"] = "Œil de Léotheras",
};

-- French head of an English head: (text, origin) with origin "community" or "english" (fallback)
function G.Head(head, lang)
	if lang == "frFR" and G.frFR[head] then return G.frFR[head], G.ORIGIN; end
	return head, "english";
end
