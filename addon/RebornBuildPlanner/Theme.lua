-- Theme: ONE small component library for the planner's look (Lot 3.5). Every visible element is built here, from the same
-- palette, with the same margins, so that no widget carries a hand-made style of its own.
--
-- Rendering technique ("regions", default): every surface is a stack of plain Texture regions on a Frame -- a vertical
-- gradient (Texture:SetGradientAlpha), a 1 px bronze border made of four textures, an inner highlight line -- and every
-- Button gets its states from the client's own button textures (highlight, pushed) tinted by us, plus our colouring of
-- the "rest" and "disabled" states. No Blizzard template is ever used, so no native red/grey button texture can show
-- through. Nothing here uses OnUpdate, a timer or a script hook (a later SetScript on the same frame cannot remove it).
-- Fallback technique ("backdrop"): the 0.4.x look (flat SetBackdrop), kept only so the visual lab can show both.
--
-- Everything is created once by the caller; the functions never create anything on their own after construction.
local ADDON, ns = ...;
ns = ns or {};
local T = { mode = "regions" };
ns.Theme = T;

local WHITE = "Interface\\Buttons\\WHITE8X8";
T.WHITE = WHITE;

-- ------------------------------------------------------------------ palette
T.C = {
	ink = { 0.030, 0.036, 0.056 },        -- window: deep blue-black
	slate = { 0.075, 0.084, 0.120 },      -- secondary panels: dark slate
	slate2 = { 0.100, 0.112, 0.158 },     -- raised rows / cells
	field = { 0.045, 0.052, 0.078 },      -- text fields, empty slots
	ivory = { 0.95, 0.92, 0.82 },         -- primary text
	mute = { 0.72, 0.74, 0.80 },          -- secondary text
	dim = { 0.50, 0.52, 0.58 },           -- disabled text
	gold = { 0.93, 0.78, 0.40 },          -- accent
	bronze = { 0.56, 0.43, 0.23 },        -- borders
	bronzeDim = { 0.34, 0.27, 0.16 },
	blue = { 0.13, 0.22, 0.42 },          -- selection fill
	green = { 0.45, 0.80, 0.52 },         -- success
	red = { 0.80, 0.30, 0.26 },           -- destructive
	rarity = { common = { 0.88, 0.88, 0.92 }, uncommon = { 0.30, 0.90, 0.35 }, rare = { 0.35, 0.62, 1 },
		epic = { 0.70, 0.40, 0.95 }, legendary = { 1, 0.58, 0.14 } },
};
local C = T.C;

-- Typography: game font objects only (they exist in every 3.3.5a client). Sizes are the game's: 16 / 12 / 10.
T.FONT = { window = "GameFontNormalLarge", section = "GameFontNormal", name = "GameFontNormal", body = "GameFontHighlight",
	small = "GameFontNormalSmall", tiny = "GameFontHighlightSmall" };

