-- Native window: a thin renderer over Controller. Standard 3.3.5a widgets only (Frame, Button with
-- UIPanelButtonTemplate, EditBox, ScrollFrame with UIPanelScrollFrameTemplate, FontString, Texture), the same
-- ones the native Reborn addons use. Every widget is created ONCE (lazily, on first open) and then reused:
-- lists are fixed pools of rows driven by paging, so nothing is created while the player uses the window.
-- No clipboard API: export shows a selectable text box, the player presses Ctrl+A, Ctrl+C (as FieldKit's copy
-- window does); import is Ctrl+V into a text box. Links are never opened. No animation, no OnUpdate.
local ADDON, ns = ...;
ns = ns or {};
local Locale, BM = ns.Locale, ns.BuildModel;
assert(Locale and BM and ns.Controller, "RebornBuildPlanner: UI.lua must load after Controller.lua");
local UI = {};
ns.UI = UI;
UI.__index = UI;

local L = function(s) return Locale.T(s); end

UI.WIDTH, UI.HEIGHT = 780, 540;
local CW, CH = 748, 420;                -- content area of a view
local COLOR = { info = { 0.4, 1, 0.5 }, warn = { 1, 0.82, 0.2 }, error = { 1, 0.35, 0.3 } };

-- ------------------------------------------------------------------ widget helpers
local function fitText(s, px, size)
	local max = math.floor(px / ((size or 12) * 0.62));   -- a little wider than the lint's 0.6: truncate early
	local n, i, len = 0, 1, #s;
	while i <= len do
		local b = string.byte(s, i);
		i = i + ((b < 0x80) and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4)));
		n = n + 1;
		if n > max then
			-- cut at the character boundary before the limit and add an ellipsis
			local cutAt, k, c = 0, 1, 0;
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
	fs.px, fs.size = w, 12;
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

local function setLabel(b, label)
	if b.label ~= label then b.label = label; b:SetText(label); end
end

local function edit(parent, w, x, y, onChange, name, maxLetters)
	local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate");
	e:SetWidth(w);
	e:SetHeight(22);
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	e:SetAutoFocus(false);
	e:SetFontObject("ChatFontNormal");
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
		-- the player selects and copies; any typing is put back
		e:SetScript("OnTextChanged", function(self, user)
			if user and self.fixed and self:GetText() ~= self.fixed then self:SetText(self.fixed); self:HighlightText(); end
		end);
		e:SetScript("OnEditFocusGained", function(self) self:HighlightText(); end);
	end
	sf:SetScrollChild(e);
	e.scroll = sf;
	return e;
end

local function cycler(parent, x, y, w, onPrev, onNext)
	local c = {};
	c.prev = button(parent, "<", 28, 22, x, y, onPrev);
	c.label = text(parent, x + 34, y + 4, w - 68, "GameFontNormal", "CENTER");
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

local function setShown(f, on)
	if on then f:Show(); else f:Hide(); end
end

local function enable(b, on)
	if on then b:Enable(); else b:Disable(); end
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
	root:SetFrameStrata("HIGH");
	root:SetClampedToScreen(true);
	root:SetMovable(true);
	root:EnableMouse(true);
	root:RegisterForDrag("LeftButton");
	root:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
	root:SetScript("OnDragStart", function(f) f:StartMoving(); end);
	root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); self:SavePosition(); end);
	root:SetScript("OnHide", function() self:SyncEscape(); end);
	root:Hide();

	self.title = text(root, 20, 14, 400, "GameFontNormalLarge", "LEFT", 18);
	local close = CreateFrame("Button", "RebornBuildPlannerClose", root, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, -6);
	close:SetScript("OnClick", function() self:RequestClose(); end);
	self.nav = {
		library = button(root, "", 120, 24, 20, 40, function() self:GoLibrary(); end),
		editor = button(root, "", 120, 24, 144, 40, function() if c:Editor() then c:SetView("editor"); end end),
		import = button(root, "", 120, 24, 268, 40, function() c:SetView("import"); end),
		export = button(root, "", 120, 24, 392, 40, function() if c.state.export then c:SetView("export"); end end),
	};
	self.sizeMinus = button(root, "", 84, 24, 556, 40, function() self:Rescale(-0.1); end);
	self.sizePlus = button(root, "", 84, 24, 644, 40, function() self:Rescale(0.1); end);
	self.banner = text(root, 20, 68, 740, "GameFontNormal", "LEFT");
	self.banner:SetTextColor(1, 0.35, 0.3);
	self.msg = text(root, 20, 504, 520, "GameFontNormal", "LEFT");
	self.undoBtn = button(root, "", 200, 24, 560, 498, function() c:UndoDelete(); end);

	local function view(name)
		local f = CreateFrame("Frame", "RebornBuildPlanner" .. name, root);
		f:SetWidth(CW);
		f:SetHeight(CH);
		f:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -80);
		f:Hide();
		return f;
	end
	self.views = { library = view("Library"), editor = view("Editor"), import = view("Import"), export = view("Export") };
	self:BuildLibrary(self.views.library);
	self:BuildEditor(self.views.editor);
	self:BuildImport(self.views.import);
	self:BuildExport(self.views.export);
	self:BuildModal();
