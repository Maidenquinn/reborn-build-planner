-- Theme v2 (Lot 3.5b): the planner's look, built from ORIGINAL texture files (tools/make_textures.py draws them; no asset of
-- any game or addon is used). The 0.4.3-proto1 lab (gradients + 1 px borders) was judged identical to the flat theme in the real
-- client, so v2 does not rely on gradients or hairlines any more:
--   * panels, windows, buttons, fields, cells, tooltips are NINE-SLICE textures (4 fixed corners, 4 stretched edges, 1 centre)
--     with chiselled corners, gold studs, bronze double rules, embossed bevels;
--   * button states are visible veils: warm light on hover, dark on pressed (the client's own highlight / pushed textures
--     carry them, no script), and a distinct texture per role (primary, secondary, danger, selected, disabled);
--   * everything is opaque (alpha 255) and sits on its own high strata / level so game text cannot show through.
-- Two techniques are kept: mode "textures" (default) and mode "backdrop" (the flat 0.4.x look, for side-by-side comparison).
-- If a texture file fails to load (wrong path, bad file), the client draws a plain green/white square: the lab prints the
-- Media path and lists every file so that this is obvious on a screenshot. No OnUpdate, no timer, no HookScript.
local ADDON, ns = ...;
ns = ns or {};
local T = { mode = "textures", surfaces = {} };
ns.Theme = T;

local WHITE = "Interface\\Buttons\\WHITE8X8";
T.WHITE = WHITE;
T.media = "Interface\\AddOns\\" .. tostring(ADDON or "RebornBuildPlanner") .. "\\Media\\";
local function M(name) return T.media .. name .. ".tga"; end
T.Media = M;

-- ------------------------------------------------------------------ palette
T.C = {
	ink = { 0.020, 0.050, 0.102 }, slate = { 0.075, 0.122, 0.210 }, slate2 = { 0.115, 0.180, 0.290 }, field = { 0.025, 0.050, 0.090 },
	ivory = { 0.92, 0.96, 1 }, mute = { 0.73, 0.83, 0.94 }, dim = { 0.52, 0.64, 0.77 },
	gold = { 0.71, 0.87, 0.98 }, bronze = { 0.35, 0.61, 0.77 }, bronzeDim = { 0.20, 0.36, 0.56 },
	blue = { 0.25, 0.52, 0.84 }, green = { 0.48, 0.88, 0.72 }, red = { 0.85, 0.40, 0.43 },
	rarity = { common = { 0.88, 0.88, 0.92 }, uncommon = { 0.30, 0.90, 0.35 }, rare = { 0.35, 0.62, 1 },
		epic = { 0.70, 0.40, 0.95 }, legendary = { 1, 0.58, 0.14 } },
};
local C = T.C;

T.FONT = { window = "GameFontNormalLarge", section = "GameFontNormal", name = "GameFontNormal", body = "GameFontHighlight",
	small = "GameFontNormalSmall", tiny = "GameFontHighlightSmall" };

-- label colour per role; the texture of each role is button_<role>_nine
T.ROLES = {
	primary = { text = { 0.95, 0.98, 1 }, flat = { 0.15, 0.35, 0.62 }, border = { 0.50, 0.79, 0.95 } },
	secondary = { text = { 0.87, 0.93, 1 }, flat = { 0.10, 0.18, 0.31 }, border = { 0.33, 0.53, 0.72 } },
	danger = { text = { 1, 0.80, 0.76 }, flat = { 0.34, 0.12, 0.11 }, border = { 0.69, 0.29, 0.24 } },
	selected = { text = { 0.95, 0.99, 1 }, flat = { 0.16, 0.34, 0.61 }, border = { 0.70, 0.88, 1 } },
	disabled = { text = { 0.55, 0.57, 0.63 }, flat = { 0.11, 0.12, 0.16 }, border = { 0.21, 0.22, 0.27 } },
};

-- ------------------------------------------------------------------ colour maths (contrast tests)
local function lin(c) if c <= 0.03928 then return c / 12.92; end return ((c + 0.055) / 1.055) ^ 2.4; end
function T.Luminance(rgb) return 0.2126 * lin(rgb[1]) + 0.7152 * lin(rgb[2]) + 0.0722 * lin(rgb[3]); end
function T.Contrast(a, b)
	local la, lb = T.Luminance(a), T.Luminance(b);
	if la < lb then la, lb = lb, la; end
	return (la + 0.05) / (lb + 0.05);