-- Button looks: top / bottom gradient colours, border, label colour. States are derived (hover/pressed come from the
-- client's highlight / pushed textures; disabled has its own look).
T.ROLES = {
	primary = { top = { 0.46, 0.35, 0.13 }, bottom = { 0.25, 0.18, 0.07 }, border = { 0.86, 0.70, 0.34 }, text = { 1, 0.93, 0.68 } },
	secondary = { top = { 0.17, 0.19, 0.27 }, bottom = { 0.10, 0.11, 0.17 }, border = { 0.40, 0.34, 0.22 }, text = { 0.88, 0.88, 0.92 } },
	danger = { top = { 0.36, 0.13, 0.12 }, bottom = { 0.20, 0.07, 0.07 }, border = { 0.62, 0.26, 0.22 }, text = { 1, 0.78, 0.74 } },
	selected = { top = { 0.18, 0.30, 0.56 }, bottom = { 0.10, 0.18, 0.38 }, border = { 0.93, 0.78, 0.40 }, text = { 1, 0.95, 0.80 } },
	disabled = { top = { 0.10, 0.11, 0.15 }, bottom = { 0.07, 0.08, 0.11 }, border = { 0.20, 0.20, 0.25 }, text = { 0.50, 0.52, 0.58 } },
};

-- ------------------------------------------------------------------ colour maths (used by the contrast tests)
local function lin(c)
	if c <= 0.03928 then return c / 12.92; end
	return ((c + 0.055) / 1.055) ^ 2.4;
end
function T.Luminance(rgb) return 0.2126 * lin(rgb[1]) + 0.7152 * lin(rgb[2]) + 0.0722 * lin(rgb[3]); end
-- WCAG contrast ratio of two colours
function T.Contrast(a, b)
	local la, lb = T.Luminance(a), T.Luminance(b);
	if la < lb then la, lb = lb, la; end
	return (la + 0.05) / (lb + 0.05);
end
local function mid(a, b) return { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }; end
T.Mid = mid;

-- ------------------------------------------------------------------ what this client can do (printed by /rbplab diag)
-- Probes methods on a real frame the caller passes in (so the answer is about THIS client, not about a guess).
function T.Capabilities(frame)
	local tex = frame:CreateTexture(nil, "BACKGROUND");
	local btn = CreateFrame("Button", nil, frame);
	local eb = CreateFrame("EditBox", nil, frame);
	local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	local cap = {
		SetGradientAlpha = type(tex.SetGradientAlpha) == "function",
		SetBackdrop = type(frame.SetBackdrop) == "function",
		SetHighlightTexture = type(btn.SetHighlightTexture) == "function",
		SetPushedTexture = type(btn.SetPushedTexture) == "function",
		GetHighlightTexture = type(btn.GetHighlightTexture) == "function",
		SetFontString = type(btn.SetFontString) == "function",
		SetTextInsets = type(eb.SetTextInsets) == "function",
		GetStringHeight = type(fs.GetStringHeight) == "function",
		SetVertexColor = type(tex.SetVertexColor) == "function",
		SetTexCoord = type(tex.SetTexCoord) == "function",
	};
	tex:Hide(); btn:Hide(); eb:Hide(); fs:Hide();      -- probes only
	return cap;
end

-- ------------------------------------------------------------------ surfaces
local function hasGradient(tex) return type(tex.SetGradientAlpha) == "function"; end

-- vertical gradient on a texture region; `top` and `bottom` are {r,g,b[,a]}. gradientFlip exists because the direction
-- convention of SetGradientAlpha is checked by eye in the visual lab, not assumed.
T.gradientFlip = false;
function T.Gradient(tex, top, bottom)
	if hasGradient(tex) then
		tex:SetTexture(WHITE);
		local a, b = top, bottom;
		if T.gradientFlip then a, b = bottom, top; end
		-- WoW's VERTICAL gradient runs from its first colour (bottom) to its second (top)
		tex:SetGradientAlpha("VERTICAL", b[1], b[2], b[3], b[4] or 1, a[1], a[2], a[3], a[4] or 1);
	else
		local m = mid(top, bottom);
		tex:SetTexture(m[1], m[2], m[3], 1);
	end
end

local function line(frame, layer, color, alpha)
	local t = frame:CreateTexture(nil, layer);
	t:SetTexture(color[1], color[2], color[3], alpha or 1);
	return t;
end

-- four border textures hugging the frame (two anchors each: the client sizes them from the frame, no width needed)
local function border(frame, color, thickness, inset)
	inset = inset or 0;
	local e = {};
	e.top = line(frame, "BORDER", color);
	e.top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset);
	e.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset);
	e.top:SetHeight(thickness);
	e.bottom = line(frame, "BORDER", color);
	e.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset);
	e.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset);
	e.bottom:SetHeight(thickness);
	e.left = line(frame, "BORDER", color);
	e.left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset);
	e.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset);
	e.left:SetWidth(thickness);
	e.right = line(frame, "BORDER", color);
	e.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset);
	e.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset);
	e.right:SetWidth(thickness);
	return e;
end

local function setBorder(e, color, alpha)
	for _, t in pairs(e) do t:SetTexture(color[1], color[2], color[3], alpha or 1); end
end
T.SetBorderColor = function(frame, color) if frame.edges then setBorder(frame.edges, color); elseif frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(color[1], color[2], color[3], 1); end end

-- Surface kinds: window (deep), panel (slate), inset (darker, for lists and fields), card (raised)
local SURFACE = {
	window = { top = { 0.050, 0.058, 0.090 }, bottom = { 0.026, 0.030, 0.050 }, border = C.bronze, inner = C.bronzeDim },
	panel = { top = { 0.098, 0.108, 0.150 }, bottom = { 0.062, 0.070, 0.102 }, border = C.bronzeDim, inner = nil },
	inset = { top = { 0.052, 0.060, 0.088 }, bottom = { 0.040, 0.046, 0.070 }, border = { 0.22, 0.19, 0.13 }, inner = nil },
	card = { top = { 0.135, 0.150, 0.205 }, bottom = { 0.095, 0.106, 0.150 }, border = { 0.30, 0.26, 0.17 }, inner = nil },
};
T.SURFACE = SURFACE;