end

-- ------------------------------------------------------------------ library view
function UI:BuildLibrary(v)
	local c = self.c;
	local lib = {};
	self.lib = lib;
	lib.classLabel = text(v, 0, 4, 70, "GameFontNormal");
	lib.cycle = cycler(v, 74, 0, 300, function() c:CycleClassFilter(-1); end, function() c:CycleClassFilter(1); end);
	lib.trashBtn = button(v, "", 180, 22, 560, 0, function() c:ShowTrash(not c.state.trashMode); end);
	lib.rows = {};
	lib.head = { name = text(v, 28, 34, 330, "GameFontNormalSmall"), class = text(v, 370, 34, 160, "GameFontNormalSmall"), status = text(v, 540, 34, 180, "GameFontNormalSmall") };
	for i = 1, ns.Controller.LIB_PAGE do
		local r = CreateFrame("Button", "RebornBuildPlannerRow" .. i, v);
		r:SetWidth(CW - 10);
		r:SetHeight(28);
		r:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -(52 + (i - 1) * 30));
		r.bg = r:CreateTexture(nil, "BACKGROUND");
		r.bg:SetAllPoints(r);
		r.bg:SetTexture(0.2, 0.4, 0.8, 0.35);
		r.bg:Hide();
		r.name = text(r, 8, 7, 340, "GameFontHighlight");
		r.class = text(r, 370, 7, 160, "GameFontNormal");
		r.status = text(r, 540, 7, 180, "GameFontNormal");
		r:SetScript("OnClick", function(f) if f.rowId then c:Select(f.rowId); end end);
		r:SetScript("OnDoubleClick", function(f) if f.rowId and not f.trashed then self:OpenEditor(f.rowId); end end);
		lib.rows[i] = r;
	end
	lib.empty = text(v, 40, 120, 660, "GameFontNormalLarge", "CENTER", 40);
	lib.empty2 = text(v, 40, 164, 660, "GameFontHighlight", "CENTER");
	lib.pager = pager(v, 0, 296, function() c:SetPage(c.state.page - 1); end, function() c:SetPage(c.state.page + 1); end);
	lib.open = button(v, "", 112, 24, 0, 334, function() local r = c:Selected(); if r then self:OpenEditor(r.id); end end);
	lib.dup = button(v, "", 112, 24, 118, 334, function() local r = c:Selected(); if r then c:Duplicate(r.id); end end);
	lib.rename = button(v, "", 112, 24, 236, 334, function() local r = c:Selected(); if r then self:AskRename(r); end end);
	lib.delete = button(v, "", 112, 24, 354, 334, function() local r = c:Selected(); if r then self:AskDelete(r); end end);
	lib.activate = button(v, "", 112, 24, 472, 334, function()
		local r = c:Selected();
		if r then if r.active then c:Deactivate(r.id); else c:Activate(r.id); end end
	end);
	lib.export = button(v, "", 112, 24, 590, 334, function() local r = c:Selected(); if r then c:PrepareExport(r.id, "saved"); c:SetView("export"); end end);
	lib.restore = button(v, "", 150, 24, 0, 334, function() local r = c:Selected(); if r then c:Restore(r.id); end end);
	lib.create = button(v, "", 200, 28, 0, 380, function() self:AskCreate(); end);
	lib.importBtn = button(v, "", 200, 28, 210, 380, function() c:SetView("import"); end);
	lib.note = text(v, 430, 384, 300, "GameFontNormalSmall", "LEFT");
end

