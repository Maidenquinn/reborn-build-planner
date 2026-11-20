-- Core: private namespace and the single place that touches the game's globals.
-- Initialisation order (3.3.5a): the client loads the saved variables of an addon BEFORE it fires ADDON_LOADED
-- for that addon (our files are already executed then), so everything that needs RebornBuildPlannerDB happens in
-- the ADDON_LOADED handler. No AZS handler, no AZS_* table touched, no network, no gameplay action.
-- Lua 5.1 syntax only.
local ADDON, ns = ...;
ns = ns or {};
-- Prefer the installed .toc metadata so diagnostics cannot drift behind release packaging.
local metaVersion = type(GetAddOnMetadata) == "function" and GetAddOnMetadata(ADDON, "Version") or nil;
ns.VERSION = (type(metaVersion) == "string" and metaVersion ~= "") and metaVersion or "0.5.0-beta.2";
RebornBuildPlanner = ns;

-- existingDb: the loaded SavedVariables table (nil on first run); now: clock function.
-- Returns the storage handle. The caller assigns RebornBuildPlannerDB only when handle.readOnly is false.
function ns.Init(existingDb, now)
	local cat, code, msg = ns.Catalog.New(ns.GeneratedCatalog);
	ns.catalog = cat;
	ns.catalogStatus = cat and "OK" or code;
	ns.catalogMessage = msg;
	local h = ns.Storage.Open(existingDb, { catalog = cat, now = now });
	ns.storage = h;
	-- Keep the user's selected locale (including Automatic) separate from the
	-- currently resolved language. Missing translations fall back per key.
	ns.Locale.SetLang(h:GetSetting("lang") or "auto");
	ns.playerClassToken = function()
		if type(UnitClass) == "function" then
			local _, token = UnitClass("player");
			return token;
		end
		return nil;
	end;
	ns.controller = ns.Controller.New(ns);
	ns.ui = ns.UI.New(ns.controller, ns);
	return h;
end

-- Called once when our saved variables are available.
function ns.Start(existingDb, now)
	local h = ns.Init(existingDb, now);
	if not h.readOnly then
		RebornBuildPlannerDB = h.db;
	end
	ns.Commands.Register(ns.ui, ns.controller);
	if ns.MinimapButton then ns.MinimapButton.Start() end
	if ns.Runtime then ns.Runtime.Start() end
	return h;
end

if CreateFrame then
	local f = CreateFrame("Frame");
	f:RegisterEvent("ADDON_LOADED");
	f:SetScript("OnEvent", function(self, event, name)
		if name ~= ADDON then
			return;
		end
		self:UnregisterEvent("ADDON_LOADED");
		ns.Start(RebornBuildPlannerDB, time);
	end);
end
