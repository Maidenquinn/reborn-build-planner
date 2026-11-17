-- Headless stand-in for the 3.3.5a widget API (Frame, Button, EditBox, ScrollFrame, FontString, Texture) used to
-- run the REAL UI code in tests. It is a MOCK: it proves the UI logic and a layout lint on estimated text widths;
-- it proves nothing about how the Reborn client draws, focuses or clips. Real captures are required for that.
local Stub = {};

local FONT_SIZE = { GameFontNormalLarge = 16, GameFontNormalSmall = 10, GameFontHighlightSmall = 10, GameFontNormal = 12,
	GameFontHighlight = 12, ChatFontNormal = 14 };

local function utf8len(s)
	local n = 0;
	for _ in string.gmatch(s, "[^\128-\191]") do n = n + 1; end
	return n;
end

local function plain(s)
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "");
	s = string.gsub(s, "|r", "");
	return s;
end

-- estimated pixel width of a string (average glyph = 0.6 * size: deliberately a little pessimistic)
function Stub.textWidth(s, size)
	return utf8len(plain(s)) * (size or 12) * 0.6;
end

function Stub.new(opts)
	opts = opts or {};
	local W, Hh = opts.width or 1024, opts.height or 768;     -- UIParent size in UI units
	local world = { G = {}, opts = opts, byName = {}, all = {}, chat = {}, focus = nil, events = {} };
	local G = world.G;
	local F = {};
	F.__index = F;

	local function new(kind, name, parent)
		local f = setmetatable({ kind = kind, name = name, parent = parent, children = {}, regions = {}, points = {}, w = 0, h = 0, shown = true,
			scripts = {}, hooks = {}, text = "", enabled = true, scale = 1, strata = "MEDIUM", alpha = 1, registered = {} }, F);
		if name then
			G[name] = f;
			world.byName[name] = f;
		end
		world.all[#world.all + 1] = f;
		return f;
	end

	-- ---- generic
	function F:GetName() return self.name; end
	function F:GetObjectType() return self.kind; end
	function F:GetParent() return self.parent; end
	function F:SetParent(p) self.parent = p; end
	function F:SetWidth(w) self.w = w; end
	function F:SetHeight(h) self.h = h; end
	function F:SetSize(w, h) self.w, self.h = w, h; end
	function F:GetWidth() return self.w; end
	function F:GetHeight() return self.h; end
	function F:SetScale(s) self.scale = s; end
	function F:GetScale() return self.scale; end
	function F:SetAlpha(a) self.alpha = a; end
	function F:SetFrameStrata(s) self.strata = s; end
	function F:GetFrameStrata() return self.strata; end
	function F:SetFrameLevel(l) self.level = l; end
	function F:Raise() end
	function F:SetClampedToScreen(v) self.clamped = v; end
	function F:SetMovable(v) self.movable = v; end
	function F:IsMovable() return self.movable; end
	function F:EnableMouse(v) self.mouse = v; end
	function F:EnableMouseWheel(v) self.wheel = v; end
	function F:EnableKeyboard(v) self.keyboard = v; end
	function F:RegisterForDrag() self.drag = true; end
	function F:StartMoving() self.moving = true; end
	function F:StopMovingOrSizing() self.moving = false; end
	function F:SetBackdrop(b) self.backdrop = b; end
	function F:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a }; end
	function F:SetBackdropBorderColor() end
	function F:SetTextColor(r, g, b) self.color = { r, g, b }; end
	function F:SetJustifyH(j) self.justifyH = j; end
	function F:SetJustifyV(j) self.justifyV = j; end
	function F:SetFontObject(o) self.fontObject = o; end
	function F:SetHighlightTexture() end
	function F:GetHighlightTexture() return { SetVertexColor = function() end, SetAllPoints = function() end }; end
	-- sliders (scroll bars)
	function F:SetOrientation() end
	function F:SetMinMaxValues(a, b) self.minv, self.maxv = a, b; end
	function F:SetValueStep() end
	function F:SetValue(v) self.value = v; end
	function F:GetValue() return self.value or 0; end
	function F:SetThumbTexture() end
	function F:GetThumbTexture() return { SetSize = function() end, SetHeight = function() end, SetWidth = function() end, SetVertexColor = function() end }; end
	function F:SetNormalTexture() end
	function F:SetTexCoord() end
	function F:SetHitRectInsets() end
	if not opts.noWordWrap then function F:SetWordWrap(v) self.wordWrap = v; end end

	function F:SetPoint(point, a, b, c, d)
		local rel, relPoint, x, y = self.parent, point, 0, 0;
		if type(a) == "number" then
			x, y = a, b or 0;
		else
			if a ~= nil then rel = type(a) == "string" and G[a] or a; end
			if type(b) == "string" then
				relPoint, x, y = b, c or 0, d or 0;
			elseif type(b) == "number" then
				x, y = b, c or 0;
			end
		end
		self.points[#self.points + 1] = { point = point, rel = rel or G.UIParent, relPoint = relPoint, x = x, y = y };
	end
	function F:ClearAllPoints() self.points = {}; self.allpoints = nil; end
	function F:GetPoint(n)
		local p = self.points[n or 1];
		if not p then return nil; end
		return p.point, p.rel, p.relPoint, p.x, p.y;
	end
	function F:SetAllPoints(rel) self.allpoints = rel or self.parent; end

	function F:Show()
		if not self.shown then
			self.shown = true;
			if self.scripts.OnShow then self.scripts.OnShow(self); end
		end
	end
	function F:Hide()
		if self.shown then
			self.shown = false;
			if self.scripts.OnHide then self.scripts.OnHide(self); end
		end
	end
	function F:IsShown() return self.shown; end
	function F:IsVisible()
		local f = self;
		while f do
			if not f.shown then return false; end
			f = f.parent;
		end
		return true;
	end

	function F:SetScript(name, fn) self.scripts[name] = fn; end
	function F:GetScript(name) return self.scripts[name]; end
	function F:HookScript(name, fn)
		local old = self.scripts[name];
		self.scripts[name] = function(...) if old then old(...); end fn(...); end;
	end
	function F:RegisterEvent(e) self.registered[e] = true; world.events[e] = world.events[e] or {}; table.insert(world.events[e], self); end
	function F:UnregisterEvent(e) self.registered[e] = nil; end

	function F:SetText(t)
		t = t == nil and "" or tostring(t);
		self.text = t;
		if self.kind == "EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false); end
	end
	function F:GetText() return self.text; end
	function F:GetFontString() return self.fs; end
	function F:Enable() self.enabled = true; end
	function F:Disable() self.enabled = false; end
	function F:IsEnabled() return self.enabled; end
	function F:GetStringWidth() return Stub.textWidth(self.text, self.fontSize or 12); end

	function F:SetTexture(a, b, c, d)
		if type(a) == "string" then self.texture = a; else self.texColor = { a, b, c, d }; end
	end

	function F:CreateFontString(name, layer, font)
		local fs = new("FontString", name, self);
		fs.fontSize = FONT_SIZE[font or "GameFontNormal"] or 12;
		fs.fontObject = font;
		fs.layer = layer;
		self.regions[#self.regions + 1] = fs;
		return fs;
	end
	function F:CreateTexture(name, layer)
		local t = new("Texture", name, self);
		t.layer = layer;
		self.regions[#self.regions + 1] = t;
		return t;
	end

	-- edit boxes
	function F:SetAutoFocus(v) self.autoFocus = v; end
	function F:SetMaxLetters(n) self.maxLetters = n; end
	function F:SetMultiLine(v) self.multiLine = v; end
	function F:SetFocus()
		if world.focus and world.focus ~= self then world.focus:ClearFocus(); end
		world.focus = self;
		if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self); end
	end
	function F:ClearFocus()
		if world.focus == self then
			world.focus = nil;
			if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self); end
		end
	end
	function F:HasFocus() return world.focus == self; end
	function F:HighlightText() self.highlighted = true; end
	-- scroll frames
	function F:SetScrollChild(c) self.scrollChild = c; c.parent = self; end

	-- ---- layout solver (UIParent units, y up); sizes and offsets are scaled by the frame's effective scale
	local function effScale(f)
		local s = 1;
		while f and f ~= G.UIParent do
			s = s * (f.scale or 1);
			f = f.parent;
		end
		return s;
	end
	world.effScale = effScale;

	local function regionSize(f)
		local w, h = f.w, f.h;
		if f.kind == "FontString" and w == 0 then w = Stub.textWidth(f.text, f.fontSize); end
		return w, h;
	end

	local rectOf;
	local function anchor(rect, point)
		local l, b, r, t = rect[1], rect[2], rect[3], rect[4];
		local x = (string.find(point, "LEFT") and l) or (string.find(point, "RIGHT") and r) or (l + r) / 2;
		local y = (string.find(point, "TOP") and t) or (string.find(point, "BOTTOM") and b) or (b + t) / 2;
		return x, y;
	end
	rectOf = function(f)
		if f == G.UIParent then return { 0, 0, W, Hh }; end
		local es = effScale(f);
		local w, h = regionSize(f);
		w, h = w * es, h * es;
		if f.allpoints then
			local r = rectOf(f.allpoints);
			return { r[1], r[2], r[3], r[4] };
		end
		local p = f.points[1];
		if not p then return nil; end
		local rr = rectOf(p.rel);
		if not rr then return nil; end
		local ax, ay = anchor(rr, p.relPoint);
		ax, ay = ax + p.x * es, ay + p.y * es;
		local l = (string.find(p.point, "LEFT") and ax) or (string.find(p.point, "RIGHT") and ax - w) or ax - w / 2;
		local b = (string.find(p.point, "TOP") and ay - h) or (string.find(p.point, "BOTTOM") and ay) or ay - h / 2;
		return { l, b, l + w, b + h };
	end
	world.rectOf = rectOf;
	function F:GetLeft() local r = rectOf(self); return r and r[1]; end
	function F:GetBottom() local r = rectOf(self); return r and r[2]; end
	function F:GetRight() local r = rectOf(self); return r and r[3]; end
	function F:GetTop() local r = rectOf(self); return r and r[4]; end
	function F:GetEffectiveScale() return effScale(self); end

	-- ---- globals
	local UIParent = new("Frame", "UIParent", nil);
	UIParent:SetSize(W, Hh);
	UIParent.points = {};
	G.UIParent = UIParent;
	G._G = G;
	G.UISpecialFrames = {};
	G.SlashCmdList = {};
	G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) world.chat[#world.chat + 1] = m; end };
	G.GetLocale = function() return opts.locale or "enUS"; end;
	G.UnitClass = function() return opts.className or "Warrior", opts.classToken or "WARRIOR"; end;
	G.time = function() return opts.now or 1700000000; end;
	G.date = function(fmt, t) return os.date(fmt, t); end;
	G.GetTime = function() return 1000; end;

	-- GameTooltip mock: records what the UI draws. opts.gameSpells = { [id] = { "Name", "description..." } } stands for the
	-- game's own spell tooltip (an unknown id shows nothing, like the client).
	do
		local tt = { lines = {}, shown = false, owner = nil, calls = 0 };
		function tt:SetOwner(o, anchor) self.owner, self.anchor, self.shown = o, anchor, false; self.lines = {}; end
		function tt:GetOwner() return self.owner; end
		function tt:ClearLines() self.lines = {}; end
		function tt:SetHyperlink(link)
			self.calls = self.calls + 1;
			local id = tonumber(string.match(link, "spell:(%d+)"));
			local g = id and opts.gameSpells and opts.gameSpells[id];
			self.lines = {};
			if g then for _, l in ipairs(g) do self.lines[#self.lines + 1] = l; end end
			for i, l in ipairs(self.lines) do G["GameTooltipTextLeft" .. i] = { GetText = function() return l; end }; end
		end
		function tt:AddLine(text) self.lines[#self.lines + 1] = text; end
		function tt:NumLines() return #self.lines; end
		function tt:Show() self.shown = true; end
		function tt:Hide() self.shown = false; self.owner = nil; self.lines = {}; end
		function tt:IsShown() return self.shown; end
		function tt:Text() return table.concat(self.lines, "\n"); end
		G.GameTooltip = tt;
		world.tooltip = tt;
	end

	G.CreateFrame = function(kind, name, parent, template)
		local f = new(kind, name, parent or UIParent);
		f.template = template;
		if parent then parent.children[#parent.children + 1] = f; else UIParent.children[#UIParent.children + 1] = f; end
		if kind == "Button" or kind == "CheckButton" then
			f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
			f.fs.points = {};
			f.fs:SetPoint("CENTER", f, "CENTER", 0, 0);
			f.SetText = function(self, t) self.text = tostring(t or ""); self.fs.text = self.text; end;
			if template == "UIPanelCloseButton" then f.w, f.h = 32, 32; end
		elseif kind == "ScrollFrame" and name then
			local bar = new("Slider", name .. "ScrollBar", f);
			f.children[#f.children + 1] = bar;
		end
		return f;
	end

	-- ---- test helpers
	function world.find(name) return world.byName[name]; end

	function world.visible(f) return f:IsVisible(); end

	-- every visible text on screen: FontStrings, button labels, edit box contents
	function world.texts()
		local out = {};
		for _, f in ipairs(world.all) do
			if f ~= UIParent and f:IsVisible() then
				if f.kind == "FontString" and f.text ~= "" then out[#out + 1] = plain(f.text); end
				if f.kind == "EditBox" and f.text ~= "" then out[#out + 1] = f.text; end
			end
		end
		return out;
	end

	function world.hasText(s)
		for _, t in ipairs(world.texts()) do
			if string.find(t, s, 1, true) then return true; end
		end
		return false;
	end

	-- visible button (not a text region) whose label equals `label`
	function world.button(label, within)
		for _, f in ipairs(world.all) do
			if (f.kind == "Button" or f.kind == "CheckButton") and plain(f.text) == label and f:IsVisible() and (not within or world.inside(f, within)) then return f; end
		end
		return nil;
	end
	function world.inside(f, anc)
		while f do
			if f == anc then return true; end
			f = f.parent;
		end
		return false;
	end

	function world.hover(f)
		assert(f and f:IsVisible(), "hover: widget not visible");
		if f.scripts.OnEnter then f.scripts.OnEnter(f); end
		return world.tooltip;
	end
	function world.unhover(f)
		if f.scripts.OnLeave then f.scripts.OnLeave(f); end
	end

	function world.click(f)
		assert(f, "click: no such widget");
		assert(f:IsVisible(), "click: widget is not visible");
		if not f.enabled then return false; end
		if f.scripts.OnClick then f.scripts.OnClick(f, "LeftButton"); end
		return true;
	end
	function world.clickLabel(label, within)
		local b = world.button(label, within);
		assert(b, "no visible button labelled '" .. label .. "'");
		return world.click(b);
	end
	function world.type(e, text)
		assert(e:IsVisible(), "type: edit box not visible");
		e.text = text;
		if e.scripts.OnTextChanged then e.scripts.OnTextChanged(e, true); end
	end
	function world.escape()
		local closed = false;
		for _, name in ipairs(G.UISpecialFrames) do
			local f = G[name];
			if f and f:IsShown() then f:Hide(); closed = true; end
		end
		return closed;
	end
	function world.fire(event, ...)
		for _, f in ipairs(world.events[event] or {}) do
			if f.registered[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...); end
		end
	end
	function world.drag(f, dx, dy)
		-- simulates a drag of the window: the client re-anchors it relative to UIParent
		f.scripts.OnDragStart(f);
		local p = f.points[1];
		local nx, ny = (p and p.x or 0) + dx, (p and p.y or 0) + dy;
		f.points = { { point = p and p.point or "CENTER", rel = UIParent, relPoint = p and p.relPoint or "CENTER", x = nx, y = ny } };
		if f.clamped then   -- the engine keeps a clamped frame on screen
			local r = rectOf(f);
			local es = effScale(f);
			local sx = (r[1] < 0 and -r[1]) or (r[3] > W and W - r[3]) or 0;
			local sy = (r[2] < 0 and -r[2]) or (r[4] > Hh and Hh - r[4]) or 0;
			local q = f.points[1];
			q.x, q.y = q.x + sx / es, q.y + sy / es;
		end
		f.scripts.OnDragStop(f);
	end

	local function overlap(a, b)
		local w = math.min(a[3], b[3]) - math.max(a[1], b[1]);
		local h = math.min(a[4], b[4]) - math.max(a[2], b[2]);
		return w > 2 and h > 2;
	end

	-- Layout lint on estimated metrics. Returns a list of problems (empty = none found).
	function world.lint(root)
		local problems = {};
		local rr = rectOf(root);
		local function add(msg) problems[#problems + 1] = msg; end
		if not rr then add("root has no position"); return problems; end
		if rr[1] < -0.5 or rr[2] < -0.5 or rr[3] > W + 0.5 or rr[4] > Hh + 0.5 then
			add(string.format("window outside the screen: %.0f,%.0f-%.0f,%.0f of %dx%d", rr[1], rr[2], rr[3], rr[4], W, Hh));
		end
		local interactive = {};
		for _, f in ipairs(world.all) do
			if f ~= root and f.kind ~= "Slider" and not (f.parent and f.parent.kind == "ScrollFrame") and f:IsVisible() and world.inside(f, root) then
				local r = rectOf(f);
				local label = tostring(f.name or f.kind) .. "[" .. (f.text ~= "" and string.sub(plain(tostring(f.text)), 1, 24) or "") .. "]";
				if not r then
					if f.kind ~= "Texture" then add("visible widget without position: " .. label); end
				else
					if r[1] < rr[1] - 0.5 or r[2] < rr[2] - 0.5 or r[3] > rr[3] + 0.5 or r[4] > rr[4] + 0.5 then add("outside the window: " .. label); end
					local es = effScale(f);
					if f.kind == "FontString" and f.text ~= "" then
						local avail = (f.w > 0 and f.w) or (f.parent and f.parent.w or 0);
						local need = Stub.textWidth(f.text, f.fontSize);
						if f.w > 0 and need > avail + 1 and not (f.h >= (f.fontSize or 12) * 2.2) then
							add(string.format("text wider than its box (%.0f > %.0f): %s", need, avail, label));
						end
					elseif f.kind == "Button" and f.text ~= "" then
						local need = Stub.textWidth(f.text, 12);
						if need > f.w - 12 then add(string.format("button label too wide (%.0f > %.0f): %s", need, f.w - 12, label)); end
					end
					if (f.kind == "Button" and #f.children == 0 and #f.regions <= 1) or f.kind == "EditBox" or f.kind == "ScrollFrame" then
						if f.kind ~= "EditBox" or not f.parent or f.parent.kind ~= "ScrollFrame" then interactive[#interactive + 1] = { f = f, r = r, label = label }; end
					end
				end
			end
		end
		for i = 1, #interactive do
			for j = i + 1, #interactive do
				local a, b = interactive[i], interactive[j];
				if overlap(a.r, b.r) and not world.inside(a.f, b.f) and not world.inside(b.f, a.f) then
					add("controls overlap: " .. a.label .. " / " .. b.label);
				end
			end
		end
		return problems;
	end

	return world;
end

return Stub;