-- A framed surface: gradient + 1 px border (+ an inner second line for windows: the "double bronze rule").
function T.Surface(frame, kind)
	local s = SURFACE[kind] or SURFACE.panel;
	frame.surfaceKind = kind;
	if T.mode == "backdrop" then
		frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
		local m = mid(s.top, s.bottom);
		frame:SetBackdropColor(m[1], m[2], m[3], 1);
		frame:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], 1);
		return frame;
	end
	frame.bg = frame:CreateTexture(nil, "BACKGROUND");
	frame.bg:SetAllPoints(frame);
	T.Gradient(frame.bg, s.top, s.bottom);
	frame.edges = border(frame, s.border, 1, 0);
	if s.inner then frame.inner = border(frame, s.inner, 1, 3); end
	-- a faint light line under the top border gives the panel its "lit from above" edge
	frame.sheen = line(frame, "ARTWORK", { 1, 1, 1 }, 0.05);
	frame.sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1);
	frame.sheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1);
	frame.sheen:SetHeight(1);
	return frame;
end

function T.Frame(parent, w, h, kind, name)
	local f = CreateFrame("Frame", name, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	return T.Surface(f, kind);
end

-- ------------------------------------------------------------------ text
function T.Text(parent, font, color, x, y, w, h, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or T.FONT.body);
	if x then fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y); end
	if w then fs:SetWidth(w); end
	if h then fs:SetHeight(h); end
	fs:SetJustifyH(justify or "LEFT");
	if fs.SetWordWrap then fs:SetWordWrap(false); end
	color = color or C.ivory;
	fs:SetTextColor(color[1], color[2], color[3]);
	return fs;
end

-- a section title: gold text, then a bronze rule with an ornament square at its left end
function T.SectionTitle(parent, label, x, y, w)
	local fs = T.Text(parent, T.FONT.section, C.gold, x, y, w, 16);
	fs:SetText(label);
	local rule = line(parent, "ARTWORK", C.bronze, 0.75);
	rule:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 20));
	rule:SetWidth(w);
	rule:SetHeight(1);
	local dot = line(parent, "ARTWORK", C.gold, 1);
	dot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 19));
	dot:SetWidth(3);
	dot:SetHeight(3);
	fs.rule, fs.dot = rule, dot;
	return fs;
end

-- ------------------------------------------------------------------ buttons
-- A Button owns: bg gradient, border, label. Hover and pressed come from the client's highlight / pushed textures
-- (no script involved); rest / disabled / role colours are ours. No template.
local function skin(b)
	local role = b.enabled == false and "disabled" or (b.role or "secondary");
	local r = T.ROLES[role] or T.ROLES.secondary;
	b.skinRole = role;
	if T.mode == "backdrop" then
		local m = mid(r.top, r.bottom);
		b:SetBackdropColor(m[1], m[2], m[3], 1);
		b:SetBackdropBorderColor(r.border[1], r.border[2], r.border[3], 1);
	else
		T.Gradient(b.bg, r.top, r.bottom);
		setBorder(b.edges, r.border);
	end
	b.label:SetTextColor(r.text[1], r.text[2], r.text[3]);
end

