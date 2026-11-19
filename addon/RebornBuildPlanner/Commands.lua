-- Slash commands /rbp and /rebornplanner. An alias already claimed by another addon is NOT taken over (the
-- other registration is left alone and a chat line says so). Standard 3.3.5a mechanism: SLASH_<NAME><n> globals
-- plus SlashCmdList[<NAME>]. Lua 5.1.
local ADDON, ns = ...;
ns = ns or {};
local Locale = ns.Locale;
local Commands = { NAME = "REBORNPLANNER", ALIASES = { "/rbp", "/rebornplanner" } };
ns.Commands = Commands;

local function say(text)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffRebornBuildPlanner|r " .. text);
	end
end

-- Is `cmd` already the alias of a command of another addon?
local function claimed(cmd)
	if type(_G) ~= "table" then
		return false;
	end
	for k, v in pairs(_G) do
		if type(k) == "string" and string.sub(k, 1, 6) == "SLASH_" and v == cmd and not string.find(k, "^SLASH_" .. Commands.NAME) then
			return true, k;
		end
	end
	return false;
end

function Commands.Handle(ui, controller, msg)
	local arg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"));
	if arg == "" or arg == "toggle" then
		ui:Toggle();
	elseif arg == "reset" then
		ui:ResetPosition();
		say(Locale.T("Window position and size reset."));
	elseif arg == "hud" then
		if ns.Runtime and ns.Runtime.ready then say("HUD " .. tostring(ns.Runtime.ToggleHud())); else say("Live API unavailable"); end
	elseif arg == "theme" then
		if ns.Runtime and ns.Runtime.ready then say("HUD theme: " .. tostring(ns.Runtime.ToggleTheme())); else say("Live API unavailable"); end
	elseif arg == "theme standard" or arg == "theme elwynn" then
		if ns.Runtime and ns.Runtime.ready then say("HUD theme: " .. tostring(ns.Runtime.SetTheme(arg:sub(7)))); else say("Live API unavailable"); end
	elseif arg == "history" then
		local h=controller:Handle();
		local history=h and h.RevisionHistory and h:RevisionHistory() or {};
		if #history==0 then say("No saved revisions yet."); end
		for i,entry in ipairs(history) do
			say(string.format("%d. %s (revision %s) [%s]",i,tostring(entry.name),
				tostring(entry.revision),tostring(entry.id)));
		end
	elseif string.match(arg,"^restore%s+") then
		local id,index=string.match(arg,"^restore%s+(%S+)%s+(%d+)$");
		local h=controller:Handle();
		if not id or not index then
			say("Usage: /rbp restore <build-id> <history-index>; see /rbp history");
		elseif not h or h.readOnly then
			say("Saved data is read-only.");
		else
			local ok,reason=h:RestoreRevision(id,tonumber(index));
			if ok then
				say("Build revision restored as a new saved version: "..id);
				if controller.Notify then controller:Notify() end
			else
				say("Restore refused: "..tostring(reason and (reason.message or reason.code) or "unknown"));
			end
		end
	elseif arg == "diag" then
		local h = controller:Handle();
		say(string.format("version %s, storage %s%s, catalogue %s (%s)", tostring(ns.VERSION), h and h.status or "none",
			(h and h.readOnly) and " (read only)" or "", ns.catalog and ns.catalog:Content() or "none", tostring(ns.catalogStatus)));
		say("Live tracker: " .. (ns.Runtime and ns.Runtime.ready and "events connected" or "API not connected"));
		if ns.JewelryEffects then
			local total, runtime, expected = ns.JewelryEffects.MetadataStatus();
			say(string.format("bijoux : %d/%s mecanique(s) locale(s), AZS_GEN %s, effets live uniquement pour objets equipes et identifies", total, expected and tostring(expected) or "?", runtime and "present" or "absent"));
		end
	else
		say(Locale.T("Usage: /rbp (open or close) | /rbp reset | /rbp diag"));
	end
end

-- Registers the aliases that are free. Returns the list of registered aliases and the list of refused ones.
function Commands.Register(ui, controller)
	local done, refused = {}, {};
	SlashCmdList = SlashCmdList or {};
	for _, cmd in ipairs(Commands.ALIASES) do
		local taken = claimed(cmd);
		if taken then
			refused[#refused + 1] = cmd;
		else
			done[#done + 1] = cmd;
			_G["SLASH_" .. Commands.NAME .. #done] = cmd;
		end
	end
	if #done > 0 then
		SlashCmdList[Commands.NAME] = function(msg) Commands.Handle(ui, controller, msg); end;
	end
	if #refused > 0 then
		say(string.format(Locale.T("Command %s is already used by another addon and was left alone."), table.concat(refused, ", ")));
	end
	return done, refused;
end

Locale.Register({
	["Window position and size reset."] = "Position et taille de la fenêtre réinitialisées.",
	["Usage: /rbp (open or close) | /rbp reset | /rbp diag"] = "Usage : /rbp (ouvrir ou fermer) | /rbp reset | /rbp diag",
	["Command %s is already used by another addon and was left alone."] = "La commande %s est déjà utilisée par un autre addon et n'a pas été modifiée.",
});
