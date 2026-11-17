-- Lot 3.5b: original textures (files), nine-slice construction, visible states, opacity / layers, visual lab v2.
-- Widget MOCK: none of this proves how the client draws; the lab exists for that. These tests prove what CAN be proven
-- offline: the texture files are valid and complete, every path the theme uses exists, nothing is built transparent or on a
-- low layer, both columns hold the same components, and nothing overlaps.
return function(H)
	local eq, ok, no, test = H.eq, H.ok, H.no, H.test;
	local Stub = dofile(H.root .. "/tests/lua/wowstub.lua");
	local MEDIA = H.root .. "/addon_lab/RebornPlannerThemeLab/Media/";
	local PREFIX = "Interface\\AddOns\\RebornPlannerThemeLab\\Media\\";

	local function loadLab(w, h)
		local world = Stub.new({ width = w or 1920, height = h or 1080 });
		local ns, sb = H.loadAddon({ globals = world.G, time = world.G.time, only = { "Util.lua" } });
		for _, f in ipairs({ { H.root .. "/addon/RebornBuildPlanner/Theme.lua" }, { H.root .. "/addon_lab/RebornPlannerThemeLab/Lab.lua" } }) do
			local fn = assert(loadstring(H.readFile(f[1]), "@" .. f[1]));
			setfenv(fn, sb.env);
			fn("RebornPlannerThemeLab", ns);
		end
		world.fire("ADDON_LOADED", "RebornPlannerThemeLab");
		world.G.SlashCmdList.RBPLAB("");
		return world, ns, sb;
	end

	local function readBin(path)
		local fh = assert(io.open(path, "rb"));
		local d = fh:read("*a");
		fh:close();
		return d;
	end
	local function u16(d, i) return d:byte(i) + d:byte(i + 1) * 256; end
	local function isPow2(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 1e-9) == math.log(n) / math.log(2) or (n > 0 and 2 ^ math.floor(math.log(n) / math.log(2) + 0.5) == n); end

	-- ------------------------------------------------------------------ the files
	test("3.5b files: every texture is a valid 32-bit uncompressed TGA, power-of-two, complete, with alpha where it must be", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		local n = 0;
		for name, def in pairs(T.FILES) do
			n = n + 1;
			local d = readBin(MEDIA .. name .. ".tga");
			eq(d:byte(3), 2, name .. ": uncompressed true-colour");
			local w, h = u16(d, 13), u16(d, 15);
			eq(d:byte(17), 32, name .. ": 32 bits per pixel");
			eq(#d, 18 + w * h * 4, name .. ": file length = header + pixels");
			ok(isPow2(w) and isPow2(h), name .. ": power of two " .. w .. "x" .. h);
			if name:find("^ultimate_") then
				ok(w <= 512 and h <= 256 and #d < 300000, name .. ": capped fantasy texture");
			else
				ok(w <= 256 and h <= 256 and #d < 70000, name .. ": small");
			end
			if name:find("_nine$") then
				eq(w, def[1], name .. ": width as declared");
				eq(h, def[3] or def[1], name .. ": height as declared");
				ok(def[2] * 2 < w, name .. ": corners leave a stretchable middle");
			end
			-- pixel(x,y): rows are stored bottom-up
			local function px(x, y) local o = 19 + ((h - 1 - y) * w + x) * 4; return d:byte(o + 2), d:byte(o + 1), d:byte(o), d:byte(o + 3); end
			local _, _, _, centreA = px(math.floor(w / 2), math.floor(h / 2));
			if name:find("_nine$") or name == "row_sel" or name == "thumb" then
				eq(centreA, name == "row_sel" and 235 or 255, name .. ": the body is opaque (nothing shows through)");
			end
			if name == "icon_frame" then eq(centreA, 0, "icon frame: transparent centre (the icon shows through)"); end
			if name == "veil_hover" or name == "veil_pressed" then ok(centreA > 40 and centreA < 255, name .. ": translucent veil: " .. centreA); end
		end
		eq(n, 23);
		-- nothing in Media that the theme does not declare (no stray / copied file)
		local listing = io.popen and io.popen('dir /b "' .. MEDIA:gsub("/", "\\") .. '" 2>nul');
		if listing then
			local seen = 0;
			for f in listing:lines() do if f:find("%.tga$") then seen = seen + 1; ok(T.FILES[f:gsub("%.tga$", "")], "undeclared file: " .. f); end end
			listing:close();
			if seen > 0 then eq(seen, 23, "inventory complete"); end
		end
	end);

	test("3.5b files: every texture path the lab and the theme set points to a file that exists", function()
		local world, ns = loadLab();
		local paths, count = {}, 0;
		for _, f in ipairs(world.all) do
			if type(f.texture) == "string" and f.texture:find("^Interface\\AddOns\\") then paths[f.texture] = true; end
			if f.hlPath and f.hlPath:find("^Interface\\AddOns\\") then paths[f.hlPath] = true; end
			if f.pushedPath and f.pushedPath:find("^Interface\\AddOns\\") then paths[f.pushedPath] = true; end
		end
		for p in pairs(paths) do
			count = count + 1;
			ok(p:sub(1, #PREFIX) == PREFIX, "inside the lab's Media folder: " .. p);
			local name = p:sub(#PREFIX + 1):gsub("%.tga$", "");
			local fh = io.open(MEDIA .. name .. ".tga", "rb");
			ok(fh, "missing file " .. name);
			if fh then fh:close(); end
			ok(p:find("%.tga$"), "explicit extension: " .. p);
		end
		ok(count >= 15, "the lab uses " .. count .. " distinct texture files");
		-- the strip of swatches draws every declared file
		local n = 0;
		for _ in pairs(world.G.RebornPlannerThemeLabFrame and ns.Lab.swatches or {}) do n = n + 1; end
		eq(n, 23);
	end);

	-- ------------------------------------------------------------------ nine-slice
	test("3.5b nine-slice: 4 fixed corners, 4 stretched edges (two anchors), 1 centre; correct texture coordinates; sizes large enough", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		local f = CreateFrame and nil;
		local frame = T.Frame(world.G.UIParent, 200, 80, "panel");
		local nine = frame.nine;
		eq(#nine.tex, 9);
		local def = T.FILES.ultimate_panel;
		local c, size = def[2], def[1];
		local u1, u2 = c / size, 1 - c / size;
		local want = { { 0, u1, 0, u1 }, { u2, 1, 0, u1 }, { 0, u1, u2, 1 }, { u2, 1, u2, 1 }, { u1, u2, 0, u1 }, { u1, u2, u2, 1 }, { 0, u1, u1, u2 }, { u2, 1, u1, u2 }, { u1, u2, u1, u2 } };
		for i, w in ipairs(want) do
			for k = 1, 4 do ok(math.abs(nine.tex[i].coords[k] - w[k]) < 1e-9, "texcoord " .. i .. "." .. k); end
		end
		for i = 1, 4 do eq(nine.tex[i].w, c, "corner is " .. c .. " px"); eq(nine.tex[i].h, c); end
		for i = 5, 8 do eq(#nine.tex[i].points, 2, "edge stretched between two anchors"); end
		eq(#nine.tex[9].points, 2);
		-- every nine-slice frame of the lab is big enough for its corners (otherwise the corners would overlap)
		for _, fr in ipairs(world.all) do
			if fr.nine and fr.w > 0 then
				local cc = T.FILES[fr.nine.file][2];
				ok(fr.w >= 2 * cc and fr.h >= 2 * cc, "frame " .. fr.w .. "x" .. fr.h .. " vs corners " .. cc .. " (" .. fr.nine.file .. ")");
			end
		end
		-- swapping the file keeps the geometry
		nine:SetFile("window_nine");
		eq(nine.tex[1].texture, T.Media("window_nine"));
		eq(nine.tex[1].coords[2], u1, "coordinates untouched by a file swap");
	end);

	-- ------------------------------------------------------------------ states
	test("3.5b states: rest / hover / pressed / selected / disabled are different TEXTURES; hover and pressed veils exist; disabled ignores clicks", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		local b = T.Button(world.G.UIParent, "Test", 100, 30, "secondary", function() end);
		eq(b.nine.file, "button_secondary_nine");
		eq(b.hlPath, T.Media("veil_hover"), "client highlight carries the warm veil");
		eq(b.pushedPath, T.Media("veil_pressed"), "client pushed state carries the dark veil");
		T.SetRole(b, "primary");   eq(b.nine.file, "button_primary_nine");
		T.SetRole(b, "selected");  eq(b.nine.file, "button_selected_nine");
		T.SetRole(b, "danger");    eq(b.nine.file, "button_danger_nine");
		T.SetRole(b, "secondary");
		T.SetEnabled(b, false);    eq(b.nine.file, "button_disabled_nine");
		ok(b.label.color[1] < 0.6, "disabled label is dim");
		T.SetEnabled(b, true);     eq(b.nine.file, "button_secondary_nine");
		T.ForceState(b, "hover");   ok(b.veilHover:IsShown() and not b.veilPressed:IsShown());
		T.ForceState(b, "pressed"); ok(b.veilPressed:IsShown() and not b.veilHover:IsShown());
		T.ForceState(b, nil);       ok(not b.veilHover:IsShown() and not b.veilPressed:IsShown());
		local hits = 0;
		local c = T.Button(world.G.UIParent, "c", 80, 24, "primary", function() hits = hits + 1; end);
		world.click(c); eq(hits, 1);
		T.SetEnabled(c, false); world.click(c); eq(hits, 1);
		-- the five looks have five different files, and the generator draws all of them
		local files = {};
		for _, r in ipairs({ "primary", "secondary", "danger", "selected", "disabled" }) do files["button_" .. r .. "_nine"] = true; end
		local n = 0; for k in pairs(files) do n = n + 1; ok(T.FILES[k], k); end
		eq(n, 5);
		-- text is centred in every button of the lab
		for _, f in ipairs(world.all) do
			if f.kind == "Button" and f.label and f.nine then
				eq(f.label.justifyH, "CENTER");
				eq(f.label.points[#f.label.points].point, "CENTER");
			end
		end
	end);

	test("3.5b contrast: label colours on the button textures' real body colours, text on every surface (WCAG)", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		for role, r in pairs(T.ROLES) do
			local need = role == "disabled" and 3 or 4.5;
			ok(T.Contrast(r.text, r.flat) >= need, role .. ": " .. T.Contrast(r.text, r.flat));
		end
		for k, s in pairs(T.SURFACE) do
			local m = T.Mid(s.top, s.bottom);
			ok(T.Contrast(T.C.ivory, m) >= 7, "ivory on " .. k);
			ok(T.Contrast(T.C.mute, m) >= 4.5, "secondary on " .. k);
			ok(T.Contrast(T.C.gold, m) >= 4.5, "gold on " .. k);
			ok(T.Contrast(T.C.green, m) >= 4.5, "success on " .. k);
		end
		for name, c in pairs(T.C.rarity) do ok(T.Contrast(c, T.Mid(T.SURFACE.card.top, T.SURFACE.card.bottom)) >= 4.5, "rarity " .. name); end
		ok(T.Contrast(T.C.dim, T.Mid(T.SURFACE.inset.top, T.SURFACE.inset.bottom)) >= 2.8, "placeholder");
	end);

	-- ------------------------------------------------------------------ opacity and layers
	test("3.5b layers: the window is on a high strata and level, top-level, mouse-opaque; no surface is translucent; tooltip above", function()
		local world, ns = loadLab();
		local root = world.G.RebornPlannerThemeLabFrame;
		eq(root.strata, "FULLSCREEN_DIALOG", "above DIALOG: the game's HUD texts cannot sit over it");
		eq(root.level, 100);
		ok(root.toplevel, "raises itself when clicked");
		ok(root.mouse, "swallows mouse events");
		-- every nine-slice texture of every surface is fully opaque (alpha 1, no vertex alpha)
		local checked = 0;
		for _, fr in ipairs(world.all) do
			if fr.nine then
				for _, tex in ipairs(fr.nine.tex) do
					checked = checked + 1;
					eq(tex.alpha, 1, "texture alpha");
					ok(not tex.vertex or tex.vertex[4] == nil or tex.vertex[4] == 1, "no translucent tint on a surface");
					eq(tex.layer, "BACKGROUND", "surfaces sit on the BACKGROUND layer, under their content");
				end
			end
		end
		ok(checked > 200, "surface textures checked: " .. checked);
		for _, fr in ipairs(world.all) do
			if fr.kind == "Frame" and fr.strata == "TOOLTIP" then ok(true); end
		end
		-- the sample tooltip frame is above the window
		local tip;
		for _, fr in ipairs(world.all) do if fr.surfaceKind == "tooltip" then tip = fr; end end
		ok(tip and tip.level and tip.level > root.level, "tooltip above the window");
	end);

	test("3.5b layers: /rbplab diag reports strata, level and any visible frame drawn over the lab", function()
		local world, ns = loadLab();
		-- a foreign frame on TOOLTIP strata over the lab: it must be named in the report
		local intruder = CreateFrame_for_test and nil;
		local foreign = world.G.CreateFrame("Frame", "GameFloatingText", world.G.UIParent);
		foreign:SetWidth(200); foreign:SetHeight(40);
		foreign:SetPoint("TOPLEFT", world.G.UIParent, "TOPLEFT", 400, -300);
		foreign:SetFrameStrata("TOOLTIP");
		world.G.SlashCmdList.RBPLAB("diag");
		local lines = table.concat(world.chat, "\n");
		ok(lines:find("SetGradientAlpha:oui", 1, true), "capabilities");
		ok(lines:find("strata FULLSCREEN_DIALOG, niveau 100", 1, true), lines);
		ok(lines:find("textures : " .. PREFIX, 1, true), "media path printed");
		ok(lines:find("GameFloatingText", 1, true), "the frame drawn over the lab is named: " .. lines);
		foreign:Hide();
		world.G.SlashCmdList.RBPLAB("diag");
		ok(table.concat(world.chat, "\n"):find("aucune autre fenêtre visible au-dessus du labo", 1, true));
	end);

	-- ------------------------------------------------------------------ the lab
	test("3.5b lab: same components in both columns, new vs old technique, inside the window at 1920x1080, 1365x768, 1280x720", function()
		for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 1280, 720 } }) do
			local world, ns = loadLab(size[1], size[2]);
			local root = world.G.RebornPlannerThemeLabFrame;
			ok(root:IsShown());
			eq(world.lint(root), {}, size[1] .. "x" .. size[2]);
			local rr = world.rectOf(root);
			ok(rr[1] >= -0.5 and rr[3] <= size[1] + 0.5 and rr[2] >= -0.5 and rr[4] <= size[2] + 0.5, "window on screen");
			if size[1] == 1920 then
				local newB, oldB = 0, 0;
				local newT, oldT = 0, 0;
				local function inColumn(f) local p = f; while p do if p.w == 560 and p.h == 700 then return true; end p = p.parent; end return false; end
				for _, f in ipairs(world.all) do
					if f.kind == "Button" and f.label and f:IsVisible() and inColumn(f) then
						if f.nine then newB = newB + 1; elseif f.mode == "backdrop" then oldB = oldB + 1; end
					end
				end
				ok(newB >= 18, "new-theme buttons: " .. newB);
				eq(newB, oldB, "both columns hold the same buttons");
				for _, label in ipairs({ "Panneaux", "Boutons : repos, survol, clic, choisi, inactif", "Champ de recherche", "Ligne de sort", "Case d'équipement : pleine, vide, choisie", "Catalogue défilant et infobulle" }) do
					local n = 0;
					for _, t in ipairs(world.texts()) do if t == label then n = n + 1; end end
					eq(n, 2, label .. " in both columns");
				end
				ok(world.hasText("Ce client : SetGradientAlpha:oui"));
				ok(world.hasText("laboratoire visuel v2"));
				-- columns: equal widths, side by side
				local cols = {};
				for _, f in ipairs(world.all) do if f.kind == "Frame" and f.w == 560 and f.h == 700 then cols[#cols + 1] = f; end end
				eq(#cols, 2);
				local r1, r2 = world.rectOf(cols[1]), world.rectOf(cols[2]);
				eq(r1[3] - r1[1], r2[3] - r2[1]);
				ok(r2[1] >= r1[3] + 10, "gap between the columns");
			end
		end
	end);

	test("3.5b lab: scrolling list (wheel + bar), sizes of the same texture (small and large), empty / filled / selected cells, search focus ring", function()
		local world, ns = loadLab();
		local T = ns.Theme;
		-- two sizes of the same panel texture, and three widths of the same button texture
		local small = T.Frame(world.G.UIParent, 40, 34, "panel");
		local big = T.Frame(world.G.UIParent, 400, 200, "panel");
		eq(small.nine.file, big.nine.file);
		eq(#small.nine.tex, #big.nine.tex);
		-- scrolling: the first list of the lab (left column): wheel moves the offset, rows change, clamped
		local hold;
		for _, f in ipairs(world.all) do if f.kind == "Frame" and f.scripts.OnMouseWheel and f.w == 300 then hold = hold or f; end end
		ok(hold, "scroll area found");
		local first = hold.children[1].name.text;
		hold.scripts.OnMouseWheel(hold, -1);
		ok(hold.children[1].name.text ~= first, "wheel scrolls");
		for _ = 1, 10 do hold.scripts.OnMouseWheel(hold, -1); end
		local last = hold.children[3].name.text;
		hold.scripts.OnMouseWheel(hold, -1);
		eq(hold.children[3].name.text, last, "clamped at the end");
		for _ = 1, 10 do hold.scripts.OnMouseWheel(hold, 1); end
		eq(hold.children[1].name.text, first, "clamped at the top");
		-- cells
		local cells = {};
		for _, f in ipairs(world.all) do if f.kind == "Button" and f.nine and f.remove then cells[#cells + 1] = f; end end
		ok(#cells >= 3, "cells in the new column: " .. #cells);
		local states = {};
		for _, c in ipairs(cells) do states[c.nine.file] = true; end
		ok(states.slot_normal_nine and states.slot_selected_nine and states.slot_empty_nine, "normal, selected and empty cell textures all shown");
		-- the long legendary title sits in a bounded, wrapped name box inside its cell
		local filled = cells[1];
		ok(filled.name.text:find("Eye of the Splitting Sky", 1, true));
		ok(filled.name.wordWrap and filled.name.h >= 24, "two lines available");
		-- search: placeholder + focus ring
		local s = T.Search(world.G.UIParent, 200, 30, "Rechercher");
		ok(s.placeholder:IsShown() and not s.focus:IsShown());
		s.edit:SetFocus();
		ok(s.focus:IsShown() and not s.placeholder:IsShown(), "focus ring shown, placeholder hidden");
		s.edit:ClearFocus();
		ok(not s.focus:IsShown() and s.placeholder:IsShown());
		-- scroll bar syncs without firing the callback
		local fired = 0;
		local bar = T.ScrollBar(world.G.UIParent, 100, function() fired = fired + 1; end);
		bar.Sync(2, 5);
		eq(fired, 0);
		eq(bar.slider:GetValue(), 2);
	end);

	test("3.5b lab: no Blizzard template, no OnUpdate / timer / hook, writes only its own variable; Media path follows the addon name", function()
		for _, f in ipairs({ "addon/RebornBuildPlanner/Theme.lua", "addon_lab/RebornPlannerThemeLab/Lab.lua" }) do
			local src = H.readFile(H.root .. "/" .. f):gsub("%-%-[^\n]*", "");
			no(src:find("Template", 1, true), f .. " uses a template");
			no(src:find("OnUpdate", 1, true) or src:find("C_Timer", 1, true) or src:find("HookScript", 1, true), f .. " polls or hooks");
		end
		local world, ns, sb = loadLab();
		eq(ns.Theme.media, PREFIX);
		for _, f in ipairs(world.all) do
			if f.kind == "Button" or f.kind == "EditBox" or f.kind == "Frame" or f.kind == "Slider" then no(f.template, "template on " .. tostring(f.name or f.kind)); end
			no(f.scripts and f.scripts.OnUpdate);
		end
		for k in pairs(sb.writes) do
			ok(k == "SlashCmdList" or k:find("^SLASH_RBPLAB") or k:find("^RebornPlannerThemeLab"), "unexpected global write: " .. k);
		end
		-- no widget is created after the build
		local n0 = #world.all;
		world.G.SlashCmdList.RBPLAB("");
		world.G.SlashCmdList.RBPLAB("");
		eq(#world.all, n0);
	end);
end
