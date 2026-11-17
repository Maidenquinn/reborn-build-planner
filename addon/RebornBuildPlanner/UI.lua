-- Native window (Lot 3.2): ONE window, three persistent zones, a thin renderer over Controller.
--   left   : library (search, filters, sort, favourites, build list, create / duplicate / delete / follow / import)
--   centre : the whole editor on one page (six spells + banish-after marks, rings / trinkets / amulet slots with
--            alternatives, integrated catalogue with a visible target, advanced data) -- or the import / export forms
--   right  : inspector (details of the last selected spell or piece)
-- Standard 3.3.5a widgets only (the ones the native Reborn addons use). Every widget is created ONCE (on first
-- open) and reused: lists are fixed pools of rows driven by paging, nothing is created while the player works,
-- there is no OnUpdate. No clipboard API: export shows a selectable box (Ctrl+A, Ctrl+C), import is Ctrl+V.
local ADDON, ns = ...;
ns = ns or {};
local Locale, BM = ns.Locale, ns.BuildModel;
assert(Locale and BM and ns.Controller, "RebornBuildPlanner: UI.lua must load after Controller.lua");
local UI = {};
ns.UI = UI;
UI.__index = UI;

local L = function(s) return Locale.T(s); end

UI.WIDTH, UI.HEIGHT = 1120, 704;
local BODY_Y, BODY_H = 58, 618;
local LP_X, LP_W = 12, 262;          -- library
local CP_X, CP_W = 282, 578;         -- editor / import / export
local RP_X, RP_W = 868, 240;         -- inspector
local EW = 562;                      -- usable width inside the centre panel
local COLOR = { info = { 0.4, 1, 0.5 }, warn = { 1, 0.82, 0.2 }, error = { 1, 0.35, 0.3 } };
-- button label colours by role: the main action stands out, secondary ones are quiet (the text always says what it is)
local ROLE = { primary = "8cff8c", quiet = "b4b4b4", warn = "ffd24d", danger = "ff8a80" };
local TONEHEX = { ok = "7dff7d", warn = "ffd24d", dim = "b4b4b4" };
local BG = { r = 0.05, g = 0.05, b = 0.08 };
local PANEL = { 0.10, 0.10, 0.14, 1 };

-- ------------------------------------------------------------------ widget helpers
local function fitText(s, px, size)
	local max = math.floor(px / ((size or 12) * 0.62));   -- a little wider than the lint's 0.6: truncate early
	local n, i, len = 0, 1, #s;
	while i <= len do
		local b = string.byte(s, i);
		i = i + ((b < 0x80) and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4)));
		n = n + 1;
		if n > max then
			local k, c = 1, 0;
			while c < max - 3 and k <= len do
				local bb = string.byte(s, k);
				k = k + ((bb < 0x80) and 1 or (bb < 0xE0 and 2 or (bb < 0xF0 and 3 or 4)));
				c = c + 1;
			end
			return string.sub(s, 1, k - 1) .. "...";
		end
	end
	return s;
end
UI.FitText = fitText;

local function text(parent, x, y, w, font, justify, size)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight");
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	fs:SetWidth(w);
	fs:SetHeight(size or 14);
	fs:SetJustifyH(justify or "LEFT");
	if fs.SetWordWrap then fs:SetWordWrap(false); end
	return fs;
end

local function wrapped(parent, x, y, w, h, font)
	local fs = text(parent, x, y, w, font, "LEFT", h);
	if fs.SetWordWrap then fs:SetWordWrap(true); end
	fs:SetJustifyV("TOP");
	return fs;
end

local function button(parent, label, w, h, x, y, onClick, name)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate");
	b:SetWidth(w);
	b:SetHeight(h or 24);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	b:SetText(label);
	b:SetScript("OnClick", function(self) if onClick then onClick(self); end end);
	return b;
end

-- label with the role colour when enabled; the plain label is kept in b.baseLabel
local function paint(b)
	local label = b.baseLabel or "";
	local shown = label;
	if b.role and label ~= "" and b.enabledFlag ~= false then shown = "|cff" .. ROLE[b.role] .. label .. "|r"; end
	if b.painted ~= shown then b.painted = shown; b:SetText(shown); end
end

local function setLabel(b, label)
	b.baseLabel = label;
	paint(b);
end

local function enable(b, on)
	if on then b:Enable(); else b:Disable(); end
	b.enabledFlag = on and true or false;
	paint(b);
end

local function setShown(f, on)
	if on then f:Show(); else f:Hide(); end
end

-- invisible button over the icon + name of a row: carries hover and click without capturing the row's real buttons
local function hitArea(parent, x, y, w, h)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(w);
	b:SetHeight(h);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	return b;
end

local function edit(parent, w, x, y, onChange, name, maxLetters)
	local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate");
	e:SetWidth(w);
	e:SetHeight(22);
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	e:SetAutoFocus(false);
	e:SetFontObject("ChatFontNormal");
	if e.SetTextInsets then e:SetTextInsets(6, 6, 0, 0); end      -- text centred in the box, off the border
	if maxLetters then e:SetMaxLetters(maxLetters); end
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnTextChanged", function(self, user) if user and onChange then onChange(self:GetText()); end end);
	return e;
end

local function setEdit(e, value)
	if e:GetText() ~= value then e:SetText(value); end
end

-- multi-line box inside a standard scroll frame (the pattern of FieldKit's copy window)
local function multiline(parent, name, w, h, x, y, onChange, readOnlyText)
	local sf = CreateFrame("ScrollFrame", name .. "Scroll", parent, "UIPanelScrollFrameTemplate");
	sf:SetWidth(w - 26);
	sf:SetHeight(h);
	sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	local e = CreateFrame("EditBox", name, sf);
	e:SetWidth(w - 30);
	e:SetHeight(h);
	e:SetMultiLine(true);
	e:SetAutoFocus(false);
	e:SetFontObject("ChatFontNormal");
	e:SetMaxLetters(60000);
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnTextChanged", function(self, user) if user and onChange then onChange(self:GetText()); end end);
	if readOnlyText then
		e:SetScript("OnTextChanged", function(self, user)
			if user and self.fixed and self:GetText() ~= self.fixed then self:SetText(self.fixed); self:HighlightText(); end
		end);
		e:SetScript("OnEditFocusGained", function(self) self:HighlightText(); end);
	end
	sf:SetScrollChild(e);
	e.scroll = sf;
	return e;
end

local function cycler(parent, x, y, w, onPrev, onNext, font)
	local c = {};
	c.prev = button(parent, "<", 28, 22, x, y, onPrev);
	c.label = text(parent, x + 34, y + 4, w - 68, font or "GameFontNormal", "CENTER");
	c.next = button(parent, ">", 28, 22, x + w - 28, y, onNext);
	return c;
end

local function pager(parent, x, y, onPrev, onNext)
	local p = {};
	p.prev = button(parent, "<", 28, 22, x, y, onPrev);
	p.label = text(parent, x + 34, y + 4, 120, "GameFontNormal", "CENTER");
	p.next = button(parent, ">", 28, 22, x + 162, y, onNext);
	return p;
end

-- a framed panel (backdrop colour = contrast against the window)
local function panel(parent, name, x, y, w, h)
	local f = CreateFrame("Frame", name, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } });
	f:SetBackdropColor(PANEL[1], PANEL[2], PANEL[3], PANEL[4]);
	f:SetBackdropBorderColor(0.45, 0.38, 0.2, 1);
	return f;
end

local function fill(f, r, g, b, a)
	local t = f:CreateTexture(nil, "BACKGROUND");
	t:SetAllPoints(f);
	t:SetTexture(r, g, b, a or 1);
	return t;
end

local function setIcon(tex, icon)
	if icon and icon ~= "" then
		tex:SetTexture("Interface\\Icons\\" .. icon);
		tex:Show();
	else
		tex:Hide();
	end
end

-- ------------------------------------------------------------------ tooltips (hover only, one shared GameTooltip)
local TONE = { ok = { 0.5, 1, 0.5 }, warn = { 1, 0.82, 0.2 }, dim = { 0.7, 0.7, 0.7 } };

-- Draws tooltip data { title, icon, spellId, lines } over `owner`. For a spell with a game id the game's own spell
-- tooltip comes first (read once, on hover, never kept); our lines follow. No value is invented here.
function UI:ShowTip(owner, d)
	local tt = GameTooltip;
	if not d or not tt then return; end
	tt:SetOwner(owner, "ANCHOR_RIGHT");
	if tt.ClearLines then tt:ClearLines(); end
	local fromGame = false;
	if d.spellId and tt.SetHyperlink then
		pcall(tt.SetHyperlink, tt, "spell:" .. d.spellId);
		fromGame = tt.NumLines ~= nil and tt:NumLines() > 0;
		if fromGame then tt:AddLine(" "); end
	end
	if not fromGame then
		local head = (d.icon and d.icon ~= "") and ("|TInterface\\Icons\\" .. d.icon .. ":16|t ") or "";
		tt:AddLine(head .. d.title, 1, 0.82, 0, true);
		if d.spellId then tt:AddLine(L("Detailed effect unavailable"), 0.7, 0.7, 0.7, true); end
	end
	for _, ln in ipairs(d.lines or {}) do
		local col = TONE[ln.tone] or { 1, 1, 1 };
		tt:AddLine(ln.text, col[1], col[2], col[3], true);
	end
	tt:Show();
	self.tipOwner = owner;
