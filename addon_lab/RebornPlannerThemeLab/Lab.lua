-- Visual lab (Lot 3.5, step B). /rbplab opens ONE window with the same sample screen built twice:
--   left  : the new components (Theme "regions": gradients + bronze borders + the client's own button states)
--   right : the 0.4.2 look ("backdrop": flat colours) for side-by-side comparison
-- plus a capability report of THIS client. Take screenshots of it: it is the only honest way to judge the rendering.
-- Nothing here touches the planner, a native addon or a saved variable except the lab's own flag.
local ADDON, ns = ...;
ns = ns or {};
local T = ns.Theme;
local lab = {};
ns.Lab = lab;

local W, H = 1180, 790;
local COLW = 560;

-- sample data (names are display text only)
local SAMPLE = {
	spells = { { "Visée", "Interface\\Icons\\Ability_Marksmanship", false }, { "Marque du chasseur", "Interface\\Icons\\Ability_Hunter_SniperShot", true } },
};

local function ico(name) return name; end

local function column(root, x, mode, heading)
	T.mode = mode;
	local col = T.Frame(root, COLW, H - 90, "window");
	col:SetPoint("TOPLEFT", root, "TOPLEFT", x, -64);
	local y = 14;
	local title = T.Text(col, T.FONT.window, T.C.ivory, 18, y, 360, 20);
	title:SetText("Reborn Build Planner");
	local sub = T.Text(col, T.FONT.small, T.C.mute, 18, y + 24, 400, 12);
	sub:SetText(heading);
	-- gradient direction check: must be LIGHT at the top
	local sw = T.Frame(col, 70, 30, "panel");
	sw:SetPoint("TOPRIGHT", col, "TOPRIGHT", -16, -14);
	local g = sw:CreateTexture(nil, "ARTWORK");
	g:SetPoint("TOPLEFT", sw, "TOPLEFT", 3, -3);
	g:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -3, 3);
	T.Gradient(g, { 0.9, 0.8, 0.5 }, { 0.1, 0.08, 0.04 });
	local gl = T.Text(col, T.FONT.tiny, T.C.mute, 0, 0, 160, 12, "RIGHT");
	gl:SetPoint("TOPRIGHT", col, "TOPRIGHT", -92, -22);
	gl:SetText("dégradé : clair en HAUT ?");

	y = 64;
	T.SectionTitle(col, "Panneaux", 18, y, COLW - 36);
	local p1 = T.Frame(col, 246, 54, "panel"); p1:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(y + 30));
	T.Text(p1, T.FONT.body, T.C.ivory, 12, 10, 220, 14):SetText("Panneau secondaire");
	T.Text(p1, T.FONT.small, T.C.mute, 12, 30, 220, 12):SetText("Texte secondaire, gris clair");
	local p2 = T.Frame(col, 246, 54, "inset"); p2:SetPoint("TOPLEFT", col, "TOPLEFT", 278, -(y + 30));
	T.Text(p2, T.FONT.body, T.C.ivory, 12, 10, 220, 14):SetText("Panneau en creux");
	T.Text(p2, T.FONT.small, T.C.dim, 12, 30, 220, 12):SetText("Texte désactivé");

	y = 150;
	T.SectionTitle(col, "Boutons : repos, sélection, désactivé", 18, y, COLW - 36);
	local labels = { { "Enregistrer", "primary" }, { "Annuler", "secondary" }, { "Supprimer", "danger" }, { "Tous *", "selected" }, { "Désactivé", "secondary", true } };
	for i, d in ipairs(labels) do
		local b = T.Button(col, d[1], 96, 28, d[2], function() end);
		b:SetPoint("TOPLEFT", col, "TOPLEFT", 18 + (i - 1) * 102, -(y + 30));
		if d[3] then T.SetEnabled(b, false); end
	end
	local hint = T.Text(col, T.FONT.tiny, T.C.mute, 18, y + 62, COLW - 36, 12);
	hint:SetText("Survolez et cliquez-maintenu : la teinte doit changer.");

	y = 224;
	T.SectionTitle(col, "Champ de recherche", 18, y, COLW - 36);
	local s = T.Search(col, 300, 30, "Rechercher un build, un sort, un objet…");
	s:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(y + 30));

	y = 292;
	T.SectionTitle(col, "Ligne de sort", 18, y, COLW - 36);
	for i, d in ipairs(SAMPLE.spells) do
		local r = T.Row(col, COLW - 36, 38, i);
		r:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(y + 28 + (i - 1) * 40));
		T.Text(r, T.FONT.section, T.C.gold, 10, 11, 20, 16):SetText(i .. ".");
		local ic = T.Icon(r, 28, 34, 5);
		T.SetIcon(ic, string.gsub(d[2], "^Interface\\Icons\\", ""), nil);
		T.Text(r, T.FONT.name, T.C.ivory, 72, 11, 220, 16):SetText(d[1]);
		local chip = T.Button(r, d[3] and "Bannir après" or "Conserver", 118, 24, d[3] and "selected" or "secondary", function() end);
		chip:SetPoint("TOPLEFT", r, "TOPLEFT", 296, -7);
		local seg = T.Segment(r, { "^", "v" }, 56, 24, function() end);
		seg:SetPoint("TOPLEFT", r, "TOPLEFT", 424, -7);
		local rm = T.Button(r, "x", 30, 24, "danger", function() end);     -- a stable zone of its own for removal
		rm:SetPoint("TOPLEFT", r, "TOPLEFT", 484, -7);
		T.SetSelected(r, i == 2);
	end

	y = 410;
	T.SectionTitle(col, "Case d'équipement : pleine, vide, choisie", 18, y, COLW - 36);
	local specs = { { "Principal 1", "filled", "Eye of the Splitting Sky: Enchaînement", "legendary" }, { "Alt. 1", "empty" }, { "Principal 2", "selected", "Anneau d'Accuria", "epic" } };
	for i, d in ipairs(specs) do
		local c = T.Cell(col, 164, 56);
		c:SetPoint("TOPLEFT", col, "TOPLEFT", 18 + (i - 1) * 172, -(y + 30));
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
		if i == 1 then lab.hoverCell = c; end
	end

	y = 504;
	T.SectionTitle(col, "Entrée de catalogue", 18, y, COLW - 36);
	local r = T.Row(col, COLW - 36, 44, 1);
	r:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(y + 28));
	local ic = T.Icon(r, 32, 8, 6);
	T.SetIcon(ic, "INV_Jewelry_Ring_15", "epic");
	local nm = T.Text(r, T.FONT.name, T.C.rarity.epic, 50, 7, 300, 16); nm:SetText("Anneau d'Accuria");
	T.Text(r, T.FONT.small, T.C.mute, 50, 26, 300, 12):SetText("Anneau · Épique");
	local tag = T.Text(r, T.FONT.small, T.C.green, 0, 15, 110, 12, "RIGHT"); tag:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -15); tag:SetText("En place");

	y = 584;
	T.SectionTitle(col, "Infobulle (cadre du thème, taille selon le contenu)", 18, y, COLW - 36);
	local owner = T.Frame(col, 24, 24, "card");
	owner:SetPoint("TOPLEFT", col, "TOPLEFT", 18, -(y + 30));
	local tip = T.Tooltip(col);
	tip:SetFrameStrata("DIALOG");
	T.ShowTooltip(tip, owner, "Eye of the Splitting Sky: Enchaînement", { "Amulette légendaire | Guerrier", "Ciblage : 4 · Dégâts : 0,5", "Cliquez pour le détail complet." });
	return col;