function UI:RefreshLibrary()
	local c, lib = self.c, self.lib;
	local st = c.state;
	local ro = c:ReadOnly();
	lib.classLabel:SetText(L("Class:"));
	lib.cycle.label:SetText(st.classFilter and c:ClassName(st.classFilter) or L("All classes"));
	local trashN = c:Handle() and #c:Handle():Trash() or 0;
	setLabel(lib.trashBtn, st.trashMode and L("Back to my builds") or string.format(L("Trash (%d)"), trashN));
	lib.head.name:SetText(st.trashMode and L("Deleted builds") or L("Build"));
	lib.head.class:SetText(L("Class"));
	lib.head.status:SetText(L("Status"));
	local rows = c:PageRows();
	local sel = st.selectedId;
	for i, r in ipairs(lib.rows) do
		local d = rows[i];
		if d then
			r.rowId, r.trashed = d.id, d.trashed;
			r.name:SetText(fitText(d.name ~= "" and d.name or L("(no name)"), 340, 12));
			r.class:SetText(fitText(d.className, 160, 12));
			local s = "";
			if d.trashed then s = L("In the trash");
			elseif d.active then s = L("Active");
			elseif d.clean == false then s = L("Needs repair"); end
			if d.active and d.clean == false then s = L("Active"); end
			r.status:SetText(s);
			if d.id == sel then r.bg:Show(); else r.bg:Hide(); end
			r:Show();
		else
			r.rowId = nil;
			r:Hide();
		end
	end
	local any = rows[1] ~= nil;
	setShown(lib.empty, not any);
	setShown(lib.empty2, not any);
	if not any then
		if st.trashMode then
			lib.empty:SetText(L("The trash is empty"));
			lib.empty2:SetText(L("A deleted build stays here until the trash is full (20 builds)."));
		elseif st.classFilter then
			lib.empty:SetText(L("No build for this class"));
			lib.empty2:SetText(L("Create a build or import a Reborn code."));
		else
			lib.empty:SetText(L("No build yet"));
			lib.empty2:SetText(L("Create a build or import a Reborn code."));
		end
	end
	lib.pager.label:SetText(string.format(L("Page %d/%d"), st.page, c:PageCount()));
	enable(lib.pager.prev, st.page > 1);
	enable(lib.pager.next, st.page < c:PageCount());
	local r = c:Selected();
	local inTrash = st.trashMode;
	for _, b in ipairs({ lib.open, lib.dup, lib.rename, lib.delete, lib.activate, lib.export }) do setShown(b, not inTrash); end
	setShown(lib.restore, inTrash);
	setLabel(lib.open, L("Open"));
	setLabel(lib.dup, L("Duplicate"));
	setLabel(lib.rename, L("Rename"));
	setLabel(lib.delete, L("Delete"));
	setLabel(lib.export, L("Export"));
	setLabel(lib.activate, (r and r.active) and L("Stop following") or L("Follow"));
	setLabel(lib.restore, L("Restore"));
	setLabel(lib.create, L("Create a build"));
	setLabel(lib.importBtn, L("Import a code"));
	local has = r ~= nil;
	enable(lib.open, has);
	enable(lib.dup, has and not ro);
	enable(lib.rename, has and not ro);
	enable(lib.delete, has and not ro);
	enable(lib.activate, has and not ro);
	enable(lib.export, has);
	enable(lib.restore, has and not ro);
	enable(lib.create, not ro);
	lib.note:SetText(L("Following a build never plays for you."));
end

