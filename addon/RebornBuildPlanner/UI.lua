-- Native window (Lot 3.3): ONE window, a thin renderer over Controller.
--   left   : LibraryPane   (search, filters, sort, favourites, scrollable build list, actions)
--   centre : EditorPane    (name, status, six spells with banish-after marks, twelve equipment slots)
--            DetailPane    (bottom of the centre: details of the selected element and its actions) -- or the
--                          advanced block (notes, link, talents, stage name, avoid list, kept data)
--            Import / Export forms replace the whole centre
--   right  : BrowserPane   (permanent browser: Spells / Rings / Trinkets / Amulets, search, scrollable list)
-- Standard 3.3.5a widgets only (the ones the native Reborn addons use; flat Buttons with their own label like
-- FieldKit's, plain Sliders like AzerothSurvivors' EditorKit). Every widget is created ONCE (on first open) and
-- reused: lists are fixed pools of rows over a scroll offset, nothing is created while the player works, there is
-- no OnUpdate. No clipboard API: export shows a selectable box (Ctrl+A, Ctrl+C), import is Ctrl+V.
local ADDON, ns = ...;
ns = ns or {};
local Locale, BM = ns.Locale, ns.BuildModel;
local THEME = ns.Theme;
assert(Locale and BM and ns.Controller, "RebornBuildPlanner: UI.lua must load after Controller.lua");
local UI = {};
ns.UI = UI;
UI.__index = UI;

local L = function(s) return Locale.T(s); end

UI.WIDTH, UI.HEIGHT = 1240, 704;
local BODY_Y, BODY_H = 58, 618;
local LP_X, LP_W = 12, 252;          -- library
local CP_X, CP_W = 272, 580;         -- editor + details / import / export
local RP_X, RP_W = 860, 368;         -- equipment browser
local EW = 562;                      -- usable width inside the centre panel
local COLOR = { info = { 0.45, 0.9, 0.55 }, warn = { 0.95, 0.78, 0.35 }, error = { 0.95, 0.4, 0.35 } };
local TONEHEX = { ok = "8fe0a0", warn = "f0c860", dim = "a8acb8" };
-- item quality colours (the game's own palette); the label always says the rarity too
local RARITY_RGB = { common = { 0.85, 0.86, 0.90 }, uncommon = { 0.12, 1, 0.2 }, rare = { 0.30, 0.62, 1 }, epic = { 0.70, 0.35, 0.95 }, legendary = { 1, 0.55, 0.1 } };
local function rarityRgb(r) return RARITY_RGB[r or ""] or RARITY_RGB.common; end
local WHITE = "Interface\\Buttons\\WHITE8X8";

-- Palette: deep ink panels, brass/gold accents, red only for destructive actions.
local BG = { 0.018, 0.045, 0.090 };
local PANEL = { 0.050, 0.095, 0.170, 1 };
local ROW_A, ROW_B = { 0.083, 0.137, 0.218, 1 }, { 0.066, 0.111, 0.185, 1 };
local ROW_SEL = { 0.22, 0.49, 0.76, 0.42 };
local GOLD = { 0.71, 0.86, 0.97 };
local BRASS = { 0.31, 0.52, 0.73, 1 };
local SKIN = {
	primary = { bg = { 0.33, 0.25, 0.09, 1 }, bd = { 0.78, 0.62, 0.28, 1 }, tx = "ffe6a0" },
	quiet = { bg = { 0.125, 0.135, 0.185, 1 }, bd = { 0.30, 0.32, 0.40, 1 }, tx = "c9ccd6" },
	warn = { bg = { 0.27, 0.21, 0.08, 1 }, bd = { 0.68, 0.54, 0.25, 1 }, tx = "ffd24d" },
	danger = { bg = { 0.21, 0.10, 0.10, 1 }, bd = { 0.48, 0.23, 0.21, 1 }, tx = "ffb0a8" },
};
local OFF = { bg = { 0.085, 0.09, 0.12, 1 }, bd = { 0.18, 0.19, 0.24, 1 } };

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
	if THEME and font == "GameFontNormal" then
		fs:SetTextColor(0.76, 0.86, 0.96); -- subdued section chrome, no yellow form labels
	end
	return fs;
end

local function wrapped(parent, x, y, w, h, font)
	local fs = text(parent, x, y, w, font, "LEFT", h);
	if fs.SetWordWrap then fs:SetWordWrap(true); end
	fs:SetJustifyV("TOP");
	return fs;
end

local function fill(f, c, layer)
	local t = f:CreateTexture(nil, layer or "BACKGROUND");
	t:SetAllPoints(f);
	t:SetTexture(c[1], c[2], c[3], c[4] or 1);
	return t;
end

-- A gold section title with a thin brass rule under it.
local function header(parent, x, y, w)
	if THEME then return THEME.SectionTitle(parent, "", x, y, w); end
	local fs = text(parent, x, y, w, "GameFontNormal");
	fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
	local rule = parent:CreateTexture(nil, "BACKGROUND");
	rule:SetWidth(w);
	rule:SetHeight(1);
	rule:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 17));
	rule:SetTexture(BRASS[1], BRASS[2], BRASS[3], 0.7);
	fs.rule = rule;
	return fs;
end

-- Flat button with its own label (no red template). Role = look; the label always says what it does.
local function button(parent, label, w, h, x, y, onClick, name)
	if THEME then
		local b = THEME.Button(parent, label, w, h, "secondary", onClick, name);
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
		b.fs = b.label;
		b.themed = true;
		return b;
	end
	local b = CreateFrame("Button", name, parent);
	b:SetWidth(w);
	b:SetHeight(h or 24);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
	local fs = b.GetFontString and b:GetFontString();
	if not fs then
		fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		fs:SetPoint("CENTER", b, "CENTER", 0, 0);
		if b.SetFontString then b:SetFontString(fs); end
	end
	b.fs = fs;
	if b.SetHighlightTexture then
		b:SetHighlightTexture(WHITE);
		local hl = b.GetHighlightTexture and b:GetHighlightTexture();
		if hl and hl.SetVertexColor then hl:SetVertexColor(1, 1, 1, 0.10); end
	end
	b:SetText(label);
	b:SetScript("OnClick", function(self) if onClick then onClick(self); end end);
	return b;
end

-- colours and label of a button from its role and enabled state; the plain label stays in b.baseLabel
local function paint(b)
	local label = b.displayLabel or b.baseLabel or "";
	if b.themed then
		if b.painted ~= label then b.painted = label; b:SetText(label); end
		local roles = { quiet = "secondary", warn = "selected", primary = "primary", danger = "danger" };
		local semanticRole = b.role or "quiet";
		local role = (b.enabledFlag == false) and "disabled" or (roles[semanticRole] or "secondary");
		THEME.SetRole(b, role);
		b.role = semanticRole; -- keep the controller's role across disabled -> enabled transitions
		return;
	end
	local sk = SKIN[b.role or "quiet"] or SKIN.quiet;
	local enabled = b.enabledFlag ~= false;
	local shown = label;
	if enabled and label ~= "" then shown = "|cff" .. sk.tx .. label .. "|r"; end
	if b.painted ~= shown then b.painted = shown; b:SetText(shown); end
	local bg, bd = enabled and sk.bg or OFF.bg, enabled and sk.bd or OFF.bd;
	if b.SetBackdropColor then b:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]); b:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4]); end
	if b.fs and b.fs.SetTextColor then if enabled then b.fs:SetTextColor(1, 1, 1); else b.fs:SetTextColor(0.45, 0.46, 0.52); end end
end

-- Ask the native font renderer to measure text instead of guessing width from
-- the number of letters. A typical Cyrillic glyph and a Latin letter may take
-- different widths depending on the client's chosen font.
local function fitFontText(fs, full, available)
	if not fs or not fs.SetText or not fs.GetStringWidth then
		return fitText(full, available, 14);
	end
	fs:SetText(full);
	if fs:GetStringWidth() <= available then return full; end
	local ellipsis = "...";
	local last, index = "", 1;
	while index <= #full do
		local byte = string.byte(full, index);
		local length = byte < 0x80 and 1 or (byte < 0xE0 and 2 or (byte < 0xF0 and 3 or 4));
		local nextText = last .. string.sub(full, index, index + length - 1);
		fs:SetText(nextText .. ellipsis);
		if fs:GetStringWidth() > available then break; end
		last = nextText;
		index = index + length;
	end
	return last .. ellipsis;
