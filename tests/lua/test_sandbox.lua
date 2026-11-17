return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local function list(t) local o = {}; for k in pairs(t) do o[#o + 1] = k; end table.sort(o); return o; end
	-- CreateFrame is the one client global Core.lua is allowed to look for (guarded); anything else is a bug.
	local function reads(sb) local o = {}; for _, k in ipairs(list(sb.reads)) do if k ~= "CreateFrame" and k ~= "GetLocale" and k ~= "UnitClass" then o[#o + 1] = k; end end return o; end
	local function strip(src) return (src:gsub("%-%-[^\n]*", "")); end
	local function files() return H.tocFiles(H.root); end
	local function now() return 1700000000; end

	test("toc: interface, dependencies, saved variables, complete and ordered", function()
		local toc = H.readFile(H.root .. "/addon/RebornBuildPlanner/RebornBuildPlanner.toc");
		ok(toc:find("## Interface: 30300", 1, true));
		ok(toc:find("## Dependencies: AzerothSurvivors, AzerothSurvivorsAPI", 1, true));
		ok(toc:find("## SavedVariables: RebornBuildPlannerDB", 1, true));
		eq(files(), { "Util.lua", "Locale.lua", "GeneratedCatalog.lua", "Catalog.lua", "Describe.lua", "BuildModel.lua", "Storage.lua", "Utf8.lua", "Base64Url.lua", "Json.lua", "PlannerCodec.lua", "UIStrings.lua", "Controller.lua", "UI.lua", "Commands.lua", "Core.lua" });
		for _, f in ipairs(files()) do
			ok(#H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f) > 0, f);
		end
		-- order matters: a module loaded before its dependency must fail
		local okLoad = pcall(H.loadAddon, { only = { "BuildModel.lua", "Util.lua" } });
		no(okLoad, "BuildModel must not load before Util");
		okLoad = pcall(H.loadAddon, { only = { "Util.lua", "Locale.lua", "Catalog.lua", "Describe.lua", "BuildModel.lua", "Storage.lua" } });
		ok(okLoad, "modules do not require GeneratedCatalog at load time");
	end);

	test("sources use only Lua 5.1 constructs available in the client", function()
		local forbidden = { "%f[%w]goto%f[%W]", "::[%a_]", "table%.unpack", "bit32", "%f[%w]load%(", "loadstring", "dofile", "require",
			"%f[%w]io%.", "%f[%w]os%.", "package%.", "debug%.", "math%.pow", "string%.pack", "utf8%.", "%f[%w]_ENV%f[%W]", "\\z", "[%w%)%]]%s+//%s+" };
		for _, f in ipairs(files()) do
			local src = strip(H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f));
			if f == "GeneratedCatalog.lua" then src = src:gsub('"[^"\n]*"', '""'); end    -- data strings may hold anything
			for _, pat in ipairs(forbidden) do
				no(src:find(pat), f .. " contains forbidden construct " .. pat);
			end
		end
		local ns = H.loadAddon();
		ok(ns.Storage and ns.BuildModel and ns.Catalog and ns.Util and ns.Locale and ns.GeneratedCatalog);
	end);

	test("only the namespace global is written; no non-client global is read", function()
		local ns, sb = H.loadAddon({ time = now });
		eq(list(sb.writes), { "RebornBuildPlanner" });
		eq(reads(sb), {}, "reads of non-whitelisted globals");
		local h = ns.Init(nil, now);
		local id = h:Create({ name = "x", class = "warrior" });
		h:Duplicate(id); h:Delete(id); h:SetActive("warrior", h:List()[1].id);
		ns.BuildModel.AddSpell(h:Get(h:List()[1].id), 1, "whirlwind", nil, ns.catalog);
		eq(list(sb.writes), { "RebornBuildPlanner" });
		eq(reads(sb), {}, "reads after a workflow");
	end);

	test("other addons' SavedVariables and AZS tables are never read, written or modified", function()
		local sentinels = {
			ASBuilderDB = { builds = { a = 1 } }, AZS_SETTINGS = { x = 1 }, AZS_API_HUD = { y = 2 },
			AzerothStatsRebornDB = { z = 3 }, AzerothFieldKitRebornDB = { w = 4 }, FieldKitRebornDB = { v = 5 },
			AZS_RUN = { ph = "playing" }, AZS_GEAR = { { slot = "ring" } }, AZS_CARDS = { kind = "spell", cards = {} },
			AZS_SPELLS = { { key = "whirlwind" } }, AZS_ZONE = { run = "r1" },
		};
		local snap = {};
		for k, v in pairs(sentinels) do snap[k] = H.roundtrip(v); end
		local ns, sb = H.loadAddon({ time = now, extra = sentinels });
		local h = ns.Init(nil, now);
		local id = h:Create({ name = "x", class = "warrior" });
		h:Update(id, ns.BuildModel.SetName(h:Get(id), "y", ns.catalog));
		h:ImportBuilds({ { name = "i", class = "mage", phases = {} } });
		local m = ns.Init({ builds = { { name = "p", class = "warrior" } } }, now);
		eq(m.status, "MIGRATED");
		for k, v in pairs(sentinels) do
			ok(H.deepeq(v, snap[k]), k .. " was modified");
		end
		eq(reads(sb), {}, "the addon must not even read another addon's table");
		local combined = "";
		for _, f in ipairs(files()) do combined = combined .. strip(H.readFile(H.root .. "/addon/RebornBuildPlanner/" .. f)); end
		for _, name in ipairs({ "ASBuilderDB", "AZS_", "AZS%.", "AzerothStats", "FieldKit", "SendAddonMessage", "SetCVar", "CHAT_MSG_ADDON" }) do
			no(combined:find(name), "source references " .. name);
		end
	end);

	test("Core wiring: ADDON_LOADED assigns RebornBuildPlannerDB only when it is safe", function()
		local handler, registered;
		local function CreateFrame()
			local f = {};
			function f:RegisterEvent(e) registered = (registered or "") .. e; end
			function f:UnregisterEvent() self.unregistered = true; end
			function f:SetScript(_, fn) handler = function(...) return fn(f, ...); end; end
			return f;
		end
		local function boot(existing)
			handler, registered = nil, nil;
			local ns, sb = H.loadAddon({ time = now, CreateFrame = CreateFrame, extra = { RebornBuildPlannerDB = existing, _G = {}, SlashCmdList = {} } });
			eq(registered, "ADDON_LOADED");
			handler("ADDON_LOADED", "SomeOtherAddon");
			ok(sb.base.RebornBuildPlannerDB == existing, "another addon's load must not initialise us");
			handler("ADDON_LOADED", "RebornBuildPlanner");
			return ns, sb;
		end
		local ns, sb = boot(nil);
		eq(sb.base.RebornBuildPlannerDB.schema, 1);
		eq(ns.catalogStatus, "OK");
		local future = { schema = 42, keep = "me" };
		ns, sb = boot(future);
		ok(sb.base.RebornBuildPlannerDB == future, "a future schema must never be replaced");
		eq(future, { schema = 42, keep = "me" });
		eq(ns.storage.status, "FUTURE_SCHEMA");
		local old = { builds = { { name = "p", class = "warrior" } } };
		local before = H.roundtrip(old);
		ns, sb = boot(old);
		ok(sb.base.RebornBuildPlannerDB ~= old, "a successful migration replaces the table");
		eq(sb.base.RebornBuildPlannerDB.schema, 1);
		ok(H.deepeq(old, before), "the old table is left as it was");
		ns, sb = boot({ schema = 1, builds = {}, library = {}, active = {} });
		eq(ns.storage.status, "OK");
	end);

	test("a broken catalogue disables nothing silently", function()
		local ns = H.loadAddon({ time = now });
		ns.GeneratedCatalog = { meta = { schema = 2, content = "x" } };
		local h = ns.Init(nil, now);
		eq(ns.catalogStatus, "FUTURE_SCHEMA");
		eq(ns.catalog, nil);
		eq(h.status, "CREATED");
		local id = h:Create({ name = "x", class = "warrior" });
		ok(id, "storage and the model still work without catalogue checks");
		eq(h:Get(id).catalog, "");
	end);
end
