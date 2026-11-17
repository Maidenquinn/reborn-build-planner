-- Visual lab v2 (Lot 3.5b). /rbplab opens ONE window with the same sample screen built twice:
--   left  : NEW theme = original nine-slice textures (Media\*.tga), embossed buttons, visible hover / pressed veils
--   right : OLD flat theme (what 0.4.2 looked like), for an immediate side-by-side comparison
-- Also: states shown without the mouse (repos / survol / clic / choisi / inactif), a scrolling list, a tooltip sample, a strip that
-- draws every texture file (a green or white square there = that file failed to load), and /rbplab diag (capabilities, strata,
-- level, frames drawn over the lab). The window sits on FULLSCREEN_DIALOG / level 100, fully opaque. Nothing here touches the
-- planner, the HUD, another addon or any saved variable except the lab's own flag.
local ADDON, ns = ...;
ns = ns or {};
local T = ns.Theme;
local lab = {};
ns.Lab = lab;

local W, H = 1180, 790;
local COLW = 560;
local SAMPLE_ROWS = {
	{ "Visée", "Ability_Marksmanship", false }, { "Marque du chasseur", "Ability_Hunter_SniperShot", true },
};
local CATALOG = {
	{ "Anneau d'Accuria", "INV_Jewelry_Ring_15", "epic", "Anneau · Épique", "En place" },
	{ "Eye of the Splitting Sky: Enchaînement", "INV_Jewelry_Necklace_AhnQiraj_03", "legendary", "Amulette légendaire · Guerrier", "" },
	{ "Bague de puissance", "INV_Jewelry_Ring_07", "rare", "Anneau · Rare", "" },
	{ "Sceau des damnés", "INV_Jewelry_Ring_51Naxxramas", "rare", "Bijou · Rare", "" },
	{ "Amulette de Vigueur", "INV_Jewelry_Necklace_14", "rare", "Amulette · Rare", "" },
	{ "Talvash", "INV_Jewelry_Necklace_02", "common", "Amulette · Commune", "" },
};