end

local function fittedButtonText(b, full)
	local available = math.max(16, (b.GetWidth and b:GetWidth() or 100) - 14);
	return fitFontText(b.fs or b.label, full, available);
end

local function setLabel(b, label)
	b.baseLabel = label or "";
	b.displayLabel = fittedButtonText(b, b.baseLabel);
	paint(b);
end

local function enable(b, on)
	if on then b:Enable(); else b:Disable(); end
	b.enabledFlag = on and true or false;
	paint(b);
end

local function setShown(f, on)
	if on then f:Show(); else f:Hide(); end
	-- Section dividers are independent textures; hiding only the label left
	-- its ornament floating in the empty editor.
	local rule = f.rule or f.separator;
	if rule then if on then rule:Show(); else rule:Hide(); end end
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
	if THEME then
		local f = THEME.Frame(parent, w, h, "panel", name);
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
		return f;
	end
	local f = CreateFrame("Frame", name, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	f:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 } });
	f:SetBackdropColor(PANEL[1], PANEL[2], PANEL[3], PANEL[4]);
	f:SetBackdropBorderColor(BRASS[1], BRASS[2], BRASS[3], BRASS[4]);
	return f;
end

local function setIcon(tex, icon)
	if icon and icon ~= "" then
		tex:SetTexture("Interface\\Icons\\" .. icon);
		tex:Show();
	else
		tex:Hide();
	end
end

-- A scrolling list: `n` pooled rows over an offset kept by the controller; the mouse wheel and a thin Slider move
-- it. onScroll(delta) / onSet(offset) call the controller. Returns { hold, slider, sync(offset, max) }.
local function scrollArea(parent, x, y, w, h, onScroll, onSet)
	local hold = CreateFrame("Frame", nil, parent);
	hold:SetWidth(w);
	hold:SetHeight(h);
	hold:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	hold:EnableMouseWheel(true);
	hold:SetScript("OnMouseWheel", function(_, delta) onScroll(delta > 0 and -3 or 3); end);
	local s = CreateFrame("Slider", nil, parent);
	s:SetWidth(8);
	s:SetHeight(h);
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x + w + 4, -y);
	s:SetOrientation("VERTICAL");
	s:SetMinMaxValues(0, 1);
	s:SetValueStep(1);
	if s.SetThumbTexture then          -- same calls as AzerothSurvivors' EditorKit scroll bar
		s:SetThumbTexture(WHITE);
		local thumb = s.GetThumbTexture and s:GetThumbTexture();
		if thumb then
			thumb:SetWidth(8);
			thumb:SetHeight(30);
			if thumb.SetVertexColor then thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.75); end
		end
	end
	local track = s:CreateTexture(nil, "BACKGROUND");
	track:SetAllPoints(s);
	track:SetTexture(1, 1, 1, 0.06);
	s:SetScript("OnValueChanged", function(self, v) if not self.syncing then onSet(math.floor(v + 0.5)); end end);
	local area = { hold = hold, slider = s };
	function area.sync(offset, max)
		s.syncing = true;
		s:SetMinMaxValues(0, math.max(1, max));
		s:SetValue(offset);
		s.syncing = nil;
		if max > 0 then s:Show(); else s:Hide(); end
	end
	return area;
end

-- ------------------------------------------------------------------ tooltips (hover only, one shared GameTooltip)
local TONE = { ok = { 0.55, 0.9, 0.62 }, warn = { 0.95, 0.78, 0.35 }, dim = { 0.66, 0.68, 0.72 } };

-- Draws tooltip data { title, icon, spellId, lines } over `owner`. For a spell with a game id the game's own spell
-- tooltip comes first (read once, on hover, never kept); our lines follow. No value is invented here.
function UI:ShowTip(owner, d)
	local tt = GameTooltip;
	if not d or not tt then return; end
	-- Short preview only (the full text lives in the Details panel). The anchor flips to the left in the right-hand
	-- half of the screen so the tooltip stays on screen and off the controls it describes. The game's own spell text is
	-- never mixed in here: it is shown, alone, in the Details panel.
	local anchor = "ANCHOR_RIGHT";
	if owner.GetLeft and UIParent.GetWidth then
		local left = owner:GetLeft();
		if left and left * (owner.GetEffectiveScale and owner:GetEffectiveScale() or 1)
			> UIParent:GetWidth() * (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1) * 0.5 then
			anchor = "ANCHOR_LEFT";
		end
	end
	tt:SetOwner(owner, anchor);
	if tt.ClearLines then tt:ClearLines(); end
	local head = (d.icon and d.icon ~= "") and ("|TInterface\\Icons\\" .. d.icon .. ":16|t ") or "";
	local rc = rarityRgb(d.rarity);
	tt:AddLine(head .. fitText(d.title, 300, 14), rc[1], rc[2], rc[3], true);
	local n = 1;
	local function add(text, tone)
		if n >= UI.TIP_LINES then return; end
		local col = TONE[tone] or { 1, 1, 1 };
		tt:AddLine(fitText(text, 340, 12), col[1], col[2], col[3], true);
		n = n + 1;
	end
	if d.subtitle then add(d.subtitle, "dim"); end
	-- The hovered item's actual bonus is the useful first thing to read.
	-- State such as "Placed: main 1" comes afterward.
	if d.preview and d.preview[1] then
		for _, t in ipairs(d.preview) do add(t); end
	elseif d.sections == nil and (d.kind ~= "help") then
		for _, ln in ipairs(d.facts or d.lines or {}) do add(ln.text, ln.tone); end
	end
	for _, ln in ipairs(d.state or {}) do add(ln.text, ln.tone); end
	if d.helpLines then for _, ln in ipairs(d.helpLines) do add(ln.text, ln.tone); end end
	if d.moreHint ~= false and d.kind ~= "help" then add(L("Click for the full details."), "dim"); end
	tt:Show();
	self.tipOwner = owner;
end
UI.TIP_LINES = 7;

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
	up = { "Move up", { "Raises this spell's priority by one." } },
	down = { "Move down", { "Lowers this spell's priority by one." } },
	del = { "Remove spell", { "Removes this spell from the plan, and its banish-after mark with it." } },
};

function UI:HelpLines(list)
	local out = {};
	for i, s in ipairs(list) do out[i] = { text = L(s), tone = i == 1 and nil or "dim" }; end
	return out;
end

local function helpData(self, key)
	local lines = self:HelpLines(HELP[key][2]);
	return { title = L(HELP[key][1]), lines = lines, helpLines = lines, kind = "help", moreHint = false };
end

-- ------------------------------------------------------------------ construction
function UI.New(controller, env)
	local self = setmetatable({ c = controller, env = env or ns, built = false }, UI);
	controller:Subscribe(function() self:Refresh(); end);
	return self;
end

function UI:HideLanguageMenu()
	self.languageMenuOpen = false;
	if self.languageMenu then self.languageMenu:Hide(); end
	if self.languageDismiss then self.languageDismiss:Hide(); end
end

function UI:ShowLanguageMenu()
	if not self.languageMenu or self.c:ReadOnly() then return; end
	self.languageMenuOpen = true;
	local current = ns.Locale.Selection();
	for i, item in ipairs(ns.Locale.LANGUAGES) do
		local row = self.languageMenu.buttons[i];
		local selected = item.code == current;
		row.role = selected and "selected" or "quiet";
		setLabel(row, (selected and "  >  " or "      ") .. item.label);
	end
	if self.languageDismiss then self.languageDismiss:Show(); end
	self.languageMenu:Show();
end

function UI:Frame() return self.root; end
function UI:IsShown() return self.root ~= nil and self.root:IsShown(); end