end
local function mid(a, b) return { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }; end
T.Mid = mid;

-- texture files of the theme: name -> { pixel size, corner (nine-slice only) }; mirrored by the generator and the tests
T.FILES = {
	ultimate_panel = { 256, 20 }, ultimate_corner = { 128 }, ultimate_crest = { 128 }, ultimate_titlebar = { 512 },
	ultimate_minimap = { 64 }, ultimate_fav_off = { 64 }, ultimate_fav_on = { 64 }, ultimate_class_monk = { 64 }, ultimate_class_dh = { 64 },
	panel_nine = { 64, 16 }, window_nine = { 128, 28 }, inset_nine = { 32, 6 }, titlebar_nine = { 64, 12, 32 }, tooltip_nine = { 64, 14 },
	slot_normal_nine = { 32, 8 }, slot_selected_nine = { 32, 8 }, slot_empty_nine = { 32, 8 },
	button_primary_nine = { 32, 8 }, button_secondary_nine = { 32, 8 }, button_danger_nine = { 32, 8 }, button_selected_nine = { 32, 8 },
	button_disabled_nine = { 32, 8 },
	veil_hover = { 32 }, veil_pressed = { 32 }, separator = { 128 }, icon_frame = { 64 }, row_sel = { 16 }, thumb = { 16 },
};

-- surface kind -> texture file
local SURFACE = { window = "window_nine", panel = "ultimate_panel", inset = "inset_nine", card = "slot_normal_nine", tooltip = "tooltip_nine",
	titlebar = "titlebar_nine" };
T.SURFACE = {
	window = { top = { 0.07, 0.085, 0.14 }, bottom = { 0.035, 0.043, 0.075 } },
	panel = { top = { 0.105, 0.125, 0.19 }, bottom = { 0.062, 0.074, 0.12 } },
	inset = { top = { 0.045, 0.055, 0.085 }, bottom = { 0.035, 0.043, 0.07 } },
	card = { top = { 0.14, 0.16, 0.24 }, bottom = { 0.09, 0.105, 0.16 } },
};

-- ------------------------------------------------------------------ nine-slice
-- Builds 9 textures on `frame` from one file (square `size` px, `corner` px): corners keep their size, edges and centre
-- stretch. Returns an object whose :SetFile(name) swaps the picture (states) and :SetColor tints it.
function T.Nine(frame, file, layer)
	local def = T.FILES[file];
	local size, c = def[1], def[2];
	local sizeH = def[3] or size;                       -- most files are square; the title bar is 64 x 32
	local n = { tex = {}, file = file };
	local u1, u2 = c / size, 1 - c / size;
	local v1, v2 = c / sizeH, 1 - c / sizeH;
	local function mk(l, r, t, b)
		local tex = frame:CreateTexture(nil, layer or "BACKGROUND");
		tex:SetTexture(M(file));
		tex:SetTexCoord(l, r, t, b);
		n.tex[#n.tex + 1] = tex;
		return tex;
	end
	local tl = mk(0, u1, 0, v1);   tl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);         tl:SetWidth(c); tl:SetHeight(c);
	local tr = mk(u2, 1, 0, v1);   tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0);       tr:SetWidth(c); tr:SetHeight(c);
	local bl = mk(0, u1, v2, 1);   bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);   bl:SetWidth(c); bl:SetHeight(c);
	local br = mk(u2, 1, v2, 1);   br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0); br:SetWidth(c); br:SetHeight(c);
	local top = mk(u1, u2, 0, v1); top:SetPoint("TOPLEFT", frame, "TOPLEFT", c, 0);        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -c, 0); top:SetHeight(c);
	local bot = mk(u1, u2, v2, 1); bot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", c, 0);  bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -c, 0); bot:SetHeight(c);
	local lf = mk(0, u1, v1, v2);  lf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -c);        lf:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, c); lf:SetWidth(c);
	local rt = mk(u2, 1, v1, v2);  rt:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -c);      rt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, c); rt:SetWidth(c);
	local ce = mk(u1, u2, v1, v2); ce:SetPoint("TOPLEFT", frame, "TOPLEFT", c, -c);        ce:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -c, c);
	function n:SetFile(f2)
		if f2 == self.file then return; end
		self.file = f2;
		for _, tex in ipairs(self.tex) do tex:SetTexture(M(f2)); end
	end
	function n:SetColor(r, g, b, a) for _, tex in ipairs(self.tex) do tex:SetVertexColor(r, g, b, a or 1); end end
	return n;
