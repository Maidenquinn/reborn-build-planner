-- Lot 3.5: community glossary for legendary titles, Theme component library, visual lab. Widget MOCK: none of this is a
-- rendering proof; the lab addon exists precisely because rendering can only be judged in the client.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");
	local ns0 = H.loadAddon();
	local cat = ns0.Catalog.New(ns0.GeneratedCatalog);
	local J = ns0.Json;
	local function fixture(name)
		local text = H.readFile(H.root .. "/tests/fixtures/catalog/384db000d5ac311d/" .. name);
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

	-- ------------------------------------------------------------------ Theme and lab
	local function loadLab(w, h)
		local world = Stub.new({ width = w or 1920, height = h or 1080 });
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time, only = { "Theme.lua" } });
		local src = H.readFile(H.root .. "/addon_lab/RebornPlannerThemeLab/Lab.lua");
		local fn = assert(loadstring(src, "@Lab.lua"));
		setfenv(fn, sb.env);
		fn("RebornPlannerThemeLab", ns);
		world.fire("ADDON_LOADED", "RebornPlannerThemeLab");
		world.G.SlashCmdList.RBPLAB("");
		return world, ns, sb;
	end

	test("3.5 theme: no Blizzard template anywhere (nothing native can show through), no timer, no script hook", function()
		for _, f in ipairs({ "addon/RebornBuildPlanner/Theme.lua", "addon_lab/RebornPlannerThemeLab/Lab.lua" }) do
			local src = H.readFile(H.root .. "/" .. f):gsub("%-%-[^\n]*", "");
			no(src:find("Template", 1, true), f .. " uses a template");
			no(src:find("OnUpdate", 1, true) or src:find("C_Timer", 1, true) or src:find("HookScript", 1, true), f .. " polls or hooks");
		end
		local world = loadLab();
		for _, f in ipairs(world.all) do
			if f.kind == "Button" or f.kind == "EditBox" or f.kind == "Frame" then no(f.template, "template on " .. tostring(f.name or f.kind)); end
			no(f.scripts and f.scripts.OnUpdate);
		end
	end);

	test("3.5 theme: every button has the same construction (own gradient + border + label + client highlight / pushed), states differ", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		local n = 0;
		for _, f in ipairs(world.all) do
			if f.kind == "Button" and f.label then
				n = n + 1;
				ok(f.hlPath == T.WHITE and f.pushedPath == T.WHITE, "highlight and pushed textures set");
				ok(f.label.color, "label colour set");
			end
		end
		ok(n >= 20, "buttons built: " .. n);
		-- rest vs disabled vs selected are different looks
		local a = T.Button(world.G.UIParent, "a", 80, 24, "secondary");
		local topRest = a.bg.gradient[5];
		T.SetEnabled(a, false);
		no(a.bg.gradient[5] == topRest and a.bg.gradient[6] == topRest, "disabled differs from rest");
		ok(a.label.color[1] < 0.6, "disabled label is dim");
		T.SetEnabled(a, true);
		T.SetRole(a, "selected");
		ok(a.edges.top.texColor[1] > 0.8, "selected has the gold border");
		T.SetRole(a, "danger");
		ok(a.edges.top.texColor[1] < 0.7 and a.edges.top.texColor[1] > 0.5, "danger has the red border");
		-- the click is ignored while disabled
		local hit = 0;
		local b = T.Button(world.G.UIParent, "b", 80, 24, "primary", function() hit = hit + 1; end);
		world.click(b); eq(hit, 1);
		T.SetEnabled(b, false);
		world.click(b); eq(hit, 1, "disabled: no action");
	end);

	test("3.5 theme: text contrast (WCAG) on every surface and button look is readable", function()
		local T = ns0.Theme;
		local function surf(k) return T.Mid(T.SURFACE[k].top, T.SURFACE[k].bottom); end
		for _, s in ipairs({ "window", "panel", "inset", "card" }) do
			ok(T.Contrast(T.C.ivory, surf(s)) >= 7, "ivory on " .. s .. ": " .. T.Contrast(T.C.ivory, surf(s)));
			ok(T.Contrast(T.C.mute, surf(s)) >= 4.5, "secondary on " .. s .. ": " .. T.Contrast(T.C.mute, surf(s)));
			ok(T.Contrast(T.C.gold, surf(s)) >= 4.5, "gold on " .. s);
			ok(T.Contrast(T.C.green, surf(s)) >= 4.5, "success on " .. s);
			ok(T.Contrast(T.C.red, surf(s)) >= 3, "red on " .. s);
		end
		for role, r in pairs(T.ROLES) do
			local need = role == "disabled" and 3 or 4.5;
			ok(T.Contrast(r.text, T.Mid(r.top, r.bottom)) >= need, role .. " label: " .. T.Contrast(r.text, T.Mid(r.top, r.bottom)));
		end
		for name, c in pairs(T.C.rarity) do ok(T.Contrast(c, surf("card")) >= 4.5, "rarity " .. name); end
		ok(T.Contrast(T.C.dim, surf("inset")) >= 2.8, "placeholder text still legible");
		-- the selection fill keeps its text readable
		ok(T.Contrast(T.C.ivory, T.C.blue) >= 7);
	end);

	test("3.5 lab: the sample screen holds every requested component, both techniques, inside the window, at three resolutions", function()
		for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 1280, 720 } }) do
			local world, ns, sb = loadLab(size[1], size[2]);
			local root = world.G.RebornPlannerThemeLabFrame;
			ok(root:IsShown());
			eq(world.lint(root), {}, size[1] .. "x" .. size[2]);
			local rr = world.rectOf(root);
			ok(rr[1] >= -0.5 and rr[3] <= size[1] + 0.5 and rr[2] >= -0.5 and rr[4] <= size[2] + 0.5, "window on screen");
			if size[1] == 1920 then
				for _, label in ipairs({ "Panneaux", "Boutons : repos, sélection, désactivé", "Champ de recherche", "Ligne de sort", "Case d'équipement : pleine, vide, choisie", "Entrée de catalogue" }) do
					ok(world.hasText(label), label);
				end
				ok(world.hasText("Infobulle"));
				ok(world.hasText("Enregistrer") and world.hasText("Supprimer") and world.hasText("Désactivé"));
				ok(world.hasText("Rechercher un build, un sort, un objet…"));
				ok(world.hasText("Eye of the Splitting Sky: Enchaînement"), "long legendary title in an equipment cell / tooltip");
				ok(world.hasText("Ce client : SetGradientAlpha:oui"), "capability report is shown");
				-- two columns of equal width
				local c1, c2;
				for _, f in ipairs(world.all) do if f.kind == "Frame" and f.w == 560 and f.h == 700 then if not c1 then c1 = f; else c2 = f; end end end
				ok(c1 and c2, "two columns");
				local r1, r2 = world.rectOf(c1), world.rectOf(c2);
				eq(r1[3] - r1[1], r2[3] - r2[1]);
				ok(r2[1] >= r1[3], "side by side, no overlap");
			end
		end
	end);

	test("3.5 lab: empty and filled equipment cells, selected row, search placeholder behaviour, themed tooltip sized by content", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		local cells = {};
		for _, f in ipairs(world.all) do if f.kind == "Button" and f.role and f.name and f.remove then cells[#cells + 1] = f; end end
		ok(#cells >= 6, "cells in both columns: " .. #cells);
		local filled, empty = 0, 0;
		for _, c in ipairs(cells) do if c.remove:IsShown() then filled = filled + 1; else empty = empty + 1; end end
		ok(filled >= 2 and empty >= 2, "filled and empty both rendered");
		-- search placeholder shows when empty, hides when typing
		local s = T.Search(world.G.UIParent, 200, 28, "Rechercher");
		ok(s.placeholder:IsShown());
		world.type(s.edit, "abc");
		no(s.placeholder:IsShown());
		world.type(s.edit, "");
		ok(s.placeholder:IsShown());
		-- tooltip: taller for more content, capped, on screen near the right edge
		local tip = T.Tooltip(world.G.UIParent);
		local owner = T.Frame(world.G.UIParent, 20, 20, "card");
		owner:SetPoint("TOPLEFT", world.G.UIParent, "TOPLEFT", 100, -100);
		T.ShowTooltip(tip, owner, "t", { "one" });
		local h1 = tip.h;
		local many = {};
		for i = 1, 30 do many[i] = "line " .. i .. " of a long effect text"; end
		T.ShowTooltip(tip, owner, "t", many);
		ok(tip.h > h1, "taller with more content");
		ok(tip.h <= 240, "capped");
		local right = T.Frame(world.G.UIParent, 20, 20, "card");
		right:SetPoint("TOPLEFT", world.G.UIParent, "TOPLEFT", 1890, -100);
		T.ShowTooltip(tip, right, "t", { "one" });
		local r = world.rectOf(tip);
		ok(r[3] <= 1920, "opens to the left near the right edge: " .. r[3]);
	end);

	test("3.5 lab: diag command and gradient flip flag; the lab writes nothing but its own saved variable", function()
		local world, ns, sb = loadLab();
		world.G.SlashCmdList.RBPLAB("diag");
		ok(world.chat[#world.chat - 1]:find("SetGradientAlpha:oui", 1, true), world.chat[#world.chat - 1]);
		world.G.SlashCmdList.RBPLAB("flip");
		ok(world.G.RebornPlannerThemeLabDB.flip == true);
		for k in pairs(sb.writes) do
			ok(k == "SlashCmdList" or k == "RebornPlannerThemeLabDB" or k:find("^SLASH_RBPLAB") or k:find("^RebornPlannerThemeLab"), "unexpected global write: " .. k);
		end
	end);
end