function UI:Build()
	if self.built then return; end
	self.built = true;
	local c = self.c;
	local root = THEME and THEME.Window(UIParent, UI.WIDTH, UI.HEIGHT, "RebornBuildPlannerFrame") or CreateFrame("Frame", "RebornBuildPlannerFrame", UIParent);
	self.root = root;
	root:SetWidth(UI.WIDTH);
	root:SetHeight(UI.HEIGHT);
	root:SetFrameStrata(THEME and "FULLSCREEN_DIALOG" or "DIALOG"); -- respect theme stacking
	root:SetFrameLevel(THEME and 100 or 20);
	if not THEME then
		root:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		root:SetBackdropColor(BG[1], BG[2], BG[3], 1);
		root:SetBackdropBorderColor(0.70, 0.58, 0.30, 1);
	end
	root:SetClampedToScreen(true);
	root:SetMovable(true);
	root:EnableMouse(true);
	root:RegisterForDrag("LeftButton");
	root:SetScript("OnDragStart", function(f) f:StartMoving(); end);
	root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing(); self:SavePosition(); end);
	root:SetScript("OnHide", function() self:HideTip(); self:HideLanguageMenu(); self:SyncEscape(); end);
	root:Hide();

	if THEME then
		self.titleBar = THEME.TitleBar(root, "Reborn Build Planner", 8, 5, 310, 40);
		self.title = self.titleBar.title;
	else
		self.title = text(root, 20, 12, 300, "GameFontNormalLarge", "LEFT", 18);
		self.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
	end
	local close = button(root, "X", 28, 22, 1204, 8, function() self:RequestClose(); end, "RebornBuildPlannerClose");
	close.role = "danger";
	self.close = close;
	self.nav = {
		import = button(root, "", 96, 24, 330, 8, function() c:SetView("import"); end),
		export = button(root, "", 96, 24, 430, 8, function()
			local e = c:Editor();
			if e then c:PrepareExport(e.id, "draft"); c:SetView("export");
			elseif c.state.export then c:SetView("export"); end
		end),
	};
	-- Dropdown matches the Reborn locale list. Missing locale dictionaries fall back
	-- per string to English; a selection never implies a completed translation.
	self.languageMenuOpen = false;
	self.languageButton = button(root, "", 184, 24, 546, 8, function()
		if self.languageMenuOpen then self:HideLanguageMenu(); else self:ShowLanguageMenu(); end
	end);
	self.languageButton.role = "quiet";
	local locales = ns.Locale.LANGUAGES;
	self.languageMenu = panel(root, "RebornBuildPlannerLanguageMenu", 546, 35, 244, #locales * 24 + 16);
	self.languageMenu:SetFrameStrata("FULLSCREEN_DIALOG");
	self.languageMenu:SetFrameLevel(139);
	self.languageMenu:EnableMouse(true);
	self.languageMenu.buttons = {};
	for index, item in ipairs(locales) do
		local code = item.code;
		local row = button(self.languageMenu, item.label, 224, 22, 10, 8 + (index - 1) * 24, function()
			local h = c:Handle();
			if not h or h.readOnly then return; end
			if h:SetSetting("lang", code) then
				ns.Locale.SetLang(code);
				self:HideLanguageMenu();
				c:Notify();
			end
		end);
		row.role = "quiet";
		row:SetFrameLevel(145);
		self.languageMenu.buttons[index] = row;
	end
	self.languageMenu:Hide();
	-- Capture clicks outside the dropdown without activating an unrelated control.
	self.languageDismiss = CreateFrame("Frame", nil, root);
	self.languageDismiss:SetAllPoints(root);
	self.languageDismiss:SetFrameStrata("FULLSCREEN_DIALOG");
	self.languageDismiss:SetFrameLevel(134);
	self.languageDismiss:EnableMouse(true);
	self.languageDismiss:SetScript("OnMouseDown", function() self:HideLanguageMenu(); end);
	self.languageDismiss:Hide();
	self.sizeMinus = button(root, "", 84, 24, 1026, 8, function() self:Rescale(-0.1); end);
	self.sizePlus = button(root, "", 84, 24, 1114, 8, function() self:Rescale(0.1); end);
	self.banner = text(root, 20, 38, 1180, "GameFontNormal", "LEFT");
	self.banner:SetTextColor(COLOR.error[1], COLOR.error[2], COLOR.error[3]);
	self.msg = text(root, 20, 684, 980, "GameFontNormal", "LEFT");
	self.undoBtn = button(root, "", 200, 22, 1026, 679, function() c:UndoDelete(); end);
	self.undoBtn.role = "warn";

	self.leftPanel = panel(root, "RebornBuildPlannerLibrary", LP_X, BODY_Y, LP_W, BODY_H);
	self.centre = panel(root, "RebornBuildPlannerEditor", CP_X, BODY_Y, CP_W, BODY_H);
	self.rightPanel = panel(root, "RebornBuildPlannerBrowser", RP_X, BODY_Y, RP_W, BODY_H);
	local function mode(name)
		local f = panel(root, "RebornBuildPlanner" .. name, CP_X, BODY_Y, CP_W, BODY_H);
		f:Hide();
		return f;
	end
	self.views = { editor = self.centre, import = mode("Import"), export = mode("Export") };
	self:BuildLibrary(self.leftPanel);
	self:BuildEditor(self.centre);
	self:BuildDetail(self.centre);
	self:BuildBrowser(self.rightPanel);
	self:BuildImport(self.views.import);
	self:BuildExport(self.views.export);
	self:BuildModal();
end

-- ------------------------------------------------------------------ LibraryPane (left)
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
	lib.searchLabel = text(v, 8, 12, 90, "GameFontNormal");
	lib.search = edit(v, 146, 98, 8, function(t) c:SetLibSearch(t); end, "RebornBuildPlannerLibSearch");
	lib.filters = {
		all = button(v, "", 62, 22, 8, 36, function() c:SetFilter("all"); end),
		favorites = button(v, "", 92, 22, 70, 36, function() c:SetFilter("favorites"); end),
		recent = button(v, "", 82, 22, 162, 36, function() c:SetFilter("recent"); end),
	};
	lib.classCycle = cycler(v, 8, 64, 236, function() c:CycleClassFilter(-1); end, function() c:CycleClassFilter(1); end, "GameFontNormalSmall");
	lib.sortCycle = cycler(v, 8, 90, 236, function() c:CycleSort(-1); end, function() c:CycleSort(1); end, "GameFontNormalSmall");
	lib.area = scrollArea(v, 8, 120, 220, 360, function(d) c:ScrollLib(d); end, function(o) c:SetLibOffset(o); end);
	lib.rows = {};
	for i = 1, ns.Controller.LIB_ROWS do
		local r = CreateFrame("Button", "RebornBuildPlannerRow" .. i, lib.area.hold);
		r:SetWidth(220);
		r:SetHeight(34);
		r:SetPoint("TOPLEFT", lib.area.hold, "TOPLEFT", 0, -((i - 1) * 36));
		r.base = fill(r, i % 2 == 0 and ROW_B or ROW_A);
		r.bg = r:CreateTexture(nil, "BORDER");
		r.bg:SetAllPoints(r);
		r.bg:SetTexture(ROW_SEL[1], ROW_SEL[2], ROW_SEL[3], ROW_SEL[4]);
		r.bg:Hide();
		r.name = text(r, 32, 3, 136, "GameFontHighlight");
		r.tag = text(r, 168, 5, 48, "GameFontNormalSmall", "RIGHT");
		r.sub = text(r, 32, 19, 186, "GameFontNormalSmall");
		r.sub:SetTextColor(0.66, 0.68, 0.74);
		r.star = button(r, "", 24, 22, 3, 6, function() local id = r.rowId; if id then c:ToggleFavorite(id); end end);
		r:SetScript("OnClick", function(f) if f.rowId then self:ClickRow(f); end end);
		self:Hover(r.star, function() return helpData(self, "star"); end);
		lib.rows[i] = r;
	end
	lib.empty = wrapped(v, 12, 160, 212, 80, "GameFontNormal");
	lib.create = button(v, "", 236, 28, 8, 494, function() self:AskCreate(); end);
	lib.follow = button(v, "", 78, 24, 8, 530, function()
		local r = c:Selected();
		if r then if r.active then c:Deactivate(r.id); else c:Activate(r.id); end end
	end);
	lib.dup = button(v, "", 82, 24, 88, 530, function() local r = c:Selected(); if r then c:Duplicate(r.id); end end);
	lib.rename = button(v, "", 72, 24, 172, 530, function() local r = c:Selected(); if r then self:AskRename(r); end end);
	lib.importBtn = button(v, "", 72, 24, 8, 560, function() c:SetView("import"); end);
	lib.trashBtn = button(v, "", 84, 24, 84, 560, function() c:ShowTrash(not c.state.trashMode); end);
	lib.delete = button(v, "", 80, 24, 172, 560, function() local r = c:Selected(); if r then self:AskDelete(r); end end);
	lib.restore = button(v, "", 160, 24, 8, 530, function() local r = c:Selected(); if r then c:Restore(r.id); end end);
	lib.create.role, lib.follow.role, lib.restore.role = "primary", "primary", "primary";
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
	lib.classCycle.label:SetText(fitText(L("Class:") .. " " .. (st.classFilter and c:ClassName(st.classFilter) or L("All classes")), 180, 13));
	local sortNames = { name = L("Name"), used = L("Last used"), modified = L("Last modified") };
	lib.sortCycle.label:SetText(fitText(L("Sort:") .. " " .. sortNames[c:Sort()], 180, 13));
	setShown(lib.sortCycle.prev, not st.trashMode); setShown(lib.sortCycle.next, not st.trashMode); setShown(lib.sortCycle.label, not st.trashMode);
	local rows, off, max = c:LibView();
	lib.area.sync(off, max);
	local sel = st.selectedId;
	local edId = st.editor and st.editor.id;
	for i, r in ipairs(lib.rows) do
		local d = rows[i];
		if d then
			r.rowId, r.trashed = d.id, d.trashed;
			r.name:SetText(fitText(d.name ~= "" and d.name or L("(no name)"), 136, 12));
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
			r.sub:SetText(fitText(d.className .. when, 186, 10));
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

-- ------------------------------------------------------------------ EditorPane (centre, top)
local EQUIP_Y = { rings = 286, trinkets = 332, amulets = 378 };
local EQUIP_GROUPS = { "rings", "trinkets", "amulets" };
local CELL_W, CELL_H, CELL_X0 = 118, 44, 66;

function UI:BuildEditor(v)
	local c = self.c;
	local ed = {};
	self.ed = ed;
	ed.empty = wrapped(v, 40, 200, EW - 60, 80, "GameFontNormalLarge");
	-- header: name, class, favourite, status, actions
	ed.nameLabel = text(v, 8, 12, 80, "GameFontNormal");
	ed.name = edit(v, 196, 94, 8, function(t) c:SetName(t); end, "RebornBuildPlannerName");
	ed.class = text(v, 294, 13, 130, "GameFontNormal");
	ed.fav = button(v, "", 132, 24, 430, 7, function() local e = c:Editor(); if e then c:ToggleFavorite(e.id); end end);
	ed.save = button(v, "", 96, 24, 8, 36, function() c:Save(); end);
	ed.follow = button(v, "", 176, 24, 108, 36, function() c:SaveAndFollow(); end);
	ed.revert = button(v, "", 124, 24, 288, 36, function() c:Revert(); end);
	ed.status = text(v, 416, 34, 154, "GameFontNormal", "RIGHT", 28);
	if ed.status.SetWordWrap then ed.status:SetWordWrap(true); end
	ed.save.role, ed.follow.role = "primary", "primary";
	-- stages and advanced toggle
	ed.phaseInfo = text(v, 8, 68, 236, "GameFontNormal");
	ed.addPhases = button(v, "", 130, 22, 248, 64, function() c:RevealPhases(); end);
	ed.phaseTabs = {};
	for p = 1, 4 do
		ed.phaseTabs[p] = button(v, "", 92, 22, 8 + (p - 1) * 94, 64, function() c:SetPhase(p); end);
	end
	ed.adv = button(v, "", 170, 22, 392, 64, function() c:ToggleAdvanced(); end);
	-- spells: number | icon | name | keep/banish-after | compact move and remove controls
	ed.spellHead = header(v, 8, 92, 280);
	ed.summary = text(v, 292, 92, 270, "GameFontNormal", "RIGHT");
	ed.spells = {};
	for i = 1, 6 do
		local r = { frame = CreateFrame("Frame", nil, v) };
		local y = 114 + (i - 1) * 24;
		r.frame:SetWidth(EW);
		r.frame:SetHeight(22);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -y);
		r.bg = fill(r.frame, i % 2 == 0 and ROW_B or ROW_A);
		r.num = text(r.frame, 6, 4, 20, "GameFontNormal");
		r.num:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
		r.icon = r.frame:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(18); r.icon:SetHeight(18);
		r.icon:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 28, -2);
		r.name = text(r.frame, 52, 4, 258, "GameFontHighlight");
		r.hit = hitArea(r.frame, 26, 0, 284, 22);
		r.add = button(r.frame, "", 190, 20, 52, 1, function() c:AddSpellTarget(); end);
		r.tog = button(r.frame, "", 108, 20, 316, 1, function() local k = r.key; if k then c:ToggleBanishAfter(k); end end);
		r.up = button(r.frame, "", 24, 20, 430, 1, function() c:MoveSpell(i, -1); end);
		r.down = button(r.frame, "", 24, 20, 456, 1, function() c:MoveSpell(i, 1); end);
		r.del = button(r.frame, "", 24, 20, 482, 1, function() local k = r.key; if k then c:RemoveSpell(k); end end);
		r.hit:SetScript("OnClick", function() if r.key then c:Inspect("spell", r.key); end end);
		self:Hover(r.hit, function() return r.key and c:TooltipData("spell", r.key) or nil; end);
		self:Hover(r.tog, function() return r.key and helpData(self, "toggle") or nil; end);
		self:Hover(r.up, function() return helpData(self, "up"); end);
		self:Hover(r.down, function() return helpData(self, "down"); end);
		self:Hover(r.del, function() return helpData(self, "del"); end);
		ed.spells[i] = r;
	end
	-- equipment: one row per kind. Each slot is a fixed 118 x 44 cell with RESERVED zones (top strip: role + remove button;
	-- below: 24 px icon, then a bounded two-line name). Main and alternative slots are separated by a brass rule.
	ed.equipHead = header(v, 8, 264, EW);
	ed.groups = {};
	for _, g in ipairs(EQUIP_GROUPS) do
		local mains = BM.MAIN_SLOTS[g];
		local grp = { label = text(v, 8, EQUIP_Y[g] + 16, 64, "GameFontNormal"), cells = {} };
		grp.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
		grp.sep = v:CreateTexture(nil, "ARTWORK");
		grp.sep:SetWidth(2);
		grp.sep:SetHeight(CELL_H);
		grp.sep:SetPoint("TOPLEFT", v, "TOPLEFT", 8 + CELL_X0 + mains * (CELL_W + 2) + 2, -EQUIP_Y[g]);
		grp.sep:SetTexture(BRASS[1], BRASS[2], BRASS[3], 0.8);
		for j = 1, BM.LIMITS[g] do
			local cell = CreateFrame("Button", nil, v);
			cell:SetWidth(CELL_W);
			cell:SetHeight(CELL_H);
			cell:SetPoint("TOPLEFT", v, "TOPLEFT", 8 + CELL_X0 + (j - 1) * (CELL_W + 2) + (j > mains and 8 or 0), -EQUIP_Y[g]);
			cell.base = fill(cell, ROW_A);
			cell.edge = cell:CreateTexture(nil, "BORDER");           -- brass frame of the slot when it is chosen
			cell.edge:SetAllPoints(cell);
			cell.edge:SetTexture(0.85, 0.68, 0.30, 0.9);
			cell.edge:Hide();
			cell.role = text(cell, 5, 2, 84, "GameFontNormalSmall");
			cell.x = button(cell, "", 22, 14, CELL_W - 24, 2, function() c:ClearSlot(g, j); end);
			cell.icon = cell:CreateTexture(nil, "OVERLAY");
			cell.icon:SetWidth(24); cell.icon:SetHeight(24);
			cell.icon:SetPoint("TOPLEFT", cell, "TOPLEFT", 4, -18);
			cell.name = wrapped(cell, 32, 18, 82, 24, "GameFontHighlightSmall");
			cell:SetScript("OnClick", function() c:SelectSlot(g, j); end);
			self:Hover(cell, function()
				local k = cell.key;
				local d = k and k ~= "" and c:TooltipData(g == "amulets" and "amulet" or "jewel", k) or nil;
				return d or helpData(self, "slots");
			end);
			grp.cells[j] = cell;
		end
		ed.groups[g] = grp;
	end
	-- advanced block (replaces the detail area when open)
	local nt = {};
	ed.nt = nt;
	nt.head = header(v, 8, 430, EW);
	nt.counter = text(v, 400, 432, 160, "GameFontNormalSmall", "RIGHT");
	nt.notes = multiline(v, "RebornBuildPlannerNotes", EW, 52, 8, 452, function(t) c:SetNotes(t); end);
	nt.linkLabel = text(v, 8, 512, 50, "GameFontNormal");
	nt.link = edit(v, 230, 58, 508, function(t) c:SetLink(t); end, "RebornBuildPlannerLink");
	nt.talentsLabel = text(v, 300, 512, 66, "GameFontNormal");
	nt.talents = edit(v, 190, 370, 508, function(t) c:SetTalents(t); end, "RebornBuildPlannerTalents");
	nt.labelLabel = text(v, 8, 540, 120, "GameFontNormal");
	nt.label = edit(v, 150, 130, 536, function(t) c:SetLabel(t); end, "RebornBuildPlannerLabel");
	nt.warn = text(v, 300, 540, 260, "GameFontNormalSmall", "LEFT", 14);
	nt.warn:SetTextColor(COLOR.warn[1], COLOR.warn[2], COLOR.warn[3]);
	nt.avoidHead = text(v, 8, 564, EW, "GameFontNormalSmall");
	nt.avoid = {};
	for i = 1, 3 do
		local r = { frame = CreateFrame("Frame", nil, v) };
		r.frame:SetWidth(180);
		r.frame:SetHeight(22);
		r.frame:SetPoint("TOPLEFT", v, "TOPLEFT", 8 + (i - 1) * 190, -580);
		r.bg = fill(r.frame, ROW_A);
		r.name = text(r.frame, 4, 5, 80, "GameFontHighlightSmall");
		r.hit = hitArea(r.frame, 0, 0, 86, 22);
		r.conv = button(r.frame, "", 66, 20, 88, 1, function() local k = r.key; if k then c:ConvertBanishToAfter(k); end end);
		r.del = button(r.frame, "", 24, 20, 154, 1, function() local k = r.key; if k then c:RemoveBanish(k); end end);
		r.conv.role = "primary";
		self:Hover(r.hit, function() return r.key and c:TooltipData("spell", r.key) or nil; end);
		self:Hover(r.conv, function() return helpData(self, "convert"); end);
		nt.avoid[i] = r;
	end
	nt.kept = text(v, 8, 608, EW, "GameFontNormalSmall");