end

-- Buttons only need horizontal stretching: 3 regions instead of 9.
-- Preserves edge proportions and greatly reduces the static widget count.
-- The caller retains the same :SetFile and .file contract as T.Nine.
function T.Three(frame, file, layer)
	local def = assert(T.FILES[file]);
	local size, c = def[1], def[2];
	local cut = c / size;
	local n = { tex = {}, file = file };
	local function mk(x1, x2)
		local t = frame:CreateTexture(nil, layer or "BACKGROUND");
		t:SetTexture(M(file));
		t:SetTexCoord(x1, x2, 0, 1);
		n.tex[#n.tex + 1] = t;
		return t;
	end
	local left = mk(0, cut);
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);
	left:SetWidth(c);
	local right = mk(1 - cut, 1);
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0);
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0);
	right:SetWidth(c);
	local mid = mk(cut, 1 - cut);
	mid:SetPoint("TOPLEFT", frame, "TOPLEFT", c, 0);
	mid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -c, 0);
	function n:SetFile(nextFile)
		if self.file == nextFile then return; end
		self.file = nextFile;
		for _, t in ipairs(self.tex) do t:SetTexture(M(nextFile)); end
	end
	return n;
end

-- text cut to a pixel budget with an ellipsis (UTF-8 aware; 0.62 x font size per glyph, a little pessimistic)
function T.Fit(str, px, size)
	local max = math.floor(px / ((size or 12) * 0.62));
	local n, i, len = 0, 1, #str;
	while i <= len do
		local b = string.byte(str, i);
		i = i + ((b < 0x80) and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4)));
		n = n + 1;
		if n > max then
			local k, c = 1, 0;
			while c < max - 3 and k <= len do
				local bb = string.byte(str, k);
				k = k + ((bb < 0x80) and 1 or (bb < 0xE0 and 2 or (bb < 0xF0 and 3 or 4)));
				c = c + 1;
			end
			return string.sub(str, 1, k - 1) .. "...";
		end
	end
	return str;
end

-- ------------------------------------------------------------------ surfaces
-- A framed surface. In "textures" mode: a nine-slice file; in "backdrop" mode: the flat 0.4.x look.
function T.Surface(frame, kind)
	frame.surfaceKind = kind;
	T.surfaces[#T.surfaces+1] = frame;
	if T.mode == "backdrop" then
		local s = T.SURFACE[kind] or T.SURFACE.panel;
		local m = mid(s.top, s.bottom);
		frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
		frame:SetBackdropColor(m[1], m[2], m[3], 1);
		frame:SetBackdropBorderColor(0.35, 0.28, 0.17, 1);
		return frame;
	end
	frame.nine = T.Nine(frame, SURFACE[kind] or "panel_nine", "BACKGROUND");
	-- Standard mode follows the game's native dark cards rather than the
	-- prototype's saturated blue panels. Keep the existing engraved corners
	-- visible but use a near-black inset in all three main surfaces.
	if kind=="window" or kind=="panel" or kind=="inset" then
		for _,piece in ipairs(frame.nine.tex or {}) do
			piece:SetVertexColor(.82,.80,.72,1);
		end
		local inset=kind=="window" and 18 or (kind=="panel" and 11 or 7);
		frame.standardMatte=frame:CreateTexture(nil,"ARTWORK");
		frame.standardMatte:SetTexture(WHITE);
		frame.standardMatte:SetPoint("TOPLEFT",frame,"TOPLEFT",inset,-inset);
		frame.standardMatte:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-inset,inset);
		frame.standardMatte:SetVertexColor(.014,.020,.023,.96);
	end
	return frame;
end