-- ------------------------------------------------------------------ editor view
function UI:BuildEditor(v)
	local c = self.c;
	local ed = {};
	self.ed = ed;
	ed.nameLabel = text(v, 0, 5, 50, "GameFontNormal");
	ed.name = edit(v, 300, 54, 0, function(t) c:SetName(t); end, "RebornBuildPlannerName");
	ed.class = text(v, 362, 5, 170, "GameFontNormal");
	ed.status = text(v, 536, 0, 212, "GameFontNormal", "RIGHT", 28);
	if ed.status.SetWordWrap then ed.status:SetWordWrap(true); end
	ed.save = button(v, "", 112, 24, 0, 30, function() c:Save(); end);
	ed.follow = button(v, "", 170, 24, 118, 30, function() c:SaveAndFollow(); end);
	ed.revert = button(v, "", 200, 24, 294, 30, function() c:Revert(); end);
	ed.export = button(v, "", 100, 24, 500, 30, function() local e = c:Editor(); c:PrepareExport(e.id, "draft"); c:SetView("export"); end);
	ed.close = button(v, "", 100, 24, 606, 30, function() self:CloseEditor(); end);
	ed.phaseInfo = text(v, 0, 64, 420, "GameFontNormal");
	ed.addPhases = button(v, "", 180, 22, 430, 60, function() c:RevealPhases(); end);
	ed.phaseTabs = {};
	for p = 1, 4 do
		ed.phaseTabs[p] = button(v, "", 140, 22, (p - 1) * 146, 60, function() c:SetPhase(p); end);
	end
	ed.tabs = {
		spells = button(v, "", 140, 24, 0, 90, function() c:SetTab("spells"); end),
		jewels = button(v, "", 140, 24, 146, 90, function() c:SetTab("jewels"); end),
		notes = button(v, "", 240, 24, 292, 90, function() c:SetTab("notes"); end),
	};
	ed.msg = text(v, 0, 400, 740, "GameFontNormal", "LEFT");
	-- shared catalogue (right side of spells / jewels tabs)
	local cat = {};
	ed.cat = cat;
	cat.search = edit(v, 230, 396, 122, function(t) c:SetSearch(t); end, "RebornBuildPlannerSearch");
	cat.searchLabel = text(v, 396, 124, 120, "GameFontNormalSmall");
	cat.rows = {};
	for i = 1, ns.Controller.CATALOG_PAGE do
		local y = 150 + (i - 1) * 24;
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(352);
		r.frame:SetHeight(22);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 396, -y);
		r.icon = r.frame:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(18);
		r.icon:SetHeight(18);
		r.icon:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -2);
		r.name = text(r.frame, 22, 4, 170, "GameFontHighlight");
		r.a = button(r.frame, "", 84, 22, 196, 0, nil);
		r.b = button(r.frame, "", 70, 22, 282, 0, nil);
		cat.rows[i] = r;
	end
	cat.pager = pager(v, 396, 372, function() c:SetEditorPage(c:Editor().page - 1); end, function() c:SetEditorPage(c:Editor().page + 1); end);
	-- plan (left side)
	local plan = {};
	ed.plan = plan;
	plan.spellHead = text(v, 0, 126, 380, "GameFontNormal");
	plan.spells = {};
	for i = 1, 6 do
		local y = 146 + (i - 1) * 25;
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(380);
		r.frame:SetHeight(24);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -y);
		r.num = text(r.frame, 0, 5, 22, "GameFontNormal");
		r.name = text(r.frame, 24, 5, 170, "GameFontHighlight");
		r.up = button(r.frame, "", 52, 22, 200, 1, function() c:MoveSpell(i, -1); end);
		r.down = button(r.frame, "", 52, 22, 254, 1, function() c:MoveSpell(i, 1); end);
		r.del = button(r.frame, "", 70, 22, 308, 1, function() local k = r.key; if k then c:RemoveSpell(k); end end);
		plan.spells[i] = r;
	end
	plan.banHead = text(v, 0, 302, 380, "GameFontNormal");
	plan.banish = {};
	for i = 1, 3 do
		local y = 322 + (i - 1) * 25;
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(380);
		r.frame:SetHeight(24);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -y);
		r.num = text(r.frame, 0, 5, 22, "GameFontNormal");
		r.name = text(r.frame, 24, 5, 260, "GameFontHighlight");
		r.del = button(r.frame, "", 70, 22, 308, 1, function() local k = r.key; if k then c:RemoveBanish(k); end end);
		plan.banish[i] = r;
	end
	-- jewels (left side)
	local jw = {};
	ed.jw = jw;
	jw.groups = {
		rings = button(v, "", 120, 22, 0, 124, function() c:SetGroup("rings"); end),
		trinkets = button(v, "", 150, 22, 126, 124, function() c:SetGroup("trinkets"); end),
		amulets = button(v, "", 100, 22, 282, 124, function() c:SetGroup("amulets"); end),
	};
	jw.head = text(v, 0, 154, 380, "GameFontNormal");
	jw.slots = {};
	for i = 1, 4 do
		local y = 176 + (i - 1) * 30;
		local r = { frame = CreateFrame("Button", nil, v) };
		r.frame:SetWidth(380);
		r.frame:SetHeight(28);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -y);
		r.bg = r.frame:CreateTexture(nil, "BACKGROUND");
		r.bg:SetAllPoints(r.frame);
		r.bg:SetTexture(0.2, 0.4, 0.8, 0.35);
		r.bg:Hide();
		r.role = text(r.frame, 4, 7, 100, "GameFontNormalSmall");
		r.icon = r.frame:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(18);
		r.icon:SetHeight(18);
		r.icon:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 108, -5);
		r.name = text(r.frame, 130, 7, 170, "GameFontHighlight");
		r.clear = button(r.frame, "", 70, 22, 306, 3, function() c:ClearSlot(c:Editor().group, i); end);
		r.frame:SetScript("OnClick", function() c:SetSlotTarget(i); end);
		jw.slots[i] = r;
	end
	jw.hint = text(v, 0, 300, 380, "GameFontNormalSmall");
	-- notes and advanced
	local nt = {};
	ed.nt = nt;
	nt.notesLabel = text(v, 0, 124, 500, "GameFontNormal");
	nt.counter = text(v, 520, 124, 228, "GameFontNormalSmall", "RIGHT");
	nt.notes = multiline(v, "RebornBuildPlannerNotes", CW, 110, 0, 142, function(t) c:SetNotes(t); end);
	nt.linkLabel = text(v, 0, 262, 120, "GameFontNormal");
	nt.link = edit(v, 400, 120, 258, function(t) c:SetLink(t); end, "RebornBuildPlannerLink");
	nt.talentsLabel = text(v, 0, 290, 120, "GameFontNormal");
	nt.talents = edit(v, 400, 120, 286, function(t) c:SetTalents(t); end, "RebornBuildPlannerTalents");
	nt.labelLabel = text(v, 0, 318, 120, "GameFontNormal");
	nt.label = edit(v, 300, 120, 314, function(t) c:SetLabel(t); end, "RebornBuildPlannerLabel");
	nt.kept = {};
	for i = 1, 3 do nt.kept[i] = text(v, 0, 344 + (i - 1) * 16, 740, "GameFontNormalSmall"); end
	nt.keptHead = text(v, 0, 330, 300, "GameFontNormalSmall");
	nt.keptHead:SetPoint("TOPLEFT", v, "TOPLEFT", 440, -318);
	nt.warn = text(v, 440, 308, 308, "GameFontNormalSmall", "LEFT", 28);
	if nt.warn.SetWordWrap then nt.warn:SetWordWrap(true); end
	nt.warn:SetTextColor(1, 0.82, 0.2);
end

local function catalogRow(r, e, a, b)
	if not e then r.frame:Hide(); return; end
	r.frame:Show();
	r.name:SetText(fitText(e.name, 170, 12));
	if e.icon and e.icon ~= "" then
		r.icon:SetTexture("Interface\\Icons\\" .. e.icon);
		r.icon:Show();
	else
		r.icon:Hide();
	end
	a(r, e);
	b(r, e);
end