end

function lab:Build()
	if self.root then return; end
	local root = CreateFrame("Frame", "RebornPlannerThemeLabFrame", UIParent);
	self.root = root;
	root:SetWidth(W);
	root:SetHeight(H);
	root:SetFrameStrata("DIALOG");
	root:SetClampedToScreen(true);
	root:SetMovable(true);
	root:EnableMouse(true);
	root:RegisterForDrag("LeftButton");
	root:SetScript("OnDragStart", function(f) f:StartMoving(); end);
	root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); end);
	T.mode = "regions";
	T.Surface(root, "window");
	local scale = math.min(1, (UIParent:GetHeight() - 30) / H, (UIParent:GetWidth() - 30) / W);
	root:SetScale(scale);
	root:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	local title = T.Text(root, T.FONT.window, T.C.gold, 20, 14, 700, 20);
	title:SetText("Reborn Build Planner — laboratoire visuel (prototype 0.4.3)");
	local cap = T.Capabilities(root);
	local keys = { "SetGradientAlpha", "SetBackdrop", "SetHighlightTexture", "SetPushedTexture", "GetHighlightTexture", "SetFontString", "SetTextInsets", "GetStringHeight", "SetVertexColor", "SetTexCoord" };
	local parts = {};
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. ":" .. (cap[k] and "oui" or "NON"); end
	self.capabilities = cap;
	self.capText = table.concat(parts, "  ");
	local capfs = T.Text(root, T.FONT.tiny, T.C.mute, 20, 38, W - 160, 24);
	if capfs.SetWordWrap then capfs:SetWordWrap(true); end
	capfs:SetJustifyV("TOP");
	capfs:SetText("Ce client : " .. self.capText .. (T.gradientFlip and "   [dégradé inversé]" or ""));
	local close = T.Button(root, "X", 30, 24, "danger", function() root:Hide(); end, "RebornPlannerThemeLabClose");
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -14, -12);
	column(root, 16, "regions", "NOUVEAU : dégradés, bordures bronze, états natifs teintés");
	column(root, 16 + COLW + 18, "backdrop", "ACTUEL (0.4.2) : aplats unis, pour comparaison");
	T.mode = "regions";
	root:Hide();
end

function lab:Toggle()
	self:Build();
	if self.root:IsShown() then self.root:Hide(); else self.root:Show(); end
end

-- ------------------------------------------------------------------ commands
local function say(m) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe6c66aRebornPlannerThemeLab|r " .. m); end end

SLASH_RBPLAB1 = "/rbplab";
SlashCmdList["RBPLAB"] = function(msg)
	msg = string.lower(msg or "");
	if msg == "diag" then
		lab:Build();
		say(lab.capText);
		say("mode par défaut : " .. T.mode .. ", dégradé inversé : " .. tostring(T.gradientFlip));
	elseif msg == "flip" then
		RebornPlannerThemeLabDB = RebornPlannerThemeLabDB or {};
		RebornPlannerThemeLabDB.flip = not RebornPlannerThemeLabDB.flip;
		say("sens du dégradé " .. (RebornPlannerThemeLabDB.flip and "inversé" or "normal") .. " : tapez /reload puis /rbplab.");
	else
		lab:Toggle();
	end
end;

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= ADDON then return; end
	self:UnregisterEvent("ADDON_LOADED");
	T.gradientFlip = RebornPlannerThemeLabDB and RebornPlannerThemeLabDB.flip or false;
end);