end

function UI:HideTip(owner)
	if self.tipOwner and (owner == nil or owner == self.tipOwner) then
		if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self.tipOwner then GameTooltip:Hide(); end
		self.tipOwner = nil;
	end
end

-- getData(frame) -> tooltip data or nil. Hover only: no polling, no OnUpdate.
function UI:Hover(frame, getData)
	frame:SetScript("OnEnter", function(f) local d = getData(f); if d then self:ShowTip(f, d); end end);
	frame:SetScript("OnLeave", function(f) self:HideTip(f); end);
	frame:SetScript("OnHide", function(f) self:HideTip(f); end);
end

-- The game's own text of a spell (description, effect), read ONCE per spell on selection through the shared tooltip
-- and cached: no hidden tooltip, no scan, no timer. Returns a list of lines or nil when the game says nothing.
function UI:GameText(id)
	self.gameText = self.gameText or {};
	local c = self.gameText[id];
	if c ~= nil then return c or nil; end
	local tt = GameTooltip;
	if not tt or not tt.SetHyperlink or not tt.SetOwner then self.gameText[id] = false; return nil; end
	tt:SetOwner(UIParent, "ANCHOR_NONE");
	if tt.ClearLines then tt:ClearLines(); end
	pcall(tt.SetHyperlink, tt, "spell:" .. id);
	local lines = {};
	local n = tt.NumLines and tt:NumLines() or 0;
	for i = 1, n do
		local fs = _G["GameTooltipTextLeft" .. i];
		local t = fs and fs.GetText and fs:GetText();
		if type(t) == "string" and t ~= "" then lines[#lines + 1] = t; end
	end
	tt:Hide();
	self.tipOwner = nil;
	self.gameText[id] = #lines > 0 and lines or false;
	return #lines > 0 and lines or nil;
end

-- static help shown on hover (title + lines, English keys)
local HELP = {
	toggle = { "Keep or banish after acquisition",
		{ "Keep: you want this spell and will keep building on it.",
			"Banish after acquisition: once you own it, you plan to banish it to concentrate on the others.",
			"Planning only: the addon never banishes anything and does not know when the game allows it.",
			"Up to 3 spells can be marked." } },
	avoid = { "Avoid list",
		{ "Spells you would banish whenever the game offers them (the official planner's banish list).",
			"Different from banishing a spell you are still acquiring: use the button on the left for that." } },
	convert = { "Wanted and avoided at once",
		{ "This spell is in both lists, which an older version treated as a conflict.",
			"If you meant \"banish after acquisition\", press this button. Nothing changes until you do." } },
	slots = { "Main and alternative slots",
		{ "Main slots: the pieces you want to use first.",
			"Alternatives: fallbacks if a main piece is not offered.",
			"Empty positions are kept as they are." } },
	star = { "Favourite",
		{ "Favourite builds come first in the list and in the Favourites filter." } },
};

function UI:HelpLines(list)
	local out = {};
	for i, s in ipairs(list) do out[i] = { text = L(s), tone = i == 1 and nil or "dim" }; end
	return out;
end

local function helpData(self, key)
	return { title = L(HELP[key][1]), lines = self:HelpLines(HELP[key][2]) };
end

-- ------------------------------------------------------------------ construction
function UI.New(controller, env)
	local self = setmetatable({ c = controller, env = env or ns, built = false }, UI);
	controller:Subscribe(function() self:Refresh(); end);
	return self;
end

function UI:Frame() return self.root; end
function UI:IsShown() return self.root ~= nil and self.root:IsShown(); end

function UI:Build()
	if self.built then return; end
	self.built = true;
	local c = self.c;
	local root = CreateFrame("Frame", "RebornBuildPlannerFrame", UIParent);
	self.root = root;
	root:SetWidth(UI.WIDTH);
	root:SetHeight(UI.HEIGHT);
	root:SetFrameStrata("DIALOG");        -- above the game's HUD texts, below the modal
	root:SetFrameLevel(20);
	root:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	root:SetBackdropColor(BG.r, BG.g, BG.b, 1);
	root:SetBackdropBorderColor(0.7, 0.6, 0.3, 1);
	root:SetClampedToScreen(true);
	root:SetMovable(true);
	root:EnableMouse(true);
	root:RegisterForDrag("LeftButton");
	root:SetScript("OnDragStart", function(f) f:StartMoving(); end);
	root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); self:SavePosition(); end);
	root:SetScript("OnHide", function() self:HideTip(); self:SyncEscape(); end);
	root:Hide();

	self.title = text(root, 18, 12, 300, "GameFontNormalLarge", "LEFT", 18);
	local close = CreateFrame("Button", "RebornBuildPlannerClose", root, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, -6);
	close:SetScript("OnClick", function() self:RequestClose(); end);
	self.nav = {
		import = button(root, "", 96, 24, 330, 8, function() c:SetView("import"); end),
		export = button(root, "", 96, 24, 430, 8, function()
			local e = c:Editor();
			if e then c:PrepareExport(e.id, "draft"); c:SetView("export");
			elseif c.state.export then c:SetView("export"); end
		end),
	};
	self.nav.import.role, self.nav.export.role = "quiet", "quiet";
	self.sizeMinus = button(root, "", 84, 24, 880, 8, function() self:Rescale(-0.1); end);
	self.sizePlus = button(root, "", 84, 24, 968, 8, function() self:Rescale(0.1); end);
	self.sizeMinus.role, self.sizePlus.role = "quiet", "quiet";
	self.banner = text(root, 18, 38, 1080, "GameFontNormal", "LEFT");
	self.banner:SetTextColor(1, 0.35, 0.3);
	self.msg = text(root, 18, 684, 860, "GameFontNormal", "LEFT");
	self.undoBtn = button(root, "", 200, 22, 900, 679, function() c:UndoDelete(); end);
	self.undoBtn.role = "warn";

	self.leftPanel = panel(root, "RebornBuildPlannerLibrary", LP_X, BODY_Y, LP_W, BODY_H);
	self.centre = panel(root, "RebornBuildPlannerEditor", CP_X, BODY_Y, CP_W, BODY_H);
	self.rightPanel = panel(root, "RebornBuildPlannerInspector", RP_X, BODY_Y, RP_W, BODY_H);
	local function mode(name)
		local f = panel(root, "RebornBuildPlanner" .. name, CP_X, BODY_Y, CP_W, BODY_H);
		f:Hide();
		return f;
	end
	self.views = { editor = self.centre, import = mode("Import"), export = mode("Export") };
	self:BuildLibrary(self.leftPanel);
	self:BuildEditor(self.centre);
	self:BuildInspector(self.rightPanel);
	self:BuildImport(self.views.import);
	self:BuildExport(self.views.export);
	self:BuildModal();
end

-- ------------------------------------------------------------------ library (left)
local function dateText(ts)
	if type(ts) ~= "number" then return nil; end
	if type(date) == "function" then
		local ok, s = pcall(date, "%d/%m/%Y", ts);
		if ok and type(s) == "string" then return s; end
	end
	return nil;
end

function UI:BuildLibrary(v)
	local c = self.c;
	local lib = {};
	self.lib = lib;
	lib.searchLabel = text(v, 8, 10, 90, "GameFontNormal");
	lib.search = edit(v, 154, 100, 6, function(t) c:SetLibSearch(t); end, "RebornBuildPlannerLibSearch");
	lib.filters = {
		all = button(v, "", 56, 22, 8, 34, function() c:SetFilter("all"); end),
		favorites = button(v, "", 104, 22, 68, 34, function() c:SetFilter("favorites"); end),
		recent = button(v, "", 78, 22, 176, 34, function() c:SetFilter("recent"); end),
	};
	lib.classCycle = cycler(v, 8, 62, 246, function() c:CycleClassFilter(-1); end, function() c:CycleClassFilter(1); end, "GameFontNormalSmall");
	lib.sortCycle = cycler(v, 8, 88, 246, function() c:CycleSort(-1); end, function() c:CycleSort(1); end, "GameFontNormalSmall");
	lib.rows = {};
	for i = 1, ns.Controller.LIB_PAGE do
		local r = CreateFrame("Button", "RebornBuildPlannerRow" .. i, v);
		r:SetWidth(246);
		r:SetHeight(34);
		r:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -(118 + (i - 1) * 36));
		r.base = fill(r, i % 2 == 0 and 0.13 or 0.15, i % 2 == 0 and 0.13 or 0.15, i % 2 == 0 and 0.18 or 0.2, 1);
		r.bg = r:CreateTexture(nil, "BORDER");
		r.bg:SetAllPoints(r);
		r.bg:SetTexture(0.2, 0.4, 0.8, 0.5);
		r.bg:Hide();
		r.name = text(r, 34, 3, 150, "GameFontHighlight");
		r.tag = text(r, 186, 4, 58, "GameFontNormalSmall", "RIGHT");
		r.sub = text(r, 34, 19, 210, "GameFontNormalSmall");
		r.star = button(r, "", 26, 22, 4, 6, function() local id = r.rowId; if id then c:ToggleFavorite(id); end end);
		r:SetScript("OnClick", function(f) if f.rowId then self:ClickRow(f); end end);
		self:Hover(r.star, function() return helpData(self, "star"); end);
		lib.rows[i] = r;
	end
	lib.empty = wrapped(v, 12, 160, 238, 80, "GameFontNormal");
	lib.pager = pager(v, 8, 482, function() c:SetPage(c.state.page - 1); end, function() c:SetPage(c.state.page + 1); end);
	lib.create = button(v, "", 246, 28, 8, 512, function() self:AskCreate(); end);
	lib.dup = button(v, "", 80, 24, 8, 546, function() local r = c:Selected(); if r then c:Duplicate(r.id); end end);
	lib.delete = button(v, "", 80, 24, 92, 546, function() local r = c:Selected(); if r then self:AskDelete(r); end end);
	lib.follow = button(v, "", 80, 24, 176, 546, function()
		local r = c:Selected();
		if r then if r.active then c:Deactivate(r.id); else c:Activate(r.id); end end
	end);
	lib.rename = button(v, "", 76, 24, 8, 576, function() local r = c:Selected(); if r then self:AskRename(r); end end);
	lib.importBtn = button(v, "", 76, 24, 88, 576, function() c:SetView("import"); end);
	lib.trashBtn = button(v, "", 88, 24, 168, 576, function() c:ShowTrash(not c.state.trashMode); end);
	lib.restore = button(v, "", 160, 24, 8, 546, function() local r = c:Selected(); if r then c:Restore(r.id); end end);
	lib.create.role, lib.follow.role, lib.restore.role = "primary", "primary", "primary";
	lib.dup.role, lib.rename.role, lib.importBtn.role, lib.trashBtn.role = "quiet", "quiet", "quiet", "quiet";
	lib.delete.role = "danger";