function UI:RefreshEditor()
	local c, ed = self.c, self.ed;
	local e = c:Editor();
	if not e then return; end
	local d = e.draft;
	local ro = c:ReadOnly();
	ed.nameLabel:SetText(L("Name:"));
	setEdit(ed.name, d.name);
	ed.class:SetText(fitText(L("Class:") .. " " .. c:ClassName(d.class), 170, 12));
	local status, needs = c:EditorStatus();
	local labels = { readonly = L("Read only"), dirty = L("Unsaved changes"), repair = L("Needs repair"), saved = L("Saved") };
	local s = labels[status];
	if needs and status == "dirty" then s = s .. " | " .. L("Needs repair"); end
	ed.status:SetText(s);
	local col = (status == "saved") and COLOR.info or ((status == "dirty") and COLOR.warn or COLOR.error);
	ed.status:SetTextColor(col[1], col[2], col[3]);
	ed.name:SetTextColor(1, 1, 1);
	setLabel(ed.save, L("Save"));
	setLabel(ed.follow, L("Save and follow"));
	setLabel(ed.revert, L("Discard changes"));
	setLabel(ed.export, L("Export"));
	setLabel(ed.close, L("Close"));
	enable(ed.save, not ro and c:EditorDirty());
	enable(ed.follow, not ro and (c:EditorDirty() or not c:EditorIsActive()));
	enable(ed.revert, c:EditorDirty());
	-- phases: one by default, the four when needed
	local many = c:ShowAllPhases();
	setShown(ed.phaseInfo, not many);
	setShown(ed.addPhases, not many);
	ed.phaseInfo:SetText(L("Single stage: the whole game"));
	setLabel(ed.addPhases, L("Add stages"));
	for p = 1, 4 do
		setShown(ed.phaseTabs[p], many);
		setLabel(ed.phaseTabs[p], fitText(c:PhaseTitle(p), 124, 12) .. (p == e.phase and " *" or ""));
	end
	if not many then e.phase = 1; end
	setLabel(ed.tabs.spells, L("Spells"));
	setLabel(ed.tabs.jewels, L("Jewelry"));
	setLabel(ed.tabs.notes, L("Notes and kept data"));
	local msg = c.state.message;
	if msg then
		ed.msg:SetText(fitText(msg.text, 740, 12));
		ed.msg:SetTextColor(unpack(COLOR[msg.level]));
	else
		ed.msg:SetText(e.tab == "spells" and L("A planned banish is not a banish already done.") or "");
		ed.msg:SetTextColor(0.7, 0.7, 0.7);
	end
	local tab = e.tab;
	local showCat = tab ~= "notes";
	setShown(ed.cat.search, showCat);
	setShown(ed.cat.searchLabel, showCat);
	setShown(ed.cat.pager.prev, showCat); setShown(ed.cat.pager.label, showCat); setShown(ed.cat.pager.next, showCat);
	for _, r in ipairs(ed.cat.rows) do if not showCat then r.frame:Hide(); end end
	for _, r in ipairs(ed.plan.spells) do if tab ~= "spells" then r.frame:Hide(); end end
	for _, r in ipairs(ed.plan.banish) do if tab ~= "spells" then r.frame:Hide(); end end
	setShown(ed.plan.spellHead, tab == "spells"); setShown(ed.plan.banHead, tab == "spells");
	for _, b in pairs(ed.jw.groups) do setShown(b, tab == "jewels"); end
	setShown(ed.jw.head, tab == "jewels"); setShown(ed.jw.hint, tab == "jewels");
	for _, r in ipairs(ed.jw.slots) do if tab ~= "jewels" then r.frame:Hide(); end end
	for _, w in ipairs({ ed.nt.notesLabel, ed.nt.counter, ed.nt.notes.scroll, ed.nt.linkLabel, ed.nt.link, ed.nt.talentsLabel, ed.nt.talents, ed.nt.labelLabel, ed.nt.label,
		ed.nt.warn, ed.nt.keptHead }) do setShown(w, tab == "notes"); end
	for _, k in ipairs(ed.nt.kept) do setShown(k, tab == "notes"); end
	ed.cat.searchLabel:SetText(L("Search:"));
	setEdit(ed.cat.search, e.search);
	if showCat then
		local page = c:CatalogPage();
		ed.cat.pager.label:SetText(string.format(L("Page %d/%d"), e.page, c:CatalogPageCount()));
		enable(ed.cat.pager.prev, e.page > 1);
		enable(ed.cat.pager.next, e.page < c:CatalogPageCount());
		for i, r in ipairs(ed.cat.rows) do
			local entry = page[i];
			if tab == "spells" then
				catalogRow(r, entry, function(row, en)
					if en.state == "wanted" then
						setLabel(row.a, L("Remove"));
						row.a:SetScript("OnClick", function() c:RemoveSpell(en.key); end);
						enable(row.a, not ro);
					else
						setLabel(row.a, L("Want"));
						row.a:SetScript("OnClick", function() c:AddSpell(en.key); end);
						enable(row.a, not ro and en.state == nil);
					end
				end, function(row, en)
					if en.state == "banished" then
						setLabel(row.b, L("Remove"));
						row.b:SetScript("OnClick", function() c:RemoveBanish(en.key); end);
						enable(row.b, not ro);
					else
						setLabel(row.b, L("Banish"));
						row.b:SetScript("OnClick", function() c:AddBanish(en.key); end);
						enable(row.b, not ro and en.state == nil);
					end
					row.b:Show();
				end);
			else
				catalogRow(r, entry, function(row, en)
					setLabel(row.a, L("Place"));
					row.a:SetScript("OnClick", function() c:SetSlot(e.group, e.slot, en.key); end);
					enable(row.a, not ro and en.state == nil);
				end, function(row) row.b:Hide(); end);
			end
		end
	end
	if tab == "spells" then
		local pv = c:PlanView();
		ed.plan.spellHead:SetText(string.format(L("Wanted spells, in priority order (%d/%d)"), #pv.spells, BM.LIMITS.spells));
		ed.plan.banHead:SetText(string.format(L("To banish if offered (%d/%d)"), #pv.banish, BM.LIMITS.banish));
		for i, r in ipairs(ed.plan.spells) do
			local it = pv.spells[i];
			setShown(r.frame, true);
			r.num:SetText(i .. ".");
			if it then
				r.key = it.key;
				local nm = it.name;
				if it.mode == "rank" then nm = nm .. " (r" .. tostring(it.rank) .. ")"; elseif it.mode == "unlimited" then nm = nm .. " (+)"; end
				if not it.known then nm = nm .. " ?"; end
				r.name:SetText(fitText(nm, 170, 12));
				setLabel(r.up, L("Up")); setLabel(r.down, L("Down")); setLabel(r.del, L("Remove"));
				r.up:Show(); r.down:Show(); r.del:Show();
				enable(r.up, not ro and i > 1);
				enable(r.down, not ro and i < #pv.spells);
				enable(r.del, not ro);
			else
				r.key = nil;
				r.name:SetText("|cff888888" .. L("(empty)") .. "|r");
				r.up:Hide(); r.down:Hide(); r.del:Hide();
			end
		end
		for i, r in ipairs(ed.plan.banish) do
			local it = pv.banish[i];
			setShown(r.frame, true);
			r.num:SetText(i .. ".");
			if it then
				r.key = it.key;
				r.name:SetText(fitText(it.name .. (it.known and "" or " ?"), 260, 12));
				setLabel(r.del, L("Remove"));
				r.del:Show();
				enable(r.del, not ro);
			else
				r.key = nil;
				r.name:SetText("|cff888888" .. L("(empty)") .. "|r");
				r.del:Hide();
			end
		end
	elseif tab == "jewels" then
		local pv = c:PlanView();
		local group = e.group;
		for g, b in pairs(ed.jw.groups) do
			setLabel(b, (g == "rings" and L("Rings") or g == "trinkets" and L("Trinkets") or L("Amulet")) .. (g == group and " *" or ""));
		end
		local list = pv[group];
		ed.jw.head:SetText(L("Slots: main first, then alternatives"));
		for i, r in ipairs(ed.jw.slots) do
			local it = list[i];
			setShown(r.frame, it ~= nil);
			if it then
				r.role:SetText(it.main and string.format(L("Main %d"), i) or string.format(L("Alternative %d"), i - BM.MAIN_SLOTS[group]));
				if it.key == "" then
					r.name:SetText("|cff888888" .. L("(empty)") .. "|r");
					r.icon:Hide();
					r.clear:Hide();
				else
					r.name:SetText(fitText(it.name .. (it.known and "" or " ?"), 170, 12));
					if it.icon then r.icon:SetTexture("Interface\\Icons\\" .. it.icon); r.icon:Show(); else r.icon:Hide(); end
					setLabel(r.clear, L("Empty"));
					r.clear:Show();
					enable(r.clear, not ro);
				end
				if i == e.slot then r.bg:Show(); else r.bg:Hide(); end
			end
		end
		ed.jw.hint:SetText(L("Click a slot, then Place a piece from the list."));
	else
		ed.nt.notesLabel:SetText(string.format(L("Notes (%s)"), c:PhaseTitle(e.phase)));
		local ph = d.phases[e.phase];
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
		ed.nt.keptHead:SetText("");
		local hidden = c:HiddenData();
		ed.nt.warn:SetText(units > ns.PlannerCodec.SITE.notes and L("The official planner cuts notes beyond 2000 characters.") or "");
		for i, k in ipairs(ed.nt.kept) do k:SetText(hidden[i] and fitText(hidden[i], 740, 10) or (i == 1 and #hidden == 0 and L("No hidden data in this build.") or "")); end
		setShown(ed.nt.label, c:ShowAllPhases());
		setShown(ed.nt.labelLabel, c:ShowAllPhases());
	end
end

-- ------------------------------------------------------------------ import view
function UI:BuildImport(v)
	local c = self.c;
	local im = {};
	self.im = im;
	im.head = text(v, 0, 4, 740, "GameFontNormal");
	im.box = multiline(v, "RebornBuildPlannerImportBox", CW, 70, 0, 24, nil);
	im.analyze = button(v, "", 140, 24, 0, 102, function() c:AnalyzeImport(im.box:GetText()); end);
	im.hint = text(v, 150, 106, 590, "GameFontNormalSmall");
	im.name = text(v, 0, 140, 700, "GameFontNormalLarge", "LEFT", 18);
	im.class = text(v, 0, 160, 360, "GameFontNormal");
	im.state = text(v, 370, 160, 370, "GameFontNormal", "RIGHT");
	im.phases = {};
	for i = 1, 4 do im.phases[i] = text(v, 0, 180 + (i - 1) * 16, 740, "GameFontHighlightSmall"); end
	im.issues = {};
	for i = 1, ns.Controller.ISSUE_PAGE do im.issues[i] = text(v, 0, 250 + (i - 1) * 16, 740, "GameFontNormalSmall"); end
	im.pager = pager(v, 0, 350, function() c:SetImportPage(c.state.import.page - 1); end, function() c:SetImportPage(c.state.import.page + 1); end);
	im.loss = text(v, 200, 354, 540, "GameFontNormalSmall");
	im.classCycle = cycler(v, 0, 380, 300, function() self:CycleImportClass(-1); end, function() self:CycleImportClass(1); end);
	im.nameLabel = text(v, 310, 384, 70, "GameFontNormal");
	im.nameEdit = edit(v, 160, 380, 380, function(t) c:SetImportName(t); end, "RebornBuildPlannerImportName");
	im.commit = button(v, "", 170, 28, 548, 378, function() local id = c:CommitImport(); if id then c.state.import = nil; c:SetView("library", true); end end);
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
		for i, w in ipairs(im.phases) do w:SetText(""); end
	else
		if pv.kind == "talents" then
			im.name:SetText(L("Talent string only"));
			im.class:SetText(pv.talents);
			im.state:SetText(st.class and L("Ready") or L("Choose a class"));
			im.state:SetTextColor(0.4, 1, 0.5);
			im.classCycle.label:SetText(st.class and c:ClassName(st.class) or L("Class?"));
			for i, w in ipairs(im.phases) do w:SetText(""); end
		else
			im.name:SetText(fitText(pv.name ~= "" and pv.name or L("(no name)"), 700, 16));
			im.class:SetText(L("Class:") .. " " .. c:ClassName(pv.class) .. (pv.classKnown and "" or " (" .. L("unknown") .. ")"));
			im.state:SetText(pv.status == "ready" and L("Ready to import") or L("Importable, needs repair"));
			local col = pv.status == "ready" and COLOR.info or COLOR.warn;
			im.state:SetTextColor(col[1], col[2], col[3]);
			for i, w in ipairs(im.phases) do
				local p = pv.phases[i];
				w:SetText(p.empty and string.format(L("%s: empty"), L(BM.DEFAULT_LABELS[i])) or fitText(string.format(L("%s: %d spell(s), %d banish, %d ring(s), %d trinket(s), %d amulet(s)"),
					p.label ~= "" and p.label or L(BM.DEFAULT_LABELS[i]), p.spells, p.banish, p.rings, p.trinkets, p.amulets), 740, 10));
			end
		end
	end
	local list = c:ImportIssues();
	local first = (st.page - 1) * ns.Controller.ISSUE_PAGE;
	for i, w in ipairs(im.issues) do
		local it = list[first + i];
		if it then
			local tag = it.level == "error" and L("Error") or it.level == "conflict" and L("Conflict") or L("Notice");
			w:SetText(fitText(tag .. ": " .. it.message .. (it.key and (" [" .. tostring(it.key) .. "]") or ""), 740, 10));
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
	im.loss:SetText(loss > 0 and string.format(L("%d thing(s) the official planner would not keep if exported back"), loss) or "");
end

-- ------------------------------------------------------------------ export view
function UI:BuildExport(v)
	local c = self.c;
	local ex = {};
	self.ex = ex;
	ex.head = text(v, 0, 4, 740, "GameFontNormalLarge", "LEFT", 18);
	ex.state = text(v, 0, 28, 740, "GameFontNormal");
	ex.rows = {};
	for i = 1, ns.Controller.ISSUE_PAGE do ex.rows[i] = text(v, 0, 54 + (i - 1) * 18, 740, "GameFontNormalSmall"); end
	ex.pager = pager(v, 0, 166, function() c:SetExportPage(c.state.export.page - 1); end, function() c:SetExportPage(c.state.export.page + 1); end);
	ex.accept = button(v, "", 380, 26, 200, 164, function() c:AcceptLosses(); end);
	ex.codeLabel = text(v, 0, 204, 740, "GameFontNormal");
	ex.box = multiline(v, "RebornBuildPlannerExportBox", CW, 110, 0, 224, nil, true);
	ex.hint = text(v, 0, 340, 740, "GameFontNormalSmall");
	ex.back = button(v, "", 160, 26, 0, 380, function() self:GoLibrary(); end);
end

function UI:RefreshExport()
	local c, ex = self.c, self.ex;
	local x = c.state.export;
	if not x then return; end
	local b = x.build;
	ex.head:SetText(string.format(L("Export: %s"), fitText(b.name ~= "" and b.name or L("(no name)"), 520, 16)));
	local r = x.report;
	local losses = c:ExportLosses();
	local first = (x.page - 1) * ns.Controller.ISSUE_PAGE;
	for i, w in ipairs(ex.rows) do
		local it = losses[first + i];
		if it then
			local tag = it.severity == "intent" and L("Lost") or L("Info");
			w:SetText(fitText(tag .. ": " .. it.message .. (it.key and (" [" .. tostring(it.key) .. "]") or ""), 740, 10));
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
		ex.state:SetText(L("Nothing of your intent is lost in the official format (to verify on the site)."));
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
	local c = self.c;
	local m = CreateFrame("Frame", "RebornBuildPlannerModal", UIParent);
	self.modal = m;
	m:SetWidth(460);
	m:SetHeight(220);
	m:SetFrameStrata("FULLSCREEN_DIALOG");
	m:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	m:SetClampedToScreen(true);
	m:EnableMouse(true);
	m:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } });
	m:Hide();
	m.title = text(m, 24, 20, 412, "GameFontNormalLarge", "LEFT", 18);
	m.body = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	m.body:SetPoint("TOPLEFT", m, "TOPLEFT", 24, -48);
	m.body:SetWidth(412);
	m.body:SetHeight(70);
	m.body:SetJustifyH("LEFT");
	m.body:SetJustifyV("TOP");
	m.edit = edit(m, 300, 28, 124, function(t) m.value = t; end, "RebornBuildPlannerModalEdit");
	m.cycle = cycler(m, 28, 124, 300, function() self:ModalClass(-1); end, function() self:ModalClass(1); end);
	m.b = {};
	for i = 1, 3 do
		m.b[i] = button(m, "", 130, 26, 24 + (i - 1) * 140, 172, function() self:ModalChoose(i); end);
	end
	m:SetScript("OnHide", function() self:SyncEscape(); end);
end

-- spec = { title, body, edit = initial text|nil, class = key|nil (shows a class cycler), buttons = { label... }, onChoose = fn(index, value, class) }
function UI:ShowModal(spec)
	self:Build();
	local m = self.modal;
	m.spec, m.value, m.class = spec, spec.edit, spec.class;
	m.title:SetText(spec.title);
	m.body:SetText(spec.body or "");
	setShown(m.edit, spec.edit ~= nil);
	if spec.edit ~= nil then m.edit:SetText(spec.edit); end
	setShown(m.cycle.prev, spec.class ~= nil); setShown(m.cycle.next, spec.class ~= nil); setShown(m.cycle.label, spec.class ~= nil);
	if spec.class then m.cycle.label:SetText(self.c:ClassName(spec.class)); end
	for i = 1, 3 do
		local label = spec.buttons[i];
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
function UI:AskCreate()
	local c = self.c;
	self:ShowModal({ title = L("Create a build"), body = L("Give it a name and choose its class. It will not be active until you follow it."),
		edit = "", class = c:DefaultClass(), buttons = { L("Create"), L("Cancel") }, cancelIndex = 2,
		onChoose = function(i, value, class)
			if i == 1 then
				local id = c:Create(value or "", class);
				if id then self:OpenEditor(id); end
			end
		end });
end

function UI:AskRename(r)
	local c = self.c;
	self:ShowModal({ title = L("Rename"), body = L("New name for this build:"), edit = r.name, buttons = { L("Rename"), L("Cancel") }, cancelIndex = 2,
		onChoose = function(i, value) if i == 1 then c:Rename(r.id, value or ""); end end });
end

function UI:AskDelete(r)
	local c = self.c;
	local info = c:DeleteInfo(r.id);
	local body = string.format(L("\"%s\" will go to the trash and can be restored (the trash keeps 20 builds: when it is full, the oldest one is removed for good)."), info.name);
	if info.trashSize >= info.cap then body = body .. "\n" .. L("The trash is full: deleting will remove the oldest deleted build for good."); end
	self:ShowModal({ title = L("Delete this build?"), body = body, buttons = { L("Delete"), L("Cancel") }, cancelIndex = 2,
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
	self.c:SetView("library");
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
	self.title:SetText("Reborn Build Planner");
	setLabel(self.nav.library, L("My builds"));
	setLabel(self.nav.editor, L("Editor"));
	setLabel(self.nav.import, L("Import"));
	setLabel(self.nav.export, L("Export"));
	setLabel(self.sizeMinus, L("Size -"));
	setLabel(self.sizePlus, L("Size +"));
	enable(self.nav.editor, c:Editor() ~= nil);
	enable(self.nav.export, st.export ~= nil);
	local ro = c:StorageStatusText();
	self.banner:SetText(ro or "");
	for name, f in pairs(self.views) do setShown(f, name == st.view); end
	local msg = st.message;
	if st.view == "editor" then
		self.msg:SetText("");     -- the editor shows its own message line
	else
		self.msg:SetText(msg and fitText(msg.text, 520, 12) or "");
		if msg then self.msg:SetTextColor(unpack(COLOR[msg.level])); end
	end
	setShown(self.undoBtn, st.undo ~= nil);
	if st.undo then setLabel(self.undoBtn, L("Undo the deletion")); end
	if st.view == "library" then self:RefreshLibrary();
	elseif st.view == "editor" then self:RefreshEditor();
	elseif st.view == "import" then self:RefreshImport();
	elseif st.view == "export" then self:RefreshExport(); end
	self:SyncEscape();
end