-- Only the painted interiors fade. Never lower a parent Frame's alpha:
-- that would also fade its labels, icons, outlines and interactive children.
function T.ApplyBackgroundOpacity(root, opacity)
  if not root then return end
  opacity=type(opacity)=="number" and math.max(0,math.min(1,opacity)) or 1;
  for _,surface in ipairs(T.surfaces) do
    local node=surface;
    local inWindow=false;
    while node do
      if node==root then inWindow=true;break end
      node=type(node.GetParent)=="function" and node:GetParent() or nil;
    end
    if inWindow then
      if T.mode=="backdrop" then
        local palette=T.SURFACE[surface.surfaceKind] or T.SURFACE.panel;
        local m=mid(palette.top,palette.bottom);
        surface:SetBackdropColor(m[1],m[2],m[3],opacity);
      else
        -- Nine tex[9] is the interior tile; the other 8 are the engraved rim.
        if surface.nine and surface.nine.tex and surface.nine.tex[9] then
          surface.nine.tex[9]:SetAlpha(opacity);
        end
        if surface.standardMatte then surface.standardMatte:SetAlpha(opacity) end
      end
    end
  end
end

function T.Frame(parent, w, h, kind, name)
	local f = CreateFrame("Frame", name, parent);
	f:SetWidth(w);
	f:SetHeight(h);
	return T.Surface(f, kind);
end

-- the main window: top strata and level (above the game's own HUD texts), mouse-opaque, nothing transparent behind it
function T.Window(parent, w, h, name)
	local f = T.Frame(parent or UIParent, w, h, "window", name);
	f:SetFrameStrata("FULLSCREEN_DIALOG");
	f:SetFrameLevel(100);
	if f.SetToplevel then f:SetToplevel(true); end
	if T.mode == "textures" then
		-- Fantasy corners are decoration only; mouse handling stays on the parent frame.
		for i, place in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
			local tex = f:CreateTexture(nil, "BORDER");
			tex:SetTexture(M("ultimate_corner"));
			tex:SetWidth(42); tex:SetHeight(42);
			tex:SetPoint(place, f, place, 0, 0);
			if i == 2 then tex:SetTexCoord(1, 0, 0, 1);
			elseif i == 3 then tex:SetTexCoord(0, 1, 1, 0);
			elseif i == 4 then tex:SetTexCoord(1, 0, 1, 0); end
		end
	end
	f:EnableMouse(true);
	return f;
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

-- Section title uses a quiet steel label and subtle fading divider.
function T.SectionTitle(parent, label, x, y, w)
	local fs = T.Text(parent, T.FONT.section, C.mute, x, y, w, 16);
	fs:SetText(label);
	local sep = parent:CreateTexture(nil, "ARTWORK");
	sep:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 17));
	sep:SetWidth(w);
	sep:SetHeight(5);
	if T.mode == "backdrop" then sep:SetTexture(0.35, 0.28, 0.17, 1); sep:SetHeight(1); else sep:SetTexture(M("separator")); end
	fs.rule = sep;
	return fs;
end

-- a title bar: nine-slice band with the title centred
function T.TitleBar(parent, label, x, y, w, h)
	local bar = CreateFrame("Frame", nil, parent);
	bar:SetWidth(w);
	bar:SetHeight(h or 34);
	bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	if T.mode == "backdrop" then
		bar:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
		bar:SetBackdropColor(0.10, 0.11, 0.16, 1);
		bar:SetBackdropBorderColor(0.35, 0.28, 0.17, 1);
	else
		local art = bar:CreateTexture(nil, "BACKGROUND");
		art:SetTexture(M("ultimate_titlebar")); art:SetAllPoints(bar);
		local crest = bar:CreateTexture(nil, "ARTWORK");
		crest:SetTexture(M("ultimate_crest"));
		crest:SetWidth(28); crest:SetHeight(28); -- restrained small emblem, not a giant RPG crest
		crest:SetPoint("LEFT", bar, "LEFT", 8, 0);
	end
	bar.title = T.Text(bar, T.FONT.window, C.ivory, 43, math.floor(((h or 34) - 16) / 2), w - 52, 18, "LEFT");
	bar.title:SetText(label or "");
	return bar;
end