local function column(root, x, mode, heading)
	T.mode = mode;
	local col = T.Frame(root, COLW, 700, "panel");
	col:SetPoint("TOPLEFT", root, "TOPLEFT", x, -64);
	local bar = T.TitleBar(col, "Reborn Build Planner", 16, 12, COLW - 32, 34);
	local sub = T.Text(col, T.FONT.small, T.C.mute, 18, 52, COLW - 36, 12, "CENTER");
	sub:SetText(heading);

	T.SectionTitle(col, "Panneaux", 18, 72, COLW - 36);
	local p1 = T.Frame(col, 110, 54, "panel"); p1:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -100);
	T.Text(p1, T.FONT.small, T.C.ivory, 14, 20, 90, 14, "CENTER"):SetText("Petit");
	local p2 = T.Frame(col, 250, 54, "panel"); p2:SetPoint("TOPLEFT", col, "TOPLEFT", 140, -100);
	T.Text(p2, T.FONT.body, T.C.ivory, 16, 10, 220, 14):SetText("Panneau secondaire");
	T.Text(p2, T.FONT.small, T.C.mute, 16, 30, 220, 12):SetText("Texte secondaire, gris clair");
	local p3 = T.Frame(col, 140, 54, "inset"); p3:SetPoint("TOPLEFT", col, "TOPLEFT", 402, -100);
	T.Text(p3, T.FONT.small, T.C.dim, 12, 20, 116, 14, "CENTER"):SetText("En creux");

	T.SectionTitle(col, "Boutons : repos, survol, clic, choisi, inactif", 18, 160, COLW - 36);
	local states = { { "Repos", "secondary" }, { "Survol", "secondary", "hover" }, { "Clic", "secondary", "pressed" }, { "Choisi", "selected" }, { "Inactif", "secondary", "off" } };
	for i, d in ipairs(states) do
		local b = T.Button(col, d[1], 98, 30, d[2], function() end);
		b:SetPoint("TOPLEFT", col, "TOPLEFT", 18 + (i - 1) * 104, -186);
		if d[3] == "off" then T.SetEnabled(b, false); elseif d[3] then T.ForceState(b, d[3]); end
	end
	local specs = { { "Enregistrer", 150, "primary" }, { "Annuler", 120, "secondary" }, { "Supprimer", 120, "danger" }, { "OK", 60, "secondary" } };
	local bx = 18;
	for _, d in ipairs(specs) do
		local b = T.Button(col, d[1], d[2], 28, d[3], function() end);
		b:SetPoint("TOPLEFT", col, "TOPLEFT", bx, -222);
		bx = bx + d[2] + 8;
	end

	T.SectionTitle(col, "Champ de recherche", 18, 258, COLW - 36);
	local s = T.Search(col, 330, 32, "Rechercher un build, un sort, un objet…");
	s:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -284);

	T.SectionTitle(col, "Ligne de sort", 18, 322, COLW - 36);
	for i, d in ipairs(SAMPLE_ROWS) do
		local r = T.Row(col, COLW - 36, 38, i);
		r:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(348 + (i - 1) * 40));
		T.Text(r, T.FONT.section, T.C.gold, 12, 11, 22, 16):SetText(i .. ".");
		local ic = T.Icon(r, 30, 36, 4);
		T.SetIcon(ic, d[2], nil);
		T.Text(r, T.FONT.name, T.C.ivory, 76, 11, 200, 16):SetText(d[1]);
		local chip = T.Button(r, d[3] and "Bannir après" or "Conserver", 118, 26, d[3] and "selected" or "secondary", function() end);
		chip:SetPoint("TOPLEFT", r, "TOPLEFT", 290, -6);
		local seg = T.Segment(r, { "^", "v" }, 56, 26, function() end);
		seg:SetPoint("TOPLEFT", r, "TOPLEFT", 418, -6);
		local rm = T.Button(r, "x", 32, 26, "danger", function() end);
		rm:SetPoint("TOPLEFT", r, "TOPLEFT", 480, -6);
		T.SetSelected(r, i == 2);
	end

	T.SectionTitle(col, "Case d'équipement : pleine, vide, choisie", 18, 434, COLW - 36);
	local specs2 = { { "Principal 1", "filled", "Eye of the Splitting Sky: Enchaînement", "legendary" }, { "Alt. 1", "empty" }, { "Principal 2", "selected", "Anneau d'Accuria", "epic" } };
	for i, d in ipairs(specs2) do
		local c = T.Cell(col, 168, 58);
		c:SetPoint("TOPLEFT", col, "TOPLEFT", 18 + (i - 1) * 176, -460);
		c.role:SetText(d[1]);
		if d[2] == "empty" then
			c.name:SetText("+ Ajouter");
			c.name:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3]);
			c.remove:Hide();
			T.SetIcon(c.icon, nil, nil);
		else
			c.name:SetText(d[3]);
			local rc = T.C.rarity[d[4]];
			c.name:SetTextColor(rc[1], rc[2], rc[3]);
			T.SetIcon(c.icon, "INV_Jewelry_Necklace_AhnQiraj_03", d[4]);
		end
		T.SetCellState(c, d[2]);
		if i == 1 then lab.hoverCell = lab.hoverCell or c; end
	end

	T.SectionTitle(col, "Catalogue défilant et infobulle", 18, 524, COLW - 36);
	local hold = CreateFrame("Frame", nil, col);
	hold:SetWidth(300);
	hold:SetHeight(120);
	hold:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -550);
	hold:EnableMouseWheel(true);
	local rows, offset = {}, 0;
	local sb;
	local function render()
		local max = #CATALOG - 3;
		if offset > max then offset = max; end
		if offset < 0 then offset = 0; end
		for i = 1, 3 do
			local d = CATALOG[offset + i];
			local r = rows[i];
			r.name:SetText(T.Fit(d[1], 190, 12));
			local rc = T.C.rarity[d[3]];
			r.name:SetTextColor(rc[1], rc[2], rc[3]);
			r.sub:SetText(T.Fit(d[4], 190, 10));
			r.tag:SetText(d[5]);
			T.SetIcon(r.icon, d[2], d[3]);
		end
		sb.Sync(offset, max);
	end
	sb = T.ScrollBar(col, 120, function(o) offset = o; render(); end);
	sb:SetPoint("TOPLEFT", col, "TOPLEFT", 322, -550);
	hold:SetScript("OnMouseWheel", function(_, delta) offset = offset + (delta > 0 and -1 or 1); render(); end);
	for i = 1, 3 do
		local r = T.Row(hold, 300, 40, i);
		r:SetPoint("TOPLEFT", hold, "TOPLEFT", 0, -((i - 1) * 40));
		r.icon = T.Icon(r, 30, 6, 5);
		r.name = T.Text(r, T.FONT.name, T.C.ivory, 44, 5, 190, 16);
		r.sub = T.Text(r, T.FONT.small, T.C.mute, 44, 22, 190, 12);
		r.tag = T.Text(r, T.FONT.small, T.C.green, 0, 14, 60, 12, "RIGHT");
		r.tag:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -14);
		rows[i] = r;
	end
	render();
	local owner = T.Frame(col, 26, 26, "card");
	owner:SetPoint("TOPLEFT", col, "TOPLEFT", 346, -556);
	local tip = T.Tooltip(col, 190);
	tip:SetFrameStrata("FULLSCREEN_DIALOG");
	tip:SetFrameLevel(120);
	T.ShowTooltip(tip, owner, "Eye of the Splitting Sky: Enchaînement", { "Amulette légendaire | Guerrier", "Cibles : 4 · Dégâts : 0,5", "Cliquez pour le détail complet." });
	tip:ClearAllPoints();                       -- the sample stays inside its column (the real tooltip follows the pointer)
	tip:SetPoint("TOPLEFT", col, "TOPLEFT", 356, -552);
	return col;
end