end

-- a click opens the build in the editor; unsaved changes elsewhere ask first (Save / Discard / Keep editing)
function UI:ClickRow(f)
	local c = self.c;
	if f.trashed then c:Select(f.rowId); return; end
	local cur = c:Editor();
	if cur and cur.id == f.rowId then c:SetView("editor"); return; end
	self:OpenEditor(f.rowId);
end

function UI:RefreshLibrary()
	local c, lib = self.c, self.lib;
	local st = c.state;
	local ro = c:ReadOnly();
	lib.searchLabel:SetText(L("Search:"));
	setEdit(lib.search, st.search or "");
	local filter = c:Filter();
	for name, b in pairs(lib.filters) do
		local label = name == "all" and L("All") or (name == "favorites" and L("Favourites") or L("Recent"));
		b.role = (name == filter) and "warn" or "quiet";
		setLabel(b, label .. (name == filter and " *" or ""));
		setShown(b, not st.trashMode);
	end
	lib.classCycle.label:SetText(L("Class:") .. " " .. (st.classFilter and c:ClassName(st.classFilter) or L("All classes")));
	local sortNames = { name = L("Name"), used = L("Last used"), modified = L("Last modified") };
	lib.sortCycle.label:SetText(L("Sort:") .. " " .. sortNames[c:Sort()]);
	setShown(lib.sortCycle.prev, not st.trashMode); setShown(lib.sortCycle.next, not st.trashMode); setShown(lib.sortCycle.label, not st.trashMode);
	local rows = c:PageRows();
	local sel = st.selectedId;
	local edId = st.editor and st.editor.id;
	for i, r in ipairs(lib.rows) do
		local d = rows[i];
		if d then
			r.rowId, r.trashed = d.id, d.trashed;
			r.name:SetText(fitText(d.name ~= "" and d.name or L("(no name)"), 150, 12));
			local s = "";
			if d.trashed then s = L("Deleted");
			elseif d.active then s = L("Active");
			elseif d.clean == false then s = L("Repair"); end
			r.tag:SetText(s);
			local when = "";
			if not d.trashed then
				local key = c:Sort() == "used" and d.used or d.modified;
				local ds = dateText(key);
				if ds then when = " | " .. ds; end
			end
			r.sub:SetText(fitText(d.className .. when, 210, 10));
			r.star.role = d.fav and "warn" or "quiet";
			setLabel(r.star, d.fav and "*" or "-");
			setShown(r.star, not d.trashed);
			if d.id == sel or d.id == edId then r.bg:Show(); else r.bg:Hide(); end
			r:Show();
		else
			r.rowId = nil;
			r:Hide();
		end
	end
	local any = rows[1] ~= nil;
	setShown(lib.empty, not any);
	if not any then
		local total = c:Handle() and c:Handle():Counts().builds or 0;
		if st.trashMode then
			lib.empty:SetText(L("The trash is empty. A deleted build stays here until the trash is full (20 builds)."));
		elseif total == 0 then
			lib.empty:SetText(L("No build yet. Create one, or import a Reborn code."));
		else
			lib.empty:SetText(L("No build matches. Change the search or the filters."));
		end
	end
	lib.pager.label:SetText(string.format(L("Page %d/%d"), st.page, c:PageCount()));
	enable(lib.pager.prev, st.page > 1);
	enable(lib.pager.next, st.page < c:PageCount());
	local r = c:Selected();
	local inTrash = st.trashMode;
	for _, b in ipairs({ lib.dup, lib.delete, lib.follow, lib.rename, lib.importBtn }) do setShown(b, not inTrash); end
	setShown(lib.restore, inTrash);
	setShown(lib.create, not inTrash);
	setLabel(lib.dup, L("Duplicate"));
	setLabel(lib.delete, L("Delete"));
	setLabel(lib.rename, L("Rename"));
	setLabel(lib.follow, (r and r.active) and L("Unfollow") or L("Follow"));
	setLabel(lib.restore, L("Restore"));
	setLabel(lib.create, L("Create a build"));
	setLabel(lib.importBtn, L("Import"));
	setLabel(lib.trashBtn, st.trashMode and L("Back") or L("Trash"));
	local has = r ~= nil;
	enable(lib.dup, has and not ro);
	enable(lib.rename, has and not ro);
	enable(lib.delete, has and not ro);
	enable(lib.follow, has and not ro);
	enable(lib.restore, has and not ro);
	enable(lib.create, not ro);
end

-- ------------------------------------------------------------------ editor (centre)
local EQUIP_Y = { rings = 296, trinkets = 338, amulets = 380 };
local EQUIP_GROUPS = { "rings", "trinkets", "amulets" };
local CELL_W, CELL_H, CELL_X0 = 120, 38, 74;