-- ------------------------------------------------------------------ buttons
local function skin(b)
	local role = b.enabled == false and "disabled" or (b.role or "secondary");
	local r = T.ROLES[role] or T.ROLES.secondary;
	b.skinRole = role;
	if b.mode == "backdrop" then
		b:SetBackdropColor(r.flat[1], r.flat[2], r.flat[3], 1);
		b:SetBackdropBorderColor(r.border[1], r.border[2], r.border[3], 1);
	else
		b.nine:SetFile("button_" .. role .. "_nine");
	end
	b.label:SetTextColor(r.text[1], r.text[2], r.text[3]);
end

function T.Button(parent, label, w, h, role, onClick, name)
	local b = CreateFrame("Button", name, parent);
	b:SetWidth(w);
	b:SetHeight(h or 28);
	b.role, b.enabled, b.mode = role or "secondary", true, T.mode;
	if T.mode == "backdrop" then
		b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } });
	else
		b.nine = T.Three(b, "button_secondary_nine", "BACKGROUND");
	end
	local fs = b.GetFontString and b:GetFontString();
	if not fs then
		fs = b:CreateFontString(nil, "OVERLAY", T.FONT.name);
		if b.SetFontString then b:SetFontString(fs); end
	end
	fs:ClearAllPoints();
	fs:SetPoint("CENTER", b, "CENTER", 0, 0);
	fs:SetJustifyH("CENTER");
	if fs.SetWordWrap then fs:SetWordWrap(false); end
	b.label = fs;
	-- visible states: the client's highlight (hover) and pushed (click) textures carry OUR veil files, no script involved
	local hoverFile, pressFile = (T.mode == "backdrop") and WHITE or M("veil_hover"), (T.mode == "backdrop") and WHITE or M("veil_pressed");
	if b.SetHighlightTexture then
		b:SetHighlightTexture(hoverFile);
		local hl = b.GetHighlightTexture and b:GetHighlightTexture();
		if hl then hl:SetAllPoints(b); if T.mode == "backdrop" and hl.SetVertexColor then hl:SetVertexColor(1, 1, 1, 0.10); end end
	end
	if b.SetPushedTexture then
		b:SetPushedTexture(pressFile);
		local pt = b.GetPushedTexture and b:GetPushedTexture();
		if pt then pt:SetAllPoints(b); if T.mode == "backdrop" and pt.SetVertexColor then pt:SetVertexColor(0, 0, 0, 0.30); end end
	end
	-- forced-state overlays (for the lab and for "selected" feedback on demand): normally hidden
	b.veilHover = b:CreateTexture(nil, "OVERLAY");
	b.veilHover:SetAllPoints(b);
	b.veilHover:SetTexture(T.mode == "backdrop" and WHITE or hoverFile);
	if T.mode == "backdrop" then b.veilHover:SetVertexColor(1, 1, 1, 0.10); end
	b.veilHover:Hide();
	b.veilPressed = b:CreateTexture(nil, "OVERLAY");
	b.veilPressed:SetAllPoints(b);
	b.veilPressed:SetTexture(T.mode == "backdrop" and WHITE or pressFile);
	if T.mode == "backdrop" then b.veilPressed:SetVertexColor(0, 0, 0, 0.30); end
	b.veilPressed:Hide();
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
-- show a state without the mouse ("hover" | "pressed" | nil)
function T.ForceState(b, state)
	if state == "hover" then b.veilHover:Show(); b.veilPressed:Hide();
	elseif state == "pressed" then b.veilPressed:Show(); b.veilHover:Hide();
	else b.veilHover:Hide(); b.veilPressed:Hide(); end
end

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
	e:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -3);
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 3);
	e:SetAutoFocus(false);
	e:SetFontObject(T.FONT.body);
	e:SetTextColor(C.ivory[1], C.ivory[2], C.ivory[3]);
	if e.SetTextInsets then e:SetTextInsets(0, 0, 0, 0); end
	local ph = T.Text(f, T.FONT.body, C.dim, 10, math.floor((h - 14) / 2), w - 20, 14);
	ph:SetText(placeholder or "");
	f.edit, f.placeholder = e, ph;
	-- focus ring: a gold nine-slice frame shown only while typing
	f.focus = f:CreateTexture(nil, "OVERLAY");
	f.focus:SetAllPoints(f);
	f.focus:SetTexture(T.mode == "backdrop" and WHITE or M("slot_selected_nine"));
	if T.mode ~= "backdrop" then f.focus:SetAlpha(0.55); else f.focus:SetVertexColor(0.93, 0.78, 0.40, 0.25); end
	f.focus:Hide();
	local function sync() if e:GetText() == "" and not e:HasFocus() then ph:Show(); else ph:Hide(); end end
	e:SetScript("OnEditFocusGained", function() f.focus:Show(); sync(); end);
	e:SetScript("OnEditFocusLost", function() f.focus:Hide(); sync(); end);
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
	e:SetScript("OnTextChanged", function(self, user) sync(); if user and onChange then onChange(self:GetText()); end end);
	f.Sync = sync;
	sync();
	return f;