-- strip drawing every texture file of the theme: a plain green / white square = that file did not load
local function mediaStrip(root)
	local names = {};
	for n in pairs(T.FILES) do names[#names + 1] = n; end
	table.sort(names);
	local x = 20;
	lab.swatches = {};
	for _, n in ipairs(names) do
		local f = CreateFrame("Frame", nil, root);
		f:SetWidth(34);
		f:SetHeight(34);
		f:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, 22);
		local bg = f:CreateTexture(nil, "BACKGROUND");
		bg:SetAllPoints(f);
		bg:SetTexture(0.25, 0.25, 0.30, 1);
		local t = f:CreateTexture(nil, "ARTWORK");
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1);
		t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1);
		t:SetTexture(T.Media(n));
		lab.swatches[n] = t;
		x = x + 40;
	end
	local fs = T.Text(root, T.FONT.tiny, T.C.mute, 20, 0, 900, 12);
	fs:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 20, 60);
	fs:SetText("Fichiers de texture (" .. #names .. ") : un carré vert ou blanc = fichier non chargé.   Dossier : " .. T.media);
	lab.mediaText = fs:GetText();
end

function lab:Build()
	if self.root then return; end
	T.mode = "textures";
	local root = T.Window(UIParent, W, H, "RebornPlannerThemeLabFrame");
	self.root = root;
	root:SetClampedToScreen(true);
	root:SetMovable(true);
	root:RegisterForDrag("LeftButton");
	root:SetScript("OnDragStart", function(f) f:StartMoving(); end);
	root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); end);
	local scale = math.min(1, (UIParent:GetHeight() - 24) / H, (UIParent:GetWidth() - 24) / W);
	root:SetScale(scale);
	root:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	local title = T.Text(root, T.FONT.window, T.C.gold, 24, 18, 760, 20);
	title:SetText("Reborn Build Planner — laboratoire Ultimate UI v3 (art fantasy)");
	local cap = T.Capabilities(root);
	local keys = { "SetGradientAlpha", "SetBackdrop", "SetHighlightTexture", "SetPushedTexture", "GetHighlightTexture", "SetFontString", "SetTextInsets", "GetStringHeight", "SetVertexColor", "SetTexCoord", "SetToplevel" };
	local parts = {};
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. ":" .. (cap[k] and "oui" or "NON"); end
	self.capabilities, self.capText = cap, table.concat(parts, "  ");
	local capfs = T.Text(root, T.FONT.tiny, T.C.mute, 24, 40, W - 150, 24);
	if capfs.SetWordWrap then capfs:SetWordWrap(true); end
	capfs:SetJustifyV("TOP");
	capfs:SetText("Ce client : " .. self.capText);
	local close = T.Button(root, "X", 32, 26, "danger", function() root:Hide(); end, "RebornPlannerThemeLabClose");
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -14);
	column(root, 18, "textures", "ULTIMATE v3 : blason, métal gravé, panneaux texturés");
	column(root, 18 + COLW + 24, "backdrop", "ANCIEN (0.4.2) : aplats unis, pour comparaison");
	T.mode = "textures";
	mediaStrip(root);
	root:Hide();
end

function lab:Toggle()
	self:Build();
	if self.root:IsShown() then self.root:Hide(); else self.root:Show(); end
end

-- frames drawn over the lab (strata / level) -- a one-off audit when asked, never polled
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 };
function lab:Over()
	local root, out = self.root, {};
	if not root or not EnumerateFrames then return out; end
	local my, myLevel = STRATA[root:GetFrameStrata()] or 0, root:GetFrameLevel();
	local f = EnumerateFrames();
	while f do
		if f ~= root and f:IsVisible() and f.GetFrameStrata then
			local p, mine = f, false;
			while p do if p == root then mine = true; break; end p = p:GetParent(); end
			local s = STRATA[f:GetFrameStrata()] or 0;
			if not mine and (s > my or (s == my and f:GetFrameLevel() > myLevel)) then
				local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom();
				local rl, rr, rt, rb = root:GetLeft(), root:GetRight(), root:GetTop(), root:GetBottom();
				if l and rl and l < rr and r > rl and b < rt and t > rb and (r - l) > 1 then
					out[#out + 1] = (f:GetName() or f:GetObjectType()) .. " (" .. f:GetFrameStrata() .. "/" .. f:GetFrameLevel() .. ")";
				end
			end
		end
		f = EnumerateFrames(f);
	end
	return out;
end

local function say(m) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe6c66aThemeLab|r " .. m); end end

SLASH_RBPLAB1 = "/rbplab";
SlashCmdList["RBPLAB"] = function(msg)
	msg = string.lower(msg or "");
	if msg == "diag" then
		lab:Build();
		say(lab.capText);
		say("fenêtre : strata " .. lab.root:GetFrameStrata() .. ", niveau " .. lab.root:GetFrameLevel() .. ", échelle " .. string.format("%.2f", lab.root:GetScale()));
		say("textures : " .. T.media);
		local over = lab:Over();
		say(#over == 0 and "aucune autre fenêtre visible au-dessus du labo" or ("au-dessus du labo (" .. #over .. ") : " .. table.concat(over, ", ", 1, math.min(#over, 8))));
	else
		lab:Toggle();
	end
end;