function UI:BuildEditor(v)
	local c = self.c;
	local ed = {};
	self.ed = ed;
	ed.empty = wrapped(v, 40, 200, EW - 60, 80, "GameFontNormalLarge");
	-- header: name, class, status, actions
	ed.nameLabel = text(v, 8, 12, 50, "GameFontNormal");
	ed.name = edit(v, 230, 58, 8, function(t) c:SetName(t); end, "RebornBuildPlannerName");
	ed.class = text(v, 294, 13, 130, "GameFontNormal");
	ed.fav = button(v, "", 132, 24, 430, 7, function() local e = c:Editor(); if e then c:ToggleFavorite(e.id); end end);
	ed.save = button(v, "", 96, 24, 8, 36, function() c:Save(); end);
	ed.follow = button(v, "", 176, 24, 108, 36, function() c:SaveAndFollow(); end);
	ed.revert = button(v, "", 124, 24, 288, 36, function() c:Revert(); end);
	ed.status = text(v, 416, 34, 154, "GameFontNormal", "RIGHT", 28);
	if ed.status.SetWordWrap then ed.status:SetWordWrap(true); end
	ed.save.role, ed.follow.role = "primary", "primary";
	ed.revert.role, ed.fav.role = "quiet", "quiet";
	-- stages and advanced toggle
	ed.phaseInfo = text(v, 8, 68, 236, "GameFontNormal");
	ed.addPhases = button(v, "", 130, 22, 248, 64, function() c:RevealPhases(); end);
	ed.addPhases.role = "quiet";
	ed.phaseTabs = {};
	for p = 1, 4 do
		ed.phaseTabs[p] = button(v, "", 92, 22, 8 + (p - 1) * 94, 64, function() c:SetPhase(p); end);
	end
	ed.adv = button(v, "", 170, 22, 392, 64, function() c:ToggleAdvanced(); end);
	ed.adv.role = "quiet";
	-- spells
	ed.spellHead = text(v, 8, 92, 280, "GameFontNormal");
	ed.summary = text(v, 292, 92, 270, "GameFontNormal", "RIGHT");
	ed.spells = {};
	for i = 1, 6 do
		local r = { frame = CreateFrame("Frame", nil, v) };
		local y = 112 + (i - 1) * 25;
		r.frame:SetWidth(EW);
		r.frame:SetHeight(23);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -y);
		r.bg = fill(r.frame, 0.14, 0.14, 0.2, 1);
		r.num = text(r.frame, 4, 5, 20, "GameFontNormal");
		r.icon = r.frame:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(18); r.icon:SetHeight(18);
		r.icon:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 24, -2);
		r.name = text(r.frame, 48, 5, 220, "GameFontHighlight");
		r.hit = hitArea(r.frame, 22, 0, 248, 23);
		r.add = button(r.frame, "", 190, 21, 48, 1, function() c:AddSpellTarget(); end);
		r.tog = button(r.frame, "", 108, 21, 276, 1, function() local k = r.key; if k then c:ToggleBanishAfter(k); end end);
		r.up = button(r.frame, "", 44, 21, 388, 1, function() c:MoveSpell(i, -1); end);
		r.down = button(r.frame, "", 46, 21, 434, 1, function() c:MoveSpell(i, 1); end);
		r.del = button(r.frame, "", 64, 21, 482, 1, function() local k = r.key; if k then c:RemoveSpell(k); end end);
		r.add.role, r.up.role, r.down.role, r.del.role = "quiet", "quiet", "quiet", "quiet";
		r.hit:SetScript("OnClick", function() if r.key then c:Inspect("spell", r.key); end end);
		self:Hover(r.hit, function() return r.key and c:TooltipData("spell", r.key) or nil; end);
		self:Hover(r.tog, function() return r.key and helpData(self, "toggle") or nil; end);
		ed.spells[i] = r;
	end
	-- equipment: one row per kind, main slots first then alternatives, all visible
	ed.equipHead = text(v, 8, 276, EW, "GameFontNormal");
	ed.groups = {};
	for _, g in ipairs(EQUIP_GROUPS) do
		local grp = { label = text(v, 8, EQUIP_Y[g] + 12, 64, "GameFontNormal"), cells = {} };
		for j = 1, BM.LIMITS[g] do
			local cell = CreateFrame("Button", nil, v);
			cell:SetWidth(CELL_W);
			cell:SetHeight(CELL_H);
			cell:SetPoint("TOPLEFT", v, "TOPLEFT", 8 + CELL_X0 + (j - 1) * (CELL_W + 2), -EQUIP_Y[g]);
			cell.base = fill(cell, 0.14, 0.14, 0.2, 1);
			cell.sel = cell:CreateTexture(nil, "BORDER");
			cell.sel:SetAllPoints(cell);
			cell.sel:SetTexture(0.2, 0.4, 0.8, 0.55);
			cell.sel:Hide();
			cell.role = text(cell, 4, 2, 90, "GameFontNormalSmall");
			cell.icon = cell:CreateTexture(nil, "ARTWORK");
			cell.icon:SetWidth(22); cell.icon:SetHeight(22);
			cell.icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 3, -13);
			cell.name = wrapped(cell, 28, 14, 90, 24, "GameFontHighlightSmall");
			cell.x = button(cell, "", 20, 18, 98, 1, function() c:ClearSlot(g, j); end);
			cell.x.role = "quiet";
			cell:SetScript("OnClick", function() c:SelectSlot(g, j); end);
			self:Hover(cell, function()
				local k = cell.key;
				local d = k and k ~= "" and c:TooltipData(g == "amulets" and "amulet" or "jewel", k) or nil;
				if d then
					d.lines[#d.lines + 1] = { text = L(HELP.slots[2][1]) .. " " .. L(HELP.slots[2][2]), tone = "dim" };
					return d;
				end
				return helpData(self, "slots");
			end);
			grp.cells[j] = cell;
		end
		ed.groups[g] = grp;
	end
	-- catalogue (integrated) with a visible target
	ed.catKinds = {
		spells = button(v, "", 90, 22, 8, 428, function() c:SetCatalog("spells"); end),
		rings = button(v, "", 90, 22, 100, 428, function() c:SetCatalog("rings"); end),
		trinkets = button(v, "", 90, 22, 192, 428, function() c:SetCatalog("trinkets"); end),
		amulets = button(v, "", 94, 22, 284, 428, function() c:SetCatalog("amulets"); end),
	};
	ed.catSearchLabel = text(v, 382, 432, 76, "GameFontNormalSmall");
	ed.catSearch = edit(v, 100, 458, 428, function(t) c:SetSearch(t); end, "RebornBuildPlannerSearch");
	ed.target = text(v, 8, 456, EW, "GameFontNormal");
	ed.cat = { rows = {} };
	for i = 1, ns.Controller.CATALOG_PAGE do
		local y = 476 + (i - 1) * 24;
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(EW);
		r.frame:SetHeight(22);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -y);
		r.bg = fill(r.frame, 0.12, 0.12, 0.17, 1);
		r.icon = r.frame:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(18); r.icon:SetHeight(18);
		r.icon:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 2, -2);
		r.name = text(r.frame, 24, 4, 222, "GameFontHighlight");
		r.info = text(r.frame, 250, 6, 150, "GameFontNormalSmall");
		r.hit = hitArea(r.frame, 0, 0, 248, 22);
		r.a = button(r.frame, "", 76, 22, 406, 0, nil);
		r.b = button(r.frame, "", 70, 22, 486, 0, nil);
		r.a.role, r.b.role = "primary", "quiet";
		r.hit:SetScript("OnClick", function() if r.tipKey then c:Inspect(r.tipKind, r.tipKey); end end);
		self:Hover(r.hit, function() return r.tipKey and c:TooltipData(r.tipKind, r.tipKey) or nil; end);
		self:Hover(r.b, function(f) return f.help and helpData(self, "avoid") or nil; end);
		ed.cat.rows[i] = r;
	end
	ed.cat.pager = pager(v, 8, 598, function() c:SetEditorPage(c:Editor().page - 1); end, function() c:SetEditorPage(c:Editor().page + 1); end);
	ed.cat.hint = text(v, 210, 602, 350, "GameFontNormalSmall");
	-- advanced block (replaces the catalogue area when open)
	local nt = {};
	ed.nt = nt;
	nt.notesLabel = text(v, 8, 430, 380, "GameFontNormal");
	nt.counter = text(v, 400, 430, 160, "GameFontNormalSmall", "RIGHT");
	nt.notes = multiline(v, "RebornBuildPlannerNotes", EW, 52, 8, 450, function(t) c:SetNotes(t); end);
	nt.linkLabel = text(v, 8, 512, 50, "GameFontNormal");
	nt.link = edit(v, 230, 58, 508, function(t) c:SetLink(t); end, "RebornBuildPlannerLink");
	nt.talentsLabel = text(v, 300, 512, 66, "GameFontNormal");
	nt.talents = edit(v, 190, 370, 508, function(t) c:SetTalents(t); end, "RebornBuildPlannerTalents");
	nt.labelLabel = text(v, 8, 540, 120, "GameFontNormal");
	nt.label = edit(v, 150, 130, 536, function(t) c:SetLabel(t); end, "RebornBuildPlannerLabel");
	nt.warn = text(v, 300, 540, 260, "GameFontNormalSmall", "LEFT", 14);
	nt.warn:SetTextColor(1, 0.82, 0.2);
	nt.avoidHead = text(v, 8, 564, EW, "GameFontNormalSmall");
	nt.avoid = {};
	for i = 1, 3 do
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(180);
		r.frame:SetHeight(22);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 8 + (i - 1) * 190, -580);
		r.bg = fill(r.frame, 0.12, 0.12, 0.17, 1);
		r.name = text(r.frame, 4, 5, 80, "GameFontHighlightSmall");
		r.hit = hitArea(r.frame, 0, 0, 86, 22);
		r.conv = button(r.frame, "", 66, 20, 88, 1, function() local k = r.key; if k then c:ConvertBanishToAfter(k); end end);
		r.del = button(r.frame, "", 24, 20, 154, 1, function() local k = r.key; if k then c:RemoveBanish(k); end end);
		r.conv.role, r.del.role = "primary", "quiet";
		self:Hover(r.hit, function() return r.key and c:TooltipData("spell", r.key) or nil; end);
		self:Hover(r.conv, function() return helpData(self, "convert"); end);
		nt.avoid[i] = r;
	end
	nt.kept = text(v, 8, 608, EW, "GameFontNormalSmall");
end

local function catalogRow(r, e, a, b)
	if not e then r.frame:Hide(); r.tipKey = nil; return; end
	r.frame:Show();
	r.name:SetText(fitText(e.name, 222, 12));
	setIcon(r.icon, e.icon);
	if e.state == "wanted" or e.state == "placed" then r.bg:SetTexture(0.16, 0.2, 0.3, 1); else r.bg:SetTexture(0.12, 0.12, 0.17, 1); end
	a(r, e);
	b(r, e);
end

local RARITY_L = { common = "Common", uncommon = "Uncommon", rare = "Rare", epic = "Epic", legendary = "Legendary" };