end

-- ------------------------------------------------------------------ icons, rows, cells
-- the icon, then an opaque bronze frame texture on top tinted by the item's rarity (the label always says the rarity too)
function T.Icon(parent, size, x, y)
	local f = CreateFrame("Frame", nil, parent);
	f:SetWidth(size);
	f:SetHeight(size);
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y);
	f.back = f:CreateTexture(nil, "BACKGROUND");
	f.back:SetAllPoints(f);
	f.back:SetTexture(C.field[1], C.field[2], C.field[3], 1);
	f.tex = f:CreateTexture(nil, "ARTWORK");
	f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3);
	f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3);
	if f.tex.SetTexCoord then f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93); end
	f.frameTex = f:CreateTexture(nil, "OVERLAY");
	f.frameTex:SetAllPoints(f);
	f.frameTex:SetTexture(T.mode == "backdrop" and WHITE or M("icon_frame"));
	if T.mode == "backdrop" then f.frameTex:SetTexture(C.bronzeDim[1], C.bronzeDim[2], C.bronzeDim[3], 0); end
	return f;
end

function T.SetIcon(icon, path, rarity)
	if path and path ~= "" then
		icon.tex:SetTexture("Interface\\Icons\\" .. path);
		icon.tex:Show();
	else
		icon.tex:Hide();
	end
	local col = rarity and C.rarity[rarity] or C.bronze;
	if T.mode ~= "backdrop" then icon.frameTex:SetVertexColor(col[1], col[2], col[3], 1); end
end

-- list row: alternating opaque bands, hover = warm veil (client highlight), selected = blue-gold texture
function T.Row(parent, w, h, index, name)
	local r = CreateFrame("Button", name, parent);
	r:SetWidth(w);
	r:SetHeight(h);
	r.band = r:CreateTexture(nil, "BACKGROUND");
	r.band:SetAllPoints(r);
	local band = (index or 1) % 2 == 0 and { 0.075, 0.088, 0.135 } or { 0.098, 0.115, 0.175 };
	r.band:SetTexture(band[1], band[2], band[3], 1);
	r.sel = r:CreateTexture(nil, "BORDER");
	r.sel:SetAllPoints(r);
	r.sel:SetTexture(T.mode == "backdrop" and WHITE or M("row_sel"));
	if T.mode == "backdrop" then r.sel:SetVertexColor(C.blue[1], C.blue[2], C.blue[3], 0.85); end
	r.sel:Hide();
	r.bar = r:CreateTexture(nil, "ARTWORK");       -- a solid gold bar (not part of row_sel.tga: stretching a texture would fatten it)
	r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0);
	r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0);
	r.bar:SetWidth(3);
	r.bar:SetTexture(C.gold[1], C.gold[2], C.gold[3], 1);
	r.bar:Hide();
	if r.SetHighlightTexture then
		r:SetHighlightTexture(T.mode == "backdrop" and WHITE or M("veil_hover"));
		local hl = r.GetHighlightTexture and r:GetHighlightTexture();
		if hl then hl:SetAllPoints(r); if hl.SetAlpha then hl:SetAlpha(T.mode == "backdrop" and 0.10 or 0.35); end end
	end
	return r;
end

function T.SetSelected(r, on)
	if on then r.sel:Show(); r.bar:Show(); else r.sel:Hide(); r.bar:Hide(); end
end

