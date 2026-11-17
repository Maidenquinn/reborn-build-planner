return function(H)
	local eq, ok, no, has, test = H.eq, H.ok, H.no, H.has, H.test;
	local ns = H.loadAddon();
	local data = ns.GeneratedCatalog;
	local cat, code = ns.Catalog.New(data);

	test("catalogue loads", function()
		ok(cat ~= nil, "Catalog.New failed: " .. tostring(code));
		eq(cat:Content(), data.meta.content, "generated content metadata must agree with the catalogue");
		eq(data.meta.schema, 1);
		eq(#data.meta.bodySha256, 64);
	end);

	test("12 classes recognised, counts match the index", function()
		eq(#cat:ClassKeys(), 12);
		for _, k in ipairs({ "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman", "mage", "warlock", "druid", "monk", "demonhunter" }) do
			ok(cat:IsClass(k), "class " .. k);
		end
		eq(#data.spells, data.meta.counts.spells);
		eq(#data.jewelry, 44);
		eq(#data.amulets, 22);
		eq(#data.legends, 237);
		eq(data.meta.counts.legends, 237);
	end);

	test("keys unique where required (New refuses duplicates, ids unique too)", function()
		local ids = {};
		for _, s in ipairs(data.spells) do
			no(ids[s.id], "spell id " .. s.id);
			ids[s.id] = true;
		end
		ok(cat:Get("spell", "whirlwind") ~= nil);
		eq(cat:Get("spell", "whirlwind").id, 1680);
		local bad = ns.Util.DeepCopy(data);
		bad.spells[2].key = bad.spells[1].key;
		local c, why = ns.Catalog.New(bad);
		eq(c, nil);
		eq(why, "INVALID_CATALOG");
	end);

	test("no orphan references", function()
		for _, c in ipairs(data.classes) do
			for _, k in ipairs(c.spells) do
				local s = cat.spells[k];
				ok(s ~= nil and s.class == c.key, "class " .. c.key .. " spell " .. k);
			end
		end
		for _, g in ipairs(data.legends) do
			ok(cat.spells[g.spell] ~= nil, "legend " .. g.key);
			eq(g.key, "legendary:" .. g.spell);
			ok(cat:IsClass(g.class));
		end
		for _, a in ipairs(data.amulets) do
			for _, c in ipairs(a.classes) do ok(cat:IsClass(c), "amulet class " .. c); end
		end
	end);

	test("FR names with EN fallback; unknown key shows itself", function()
		eq(cat:Name("spell", "whirlwind", "frFR"), "Tourbillon");
		eq(cat:Name("spell", "whirlwind", "enUS"), "Whirlwind");
		eq(cat:Name("spell", "whirlwind"), "Whirlwind");
		eq(cat:Name("jewel", "accuria", "frFR"), "Anneau d'Accuria");
		eq(cat:Name("amulet", "mark_of_fordring", "frFR"), "Marque de Fordring");
		eq(cat:Name("amulet", "legendary:cleave", "frFR"), "Médaillon de la Tempête de lames: Enchaînement");   -- head: English only in the data; spell part translated
		eq(cat:Name("amulet", "legendary:cleave", "deDE"), "Medallion of the Bladestorm: Cleave");   -- no embedded language: English
		eq(cat:Name("spell", "no_such_spell", "frFR"), "no_such_spell");
		eq(cat:Name("spell", "whirlwind", "deDE"), "Whirlwind");                                    -- language not embedded
	end);

	test("legendary homonyms need the class; head and icon are never identifiers", function()
		local n = "Eye of the Splitting Sky: Death Coil";
		eq(#cat:Homonyms(n), 2);
		eq(#cat:FindByName("amulets", n), 2);
		local w = cat:FindByName("amulets", n, nil, "warlock");
		eq(#w, 1);
		eq(w[1].key, "legendary:death_coil");
		eq(cat:FindByName("amulets", n, nil, "deathknight")[1].key, "legendary:dk_death_coil");
		eq(#cat:FindByName("amulets", "Medallion of the Bladestorm"), 0, "a shared head matches nothing");
		eq(cat.legends["legendary:cleave"].head, "Medallion of the Bladestorm");
	end);

	test("shared icons are listed, never used as identity", function()
		eq(cat:SharedIcon("INV_Jewelry_Ring_15"), { "accuria", "elementium_signet" });
		eq(cat:SharedIcon("INV_Jewelry_Ring_07"), nil);
		eq(#cat:FindByName("rings", "Band of Accuria"), 1);
	end);

	test("call_of_flame anomaly is reported and nothing is invented", function()
		local an = cat:Anomalies();
		eq(#an, 1);
		eq(an[1].code, "LEGENDARY_FLAG_WITHOUT_LEGEND");
		eq(an[1].key, "call_of_flame");
		ok(cat.spells.call_of_flame.legendary, "source flag kept");
		eq(cat.legends["legendary:call_of_flame"], nil);
		eq(cat:Get("amulet", "legendary:call_of_flame"), nil);
	end);

	test("class normalisation (key, token, any case)", function()
		eq(cat:NormalizeClass("WARRIOR"), "warrior");
		eq(cat:NormalizeClass("Warrior"), "warrior");
		eq(cat:NormalizeClass("DEATHKNIGHT"), "deathknight");
		eq(cat:NormalizeClass("nope"), nil);
		eq(cat:NormalizeClass(""), nil);
		eq(cat:NormalizeClass(nil), nil);
		eq(cat:NormalizeClass(5), nil);
	end);

	test("CheckKey per list", function()
		eq((cat:CheckKey("spells", "whirlwind", "warrior")), "ok");
		eq((cat:CheckKey("banish", "whirlwind", "warrior")), "ok");
		eq((cat:CheckKey("spells", "death_coil", "warrior")), "wrongclass");
		eq((cat:CheckKey("spells", "death_coil", nil)), "ok");
		eq((cat:CheckKey("spells", "zzz", "warrior")), "unknown");
		eq((cat:CheckKey("rings", "accuria")), "ok");
		eq((cat:CheckKey("rings", "earthstrike")), "wrongslot");
		eq((cat:CheckKey("trinkets", "earthstrike")), "ok");
		eq((cat:CheckKey("amulets", "warglaives", "warrior")), "ok");
		eq((cat:CheckKey("amulets", "warglaives", "hunter")), "wrongclass");
		eq((cat:CheckKey("amulets", "mark_of_fordring", "hunter")), "ok");
		eq((cat:CheckKey("amulets", "legendary:cleave", "warrior")), "ok");
		eq((cat:CheckKey("amulets", "legendary:cleave", "mage")), "wrongclass");
		eq((cat:CheckKey("amulets", "")), "unknown");
		eq((cat:CheckKey("nolist", "x")), "unknown");
	end);

	test("class-scoped lists", function()
		ok(#cat:SpellsOfClass("warrior") > 0);
		eq(cat:SpellsOfClass("nosuch"), {});
		has(cat:LegendsOfClass("warrior"), "legendary:cleave");
		has(cat:AmuletsForClass("warrior"), "warglaives");
		no(#cat:AmuletsForClass("hunter") == 0);
		has(cat:JewelsBySlot("trinket"), "earthstrike");
	end);

	test("missing, invalid and future catalogues are refused or tolerated explicitly", function()
		local c, why = ns.Catalog.New(nil);
		eq(why, "NO_CATALOG");
		c, why = ns.Catalog.New({ meta = {} });
		eq(why, "INVALID_CATALOG");
		c, why = ns.Catalog.New({ meta = { schema = 2, content = "x" } });
		eq(c, nil);
		eq(why, "FUTURE_SCHEMA");
		c, why = ns.Catalog.New({ meta = { schema = 0, content = "x" } });
		eq(why, "INVALID_CATALOG");
		c, why = ns.Catalog.New({ meta = { schema = 1, content = "abc" } });      -- sections absent: tolerated, empty
		ok(c ~= nil, tostring(why));
		eq(#c:ClassKeys(), 0);
		eq(c:Name("spell", "whirlwind"), "whirlwind");
		ok(not c:IsClass("warrior"));
	end);

	test("catalogue version comparison", function()
		eq(cat:Compare(data.meta.content), "same");
		eq(cat:Compare("0000000000000000"), "different");
		eq(cat:Compare(""), "unknown");
		eq(cat:Compare(nil), "unknown");
	end);

	test("catalogue data is not mutated by queries", function()
		local before = ns.Util.DeepCopy(data);
		cat:Name("spell", "whirlwind", "frFR"); cat:FindByName("amulets", "x"); cat:CheckKey("amulets", "warglaives", "warrior");
		ok(H.deepeq(before, data));
	end);

	test("class names: localized with English fallback, unknown class shows its key", function()
		eq(cat:ClassName("warrior"), "Warrior");
		eq(cat:ClassName("warrior", "frFR"), "Guerrier");
		eq(cat:ClassName("warrior", "deDE"), "Warrior");
		eq(cat:ClassName("necromancer", "frFR"), "necromancer");
		for _, k in ipairs(cat:ClassKeys()) do ok(cat:ClassName(k, "frFR") ~= "", k); end
	end);
end