function T.Button(parent, label, w, h, role, onClick, name)
	local b = CreateFrame("Button", name, parent);
	b:SetWidth(w);
	b:SetHeight(h or 26);
	b.role, b.enabled = role or "secondary", true;
	if T.mode == "backdrop" then
		b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
	else
		b.bg = b:CreateTexture(nil, "BACKGROUND");
		b.bg:SetAllPoints(b);
		b.edges = border(b, C.bronze, 1, 0);
		b.sheen = line(b, "ARTWORK", { 1, 1, 1 }, 0.10);
		b.sheen:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1);
		b.sheen:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1);
		b.sheen:SetHeight(1);
	end
	local fs = b.GetFontString and b:GetFontString();
	if not fs then
		fs = b:CreateFontString(nil, "OVERLAY", T.FONT.name);
		fs:SetPoint("CENTER", b, "CENTER", 0, 0);
		if b.SetFontString then b:SetFontString(fs); end
	end
	if fs.SetWordWrap then fs:SetWordWrap(false); end
	b.label = fs;
	-- the client's own button states, tinted: hover = light veil, pressed = dark veil
	if b.SetHighlightTexture then
		b:SetHighlightTexture(WHITE);
		local hl = b.GetHighlightTexture and b:GetHighlightTexture();
		if hl and hl.SetVertexColor then hl:SetVertexColor(1, 0.95, 0.75, 0.16); end
	end
	if b.SetPushedTexture then
		b:SetPushedTexture(WHITE);
		local pt = b.GetPushedTexture and b:GetPushedTexture();
		if pt and pt.SetVertexColor then pt:SetVertexColor(0, 0, 0, 0.30); end
	end
	b:SetText(label or "");
	b:SetScript("OnClick", function(self, ...) if onClick and self.enabled ~= false then onClick(self, ...); end end);
	skin(b);
	return b;
end

function T.SetLabel(b, label) b:SetText(label or ""); end
function T.SetRole(b, role) b.role = role; skin(b); end
function T.SetEnabled(b, on)
	b.enabled = on and true or false;
	if on then b:Enable(); else b:Disable(); end
	skin(b);
end

-- a segmented pair (e.g. up / down) sharing one frame: two Buttons side by side with a divider
function T.Segment(parent, labels, w, h, onClick)
	local f = CreateFrame("Frame", nil, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	f.buttons = {};
	local each = math.floor(w / #labels);
	for i, label in ipairs(labels) do
		local b = T.Button(f, label, each, h, "secondary", function() if onClick then onClick(i); end end);
		b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * each, 0);
		f.buttons[i] = b;
	end
	return f;
end

-- ------------------------------------------------------------------ text field
function T.Search(parent, w, h, placeholder, onChange, name)
	local f = T.Frame(parent, w, h, "inset");
	local e = CreateFrame("EditBox", name, f);
	e:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -2);
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 2);
	e:SetAutoFocus(false);
	e:SetFontObject(T.FONT.body);
	e:SetTextColor(C.ivory[1], C.ivory[2], C.ivory[3]);
	if e.SetTextInsets then e:SetTextInsets(0, 0, 0, 0); end
	local ph = T.Text(f, T.FONT.body, C.dim, 8, math.floor((h - 14) / 2), w - 16, 14);
	ph:SetText(placeholder or "");
	f.edit, f.placeholder = e, ph;
	local function sync() if e:GetText() == "" and not e:HasFocus() then ph:Show(); else ph:Hide(); end end
	e:SetScript("OnEditFocusGained", function() T.SetBorderColor(f, C.gold); sync(); end);
	e:SetScript("OnEditFocusLost", function() T.SetBorderColor(f, SURFACE.inset.border); sync(); end);
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnTextChanged", function(self, user) sync(); if user and onChange then onChange(self:GetText()); end end);
	f.Sync = sync;
	sync();
	return f;
end

-- ------------------------------------------------------------------ rows, icons, cells
-- icon in a bordered square; the border colour is the item's rarity (the label always says the rarity too)
function T.Icon(parent, size, x, y)
	local f = CreateFrame("Frame", nil, parent);
	f:SetWidth(size);
	f:SetHeight(size);
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	f.frameTex = f:CreateTexture(nil, "BACKGROUND");
	f.frameTex:SetAllPoints(f);
	f.frameTex:SetTexture(C.bronzeDim[1], C.bronzeDim[2], C.bronzeDim[3], 1);
	f.tex = f:CreateTexture(nil, "ARTWORK");
	f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2);
	f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2);
	if f.tex.SetTexCoord then f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93); end    -- crop the icon's own dark edge
	return f;
end

function T.SetIcon(icon, path, rarity)
	if path and path ~= "" then
		icon.tex:SetTexture("Interface\\Icons\\" .. path);
		icon:Show();
	else
		icon.tex:SetTexture(C.field[1], C.field[2], C.field[3], 1);
	end
	local col = rarity and C.rarity[rarity] or C.bronzeDim;
	icon.frameTex:SetTexture(col[1], col[2], col[3], 1);
end