-- equipment cell: nine-slice background (normal / selected / empty), reserved zones: header strip (role + remove), icon, name
function T.Cell(parent, w, h, name)
	local c = CreateFrame("Button", name, parent);
	c:SetWidth(w);
	c:SetHeight(h);
	c.mode = T.mode;
	if T.mode == "backdrop" then
		T.Surface(c, "card");
	else
		c.nine = T.Nine(c, "slot_normal_nine", "BACKGROUND");
	end
	c.role = T.Text(c, T.FONT.small, C.mute, 9, 6, w - 44, 12);
	c.icon = T.Icon(c, h - 24, 8, 20);
	c.name = T.Text(c, T.FONT.small, C.ivory, h - 12, 22, w - (h - 12) - 8, h - 28);
	if c.name.SetWordWrap then c.name:SetWordWrap(true); end
	c.name:SetJustifyV("TOP");
	c.remove = T.Button(c, "x", 22, 18, "danger", nil);
	c.remove:SetPoint("TOPRIGHT", c, "TOPRIGHT", -5, -5);
	if c.SetHighlightTexture then
		c:SetHighlightTexture(T.mode == "backdrop" and WHITE or M("veil_hover"));
		local hl = c.GetHighlightTexture and c:GetHighlightTexture();
		if hl then hl:SetAllPoints(c); if hl.SetAlpha then hl:SetAlpha(T.mode == "backdrop" and 0.07 or 0.25); end end
	end
	return c;
end

function T.SetCellState(c, state)       -- "empty" | "filled" | "selected"
	if c.mode == "backdrop" then
		local col = state == "selected" and C.gold or C.bronzeDim;
		c:SetBackdropBorderColor(col[1], col[2], col[3], 1);
		return;
	end
	c.nine:SetFile(state == "selected" and "slot_selected_nine" or (state == "empty" and "slot_empty_nine" or "slot_normal_nine"));
end

-- ------------------------------------------------------------------ scroll bar (a Slider with our thumb and a sunken track)
function T.ScrollBar(parent, h, onChange)
	local track = T.Frame(parent, 14, h, "inset");
	local s = CreateFrame("Slider", nil, track);
	s:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -2);
	s:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 2);
	s:SetOrientation("VERTICAL");
	s:SetMinMaxValues(0, 1);
	s:SetValueStep(1);
	s:SetThumbTexture(T.mode == "backdrop" and WHITE or M("thumb"));
	local th = s.GetThumbTexture and s:GetThumbTexture();
	if th then th:SetWidth(12); th:SetHeight(30); if T.mode == "backdrop" and th.SetVertexColor then th:SetVertexColor(0.93, 0.78, 0.40, 0.8); end end
	s:SetScript("OnValueChanged", function(self, v) if not self.syncing and onChange then onChange(math.floor(v + 0.5)); end end);
	track.slider = s;
	function track.Sync(offset, max)
		s.syncing = true;
		s:SetMinMaxValues(0, math.max(1, max));
		s:SetValue(offset);
		s.syncing = nil;
		if max > 0 then s:Show(); else s:Hide(); end
	end
	return track;
end

-- ------------------------------------------------------------------ tooltip frame: opaque nine-slice, sized by content, kept on screen
function T.Tooltip(parent, width)
	width = width or 300;
	local f = T.Frame(parent, width, 60, "tooltip");
	f.inner = width - 28;
	f:SetFrameStrata("TOOLTIP");
	f.title = T.Text(f, T.FONT.name, C.gold, 14, 12, width - 28, 16);
	f.body = T.Text(f, T.FONT.small, C.ivory, 14, 32, width - 28, 14);
	if f.body.SetWordWrap then f.body:SetWordWrap(true); end
	f.body:SetJustifyV("TOP");
	f:Hide();
	return f;
end

function T.ShowTooltip(tip, owner, title, lines)
	tip.title:SetText(T.Fit(title or "", tip.inner or 272, 12));
	tip.body:SetText(table.concat(lines or {}, "\n"));
	local bodyH = tip.body.GetStringHeight and tip.body:GetStringHeight() or (#(lines or {}) * 13);
	if not bodyH or bodyH < 13 then bodyH = 13; end
	tip.body:SetHeight(bodyH);
	tip:SetHeight(math.min(32 + bodyH + 16, 240));
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

-- ------------------------------------------------------------------ what this client can do (printed by /rbplab diag)
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
		SetToplevel = type(frame.SetToplevel) == "function",
	};
	tex:Hide(); btn:Hide(); eb:Hide(); fs:Hide();
	return cap;
end