end

function UI:RefreshEditor()
	local c, ed = self.c, self.ed;
	local e = c:Editor();
	local on = e ~= nil;
	for _, w in ipairs({ ed.nameLabel, ed.name, ed.class, ed.status, ed.save, ed.follow, ed.revert, ed.fav, ed.phaseInfo, ed.addPhases, ed.adv,
		ed.spellHead, ed.summary, ed.equipHead }) do
		setShown(w, on);
	end
	setShown(ed.empty, not on);
	local adv = on and e.adv;
	for _, w in ipairs({ ed.nt.head, ed.nt.counter, ed.nt.notes.scroll, ed.nt.linkLabel, ed.nt.link, ed.nt.talentsLabel, ed.nt.talents,
		ed.nt.warn, ed.nt.avoidHead, ed.nt.kept }) do setShown(w, adv); end
	if not on then
		ed.empty:SetText(L("Pick a build in the library, or create one."));
		for _, r in ipairs(ed.spells) do r.frame:Hide(); end
		for _, g in pairs(ed.groups) do
			g.label:Hide();
			g.sep:Hide(); -- independent vertical divider, not a child of any cell
			for _, cell in ipairs(g.cells) do cell:Hide(); end
		end
		for _, b in ipairs(ed.phaseTabs) do b:Hide(); end
		for _, w in ipairs({ ed.nt.labelLabel, ed.nt.label }) do w:Hide(); end
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
	ed.fav.role = favNow and "warn" or "quiet";
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
		ed.phaseTabs[p].role = (p == e.phase) and "warn" or "quiet";
		setLabel(ed.phaseTabs[p], fitText(c:PhaseTitle(p), 66, 12) .. (p == e.phase and " *" or ""));
	end
	if not many then e.phase = 1; end
	ed.adv.role = e.adv and "warn" or "quiet";
	setLabel(ed.adv, e.adv and L("Back to the details") or L("Notes and advanced"));
	local ph = d.phases[e.phase];
	local pv = c:PlanView();
	-- spells
	ed.spellHead:SetText(string.format(L("Spells to acquire, by priority (%d/%d)"), #pv.spells, BM.LIMITS.spells));
	ed.summary:SetText(fitText(string.format(L("%d keep / %d banish after (max %d)"), pv.keepCount, pv.afterCount, BM.LIMITS.banishAfter), 270, 13));
	if pv.afterCount > 0 then ed.summary:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); else ed.summary:SetTextColor(0.7, 0.72, 0.78); end
	local insp = c.state.inspect;
	for i, r in ipairs(ed.spells) do
		local it = pv.spells[i];
		local base = i % 2 == 0 and ROW_B or ROW_A;
		r.frame:Show();
		r.num:SetText(i .. ".");
		if it then
			r.key = it.key;
			local nm = it.name;
			if it.mode == "rank" then nm = nm .. " (r" .. tostring(it.rank) .. ")"; elseif it.mode == "unlimited" then nm = nm .. " (+)"; end
			if not it.known then nm = nm .. " ?"; end
			r.name:SetText(fitText(nm, 258, 12));
			setIcon(r.icon, it.icon);
			r.name:Show(); r.hit:Show(); r.add:Hide();
			r.tog.role = it.after and "warn" or "quiet";
			setLabel(r.tog, it.after and L("Banish after") or L("Keep"));
			setLabel(r.up, "^"); setLabel(r.down, "v"); setLabel(r.del, "x");
			r.tog:Show(); r.up:Show(); r.down:Show(); r.del:Show();
			enable(r.tog, not ro);
			enable(r.up, not ro and i > 1);
			enable(r.down, not ro and i < #pv.spells);
			enable(r.del, not ro);
			local picked = insp and insp.kind == "spell" and insp.key == it.key;
			if picked then r.bg:SetTexture(ROW_SEL[1], ROW_SEL[2], ROW_SEL[3], 1);
			elseif it.after then r.bg:SetTexture(0.20, 0.14, 0.09, 1);
			else r.bg:SetTexture(base[1], base[2], base[3], 1); end
		else
			r.key = nil;
			r.icon:Hide(); r.name:Hide(); r.hit:Hide();
			r.tog:Hide(); r.up:Hide(); r.down:Hide(); r.del:Hide();
			r.add.role = "quiet";
			setLabel(r.add, L("+ Add a spell"));
			enable(r.add, not ro and #pv.spells < BM.LIMITS.spells);
			r.add:Show();
			r.bg:SetTexture(0.06, 0.065, 0.09, 1);
		end
	end
	-- equipment
	ed.equipHead:SetText(L("Equipment (main | alternatives)"));
	for _, g in ipairs(EQUIP_GROUPS) do
		local grp = ed.groups[g];
		local categoryLabel = g == "rings" and L("Rings") or (g == "trinkets" and L("Trinkets") or L("Amulet"));
		grp.label:SetText(fitFontText(grp.label, categoryLabel, 60));
		grp.label:Show();
		grp.sep:Show();
		local list = pv[g];
		for j, cell in ipairs(grp.cells) do
			local it = list[j];
			cell:Show();
			cell.key = it.key;
			local chosen = (e.cat == g and e.slot == j);
			local role = it.main and string.format(L("Main %d"), j) or string.format(L("Alt. %d"), j - BM.MAIN_SLOTS[g]);
			cell.role:SetText((chosen and "> " or "") .. role);
			cell.role:SetTextColor(chosen and GOLD[1] or 0.62, chosen and GOLD[2] or 0.65, chosen and GOLD[3] or 0.72);
			if it.key == "" then
				cell.name:SetText("|cff7d8090" .. L("+ Add") .. "|r");
				cell.name:SetTextColor(1, 1, 1);
				cell.icon:Hide();
				cell.x:Hide();
			else
				cell.name:SetText(fitText(it.name .. (it.known and "" or " ?"), 2 * 82 - 6, 10));
				local rc = rarityRgb(it.rarity);
				cell.name:SetTextColor(rc[1], rc[2], rc[3]);
				setIcon(cell.icon, it.icon);
				cell.x.role = "quiet";
				setLabel(cell.x, "x");
				cell.x:Show();
				enable(cell.x, not ro);
			end
			if chosen then cell.edge:Show(); else cell.edge:Hide(); end
		end
	end
	-- advanced block contents
	local manyPhases = c:ShowAllPhases();
	setShown(ed.nt.label, adv and manyPhases);
	setShown(ed.nt.labelLabel, adv and manyPhases);
	if adv then
		ed.nt.head:SetText(string.format(L("Notes (%s)"), c:PhaseTitle(e.phase)));
		setEdit(ed.nt.notes, ph.notes);
		local units = ns.Utf8 and ns.Utf8.Len16(ph.notes) or #ph.notes;
		ed.nt.counter:SetText(string.format("%d/%d", units, ns.PlannerCodec.SITE.notes));
		if units > ns.PlannerCodec.SITE.notes then ed.nt.counter:SetTextColor(1, 0.35, 0.3); else ed.nt.counter:SetTextColor(0.7, 0.72, 0.78); end
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
				r.del.role = "quiet";
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

-- ------------------------------------------------------------------ DetailPane (centre, bottom)
-- A fixed inspector: icon, full name, type line, then SECTIONS (In this build / Description / Information / Effects /
-- Growth / Availability / Source) in a scrollable pool of 8 wrapped rows (wheel or slider); actions on the right.
local DET_ROWS, DET_CHARS = 8, 70; -- all available width for real effect descriptions

-- word wrap by character budget (a deterministic estimate; long words are cut)
local function wrapText(textIn, max)
	local out = {};
	local line = "";
	for word in string.gmatch(textIn, "%S+") do
		while #word > max do
			if line ~= "" then out[#out + 1] = line; line = ""; end
			out[#out + 1] = string.sub(word, 1, max);
			word = string.sub(word, max + 1);
		end
		if line == "" then line = word;
		elseif #line + 1 + #word <= max then line = line .. " " .. word;
		else out[#out + 1] = line; line = word; end
	end
	if line ~= "" then out[#out + 1] = line; end
	if #out == 0 then out[1] = ""; end
	return out;
end
UI.WrapText = wrapText;

function UI:BuildDetail(v)
	local c = self.c;
	local det = {};
	self.det = det;
	det.head = header(v, 8, 430, EW);
	det.icon = v:CreateTexture(nil, "ARTWORK");
	det.icon:SetWidth(36); det.icon:SetHeight(36);
	det.icon:SetPoint("TOPLEFT", v, "TOPLEFT", 8, -454);
	det.title = text(v, 52, 454, 340, "GameFontNormalLarge", "LEFT", 18);
	det.type = text(v, 52, 474, 340, "GameFontNormalSmall");
	det.type:SetTextColor(0.66, 0.68, 0.74);
	det.area = scrollArea(v, 8, 496, 548, DET_ROWS * 15, function(d) self:ScrollDetail(d); end, function(o) self:SetDetailOffset(o); end);
	det.rows = {};
	for i = 1, DET_ROWS do
		det.rows[i] = text(det.area.hold, 0, (i - 1) * 15, 530, "GameFontHighlight");
	end
	det.body = det.rows[1];        -- first row (kept for tests and callers that only want "the text")
	det.source = wrapped(v, 8, 626, 540, 16, "GameFontNormalSmall");
	det.source:SetTextColor(0.62, 0.64, 0.70);
	det.source:Hide(); -- source metadata is appended to the scrollable full-width text
	det.act1 = button(v, "", 166, 26, 396, 454, function() self:DetailAct(1); end);
	det.act2 = button(v, "", 166, 24, 396, 484, function() self:DetailAct(2); end);
	det.act1.role = "primary";
	det.offset, det.lines = 0, {};
end

-- all the inspector's lines as one text (tests and diagnostics)
function UI:DetailText()
	local t = {};
	for i, ln in ipairs(self.det.lines) do t[i] = ln.text; end
	return table.concat(t, "\n");
end

function UI:ScrollDetail(delta) self:SetDetailOffset((self.det.offset or 0) + delta); end

function UI:SetDetailOffset(o)
	local det = self.det;
	local max = math.max(0, #det.lines - DET_ROWS);
	if o > max then o = max; end
	if o < 0 then o = 0; end
	det.offset = o;
	for i, r in ipairs(det.rows) do
		local ln = det.lines[o + i];
		if ln then
			r:SetText(ln.text);
			r:SetTextColor(ln.rgb[1], ln.rgb[2], ln.rgb[3]);
			r:Show();
		else
			r:SetText("");
		end
	end
	det.area.sync(o, max);
end

-- runs the selected element's primary (1) or secondary (2) action through the same controller calls as everywhere
function UI:DetailAct(which)
	local c = self.c;
	local d = c:DetailState();
	local e = c:Editor();
	if not d or not e then return; end
	if d.spell then
		if which == 1 then
			if d.spell.wanted then c:RemoveSpell(d.key); else c:AddSpell(d.key); end
		else
			if d.spell.avoided then c:RemoveBanish(d.key); else c:AddBanish(d.key); end
		end
	elseif which == 1 and d.piece.group then
		if d.piece.inTarget then c:ClearSlot(e.group, e.slot);
		elseif not d.piece.placedAt and d.piece.targetGroupOk then c:SetSlot(e.group, e.slot, d.key); end
	end
end

local TONE_RGB = { ok = { 0.56, 0.88, 0.63 }, warn = { 0.94, 0.78, 0.38 }, dim = { 0.66, 0.68, 0.72 } };

-- the inspector's wrapped lines, grouped by section (title rows in gold, body rows by tone)
function UI:DetailLines(d)
	local out = {};
	local function head(title) out[#out + 1] = { text = string.upper(title), rgb = GOLD }; end
	local function body(textIn, tone)
		for _, w in ipairs(wrapText(textIn, DET_CHARS)) do out[#out + 1] = { text = w, rgb = TONE_RGB[tone or ""] or { 1, 1, 1 } }; end
	end
	-- Equipment buyers first want the EFFECT, not the bookkeeping of their plan.
	-- Keep state and provenance underneath; spells retain their original order.
	local equipment = d.sections and not d.spellId;
	if equipment then
		for _, sec in ipairs(d.sections) do
			head(sec.title);
			for _, ln in ipairs(sec.lines) do body(ln.text, ln.tone); end
		end
	end
	if d.state and d.state[1] then
		head(L("In this build"));
		for _, ln in ipairs(d.state) do body(ln.text, ln.tone); end
	end
	if d.spellId then
		head(L("Description"));
		local game = self:GameText(d.spellId);
		if game then
			for i, t in ipairs(game) do if i > 1 then body(t); end end
		else
			body(L("Detailed effect unavailable"), "dim");
		end
	end
	if d.facts and d.facts[1] then
		head(L("Information"));
		for _, ln in ipairs(d.facts) do body(ln.text, ln.tone); end
	end
	if not equipment then
		for _, sec in ipairs(d.sections or {}) do
			head(sec.title);
			for _, ln in ipairs(sec.lines) do body(ln.text, ln.tone); end
		end
	end
	return out;
end

function UI:RefreshDetail()
	local c, det = self.c, self.det;
	local e = c:Editor();
	local show = e ~= nil and not e.adv;
	for _, w in ipairs({ det.head, det.title, det.type, det.act1, det.act2 }) do setShown(w, show); end
	det.source:Hide();
	setShown(det.area.hold, show);
	if not show then det.icon:Hide(); det.area.slider:Hide(); return; end
	local ro = c:ReadOnly();
	det.head:SetText(L("Details"));
	local d = c:InspectorData();
	local st = c:DetailState();
	local key = d and (d.title .. "|" .. tostring(c.state.inspect.key)) or "";
	if not d then
		det.icon:Hide();
		det.title:SetText("");
		det.type:SetText("");
		det.lines = {};
		for _, w in ipairs(wrapText(L("Select a spell or a piece to see its details here."), DET_CHARS)) do det.lines[#det.lines + 1] = { text = w, rgb = TONE_RGB.dim }; end
		det.source:SetText("");
		det.act1:Hide(); det.act2:Hide();
		det.key = nil;
		self:SetDetailOffset(0);
		return;
	end
	setIcon(det.icon, d.icon);
	det.title:SetText(fitText(d.title, 340, 16));
	local rc = rarityRgb(d.rarity);
	det.title:SetTextColor(rc[1], rc[2], rc[3]);
	det.type:SetText(fitText(d.subtitle or "", 340, 10));
	det.lines = self:DetailLines(d);
	if det.key ~= key then det.offset = 0; det.key = key; end      -- a new selection starts at the top
	self:SetDetailOffset(det.offset);
	local source = L("Source: Reborn catalogue (name, type, class).");
	if d.spellId and self:GameText(d.spellId) then source = L("Source: the game's own spell text, and the Reborn catalogue.");
	elseif d.sourceKind == "jewelry_live" then source = (c:Lang() == "frFR" and
		"Source : texte de l'objet actuellement équipé dans Reborn ; suivi de ses valeurs de base si disponibles." or
		"Source: currently equipped item text from Reborn, followed by available base values.");
	elseif d.sourceKind == "jewelry_local" then source = (c:Lang() == "frFR" and
		"Source : mécaniques locales du client Reborn (valeurs de base, non actuelles)." or
		"Source: local Reborn client mechanics (base values, not current stats).");
	elseif d.sections then source = L("Source: published game data (azreborn.com/data/v1), rank 1 values and the official growth rule."); end
	det.source:SetText(source); -- retained for diagnostics and tests
	-- Source is full-width and scrollable instead of cropped to 162px.
	if source and source ~= "" then
		det.lines[#det.lines + 1] = { text = "", rgb = TONE_RGB.dim };
		for _, w in ipairs(wrapText(source, DET_CHARS)) do
			det.lines[#det.lines + 1] = { text = w, rgb = TONE_RGB.dim };
		end
		self:SetDetailOffset(det.offset);
	end
	-- actions
	if st.spell then
		det.act1.role = st.spell.wanted and "quiet" or "primary";
		setLabel(det.act1, st.spell.wanted and L("Remove from my spells") or L("Add to my spells"));
		enable(det.act1, not ro and (st.spell.wanted or (st.spell.room and not st.spell.avoided)));
		det.act2.role = "quiet";
		setLabel(det.act2, st.spell.avoided and L("Stop avoiding") or L("Avoid this spell"));
		enable(det.act2, not ro and (st.spell.avoided or not st.spell.wanted));
		det.act1:Show(); det.act2:Show();
	else
		local p = st.piece;
		det.act2:Hide();
		det.act1:Show();
		if p.inTarget then
			det.act1.role = "quiet";
			setLabel(det.act1, L("Empty this slot"));
			enable(det.act1, not ro);
		elseif p.placedAt then
			det.act1.role = "quiet";
			setLabel(det.act1, L("Already placed"));
			enable(det.act1, false);
		else
			det.act1.role = "primary";
			setLabel(det.act1, L("Place here"));
			enable(det.act1, not ro and p.targetGroupOk);
		end
	end
end

-- ------------------------------------------------------------------ BrowserPane (right)
local RARITY_L = { common = "Common", uncommon = "Uncommon", rare = "Rare", epic = "Epic", legendary = "Legendary" };

function UI:BuildBrowser(v)
	local c = self.c;
	local bs = {};
	self.bs = bs;
	bs.head = header(v, 8, 8, RP_W - 16);
	bs.kinds = {
		spells = button(v, "", 90, 22, 8, 34, function() c:SetCatalog("spells"); end),
		rings = button(v, "", 77, 22, 98, 34, function() c:SetCatalog("rings"); end),
		trinkets = button(v, "", 100, 22, 175, 34, function() c:SetCatalog("trinkets"); end),
		amulets = button(v, "", 85, 22, 275, 34, function() c:SetCatalog("amulets"); end),
	};
	bs.searchLabel = text(v, 8, 66, 80, "GameFontNormalSmall");
	bs.search = edit(v, 262, 92, 62, function(t) c:SetSearch(t); end, "RebornBuildPlannerSearch");
	bs.target = text(v, 8, 90, RP_W - 16, "GameFontNormal");
	bs.area = scrollArea(v, 8, 110, 340, 504, function(d) c:ScrollCatalog(d); end, function(o) c:SetCatalogOffset(o); end);
	bs.empty = wrapped(v, 16, 140, 320, 60, "GameFontNormal");
	bs.rows = {};
	for i = 1, ns.Controller.CATALOG_ROWS do
		local r = CreateFrame("Button", nil, bs.area.hold);
		r:SetWidth(340);
		r:SetHeight(34);
		r:SetPoint("TOPLEFT", bs.area.hold, "TOPLEFT", 0, -((i - 1) * 36));
		r.base = fill(r, i % 2 == 0 and ROW_B or ROW_A);
		r.sel = r:CreateTexture(nil, "BORDER");
		r.sel:SetAllPoints(r);
		r.sel:SetTexture(ROW_SEL[1], ROW_SEL[2], ROW_SEL[3], ROW_SEL[4]);
		r.sel:Hide();
		r.icon = r:CreateTexture(nil, "ARTWORK");
		r.icon:SetWidth(26); r.icon:SetHeight(26);
		r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -4);
		r.name = text(r, 36, 3, 222, "GameFontHighlight");
		r.sub = text(r, 36, 19, 222, "GameFontNormalSmall");
		r.sub:SetTextColor(0.66, 0.68, 0.74);
		r.tag = text(r, 260, 10, 76, "GameFontNormalSmall", "RIGHT");
		r:SetScript("OnClick", function() if r.tipKey then c:Inspect(r.tipKind, r.tipKey); end end);
		r:SetScript("OnDoubleClick", function() if r.tipKey then c:Inspect(r.tipKind, r.tipKey); self:DetailAct(1); end end);
		self:Hover(r, function() return r.tipKey and c:TooltipData(r.tipKind, r.tipKey) or nil; end);
		bs.rows[i] = r;
	end
end

function UI:RefreshBrowser()
	local c, bs = self.c, self.bs;
	local e = c:Editor();
	local on = e ~= nil;
	bs.head:SetText(L("Browser"));
	for kind, b in pairs(bs.kinds) do
		local label = kind == "spells" and L("Spells") or (kind == "rings" and L("Rings") or (kind == "trinkets" and L("Trinkets") or L("Amulets")));
		b.role = (on and kind == e.cat) and "warn" or "quiet";
		setLabel(b, label .. ((on and kind == e.cat) and " *" or ""));
		enable(b, on);
	end
	setShown(bs.searchLabel, on); setShown(bs.search, on); setShown(bs.target, on);
	bs.searchLabel:SetText(L("Search:"));
	if not on then
		for _, r in ipairs(bs.rows) do r:Hide(); r.tipKey = nil; end
		bs.area.sync(0, 0);
		bs.empty:SetText(L("Open a build to browse spells and equipment."));
		bs.empty:Show();
		return;
	end
	setEdit(bs.search, e.search);
	local target = c:TargetInfo();
	if target then
		local where = (e.cat == "rings" and L("Rings") or (e.cat == "trinkets" and L("Trinkets") or L("Amulet"))) .. " - "
			.. (target.main and string.format(L("Main %d"), target.slot) or string.format(L("Alternative %d"), target.altIndex));
		bs.target:SetText(fitText(string.format(L("Target: %s (%s)"), where, target.key == "" and L("empty") or target.name), RP_W - 16, 12));
	else
		bs.target:SetText(fitText(string.format(L("Adding to the %d spells to acquire"), BM.LIMITS.spells), RP_W - 16, 12));
	end
	bs.target:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
	local view, off, max = c:CatalogView();
	bs.area.sync(off, max);
	local insp = c.state.inspect;
	local kind = e.cat == "spells" and "spell" or (e.cat == "amulets" and "amulet" or "jewel");
	setShown(bs.empty, view[1] == nil);
	if view[1] == nil then bs.empty:SetText(L("Nothing matches this search.")); end
	for i, r in ipairs(bs.rows) do
		local en = view[i];
		if en then
			r.tipKind, r.tipKey = kind, en.key;
			r.name:SetText(fitText(en.name, 228, 12));
			local rcol = rarityRgb(en.legend and "legendary" or en.rarity);
			if kind == "amulet" then r.name:SetTextColor(rcol[1], rcol[2], rcol[3]); else r.name:SetTextColor(1, 1, 1); end
			setIcon(r.icon, en.icon);
			local sub, tag = "", "";
			if kind == "spell" then
				sub = L("Spell");
				tag = en.state == "wanted" and L("Wanted") or (en.state == "banished" and L("Avoided") or "");
				if en.after then tag = L("Banish after"); end
			elseif kind == "amulet" then
				sub = en.legend and L("Legendary amulet") or (L("Amulet") .. " | " .. L(RARITY_L[en.rarity or ""] or "Unknown"));
				if en.legend and en.spellName then      -- spell name first (what tells two legends apart), head and class below
					r.name:SetText(fitText(en.spellName, 228, 12));
					sub = (en.head or "") .. " | " .. (en.className or "");
				end
				tag = en.here and L("In slot") or (en.state == "placed" and L("Placed") or "");
			else
				sub = e.cat == "rings" and L("Ring") or L("Trinket");
				tag = en.here and L("In slot") or (en.state == "placed" and L("Placed") or "");
			end
			r.sub:SetText(fitText(sub, 228, 10));
				r.tag:SetText(fitFontText(r.tag, tag, 72));
			r.tag:SetTextColor(en.here and 0.55 or 0.95, en.here and 0.9 or 0.78, en.here and 0.62 or 0.35);
			if insp and insp.kind == kind and insp.key == en.key then r.sel:Show(); else r.sel:Hide(); end
			r:Show();
		else
			r.tipKey = nil;
			r:Hide();
		end
	end
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
	im.nameLabel = text(v, 270, 444, 80, "GameFontNormal");
	im.nameEdit = edit(v, 128, 354, 440, function(t) c:SetImportName(t); end, "RebornBuildPlannerImportName");
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
		im.state:SetTextColor(COLOR.error[1], COLOR.error[2], COLOR.error[3]);
		for _, w in ipairs(im.phases) do w:SetText(""); end
	else
		if pv.kind == "talents" then
			im.name:SetText(L("Talent string only"));
			im.class:SetText(fitText(pv.talents, 270, 12));
			im.state:SetText(st.class and L("Ready") or L("Choose a class"));
			im.state:SetTextColor(COLOR.info[1], COLOR.info[2], COLOR.info[3]);
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
			local col = it.level == "error" and COLOR.error or (it.level == "conflict" and COLOR.warn or { 0.8, 0.8, 0.84 });
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
			if it.severity == "intent" then w:SetTextColor(COLOR.warn[1], COLOR.warn[2], COLOR.warn[3]); else w:SetTextColor(0.7, 0.72, 0.78); end
		else
			w:SetText("");
		end
	end
	ex.pager.label:SetText(string.format(L("Page %d/%d"), x.page, c:ExportPageCount()));
	enable(ex.pager.prev, x.page > 1);
	enable(ex.pager.next, x.page < c:ExportPageCount());
	if not r.ok then
		ex.state:SetText(L("This build cannot be exported to the official planner."));
		ex.state:SetTextColor(COLOR.error[1], COLOR.error[2], COLOR.error[3]);
	elseif r.intentLosses == 0 then
		ex.state:SetText(fitText(L("Nothing of your intent is lost in the official format (to verify on the site)."), EW, 12));
		ex.state:SetTextColor(COLOR.info[1], COLOR.info[2], COLOR.info[3]);
	elseif x.accepted then
		ex.state:SetText(string.format(L("Exported with %d known loss(es) that you accepted."), r.intentLosses));
		ex.state:SetTextColor(COLOR.warn[1], COLOR.warn[2], COLOR.warn[3]);
	else
		ex.state:SetText(string.format(L("%d thing(s) would be lost. Read the list, then accept to see the code."), r.intentLosses));
		ex.state:SetTextColor(COLOR.warn[1], COLOR.warn[2], COLOR.warn[3]);
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
	local m = THEME and THEME.Window(UIParent, 460, 250, "RebornBuildPlannerModal") or CreateFrame("Frame", "RebornBuildPlannerModal", UIParent);
	self.modal = m;
	m:SetWidth(460);
	m:SetHeight(250);
	m:SetFrameStrata("FULLSCREEN_DIALOG");
	m:SetFrameLevel(160); -- must stay above the planner root (level 100)
	m:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	m:SetClampedToScreen(true);
	m:EnableMouse(true);
	if not THEME then
		m:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } });
		m:SetBackdropColor(0.06, 0.065, 0.09, 1);
		m:SetBackdropBorderColor(0.70, 0.58, 0.30, 1);
	end
	m:Hide();
	-- Modal scrim blocks underlying editor interaction and establishes a clear
	-- foreground focus; it is always below the actual dialog and its footer.
	m.dim = CreateFrame("Frame", nil, UIParent);
	m.dim:SetAllPoints(UIParent);
	m.dim:SetFrameStrata("FULLSCREEN_DIALOG");
	m.dim:SetFrameLevel(145);
	local veil = m.dim:CreateTexture(nil, "BACKGROUND");
	veil:SetAllPoints(m.dim);
	veil:SetTexture(0.0, 0.015, 0.035, 0.60);
	m.dim:EnableMouse(true);
	m.dim:Hide();
	if THEME then
		m.titleBar = THEME.TitleBar(m, "", 14, 8, 432, 36);
		m.title = m.titleBar.title;
	else
		m.title = text(m, 24, 18, 412, "GameFontNormalLarge", "LEFT", 18);
		m.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]);
	end
	m.body = wrapped(m, 24, 58, 412, 64, "GameFontHighlight");
	m.editLabel = text(m, 24, 118, 120, "GameFontNormal");
	m.edit = edit(m, 288, 148, 114, function(t) m.value = t; end, "RebornBuildPlannerModalEdit");
	m.cycleLabel = text(m, 24, 150, 120, "GameFontNormal");
	m.cycle = cycler(m, 148, 146, 288, function() self:ModalClass(-1); end, function() self:ModalClass(1); end);
	m.err = text(m, 24, 176, 412, "GameFontNormal");
	m.err:SetTextColor(COLOR.error[1], COLOR.error[2], COLOR.error[3]);
	-- Explicit high-level footer: the native client can otherwise place the
	-- modal's low-level button textures behind its opaque window materials.
	-- Anchor from BOTTOMLEFT so controls cannot drift out of the 250px dialog.
	m.footer = CreateFrame("Frame", nil, m);
	m.footer:SetWidth(436); m.footer:SetHeight(50);
	m.footer:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 12, 10);
	m.footer:SetFrameStrata("FULLSCREEN_DIALOG");
	m.footer:SetFrameLevel(180);
	m.b = {};
	for i = 1, 3 do
		m.b[i] = button(m.footer, "", 132, 32, 4 + (i - 1) * 144, 9, function() self:ModalChoose(i); end);
		m.b[i]:SetFrameLevel(185);
		m.b[i].role = i == 1 and "primary" or "quiet";
		m.b[i].enabledFlag = true;
	end
	m:SetScript("OnHide", function()
		if m.dim then m.dim:Hide(); end
		self:SyncEscape();
	end);
end

-- spec = { title, body, edit = initial text|nil, editLabel, class = key|nil (class cycler), buttons = { label... },
--          validate = fn(index, value, class) -> error text | nil (keeps the dialog open),
--          onChoose = fn(index, value, class), cancelIndex, dangerFirst }
function UI:ShowModal(spec)
	self:HideLanguageMenu();
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
	m.dim:Show();
	m:Show();
	m.footer:Show();
	for i = 1, 3 do
		local label = spec.buttons[i];
		m.b[i].role = (i == 1 and spec.dangerFirst) and "danger" or (i == 1 and "primary" or "quiet");
		if label then
			m.b[i]:Enable();
			m.b[i].enabledFlag = true;
			setLabel(m.b[i], label);
			m.b[i]:Show();
		else
			m.b[i]:Hide();
		end
	end
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
	self:HideTip();       -- list / view / data may have changed under the pointer
	self.title:SetText("Reborn Build Planner");
	local choice = ns.Locale.Selection();
	setLabel(self.languageButton, ns.Locale.Label(choice) .. "  v");
	if self.languageMenuOpen then self:ShowLanguageMenu(); end
	enable(self.languageButton, not c:ReadOnly());
	setLabel(self.nav.import, L("Import"));
	setLabel(self.nav.export, L("Export"));
	setLabel(self.sizeMinus, L("Size -"));
	setLabel(self.sizePlus, L("Size +"));
	setLabel(self.close, "X");
	enable(self.nav.export, st.export ~= nil or st.editor ~= nil);
	self.banner:SetText(c:StorageStatusText() or "");
	for name, f in pairs(self.views) do setShown(f, name == st.view); end
	local msg = st.message;
	self.msg:SetText(msg and fitText(msg.text, 980, 12) or "");
	if msg then self.msg:SetTextColor(unpack(COLOR[msg.level])); end
	setShown(self.undoBtn, st.undo ~= nil);
	if st.undo then setLabel(self.undoBtn, L("Undo the deletion")); end
	self:RefreshLibrary();
	self:RefreshBrowser();
	if st.view == "editor" then self:RefreshEditor(); self:RefreshDetail();
	elseif st.view == "import" then self:RefreshImport();
	elseif st.view == "export" then self:RefreshExport(); end
	self:SyncEscape();
end