-- list row: alternating band, hover veil from the client's highlight, selection = deep blue + gold bar on the left
function T.Row(parent, w, h, index, name)
	local r = CreateFrame("Button", name, parent);
	r:SetWidth(w);
	r:SetHeight(h);
	r.band = r:CreateTexture(nil, "BACKGROUND");
	r.band:SetAllPoints(r);
	local band = (index or 1) % 2 == 0 and { 0.070, 0.078, 0.112 } or { 0.088, 0.098, 0.138 };
	r.band:SetTexture(band[1], band[2], band[3], 1);
	r.sel = r:CreateTexture(nil, "BORDER");
	r.sel:SetAllPoints(r);
	r.sel:SetTexture(C.blue[1], C.blue[2], C.blue[3], 0.85);
	r.sel:Hide();
	r.bar = r:CreateTexture(nil, "ARTWORK");
	r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0);
	r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0);
	r.bar:SetWidth(3);
	r.bar:SetTexture(C.gold[1], C.gold[2], C.gold[3], 1);
	r.bar:Hide();
	if r.SetHighlightTexture then
		r:SetHighlightTexture(WHITE);
		local hl = r.GetHighlightTexture and r:GetHighlightTexture();
		if hl and hl.SetVertexColor then hl:SetVertexColor(1, 0.95, 0.75, 0.08); end
	end
	return r;
end

function T.SetSelected(r, on)
	if on then r.sel:Show(); r.bar:Show(); else r.sel:Hide(); r.bar:Hide(); end
end

-- equipment cell: framed, with RESERVED zones (header strip: role + remove button; below: icon + two-line name)
function T.Cell(parent, w, h, name)
	local c = CreateFrame("Button", name, parent);
	c:SetWidth(w);
	c:SetHeight(h);
	T.Surface(c, "card");
	c.role = T.Text(c, T.FONT.small, C.mute, 7, 4, w - 40, 12);
	c.icon = T.Icon(c, h - 22, 6, 18);
	c.name = T.Text(c, T.FONT.small, C.ivory, h - 12, 20, w - (h - 12) - 6, h - 24);
	if c.name.SetWordWrap then c.name:SetWordWrap(true); end
	c.name:SetJustifyV("TOP");
	c.remove = T.Button(c, "x", 22, 16, "danger", nil);
	c.remove:SetPoint("TOPRIGHT", c, "TOPRIGHT", -3, -3);
	if c.SetHighlightTexture then
		c:SetHighlightTexture(WHITE);
		local hl = c.GetHighlightTexture and c:GetHighlightTexture();
		if hl and hl.SetVertexColor then hl:SetVertexColor(1, 0.95, 0.75, 0.07); end
	end
	return c;
end

function T.SetCellState(c, state)       -- "empty" | "filled" | "selected"
	if state == "selected" then
		T.SetBorderColor(c, C.gold);
	elseif state == "empty" then
		T.SetBorderColor(c, C.bronzeDim);
	else
		T.SetBorderColor(c, SURFACE.card.border);
	end
end

-- ------------------------------------------------------------------ tooltip (own frame: sized by its content, kept on screen)
function T.Tooltip(parent)
	local f = T.Frame(parent, 300, 60, "window");
	f:SetFrameStrata("TOOLTIP");
	f.title = T.Text(f, T.FONT.name, C.gold, 10, 8, 280, 16);
	f.body = T.Text(f, T.FONT.small, C.ivory, 10, 28, 280, 14);
	if f.body.SetWordWrap then f.body:SetWordWrap(true); end
	f.body:SetJustifyV("TOP");
	f:Hide();
	return f;
end

-- shows `title` and `lines` (array of strings) next to `owner`; opens on the side with more room
function T.ShowTooltip(tip, owner, title, lines)
	tip.title:SetText(title or "");
	local text = table.concat(lines or {}, "\n");
	tip.body:SetText(text);
	local bodyH = tip.body.GetStringHeight and tip.body:GetStringHeight() or (#(lines or {}) * 13);
	if not bodyH or bodyH < 13 then bodyH = 13; end
	tip.body:SetHeight(bodyH);
	tip:SetHeight(math.min(34 + bodyH + 10, 240));       -- sized by content, with a sensible maximum
	tip:ClearAllPoints();
	local left, right = owner:GetLeft(), owner:GetRight();
	local sw = UIParent:GetWidth() * UIParent:GetEffectiveScale();
	local es = owner:GetEffectiveScale();
	if left and right and (right * es + 310) > sw then
		tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -6, 0);
	else
		tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 6, 0);
	end
	tip:Show();
end