function UI:RefreshEditor()
	local c, ed = self.c, self.ed;
	local e = c:Editor();
	local on = e ~= nil;
	-- everything but the placeholder belongs to an open build
	for _, w in ipairs({ ed.nameLabel, ed.name, ed.class, ed.status, ed.save, ed.follow, ed.revert, ed.fav, ed.export, ed.phaseInfo, ed.addPhases, ed.adv,
		ed.spellHead, ed.summary, ed.equipHead, ed.catSearchLabel, ed.catSearch, ed.target, ed.cat.pager.prev, ed.cat.pager.label, ed.cat.pager.next, ed.cat.hint }) do
		setShown(w, on);
	end
	setShown(ed.empty, not on);
	if not on then
		ed.empty:SetText(L("Pick a build in the library, or create one."));
		for _, r in ipairs(ed.spells) do r.frame:Hide(); end
		for _, g in pairs(ed.groups) do g.label:Hide(); for _, cell in ipairs(g.cells) do cell:Hide(); end end
		for _, r in ipairs(ed.cat.rows) do r.frame:Hide(); r.tipKey = nil; end
		for _, b in pairs(ed.catKinds) do b:Hide(); end
		for _, b in ipairs(ed.phaseTabs) do b:Hide(); end
		for _, w in ipairs({ ed.nt.notesLabel, ed.nt.counter, ed.nt.notes.scroll, ed.nt.linkLabel, ed.nt.link, ed.nt.talentsLabel, ed.nt.talents, ed.nt.labelLabel,
			ed.nt.label, ed.nt.warn, ed.nt.avoidHead, ed.nt.kept }) do w:Hide(); end
		for _, r in ipairs(ed.nt.avoid) do r.frame:Hide(); end
		return;
	end
	local d = e.draft;
	local ro = c:ReadOnly();
	ed.nameLabel:SetText(L("Name:"));
	setEdit(ed.name, d.name);
	ed.class:SetText(fitText(L("Class:") .. " " .. c:ClassName(d.class), 130, 12));
	local status, needs = c:EditorStatus();
	local labels = { readonly = L("Read only"), dirty = L("Unsaved changes"), repair = L("Needs repair"), saved = L("Saved") };
	local s = labels[status];
	if needs and status == "dirty" then s = s .. " | " .. L("Needs repair"); end
	ed.status:SetText(s);
	local col = (status == "saved") and COLOR.info or ((status == "dirty") and COLOR.warn or COLOR.error);
	ed.status:SetTextColor(col[1], col[2], col[3]);
	setLabel(ed.save, L("Save"));
	setLabel(ed.follow, L("Save and follow"));
	setLabel(ed.revert, L("Discard changes"));
		local favNow = c:Handle() and c:Handle():Meta(e.id).fav;
	setLabel(ed.fav, favNow and L("Favourite *") or L("Favourite"));
	enable(ed.save, not ro and c:EditorDirty());
	enable(ed.follow, not ro and (c:EditorDirty() or not c:EditorIsActive()));
	enable(ed.revert, c:EditorDirty());
	enable(ed.fav, not ro);
	-- stages
	local many = c:ShowAllPhases();
	setShown(ed.phaseInfo, not many);
	setShown(ed.addPhases, not many);
	ed.phaseInfo:SetText(L("Single stage: the whole game"));
	setLabel(ed.addPhases, L("Add stages"));
	for p = 1, 4 do
		setShown(ed.phaseTabs[p], many);
		setLabel(ed.phaseTabs[p], fitText(c:PhaseTitle(p), 66, 12) .. (p == e.phase and " *" or ""));
	end
	if not many then e.phase = 1; end
	setLabel(ed.adv, e.adv and L("Back to the catalogue") or L("Notes and advanced"));
	local ph = d.phases[e.phase];
	local pv = c:PlanView();
	-- spells
	ed.spellHead:SetText(string.format(L("Spells to acquire, by priority (%d/%d)"), #pv.spells, BM.LIMITS.spells));
	ed.summary:SetText(string.format(L("%d keep / %d banish after (max %d)"), pv.keepCount, pv.afterCount, BM.LIMITS.banishAfter));
	if pv.afterCount > 0 then ed.summary:SetTextColor(1, 0.82, 0.2); else ed.summary:SetTextColor(0.8, 0.8, 0.8); end
	for i, r in ipairs(ed.spells) do
		local it = pv.spells[i];
		r.frame:Show();
		r.num:SetText(i .. ".");
		if it then
			r.key = it.key;
			local nm = it.name;
			if it.mode == "rank" then nm = nm .. " (r" .. tostring(it.rank) .. ")"; elseif it.mode == "unlimited" then nm = nm .. " (+)"; end
			if not it.known then nm = nm .. " ?"; end
			r.name:SetText(fitText(nm, 220, 12));
			setIcon(r.icon, it.icon);
			r.name:Show(); r.hit:Show(); r.add:Hide();
			r.tog.role = it.after and "warn" or "quiet";
			setLabel(r.tog, it.after and L("Banish after") or L("Keep"));
			setLabel(r.up, L("Up")); setLabel(r.down, L("Down")); setLabel(r.del, L("Remove"));
			r.tog:Show(); r.up:Show(); r.down:Show(); r.del:Show();
			enable(r.tog, not ro);
			enable(r.up, not ro and i > 1);
			enable(r.down, not ro and i < #pv.spells);
			enable(r.del, not ro);
			if it.after then r.bg:SetTexture(0.28, 0.16, 0.12, 1); else r.bg:SetTexture(0.14, 0.14, 0.2, 1); end
		else
			r.key = nil;
			r.icon:Hide(); r.name:Hide(); r.hit:Hide();
			r.tog:Hide(); r.up:Hide(); r.down:Hide(); r.del:Hide();
			setLabel(r.add, L("+ Add a spell"));
			enable(r.add, not ro and #pv.spells < BM.LIMITS.spells);
			r.add:Show();
			r.bg:SetTexture(0.10, 0.10, 0.14, 1);
		end
	end
	-- equipment
	ed.equipHead:SetText(L("Equipment: click a slot, then pick a piece below"));
	for _, g in ipairs(EQUIP_GROUPS) do
		local grp = ed.groups[g];
		grp.label:SetText(g == "rings" and L("Rings") or (g == "trinkets" and L("Trinkets") or L("Amulet")));
		grp.label:Show();
		local list = pv[g];
		for j, cell in ipairs(grp.cells) do
			local it = list[j];
			cell:Show();
			cell.key = it.key;
			local chosen = (e.cat == g and e.slot == j);
			local role = it.main and string.format(L("Main %d"), j) or string.format(L("Alt. %d"), j - BM.MAIN_SLOTS[g]);
			cell.role:SetText((chosen and "> " or "") .. role);
			if it.key == "" then
				cell.name:SetText("|cff8a8a8a" .. L("+ Add") .. "|r");
				cell.icon:Hide();
				cell.x:Hide();
			else
				cell.name:SetText(fitText(it.name .. (it.known and "" or " ?"), 170, 10));
				setIcon(cell.icon, it.icon);
				setLabel(cell.x, "x");
				cell.x:Show();
				enable(cell.x, not ro);
			end
			if chosen then cell.sel:Show(); else cell.sel:Hide(); end
		end
	end
	-- catalogue or advanced block
	local adv = e.adv;
	for kind, b in pairs(ed.catKinds) do
		b.role = (kind == e.cat) and "warn" or "quiet";
		local label = kind == "spells" and L("Spells") or (kind == "rings" and L("Rings") or (kind == "trinkets" and L("Trinkets") or L("Amulets")));
		setLabel(b, label .. (kind == e.cat and " *" or ""));
		setShown(b, not adv);
	end
	setShown(ed.catSearchLabel, not adv); setShown(ed.catSearch, not adv); setShown(ed.target, not adv);
	setShown(ed.cat.pager.prev, not adv); setShown(ed.cat.pager.label, not adv); setShown(ed.cat.pager.next, not adv); setShown(ed.cat.hint, not adv);
	ed.catSearchLabel:SetText(L("Search:"));
	setEdit(ed.catSearch, e.search);
	local target = c:TargetInfo();
	if adv then
		for _, r in ipairs(ed.cat.rows) do r.frame:Hide(); r.tipKey = nil; end
	else
		if target then
			local where = (e.cat == "rings" and L("Rings") or (e.cat == "trinkets" and L("Trinkets") or L("Amulet"))) .. " - "
				.. (target.main and string.format(L("Main %d"), target.slot) or string.format(L("Alternative %d"), target.altIndex));
			ed.target:SetText(fitText(string.format(L("Target: %s (%s)"), where, target.key == "" and L("empty") or target.name), EW, 12));
			ed.target:SetTextColor(1, 0.82, 0.2);
		else
			ed.target:SetText(string.format(L("Adding to the %d spells to acquire"), BM.LIMITS.spells));
			ed.target:SetTextColor(1, 0.82, 0.2);
		end
		ed.cat.pager.label:SetText(string.format(L("Page %d/%d"), e.page, c:CatalogPageCount()));
		enable(ed.cat.pager.prev, e.page > 1);
		enable(ed.cat.pager.next, e.page < c:CatalogPageCount());
		ed.cat.hint:SetText(target and L("Place fills the target slot and replaces its content.") or L("Add: spell to acquire. Avoid: avoid list."));
		local page = c:CatalogPage();
		for i, r in ipairs(ed.cat.rows) do
			local entry = page[i];
			if entry then
				r.tipKind = e.cat == "spells" and "spell" or (e.cat == "amulets" and "amulet" or "jewel");
				r.tipKey = entry.key;
				r.b.help = e.cat == "spells";
			end
			if e.cat == "spells" then
				catalogRow(r, entry, function(row, en)
					if en.state == "wanted" then
						setLabel(row.a, L("Remove"));
						row.a:SetScript("OnClick", function() c:RemoveSpell(en.key); end);
						enable(row.a, not ro);
					else
						setLabel(row.a, L("Add"));
						row.a:SetScript("OnClick", function() c:AddSpell(en.key); end);
						enable(row.a, not ro and en.state == nil);
					end
					row.info:SetText(en.state == "wanted" and L("Wanted") or (en.state == "banished" and L("In the avoid list") or ""));
				end, function(row, en)
					if en.state == "banished" then
						setLabel(row.b, L("Remove"));
						row.b:SetScript("OnClick", function() c:RemoveBanish(en.key); end);
						enable(row.b, not ro);
					else
						setLabel(row.b, L("Avoid"));
						row.b:SetScript("OnClick", function() c:AddBanish(en.key); end);
						enable(row.b, not ro and en.state == nil);
					end
					row.b:Show();
				end);
			else
				catalogRow(r, entry, function(row, en)
					setLabel(row.a, en.state == "placed" and L("Placed") or L("Place"));
					row.a:SetScript("OnClick", function() c:SetSlot(e.group, e.slot, en.key); end);
					enable(row.a, not ro and en.state == nil);
					local info = "";
					if e.cat == "amulets" then
						info = en.legend and L("Legendary") or L(RARITY_L[en.rarity or ""] or "Unknown");
					else
						info = e.cat == "rings" and L("Ring") or L("Trinket");
					end
					row.info:SetText(info);
				end, function(row) row.b:Hide(); end);
			end
		end
	end
	-- advanced block
	for _, w in ipairs({ ed.nt.notesLabel, ed.nt.counter, ed.nt.notes.scroll, ed.nt.linkLabel, ed.nt.link, ed.nt.talentsLabel, ed.nt.talents,
		ed.nt.warn, ed.nt.avoidHead, ed.nt.kept }) do setShown(w, adv); end
	local manyPhases = c:ShowAllPhases();
	setShown(ed.nt.label, adv and manyPhases);
	setShown(ed.nt.labelLabel, adv and manyPhases);
	if adv then
		ed.nt.notesLabel:SetText(string.format(L("Notes (%s)"), c:PhaseTitle(e.phase)));
		setEdit(ed.nt.notes, ph.notes);
		local units = ns.Utf8 and ns.Utf8.Len16(ph.notes) or #ph.notes;
		ed.nt.counter:SetText(string.format("%d/%d", units, ns.PlannerCodec.SITE.notes));
		if units > ns.PlannerCodec.SITE.notes then ed.nt.counter:SetTextColor(1, 0.35, 0.3); else ed.nt.counter:SetTextColor(0.7, 0.7, 0.7); end
		ed.nt.linkLabel:SetText(L("Link:"));
		setEdit(ed.nt.link, ph.link);
		ed.nt.talentsLabel:SetText(L("Talents:"));
		setEdit(ed.nt.talents, d.talents);
		ed.nt.labelLabel:SetText(L("Stage name:"));
		setEdit(ed.nt.label, ph.label);
		ed.nt.warn:SetText(units > ns.PlannerCodec.SITE.notes and L("Notes over 2000 characters are cut.") or "");
		local hidden = c:HiddenData();
		ed.nt.kept:SetText(#hidden == 0 and L("No hidden data in this build.") or fitText(table.concat(hidden, " | "), EW, 10));
		ed.nt.avoidHead:SetText(string.format(L("Avoid list: banish if offered (%d/%d)"), #pv.banish, BM.LIMITS.banish));
		for i, r in ipairs(ed.nt.avoid) do
			local it = pv.banish[i];
			if it then
				r.key = it.key;
				r.name:SetText(fitText(it.name .. (it.known and "" or " ?"), 80, 10));
				setLabel(r.del, "x");
				enable(r.del, not ro);
				setLabel(r.conv, L("Convert"));
				setShown(r.conv, it.overlap);
				r.del:Show();
				r.hit:Show();
				r.frame:Show();
			else
				r.key = nil;
				r.frame:Hide();
			end
		end
	else
		for _, r in ipairs(ed.nt.avoid) do r.frame:Hide(); end
	end
end

-- ------------------------------------------------------------------ inspector (right)
function UI:BuildInspector(v)
	local ins = {};
	self.ins = ins;
	ins.head = text(v, 8, 8, RP_W - 16, "GameFontNormal");
	ins.icon = v:CreateTexture(nil, "ARTWORK");
	ins.icon:SetWidth(40); ins.icon:SetHeight(40);
	ins.icon:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -32);
	ins.title = wrapped(v, 56, 32, RP_W - 64, 40, "GameFontNormalLarge");
	ins.body = wrapped(v, 8, 82, RP_W - 16, 420, "GameFontHighlight");
	ins.source = wrapped(v, 8, 520, RP_W - 16, 60, "GameFontNormalSmall");
end

function UI:RefreshInspector()
	local c, ins = self.c, self.ins;
	ins.head:SetText(L("Details"));
	local d = c:InspectorData();
	if not d then
		ins.icon:Hide();
		ins.title:SetText("");
		ins.body:SetText("|cffb4b4b4" .. L("Select a spell or a piece to see its details here.") .. "|r");
		ins.source:SetText("");
		return;
	end
	setIcon(ins.icon, d.icon);
	ins.title:SetText(fitText(d.title, 2 * (RP_W - 64) - 10, 16));
	local out = {};
	local source = L("Source: Reborn catalogue (name, type, class).");
	if d.spellId then
		local game = self:GameText(d.spellId);
		if game then
			for i, t in ipairs(game) do if i > 1 then out[#out + 1] = t; end end   -- line 1 repeats the name
			source = L("Source: the game's own spell text, and the Reborn catalogue.");
		else
			out[#out + 1] = "|cffb4b4b4" .. L("Detailed effect unavailable") .. "|r";
		end
		out[#out + 1] = "";
	end
	for _, ln in ipairs(d.lines) do
		local hex = TONEHEX[ln.tone];
		out[#out + 1] = hex and ("|cff" .. hex .. ln.text .. "|r") or ln.text;
	end
	ins.body:SetText(table.concat(out, "\n"));
	ins.source:SetText(source);
end

-- ------------------------------------------------------------------ import (centre)
function UI:BuildImport(v)
	local c = self.c;
	local im = {};
	self.im = im;
	im.head = text(v, 8, 8, EW, "GameFontNormal");
	im.box = multiline(v, "RebornBuildPlannerImportBox", EW, 90, 8, 30, nil);
	im.analyze = button(v, "", 140, 24, 8, 126, function() c:AnalyzeImport(im.box:GetText()); end);
	im.analyze.role = "primary";
	im.back = button(v, "", 120, 24, 156, 126, function() c:SetView("editor"); end);
	im.back.role = "quiet";
	im.hint = text(v, 8, 156, EW, "GameFontNormalSmall");
	im.name = text(v, 8, 180, EW, "GameFontNormalLarge", "LEFT", 18);
	im.class = text(v, 8, 202, 270, "GameFontNormal");
	im.state = text(v, 290, 202, 280, "GameFontNormal", "RIGHT");
	im.phases = {};
	for i = 1, 4 do im.phases[i] = text(v, 8, 226 + (i - 1) * 16, EW, "GameFontHighlightSmall"); end
	im.issues = {};
	for i = 1, ns.Controller.ISSUE_PAGE do im.issues[i] = text(v, 8, 298 + (i - 1) * 16, EW, "GameFontNormalSmall"); end
	im.pager = pager(v, 8, 404, function() c:SetImportPage(c.state.import.page - 1); end, function() c:SetImportPage(c.state.import.page + 1); end);
	im.loss = text(v, 210, 408, 350, "GameFontNormalSmall");
	im.classCycle = cycler(v, 8, 440, 250, function() self:CycleImportClass(-1); end, function() self:CycleImportClass(1); end);
	im.nameLabel = text(v, 270, 444, 60, "GameFontNormal");
	im.nameEdit = edit(v, 150, 332, 440, function(t) c:SetImportName(t); end, "RebornBuildPlannerImportName");
	im.commit = button(v, "", 150, 28, 8, 480, function() local id = c:CommitImport(); if id then c.state.import = nil; c:SetView("editor", true); end end);
	im.commit.role = "primary";
end

function UI:CycleImportClass(dir)
	local c = self.c;
	local keys = c:ClassKeys();
	local i = ns.Util.IndexOf(keys, c.state.import.class or "") or 0;
	i = i + dir;
	if i < 1 then i = #keys; end
	if i > #keys then i = 1; end
	c:SetImportClass(keys[i]);
end

function UI:RefreshImport()
	local c, im = self.c, self.im;
	local st = c:ImportState();
	im.head:SetText(L("Paste an azsb1: code or a planner link (Ctrl+V), then Analyze."));
	setLabel(im.analyze, L("Analyze"));
	setLabel(im.back, L("Back"));
	im.hint:SetText(L("Nothing is saved until you press Import. The new build is never active."));
	local pv = st and st.preview;
	local show = pv ~= nil;
	for _, w in ipairs({ im.name, im.class, im.state }) do setShown(w, show); end
	for _, w in ipairs(im.phases) do setShown(w, show); end
	for _, w in ipairs(im.issues) do setShown(w, show); end
	setShown(im.pager.prev, show); setShown(im.pager.next, show); setShown(im.pager.label, show); setShown(im.loss, show);
	local talents = show and pv.ok and pv.kind == "talents";
	setShown(im.classCycle.prev, talents); setShown(im.classCycle.next, talents); setShown(im.classCycle.label, talents);
	setShown(im.nameLabel, show and pv.ok); setShown(im.nameEdit, show and pv.ok); setShown(im.commit, show);
	if not show then return; end
	im.nameLabel:SetText(L("Name:"));
	setLabel(im.commit, L("Import"));
	enable(im.commit, c:ImportReady());
	if not pv.ok then
		im.name:SetText(L("Cannot import this text"));
		im.class:SetText("");
		im.state:SetText(L("Refused"));
		im.state:SetTextColor(1, 0.35, 0.3);
		for _, w in ipairs(im.phases) do w:SetText(""); end
	else
		if pv.kind == "talents" then
			im.name:SetText(L("Talent string only"));
			im.class:SetText(fitText(pv.talents, 270, 12));
			im.state:SetText(st.class and L("Ready") or L("Choose a class"));
			im.state:SetTextColor(0.4, 1, 0.5);
			im.classCycle.label:SetText(st.class and c:ClassName(st.class) or L("Class?"));
			for _, w in ipairs(im.phases) do w:SetText(""); end
		else
			im.name:SetText(fitText(pv.name ~= "" and pv.name or L("(no name)"), EW, 16));
			im.class:SetText(fitText(L("Class:") .. " " .. c:ClassName(pv.class) .. (pv.classKnown and "" or " (" .. L("unknown") .. ")"), 270, 12));
			im.state:SetText(pv.status == "ready" and L("Ready to import") or L("Importable, needs repair"));
			local col = pv.status == "ready" and COLOR.info or COLOR.warn;
			im.state:SetTextColor(col[1], col[2], col[3]);
			for i, w in ipairs(im.phases) do
				local p = pv.phases[i];
				w:SetText(p.empty and string.format(L("%s: empty"), L(BM.DEFAULT_LABELS[i])) or fitText(string.format(L("%s: %d spell(s), %d banish, %d ring(s), %d trinket(s), %d amulet(s)"),
					p.label ~= "" and p.label or L(BM.DEFAULT_LABELS[i]), p.spells, p.banish, p.rings, p.trinkets, p.amulets), EW, 10));
			end
		end
	end
	local list = c:ImportIssues();
	local first = (st.page - 1) * ns.Controller.ISSUE_PAGE;
	for i, w in ipairs(im.issues) do
		local it = list[first + i];
		if it then
			local tag = it.level == "error" and L("Error") or it.level == "conflict" and L("Conflict") or L("Notice");
			w:SetText(fitText(tag .. ": " .. it.message .. (it.key and (" [" .. tostring(it.key) .. "]") or ""), EW, 10));
			local col = it.level == "error" and COLOR.error or (it.level == "conflict" and COLOR.warn or { 0.8, 0.8, 0.8 });
			w:SetTextColor(col[1], col[2], col[3]);
		else
			w:SetText("");
		end
	end
	im.pager.label:SetText(string.format(L("Page %d/%d"), st.page, c:ImportPageCount()));
	enable(im.pager.prev, st.page > 1);
	enable(im.pager.next, st.page < c:ImportPageCount());
	local loss = pv.exportReport and pv.exportReport.intentLosses or 0;
	im.loss:SetText(loss > 0 and fitText(string.format(L("%d thing(s) the official planner would not keep if exported back"), loss), 350, 10) or "");
end

-- ------------------------------------------------------------------ export (centre)
function UI:BuildExport(v)
	local c = self.c;
	local ex = {};
	self.ex = ex;
	ex.head = text(v, 8, 8, EW, "GameFontNormalLarge", "LEFT", 18);
	ex.state = text(v, 8, 32, EW, "GameFontNormal");
	ex.rows = {};
	for i = 1, ns.Controller.ISSUE_PAGE do ex.rows[i] = text(v, 8, 58 + (i - 1) * 18, EW, "GameFontNormalSmall"); end
	ex.pager = pager(v, 8, 170, function() c:SetExportPage(c.state.export.page - 1); end, function() c:SetExportPage(c.state.export.page + 1); end);
	ex.accept = button(v, "", 340, 26, 210, 168, function() c:AcceptLosses(); end);
	ex.accept.role = "warn";
	ex.codeLabel = text(v, 8, 204, EW, "GameFontNormal");
	ex.box = multiline(v, "RebornBuildPlannerExportBox", EW, 110, 8, 224, nil, true);
	ex.hint = text(v, 8, 340, EW, "GameFontNormalSmall");
	ex.back = button(v, "", 160, 26, 8, 372, function() c:SetView("editor"); end);
	ex.back.role = "quiet";
end

function UI:RefreshExport()
	local c, ex = self.c, self.ex;
	local x = c.state.export;
	if not x then return; end
	local b = x.build;
	ex.head:SetText(string.format(L("Export: %s"), fitText(b.name ~= "" and b.name or L("(no name)"), 400, 16)));
	local r = x.report;
	local losses = c:ExportLosses();
	local first = (x.page - 1) * ns.Controller.ISSUE_PAGE;
	for i, w in ipairs(ex.rows) do
		local it = losses[first + i];
		if it then
			local tag = it.severity == "intent" and L("Lost") or L("Info");
			w:SetText(fitText(tag .. ": " .. it.message .. (it.key and (" [" .. tostring(it.key) .. "]") or ""), EW, 10));
			if it.severity == "intent" then w:SetTextColor(1, 0.82, 0.2); else w:SetTextColor(0.7, 0.7, 0.7); end
		else
			w:SetText("");
		end
	end
	ex.pager.label:SetText(string.format(L("Page %d/%d"), x.page, c:ExportPageCount()));
	enable(ex.pager.prev, x.page > 1);
	enable(ex.pager.next, x.page < c:ExportPageCount());
	if not r.ok then
		ex.state:SetText(L("This build cannot be exported to the official planner."));
		ex.state:SetTextColor(1, 0.35, 0.3);
	elseif r.intentLosses == 0 then
		ex.state:SetText(fitText(L("Nothing of your intent is lost in the official format (to verify on the site)."), EW, 12));
		ex.state:SetTextColor(0.4, 1, 0.5);
	elseif x.accepted then
		ex.state:SetText(string.format(L("Exported with %d known loss(es) that you accepted."), r.intentLosses));
		ex.state:SetTextColor(1, 0.82, 0.2);
	else
		ex.state:SetText(string.format(L("%d thing(s) would be lost. Read the list, then accept to see the code."), r.intentLosses));
		ex.state:SetTextColor(1, 0.82, 0.2);
	end
	setLabel(ex.accept, L("Accept the losses and show the code"));
	setShown(ex.accept, r.ok and r.intentLosses > 0 and not x.accepted);
	ex.codeLabel:SetText(x.code and L("Code (Ctrl+A then Ctrl+C to copy):") or "");
	setShown(ex.box.scroll, x.code ~= nil);
	if x.code then
		ex.box.fixed = x.code;
		setEdit(ex.box, x.code);
	end
	ex.hint:SetText(x.source == "draft" and L("This is the draft shown in the editor, saved or not.") or L("This is the saved build."));
	setLabel(ex.back, L("Back"));
end

-- ------------------------------------------------------------------ modal dialog (one frame, reused)
function UI:BuildModal()
	local m = CreateFrame("Frame", "RebornBuildPlannerModal", UIParent);
	self.modal = m;
	m:SetWidth(460);
	m:SetHeight(250);
	m:SetFrameStrata("FULLSCREEN_DIALOG");
	m:SetFrameLevel(100);
	m:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	m:SetClampedToScreen(true);
	m:EnableMouse(true);
	m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
	m:SetBackdropColor(0.07, 0.07, 0.11, 1);
	m:SetBackdropBorderColor(0.7, 0.6, 0.3, 1);
	m:Hide();
	m.title = text(m, 24, 18, 412, "GameFontNormalLarge", "LEFT", 18);
	m.body = wrapped(m, 24, 46, 412, 66, "GameFontHighlight");
	m.editLabel = text(m, 24, 118, 120, "GameFontNormal");
	m.edit = edit(m, 288, 148, 114, function(t) m.value = t; end, "RebornBuildPlannerModalEdit");
	m.cycleLabel = text(m, 24, 150, 120, "GameFontNormal");
	m.cycle = cycler(m, 148, 146, 288, function() self:ModalClass(-1); end, function() self:ModalClass(1); end);
	m.err = text(m, 24, 176, 412, "GameFontNormal");
	m.err:SetTextColor(1, 0.35, 0.3);
	m.b = {};
	for i = 1, 3 do
		m.b[i] = button(m, "", 130, 26, 24 + (i - 1) * 140, 204, function() self:ModalChoose(i); end);
		m.b[i].role = i == 1 and "primary" or "quiet";
	end
	m:SetScript("OnHide", function() self:SyncEscape(); end);
end

-- spec = { title, body, edit = initial text|nil, editLabel, class = key|nil (class cycler), buttons = { label... },
--          validate = fn(index, value, class) -> error text | nil (keeps the dialog open),
--          onChoose = fn(index, value, class), cancelIndex, dangerFirst }
function UI:ShowModal(spec)
	self:Build();
	local m = self.modal;
	m.spec, m.value, m.class = spec, spec.edit, spec.class;
	m.title:SetText(spec.title);
	m.body:SetText(spec.body or "");
	m.err:SetText("");
	setShown(m.edit, spec.edit ~= nil);
	setShown(m.editLabel, spec.edit ~= nil);
	m.editLabel:SetText(spec.editLabel or "");
	if spec.edit ~= nil then m.edit:SetText(spec.edit); end
	setShown(m.cycle.prev, spec.class ~= nil); setShown(m.cycle.next, spec.class ~= nil); setShown(m.cycle.label, spec.class ~= nil);
	setShown(m.cycleLabel, spec.class ~= nil);
	m.cycleLabel:SetText(L("Class:"));
	if spec.class then m.cycle.label:SetText(self.c:ClassName(spec.class)); end
	for i = 1, 3 do
		local label = spec.buttons[i];
		m.b[i].role = (i == 1 and spec.dangerFirst) and "danger" or (i == 1 and "primary" or "quiet");
		if label then setLabel(m.b[i], label); m.b[i]:Show(); else m.b[i]:Hide(); end
	end
	m:Show();
	self:SyncEscape();
end

function UI:ModalClass(dir)
	local m, keys = self.modal, self.c:ClassKeys();
	local i = (ns.Util.IndexOf(keys, m.class or "") or 0) + dir;
	if i < 1 then i = #keys; end
	if i > #keys then i = 1; end
	m.class = keys[i];
	m.cycle.label:SetText(self.c:ClassName(m.class));
end

function UI:ModalChoose(i)
	local m = self.modal;
	local spec = m.spec;
	if spec and spec.validate then
		local err = spec.validate(i, m.value, m.class);
		if err then m.err:SetText(err); return; end
	end
	m:Hide();
	if spec and spec.onChoose then spec.onChoose(i, m.value, m.class); end
end

function UI:ModalCancel()
	local m = self.modal;
	local spec = m.spec;
	m:Hide();
	if spec and spec.onChoose and spec.cancelIndex then spec.onChoose(spec.cancelIndex, m.value, m.class); end
end

-- ------------------------------------------------------------------ actions with prompts
local function trimmed(s)
	s = string.gsub(s or "", "^%s+", "");
	s = string.gsub(s, "%s+$", "");
	return s;
end

function UI:AskCreate()
	local c = self.c;
	self:ShowModal({ title = L("Create a build"), body = L("Give it a name and choose its class. It will not be active until you follow it."),
		edit = "", editLabel = L("Build name:"), class = c:DefaultClass(), buttons = { L("Create"), L("Cancel") }, cancelIndex = 2,
		validate = function(i, value)
			if i ~= 1 then return nil; end
			local v = trimmed(value);
			if v == "" then return L("Give the build a name"); end
			if #v > BM.LIMITS.name then return L("The name is too long"); end
			return nil;
		end,
		onChoose = function(i, value, class)
			if i == 1 then
				local id = c:Create(value or "", class);
				if id then self:OpenEditor(id); end
			end
		end });
end

function UI:AskRename(r)
	local c = self.c;
	self:ShowModal({ title = L("Rename"), body = L("New name for this build:"), edit = r.name, editLabel = L("Build name:"), buttons = { L("Rename"), L("Cancel") }, cancelIndex = 2,
		validate = function(i, value)
			if i == 1 and trimmed(value) == "" then return L("Give the build a name"); end
			return nil;
		end,
		onChoose = function(i, value) if i == 1 then c:Rename(r.id, value or ""); end end });
end

function UI:AskDelete(r)
	local c = self.c;
	local info = c:DeleteInfo(r.id);
	local body = string.format(L("\"%s\" will go to the trash and can be restored (the trash keeps 20 builds: when it is full, the oldest one is removed for good)."), info.name);
	if info.trashSize >= info.cap then body = body .. "\n" .. L("The trash is full: deleting will remove the oldest deleted build for good."); end
	self:ShowModal({ title = L("Delete this build?"), body = body, buttons = { L("Delete"), L("Cancel") }, cancelIndex = 2, dangerFirst = true,
		onChoose = function(i) if i == 1 then c:ConfirmDelete(r.id); end end });
end

function UI:OpenEditor(id)
	local c = self.c;
	local ok, why = c:OpenEditor(id);
	if not ok and why == "DIRTY" then
		self:AskDirty(function() return c:OpenEditor(id); end);
	end
end

-- Unsaved changes: Save / Discard / Keep editing. `after` runs once the draft is settled.
function UI:AskDirty(after)
	local c = self.c;
	self:ShowModal({ title = L("Unsaved changes"), body = L("This build has changes that are not saved. What do you want to do?"),
		buttons = { L("Save"), L("Discard"), L("Keep editing") }, cancelIndex = 3,
		onChoose = function(i)
			if i == 1 then
				if c:Save() then c.state.editor = nil; if after then after(); end end
			elseif i == 2 then
				c.state.editor = nil;
				if after then after(); end
				c:Notify();
			end
		end });
end

function UI:CloseEditor()
	local c = self.c;
	if c:RequestCloseEditor() == "prompt" then
		self:AskDirty(function() c:CloseEditor(); end);
	end
end

function UI:GoLibrary()
	self.c:SetView("editor");
end

-- ------------------------------------------------------------------ window management
function UI:SyncEscape()
	local list = UISpecialFrames;
	if not list then return; end
	local mine = { RebornBuildPlannerFrame = true, RebornBuildPlannerModal = true };
	for i = #list, 1, -1 do
		if mine[list[i]] then table.remove(list, i); end
	end
	if not self.root then return; end
	if self.modal and self.modal:IsShown() then
		list[#list + 1] = "RebornBuildPlannerModal";
	elseif self.root:IsShown() and not self.c:EditorDirty() then
		list[#list + 1] = "RebornBuildPlannerFrame";
	end
end

function UI:ApplyPosition()
	local root, h = self.root, self.c:Handle();
	root:ClearAllPoints();
	local w = h and h:GetSetting("window");
	if type(w) == "table" and type(w.x) == "number" and type(w.y) == "number" and math.abs(w.x) < 4000 and math.abs(w.y) < 4000 then
		root:SetPoint(w.point or "CENTER", UIParent, w.point or "CENTER", w.x, w.y);
	else
		root:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	end
end

function UI:SavePosition()
	local h = self.c:Handle();
	if not h or h.readOnly then return; end
	local point, _, _, x, y = self.root:GetPoint();
	if point and x and y then h:SetSetting("window", { point = point, x = x, y = y }); end
end

function UI:ResetPosition()
	local h = self.c:Handle();
	if h and not h.readOnly then h.db.settings.window = nil; h.db.settings.scale = nil; end
	if self.root then self:ApplyScale(); self:ApplyPosition(); end
end

-- the window always fits the screen: scale is the player's choice, lowered when the screen is small
function UI:ApplyScale()
	local h = self.c:Handle();
	local want = h and h:GetSetting("scale") or 1;
	local fit = (UIParent:GetHeight() - 24) / UI.HEIGHT;
	local fitW = (UIParent:GetWidth() - 24) / UI.WIDTH;
	self.root:SetScale(math.max(0.5, math.min(want, fit, fitW)));
end

function UI:Rescale(delta)
	local h = self.c:Handle();
	if not h or h.readOnly then return; end
	local s = math.floor(((h:GetSetting("scale") or 1) + delta) * 10 + 0.5) / 10;
	if h:SetSetting("scale", math.max(0.6, math.min(1.5, s))) then self:ApplyScale(); end
end

function UI:Show()
	self:Build();
	self:ApplyScale();
	self:ApplyPosition();
	self.root:Show();
	self:Refresh();
	self:SyncEscape();
end

function UI:Hide()
	if self.root then self.root:Hide(); end
	self:SyncEscape();
end

-- closing the window with unsaved changes asks first (the draft is otherwise kept in memory, never auto-saved)
function UI:RequestClose()
	local c = self.c;
	if c:EditorDirty() then
		self:AskDirty(function() c:CloseEditor(); self:Hide(); end);
		return;
	end
	self:Hide();
end

function UI:Toggle()
	if self:IsShown() then self:RequestClose(); else self:Show(); end
end

function UI:Refresh()
	if not self.built or not self.root then return; end
	local c = self.c;
	local st = c.state;
	self:HideTip();       -- page / view / data may have changed under the pointer
	self.title:SetText("Reborn Build Planner");
	setLabel(self.nav.import, L("Import"));
	setLabel(self.nav.export, L("Export"));
	setLabel(self.sizeMinus, L("Size -"));
	setLabel(self.sizePlus, L("Size +"));
	enable(self.nav.export, st.export ~= nil or st.editor ~= nil);
	self.banner:SetText(c:StorageStatusText() or "");
	for name, f in pairs(self.views) do setShown(f, name == st.view); end
	local msg = st.message;
	self.msg:SetText(msg and fitText(msg.text, 860, 12) or "");
	if msg then self.msg:SetTextColor(unpack(COLOR[msg.level])); end
	setShown(self.undoBtn, st.undo ~= nil);
	if st.undo then setLabel(self.undoBtn, L("Undo the deletion")); end
	self:RefreshLibrary();
	self:RefreshInspector();
	if st.view == "editor" then self:RefreshEditor();
	elseif st.view == "import" then self:RefreshImport();
	elseif st.view == "export" then self:RefreshExport(); end
	self:SyncEscape();
end
