-- Lot 3.5: community glossary for legendary titles, Theme component library, visual lab. Widget MOCK: none of this is a
-- rendering proof; the lab addon exists precisely because rendering can only be judged in the client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");
	local ns0 = H.loadAddon();
	local cat = ns0.Catalog.New(ns0.GeneratedCatalog);
	local J = ns0.Json;
	local function fixture(name)
		local text = H.readFile(H.catalogDir .. "/" .. name);
		local function denull(v)
			if v == J.null then return nil; end
			if type(v) == "table" then local o = {}; for k, x in pairs(v) do o[k] = denull(x); end return o; end
			return v;
		end
		return denull(assert(J.Decode(text)));
	end
	local function boot(o)
		o = o or {};
		local world = Stub.new({ width = o.width or 1365, height = o.height or 768, locale = o.locale or "enUS" });
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time });
		local env = { world = world, ns = ns, sb = sb, G = world.G };
		world.fire("ADDON_LOADED", "RebornBuildPlanner");
		env.c, env.ui = ns.controller, ns.ui;
		world.G.SlashCmdList.REBORNPLANNER("");
		env.root = world.G.RebornBuildPlannerFrame;
		function env.h() return ns.storage; end
		return env;
	end

	-- ------------------------------------------------------------------ glossary (community titles)
	test("3.5 glossary: every head of the published legends has a community French title; nothing else is listed", function()
		local heads = {};
		for _, l in ipairs(fixture("legends.json")) do heads[l.head] = true; end
		local n = 0;
		for h in pairs(heads) do
			n = n + 1;
			local fr = ns0.Glossary.frFR[h];
			ok(fr and fr ~= "" and fr ~= h, "head covered: " .. h);
			ok(#fr <= 60, "reasonable length: " .. fr);
		end
		eq(n, 21);
		for h in pairs(ns0.Glossary.frFR) do ok(heads[h], "glossary entry for an unknown head: " .. h); end
		eq(ns0.Glossary.ORIGIN, "community");
	end);

	test("3.5 glossary: composition is deterministic, by stable key, with English fallback and official precedence", function()
		local p = cat:LegendParts("legendary:cleave", "frFR");
		eq(p.head, "Médaillon de la Tempête de lames");
		eq(p.headOrigin, "community");
		eq(p.spell, "Enchaînement");
		eq(p.title, "Médaillon de la Tempête de lames: Enchaînement");
		eq(cat:Name("amulet", "legendary:cleave", "frFR"), p.title);
		-- fallbacks
		eq(cat:Name("amulet", "legendary:cleave", nil), "Medallion of the Bladestorm: Cleave");
		eq(cat:Name("amulet", "legendary:cleave", "deDE"), "Medallion of the Bladestorm: Cleave");
		eq(cat:LegendParts("legendary:cleave", "deDE").headOrigin, "english");
		eq(cat:LegendParts("legendary:nope", "frFR"), nil);
		-- a spell whose name i18n does not carry (same in French) stays English; entries without a spell part show the head only
		local e = cat.legends["legendary:rend"];
		eq(cat:LegendParts("legendary:rend", "frFR").spell, e and cat.spells["rend"] and (cat.i18n.frFR[cat.spells["rend"].name] or cat.spells["rend"].name));
		for _, l in ipairs(fixture("legends.json")) do
			if l.name == l.head then eq(cat:LegendParts(l.key, "frFR").title, ns0.Glossary.frFR[l.head], "head only: " .. l.key); end
		end
		-- a head missing from the glossary falls back to the English head, without error
		local saved = ns0.Glossary.frFR["Eye of the Splitting Sky"];
		ns0.Glossary.frFR["Eye of the Splitting Sky"] = nil;
		local fb = cat:LegendParts("legendary:heroic_throw", "frFR");
		eq(fb.head, "Eye of the Splitting Sky");
		eq(fb.headOrigin, "english");
		ns0.Glossary.frFR["Eye of the Splitting Sky"] = saved;
		-- an official translation of the whole title, if the data ever had one, wins
		local c2 = ns0.Catalog.New(ns0.GeneratedCatalog);
		c2.i18n.frFR = setmetatable({ ["Medallion of the Bladestorm: Cleave"] = "TITRE OFFICIEL" }, { __index = ns0.GeneratedCatalog.i18n and ns0.GeneratedCatalog.i18n.frFR });
		eq(c2:Name("amulet", "legendary:cleave", "frFR"), "TITRE OFFICIEL");
	end);

	test("3.5 glossary: homonymous titles stay distinguishable (class, spell) and stored data never holds a translated name", function()
		local byTitle = {};
		for _, l in ipairs(fixture("legends.json")) do
			local t = cat:LegendParts(l.key, "frFR").title;
			byTitle[t] = byTitle[t] or {};
			table.insert(byTitle[t], l);
		end
		local shared = 0;
		for t, list in pairs(byTitle) do
			if #list > 1 then
				shared = shared + 1;
				local classes = {};
				for _, l in ipairs(list) do no(classes[l.class], "same title AND same class: " .. t); classes[l.class] = true; end
			end
		end
		ok(shared >= 1, "the data does contain titles shared between classes");
		-- the browser row shows spell name, head and CLASS: two homonyms never look identical
		local e = boot({ locale = "frFR" });
		local id = e.c:Create("L", "warlock");
		e.ui:OpenEditor(id);
		e.c:SetCatalog("amulets");
		e.world.type(e.ui.bs.search, "Métamorphose");
		ok(#e.c:CatalogEntries() >= 1);
		local en = e.c:CatalogEntries()[1];
		ok(en.className and en.head and en.spellName, "row data carries class, head and spell");
		-- storage: only the canonical key reaches the saved variables
		e.c:SelectSlot("amulets", 1);
		e.c:SetSlot("amulets", 1, en.key);
		e.c:Save();
		local text = H.serialize("X", e.G.RebornBuildPlannerDB);
		ok(text:find(en.key, 1, true), "the key is stored");
		no(text:find("Médaillon", 1, true) or text:find("Œil du Ciel", 1, true) or text:find("Le Talisman éternel", 1, true), "no translated title in the saved variables");
	end);

	test("3.5 glossary: browser rows put the spell first and the head + class below; the inspector says the title is a community translation", function()
		local e = boot({ locale = "frFR" });
		local id = e.c:Create("L", "warrior"); e.ui:OpenEditor(id);
		e.c:SetCatalog("amulets");
		e.world.type(e.ui.bs.search, "Ciel fendu");
		ok(#e.c:CatalogEntries() >= 1);
		local row = e.ui.bs.rows[1];
		ok(row.sub.text:find("Œil du Ciel fendu", 1, true) and row.sub.text:find("Guerrier", 1, true), row.sub.text);
		ok(not row.name.text:find("Œil du Ciel", 1, true), "the row title is the spell, not a truncated long title: " .. row.name.text);
		e.world.click(row);
		ok(e.ui:DetailText():find("traduction communautaire", 1, true), e.ui:DetailText());
		ok(e.ui.det.title.text:find("Œil du Ciel fendu", 1, true));
		-- English client: no community note, English title
		local en = boot({ locale = "enUS" });
		local id2 = en.c:Create("L", "warrior"); en.ui:OpenEditor(id2);
		en.c:SetCatalog("amulets");
		en.world.type(en.ui.bs.search, "Splitting Sky");
		en.world.click(en.ui.bs.rows[1]);
		no(en.ui:DetailText():find("community", 1, true));
		ok(en.ui.det.title.text:find("Eye of the Splitting Sky", 1, true));
		eq(en.world.lint(en.root), {});
		eq(e.world.lint(e.root), {});
	end);
end
