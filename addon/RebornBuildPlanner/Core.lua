-- Core: private namespace and the single place that touches the game's globals.
-- Lot 1 wiring only (catalogue + storage). No AZS handler, no frame besides the ADDON_LOADED listener,
-- no UI, no write to any AZS_* table. Lua 5.1 syntax only.
local ADDON, ns = ...;
ns = ns or {};
ns.VERSION = "0.1.0-lot1";
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
		local h = ns.Init(RebornBuildPlannerDB, time);
		if not h.readOnly then
			RebornBuildPlannerDB = h.db;
		end
	end);
end
