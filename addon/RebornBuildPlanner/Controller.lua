-- Controller: ALL the behaviour of the planner window, with no widget in it (so it is testable headless and
-- the widget layer in UI.lua stays a thin renderer). It holds the view state, the editor DRAFT (a copy of the
-- build, distinct from the persisted one), and calls only the validated modules: Storage, BuildModel, Catalog,
-- PlannerCodec. Nothing is saved implicitly; nothing is activated except by an explicit call.
local ADDON, ns = ...;
ns = ns or {};
local Util, BM, Locale = ns.Util, ns.BuildModel, ns.Locale;
assert(Util and BM and Locale and ns.PlannerCodec, "RebornBuildPlanner: Controller.lua must load after the codec");
local Controller = { LIB_ROWS = 10, CATALOG_ROWS = 14, ISSUE_PAGE = 6, RECENT_MAX = 10 };
ns.Controller = Controller;
Controller.__index = Controller;

local L = function(s) return Locale.T(s); end

function Controller.New(env)
	local self = setmetatable({ env = env or ns, listeners = {} }, Controller);
	self.state = { view = "editor", classFilter = nil, selectedId = nil, libOffset = 0, trashMode = false, message = nil, undo = nil,
		editor = nil, import = nil, export = nil, search = "", filter = nil, sort = nil, inspect = nil };
	self.searchIndex = {};
	return self;
end

-- ------------------------------------------------------------------ plumbing
function Controller:Handle() return self.env.storage; end
function Controller:Catalog() return self.env.catalog; end
function Controller:Lang() return Locale.lang; end
function Controller:ReadOnly() local h = self:Handle(); return h == nil or h.readOnly == true; end

function Controller:Subscribe(fn) self.listeners[#self.listeners + 1] = fn; end
function Controller:Notify()
	self.rowsCache = nil;      -- the library list is recomputed once per change, not per widget or per frame
	for _, fn in ipairs(self.listeners) do fn(self); end
end

function Controller:Say(level, text)
	self.state.message = text and { level = level, text = text } or nil;
	self:Notify();
end

function Controller:StorageStatusText()
	local h = self:Handle();
	if not h then return L("Storage unavailable"); end
	if h.readOnly then
		if h.status == "FUTURE_SCHEMA" then return L("Read only: the saved data comes from a newer version"); end
		if h.status == "REPAIR_REFUSED" or h.status == "MIGRATION_FAILED" then return L("Read only: the saved data could not be repaired safely"); end
		return L("Read only");
	end
	return nil;
end

-- first useful explanation out of a model/storage report
local REASON = {
	TOO_MANY = "Limit reached",
	DUPLICATE_ENTRY = "Already in this list",
	DUPLICATE_PIECE = "Already in this list",
	CONFLICT_SPELL_BANISH = "A spell cannot be both wanted and in the avoid list",
	BANISH_AFTER_NOT_WANTED = "Only a wanted spell can be banished after acquisition",
	WRONG_CLASS = "This entry belongs to another class",
	WRONG_SLOT = "This piece does not fit this slot",
	TOO_LONG = "Text too long",
	INVALID_VALUE = "Invalid value",
	READ_ONLY = "Read only",
	NOT_ACTIVATABLE = "This build needs repair before it can be followed",
	STALE_REVISION = "The build changed elsewhere; reopen it",
	LIBRARY_FULL = "The library is full",
	NOT_FOUND = "Not found",
	INVALID_BUILD = "The build is invalid",
};
local function explain(rep)
	if type(rep) ~= "table" then return L("Refused"); end
	local it = (rep.errors and rep.errors[1]) or (rep.conflicts and rep.conflicts[1]) or (rep.issues and rep.issues[1]);
	local code = it and it.code or rep.code;
	if code == "INVALID_BUILD" and type(rep.detail) == "table" then
		return explain(rep.detail);
	end
	return L(REASON[code] or "Refused");
end
Controller.Explain = explain;

-- ------------------------------------------------------------------ library
function Controller:ClassKeys()
	local cat = self:Catalog();
	return cat and cat:ClassKeys() or {};
end

function Controller:ClassName(key)
	local cat = self:Catalog();
	return cat and cat:ClassName(key, self:Lang()) or tostring(key);
end

-- dir = 1 / -1 cycles: all classes (nil) -> first class -> ... -> last -> all
function Controller:CycleClassFilter(dir)
	local keys = self:ClassKeys();
	local cur = self.state.classFilter;
	local i = 0;
	if cur then
		i = Util.IndexOf(keys, cur) or 0;
	end
	i = i + dir;
	if i < 0 then i = #keys; end
	if i > #keys then i = 0; end
	self:SetClassFilter(i == 0 and nil or keys[i]);
end

function Controller:SetClassFilter(class)
	self.state.classFilter = class;
	self.state.libOffset = 0;
	self.state.selectedId = nil;
	self:Notify();
end

-- ---- library: search, filter, sort (computed once per change; indexed text is cached per build revision)
function Controller:Filter()
	local h = self:Handle();
	return self.state.filter or (h and h:GetSetting("libFilter")) or "all";
end

function Controller:Sort()
	local h = self:Handle();
	return self.state.sort or (h and h:GetSetting("libSort")) or "name";
end

function Controller:SetFilter(f)
	self.state.filter = f;
	local h = self:Handle();
	if h and not h.readOnly then h:SetSetting("libFilter", f); end
	self.state.libOffset = 0;
	self:Notify();
end

function Controller:SetSort(sort)
	self.state.sort = sort;
	local h = self:Handle();
	if h and not h.readOnly then h:SetSetting("libSort", sort); end
	self.state.libOffset = 0;
	self:Notify();
end

function Controller:CycleSort(dir)
	local order, cur = { "name", "used", "modified" }, self:Sort();
	local i = (Util.IndexOf(order, cur) or 1) + dir;
	if i < 1 then i = #order; end
	if i > #order then i = 1; end
	self:SetSort(order[i]);
end

function Controller:SetLibSearch(text)
	text = text or "";
	if self.state.search ~= text then
		self.state.search = text;
		self.state.libOffset = 0;
		self:Notify();
	end
end

-- Lowercased searchable text of a build: name, class (EN and FR names and key), wanted/avoided spells and placed
-- pieces (EN and FR names). Rebuilt only when the build's revision changes.
function Controller:IndexOf(b)
	local cached = self.searchIndex[b.id];
	if cached and cached.rev == b.revision and cached.lang == Locale.lang then return cached.text; end
	local cat = self:Catalog();
	local parts = { b.name or "", b.class or "" };
	if cat then
		parts[#parts + 1] = self:ClassName(b.class);
		if cat:IsClass(b.class) then parts[#parts + 1] = cat:ClassName(b.class); end
	end
	local function name(kind, k)
		if type(k) ~= "string" or k == "" then return; end
		parts[#parts + 1] = k;
		if cat and cat:Get(kind, k) then
			parts[#parts + 1] = cat:Name(kind, k, nil);
			parts[#parts + 1] = cat:Name(kind, k, "frFR");
		end
	end
	for _, ph in ipairs(b.phases or {}) do
		for _, g in ipairs(ph.spells or {}) do name("spell", g.key); end
		for _, k in ipairs(ph.banish or {}) do name("spell", k); end
		for _, k in ipairs(ph.rings or {}) do name("jewel", k); end
		for _, k in ipairs(ph.trinkets or {}) do name("jewel", k); end
		for _, k in ipairs(ph.amulets or {}) do name("amulet", k); end
	end
	local text = string.lower(table.concat(parts, " \n "));
	self.searchIndex[b.id] = { rev = b.revision, lang = Locale.lang, text = text };
	return text;
end

-- Rows of the library: favourites first, then the chosen sort. Items of the trash when trashMode.
function Controller:Rows()
	if self.rowsCache then return self.rowsCache; end
	local h = self:Handle();
	local out = {};
	self.rowsCache = out;
	if not h then return out; end
	local st = self.state;
	if st.trashMode then
		for _, t in ipairs(h:Trash()) do
			if not st.classFilter or t.class == st.classFilter then
				out[#out + 1] = { id = t.id, name = t.name, class = t.class, className = self:ClassName(t.class), trashed = true };
			end
		end
		return out;
	end
	local words = {};
	for w in string.gmatch(string.lower(st.search or ""), "%S+") do words[#words + 1] = w; end
	local filter = self:Filter();
	local builds = h.db and type(h.db.builds) == "table" and h.db.builds or {};
	for _, e in ipairs(h:List(st.classFilter)) do
		local meta = h:Meta(e.id);
		local keep = true;
		if filter == "favorites" and not meta.fav then keep = false; end
		if filter == "recent" and not meta.used then keep = false; end
		if keep and #words > 0 then
			local text = builds[e.id] and self:IndexOf(builds[e.id]) or string.lower(e.name or "");
			for _, w in ipairs(words) do
				if not string.find(text, w, 1, true) then keep = false; break; end
			end
		end
		if keep then
			out[#out + 1] = { id = e.id, name = e.name, class = e.class, className = self:ClassName(e.class), revision = e.revision,
				clean = e.clean, active = h:GetActive(e.class) == e.id, fav = meta.fav, used = meta.used, modified = meta.modified,
				lname = string.lower(e.name or "") };
		end
	end
	local sort = self:Sort();
	local function newer(key)
		return function(x, y)
			if x.fav ~= y.fav then return x.fav; end
			local a, b = x[key], y[key];
			if a ~= b then
				if a == nil then return false; end
				if b == nil then return true; end
				return a > b;
			end
			if x.lname ~= y.lname then return x.lname < y.lname; end
			return x.id < y.id;
		end
	end
	if filter == "recent" then
		table.sort(out, function(x, y)
			if x.used ~= y.used then return x.used > y.used; end
			return x.id < y.id;
		end);
		while #out > Controller.RECENT_MAX do out[#out] = nil; end
	elseif sort == "name" then
		table.sort(out, function(x, y)
			if x.fav ~= y.fav then return x.fav; end
			if x.lname ~= y.lname then return x.lname < y.lname; end
			return x.id < y.id;
		end);
	else
		table.sort(out, newer(sort == "used" and "used" or "modified"));
	end
	return out;
end

-- Scrollable lists: the UI shows a fixed window of rows over the full list; offsets are 0-based and clamped.
local function windowOf(list, offset, n)
	local max = math.max(0, #list - n);
	if offset > max then offset = max; end
	if offset < 0 then offset = 0; end
	local out = {};
	for i = 1, n do out[i] = list[offset + i]; end
	return out, offset, max;
end

function Controller:LibView()
	local out, off, max = windowOf(self:Rows(), self.state.libOffset, Controller.LIB_ROWS);
	self.state.libOffset = off;
	return out, off, max;
end

function Controller:ScrollLib(delta)
	self.state.libOffset = (self.state.libOffset or 0) + delta;
	self:LibView();
	self:Notify();
end

function Controller:SetLibOffset(o)
	self.state.libOffset = o;
	self:LibView();
	self:Notify();
end

function Controller:Select(id)
	self.state.selectedId = id;
	self:Notify();
end

function Controller:Selected()
	for _, r in ipairs(self:Rows()) do
		if r.id == self.state.selectedId then return r; end
	end
	return nil;
end

function Controller:ShowTrash(on)
	self.state.trashMode = on and true or false;
	self.state.libOffset = 0;
	self.state.selectedId = nil;
	self:Notify();
end

-- class for a new build: the filter, else the player's class (token) when known, else the first class
function Controller:DefaultClass()
	local cat = self:Catalog();
	if self.state.classFilter then return self.state.classFilter; end
	local h = self:Handle();
	local last = h and h:GetSetting("lastClass");
	if cat and last and cat:IsClass(last) then return last; end
	if cat and self.env.playerClassToken then
		local c = cat:NormalizeClass(self.env.playerClassToken());
		if c then return c; end
	end
	return cat and cat:ClassKeys()[1] or nil;
end

function Controller:Create(name, class)
	local h = self:Handle();
	if not h or h.readOnly then self:Say("error", L("Read only")); return nil; end
	name = string.gsub(name or "", "^%s+", "");
	name = string.gsub(name, "%s+$", "");
	if name == "" then self:Say("error", L("Give the build a name")); return nil, "EMPTY_NAME"; end
	local id, b = h:Create({ name = name, class = class });
	if not id then self:Say("error", explain(b)); return nil; end
	h:SetSetting("lastClass", class);
	self.state.trashMode = false;
	self.state.selectedId = id;
	self:Say("info", L("Build created (not active)"));
	return id;
end

function Controller:ToggleFavorite(id)
	local h = self:Handle();
	if not h or h.readOnly then self:Say("error", L("Read only")); return false; end
	local ok, err = h:SetFavorite(id, not h:Meta(id).fav);
	if not ok then self:Say("error", explain(err)); return false; end
	self:Notify();
	return true;
end

function Controller:Duplicate(id)
	local h = self:Handle();
	local nid, b = h:Duplicate(id);
	if not nid then self:Say("error", explain(b)); return nil; end
	self.state.selectedId = nid;
	self:Say("info", L("Build duplicated (not active)"));
	return nid;
end

function Controller:Rename(id, name)
	local h = self:Handle();
	local cur = h and h:Get(id);
	if not cur then self:Say("error", L("Not found")); return false; end
	local nb, rep = BM.SetName(cur, name, self:Catalog());
	if not nb then self:Say("error", explain(rep)); return false; end
	local ok, err = h:Update(id, nb);
	if not ok then self:Say("error", explain(err)); return false; end
	-- an open editor on this build must not keep a stale name
	local e = self.state.editor;
	if e and e.id == id then
		e.saved = h:Get(id);
		if e.draft.name == cur.name then e.draft = BM.Clone(e.saved); end
	end
	self:Say("info", L("Renamed"));
	return true;
end

-- Deletion goes through the trash and can be undone; the 20-entry cap is explained to the player.
function Controller:DeleteInfo(id)
	local h = self:Handle();
	local b = h and h:Get(id);
	return { name = b and b.name or "?", trashSize = #h:Trash(), cap = ns.Storage.LIMITS.trash };
end

function Controller:ConfirmDelete(id)
	local h = self:Handle();
	local b = h:Get(id);
	if not b then self:Say("error", L("Not found")); return false; end
	local e = self.state.editor;
	if e and e.id == id and self:EditorDirty() then
		self:Say("error", L("Close the editor of this build first"));
		return false;
	end
	local ok, evicted = h:Delete(id);
	if not ok then self:Say("error", explain(evicted)); return false; end
	if e and e.id == id then self.state.editor = nil; end
	self.state.undo = { id = id, name = b.name };
	self.state.selectedId = nil;
	if evicted then
		self:Say("warn", string.format(L("Deleted. The trash is full: \"%s\" was removed for good"), evicted.name));
	else
		self:Say("info", string.format(L("\"%s\" moved to the trash"), b.name));
	end
	return true;
end

function Controller:UndoDelete()
	local u = self.state.undo;
	if not u then return false; end
	local ok, err = self:Handle():Restore(u.id);
	if not ok then self:Say("error", explain(err)); return false; end
	self.state.undo = nil;
	self.state.selectedId = u.id;
	self:Say("info", L("Build restored"));
	return true;
end

function Controller:Restore(id)
	local ok, err = self:Handle():Restore(id);
	if not ok then self:Say("error", explain(err)); return false; end
	self.state.undo = nil;
	self.state.trashMode = false;
	self.state.selectedId = id;
	self:Say("info", L("Build restored"));
	return true;
end

function Controller:Activate(id)
	local h = self:Handle();
	local b = h:Get(id);
	if not b then return false; end
	local ok, err = h:SetActive(b.class, id);
	if not ok then self:Say("error", explain(err)); return false; end
	h:Touch(id);
	self:Say("info", L("Active build for this class"));
	return true;
end

function Controller:Deactivate(id)
	local h = self:Handle();
	local b = h:Get(id);
	if not b then return false; end
	h:ClearActive(b.class);
	self:Say("info", L("No active build for this class"));
	return true;
end

-- ------------------------------------------------------------------ editor (draft / saved)
local function strip(b)
	local c = Util.DeepCopy(b);
	c.revision = nil;
	-- builds saved before 0.3.1 have no banishAfter: "absent" and "empty" are the same thing
	if type(c.phases) == "table" then
		for _, ph in ipairs(c.phases) do
			if type(ph) == "table" and ph.banishAfter == nil then ph.banishAfter = {}; end
		end
	end
	return c;
end

function Controller:Editor() return self.state.editor; end

function Controller:OpenEditor(id)
	local h = self:Handle();
	local b = h and h:Get(id);
	if not b then self:Say("error", L("Not found")); return false; end
	local cur = self.state.editor;
	if cur and cur.id ~= id and self:EditorDirty() then
		return false, "DIRTY";
	end
	self.state.editor = { id = id, saved = b, draft = BM.Clone(b), phase = 1, cat = "spells", group = "rings", slot = 1, search = "", offset = 0, adv = false };
	self.state.view = "editor";
	self.state.selectedId = id;
	self.state.inspect = nil;
	self.state.message = nil;
	if h then h:Touch(id); end
	self:Notify();
	return true;
end

function Controller:EditorDirty()
	local e = self.state.editor;
	return e ~= nil and not Util.DeepEqual(strip(e.draft), strip(e.saved));
end

-- "readonly" | "dirty" | "repair" | "saved" (primary status), plus needsRepair separately
function Controller:EditorStatus()
	local e = self.state.editor;
	if not e then return nil; end
	local rep = BM.Validate(e.draft, self:Catalog());
	local needs = not rep.clean;
	if self:ReadOnly() then return "readonly", needs; end
	if self:EditorDirty() then return "dirty", needs; end
	if needs then return "repair", needs; end
	return "saved", needs;
end

function Controller:EditorReport()
	local e = self.state.editor;
	return e and BM.Validate(e.draft, self:Catalog()) or nil;
end

function Controller:EditorIsActive()
	local e = self.state.editor;
	return e and self:Handle():GetActive(e.draft.class) == e.id or false;
end

function Controller:Save()
	local e = self.state.editor;
	if not e then return false; end
	if self:ReadOnly() then self:Say("error", L("Read only")); return false; end
	if not self:EditorDirty() then self:Say("info", L("Nothing to save")); return true; end
	local ok, err = self:Handle():Update(e.id, e.draft);
	if not ok then self:Say("error", explain(err)); return false; end
	e.saved = self:Handle():Get(e.id);
	e.draft = BM.Clone(e.saved);
	local _, needs = self:EditorStatus();
	self:Say(needs and "warn" or "info", needs and L("Saved. The build needs repair before it can be followed") or L("Saved"));
	return true;
end

-- save, then make it the active build of its class; the save is kept even if activation is refused
function Controller:SaveAndFollow()
	local e = self.state.editor;
	if not e then return false; end
	if not self:Save() then return false; end
	local ok, err = self:Handle():SetActive(e.draft.class, e.id);
	if not ok then
		self:Say("warn", L("Saved, but not followed: ") .. explain(err));
		return true, "not_active";
	end
	self:Say("info", L("Saved and followed"));
	return true, "active";
end

function Controller:Revert()
	local e = self.state.editor;
	if not e then return; end
	e.draft = BM.Clone(e.saved);
	self:Say("info", L("Changes discarded"));
end

-- "close" when nothing is at stake, "prompt" when there are unsaved changes
function Controller:RequestCloseEditor()
	if self:EditorDirty() then return "prompt"; end
	self:CloseEditor();
	return "close";
end

function Controller:ResolveClose(choice)
	if choice == "cancel" then return false; end
	if choice == "save" then
		if not self:Save() then return false; end
	end
	self:CloseEditor();
	return true;
end

function Controller:CloseEditor()
	self.state.editor = nil;
	self.state.view = "editor";
	self:Notify();
end

-- ---- editing the draft
local function edit(self, fn, ...)
	local e = self.state.editor;
	if not e then return false; end
	if self:ReadOnly() then self:Say("error", L("Read only")); return false; end
	local nb, rep = fn(e.draft, ...);
	if not nb then
		self:Say("error", explain(rep));
		return false, rep;
	end
	e.draft = nb;
	self.state.message = nil;
	self:Notify();
	return true;
end

function Controller:SetName(name) return edit(self, function(b) return BM.SetName(b, name, self:Catalog()); end); end
function Controller:SetTalents(t) return edit(self, function(b) return BM.SetTalents(b, t, self:Catalog()); end); end
function Controller:SetNotes(text) return edit(self, function(b) return BM.SetNotes(b, self.state.editor.phase, text, self:Catalog()); end); end
function Controller:SetLink(text) return edit(self, function(b) return BM.SetLink(b, self.state.editor.phase, text, self:Catalog()); end); end
function Controller:SetLabel(text) return edit(self, function(b) return BM.SetLabel(b, self.state.editor.phase, text, self:Catalog()); end); end

function Controller:AddSpell(key)
	local ph = self.state.editor.draft.phases[self.state.editor.phase];
	for _, b in ipairs(ph.banish) do
		if b == key then self:Say("error", L("This spell is in the banish list: remove it there first")); return false; end
	end
	return edit(self, function(b) return BM.AddSpell(b, self.state.editor.phase, key, nil, self:Catalog()); end);
end

function Controller:AddBanish(key)
	local ph = self.state.editor.draft.phases[self.state.editor.phase];
	for _, g in ipairs(ph.spells) do
		if g.key == key then self:Say("error", L("This spell is wanted: remove it from the plan first")); return false; end
	end
	return edit(self, function(b) return BM.AddBanish(b, self.state.editor.phase, key, self:Catalog()); end);
end

function Controller:RemoveSpell(key)
	local e = self.state.editor;
	local ph = e and e.draft.phases[e.phase];
	local marked = ph and ph.banishAfter and Util.IndexOf(ph.banishAfter, key) ~= nil;
	local ok, rep = edit(self, function(b) return BM.RemoveSpell(b, self.state.editor.phase, key, self:Catalog()); end);
	if ok and marked then
		self:Say("info", L("Spell removed, and its banish-after mark with it"));   -- controlled cleanup, stated
	end
	return ok, rep;
end

-- "Banish after acquisition": a mark on a WANTED spell. Planning only: nothing is ever banished by this addon.
function Controller:SetBanishAfter(key, on)
	return edit(self, function(b) return BM.SetBanishAfter(b, self.state.editor.phase, key, on and true or false, self:Catalog()); end);
end

function Controller:ToggleBanishAfter(key)
	local e = self.state.editor;
	if not e then return false; end
	local ph = e.draft.phases[e.phase];
	local marked = ph.banishAfter and Util.IndexOf(ph.banishAfter, key) ~= nil;
	if not marked and ph.banishAfter and #ph.banishAfter >= BM.LIMITS.banishAfter then
		self:Say("error", string.format(L("At most %d spells can be marked to banish after acquisition"), BM.LIMITS.banishAfter));
		return false;
	end
	return self:SetBanishAfter(key, not marked);
end

-- explicit repair of an old / imported overlap: moves the entry from "avoid" to "banish after acquisition"
function Controller:ConvertBanishToAfter(key)
	return edit(self, function(b) return BM.ConvertBanishToAfter(b, self.state.editor.phase, key, self:Catalog()); end);
end
function Controller:RemoveBanish(key) return edit(self, function(b) return BM.RemoveBanish(b, self.state.editor.phase, key, self:Catalog()); end); end

function Controller:MoveSpell(index, dir)
	return edit(self, function(b) return BM.MoveSpell(b, self.state.editor.phase, index, index + dir, self:Catalog()); end);
end

function Controller:SetSlot(group, pos, key)
	return edit(self, function(b) return BM.SetSlot(b, self.state.editor.phase, group, pos, key, self:Catalog()); end);
end

function Controller:ClearSlot(group, pos)
	return edit(self, function(b) return BM.ClearSlot(b, self.state.editor.phase, group, pos, self:Catalog()); end);
end

-- The catalogue shows one kind at a time: "spells" | "rings" | "trinkets" | "amulets". Choosing an equipment kind
-- also targets a slot of that kind (the first empty main one, else the first slot): the target is always visible.
function Controller:SetCatalog(cat)
	local e = self.state.editor;
	if not e then return; end
	if cat ~= "spells" and not BM.MAIN_SLOTS[cat] then return; end
	e.cat, e.offset = cat, 0;
	if cat ~= "spells" then
		e.group = cat;
		local list = e.draft.phases[e.phase][cat];
		local pick = 1;
		for i = 1, BM.MAIN_SLOTS[cat] do if list[i] == "" then pick = i; break; end end
		if list[pick] ~= "" then
			for i = 1, #list do if list[i] == "" then pick = i; break; end end
		end
		e.slot = pick;
	end
	self:Notify();
end

-- Clicking a slot (empty or filled) targets it and shows the matching catalogue.
function Controller:SelectSlot(group, pos)
	local e = self.state.editor;
	if not e or not BM.MAIN_SLOTS[group] then return; end
	local list = e.draft.phases[e.phase][group];
	if type(pos) ~= "number" or pos < 1 or pos > #list then return; end
	e.cat, e.group, e.slot, e.offset = group, group, pos, 0;
	local k = list[pos];
	if k ~= "" then self.state.inspect = { kind = group == "amulets" and "amulet" or "jewel", key = k }; end
	self:Notify();
end

function Controller:AddSpellTarget() local e = self.state.editor; if e then e.cat, e.offset = "spells", 0; self:Notify(); end end
function Controller:ToggleAdvanced() local e = self.state.editor; if e then e.adv = not e.adv; self:Notify(); end end

-- What "Place" will fill: { group, slot, role, key, name } for equipment, nil when the catalogue shows spells.
function Controller:TargetInfo()
	local e, cat = self.state.editor, self:Catalog();
	if not e or e.cat == "spells" then return nil; end
	local list = e.draft.phases[e.phase][e.group];
	local main = BM.MAIN_SLOTS[e.group];
	local key = list[e.slot] or "";
	local lang = self:Lang();
	local kind = e.group == "amulets" and "amulet" or "jewel";
	return { group = e.group, slot = e.slot, main = e.slot <= main, altIndex = e.slot - main, key = key,
		name = key ~= "" and (cat and cat:Get(kind, key) and cat:Name(kind, key, lang) or key) or "" };
end

-- what the inspector shows: set by selecting (click) a spell or a piece
function Controller:Inspect(kind, key)
	if type(key) ~= "string" or key == "" then self.state.inspect = nil; else self.state.inspect = { kind = kind, key = key }; end
	self:Notify();
end
function Controller:SetSearch(text) local e = self.state.editor; if e.search ~= text then e.search = text; e.offset = 0; self:Notify(); end end

function Controller:SetPhase(p)
	local e = self.state.editor;
	if p >= 1 and p <= 4 then e.phase = p; e.offset = 0; self:Notify(); end
end

-- Phases 2-4 stay hidden until needed: an imported/edited build that uses them shows them at once.
local function phaseUsed(ph)
	return #ph.spells > 0 or #ph.banish > 0 or #(ph.banishAfter or {}) > 0 or ph.notes ~= "" or ph.link ~= "" or ph.label ~= "" or next(ph.stats) ~= nil
		or next(ph.ext) ~= nil or ph.rings[1] .. ph.rings[2] .. ph.rings[3] .. ph.rings[4] .. ph.trinkets[1] .. ph.trinkets[2] .. ph.trinkets[3]
		.. ph.trinkets[4] .. ph.amulets[1] .. ph.amulets[2] .. ph.amulets[3] .. ph.amulets[4] ~= "";
end

function Controller:ShowAllPhases()
	local e = self.state.editor;
	if not e then return false; end
	if e.showPhases then return true; end
	local h = self:Handle();
	if h and h:GetSetting("advancedPhases") then return true; end
	for p = 2, 4 do
		if phaseUsed(e.draft.phases[p]) then return true; end
	end
	return false;
end

function Controller:RevealPhases() self.state.editor.showPhases = true; self:Notify(); end

function Controller:PhaseTitle(p)
	local e = self.state.editor;
	local label = e and e.draft.phases[p].label or "";
	if label ~= "" then return label; end
	return L(BM.DEFAULT_LABELS[p]);
end

-- ---- catalogue lists for the editor (identifiers are the catalogue keys; names are display only)
local function matches(entryNames, filter)
	if filter == "" then return true; end
	local f = string.lower(filter);
	for _, n in ipairs(entryNames) do
		if string.find(string.lower(n), f, 1, true) then return true; end
	end
	return false;
end

-- list of { key, name, icon, state } for the current tab/group
function Controller:CatalogEntries()
	local e, cat = self.state.editor, self:Catalog();
	local out = {};
	if not e or not cat then return out; end
	local class = e.draft.class;
	local lang = self:Lang();
	local ph = e.draft.phases[e.phase];
	local keys, kind = {}, "spell";
	if e.cat == "spells" then
		if cat:IsClass(class) then keys = cat:SpellsOfClass(class); end
	elseif e.group == "rings" then
		keys, kind = cat:JewelsBySlot("ring"), "jewel";
	elseif e.group == "trinkets" then
		keys, kind = cat:JewelsBySlot("trinket"), "jewel";
	else
		kind = "amulet";
		keys = {};
		if cat:IsClass(class) then
			for _, k in ipairs(cat:AmuletsForClass(class)) do keys[#keys + 1] = k; end
			for _, k in ipairs(cat:LegendsOfClass(class)) do keys[#keys + 1] = k; end
		end
	end
	local used, after = {}, {};
	for _, k in ipairs(ph.banishAfter or {}) do after[k] = true; end
	if e.cat == "spells" then
		for _, g in ipairs(ph.spells) do used[g.key] = "wanted"; end
		for _, k in ipairs(ph.banish) do if not used[k] then used[k] = "banished"; end end
	else
		for _, k in ipairs(ph[e.group]) do if k ~= "" then used[k] = "placed"; end end
	end
	for _, k in ipairs(keys) do
		local entry = cat:Get(kind, k);
		if entry then
			local name = cat:Name(kind, k, lang);
			local lp = entry.spell and cat:LegendParts(k, lang) or nil;
			if matches({ name, entry.name }, e.search) then
				out[#out + 1] = { key = k, name = name, icon = entry.icon, state = used[k], rarity = entry.rarity, legend = entry.spell ~= nil, after = after[k] or nil,
				spellName = lp and lp.spell or nil, head = lp and lp.head or nil, headOrigin = lp and lp.headOrigin or nil,
				className = entry.class and self:ClassName(entry.class) or nil,
				here = (e.cat ~= "spells" and ph[e.group] and ph[e.group][e.slot] == k) or nil };
			end
		end
	end
	return out;
end

function Controller:CatalogView()
	local e = self.state.editor;
	local out, off, max = windowOf(self:CatalogEntries(), e.offset or 0, Controller.CATALOG_ROWS);
	e.offset = off;
	return out, off, max;
end

function Controller:ScrollCatalog(delta)
	local e = self.state.editor;
	if not e then return; end
	e.offset = (e.offset or 0) + delta;
	self:CatalogView();
	self:Notify();
end

function Controller:SetCatalogOffset(o)
	local e = self.state.editor;
	if not e then return; end
	e.offset = o;
	self:CatalogView();
	self:Notify();
end

-- What the detail panel can do with the selected element: { kind, key, spell = {wanted, avoided, room}, piece = {group,
-- placedAt, inTarget, targetGroupOk} }. Pure data; the UI draws the buttons, the controller executes through the
-- same functions as every other control.
function Controller:DetailState()
	local e, i = self.state.editor, self.state.inspect;
	if not e or not i then return nil; end
	local ph = e.draft.phases[e.phase];
	local d = { kind = i.kind, key = i.key };
	if i.kind == "spell" then
		local wanted = false;
		for _, g in ipairs(ph.spells) do if g.key == i.key then wanted = true; end end
		d.spell = { wanted = wanted, avoided = Util.IndexOf(ph.banish, i.key) ~= nil, room = #ph.spells < BM.LIMITS.spells };
	else
		local group = i.kind == "amulet" and "amulets" or nil;
		if not group then
			local cat = self:Catalog();
			local j = cat and cat:Get("jewel", i.key);
			group = j and (j.slot == "ring" and "rings" or "trinkets") or nil;
		end
		local placedAt;
		if group then for pos, k in ipairs(ph[group]) do if k == i.key then placedAt = pos; end end end
		d.piece = { group = group, placedAt = placedAt, targetGroupOk = group ~= nil and e.cat == group and e.group == group,
			inTarget = placedAt ~= nil and placedAt == e.slot and e.group == group };
	end
	return d;
end

-- display rows of the plan (wanted spells, banish, slot lists) with localized names; unknown keys shown raw
function Controller:PlanView()
	local e, cat = self.state.editor, self:Catalog();
	local lang = self:Lang();
	local ph = e.draft.phases[e.phase];
	local function nm(kind, k)
		if k == "" then return ""; end
		if cat and cat:Get(kind, k) then return cat:Name(kind, k, lang), cat:Get(kind, k).icon; end
		return k, nil;
	end
	local v = { spells = {}, banish = {}, rings = {}, trinkets = {}, amulets = {}, afterCount = 0, keepCount = 0 };
	local after, wanted = {}, {};
	for _, k in ipairs(ph.banishAfter or {}) do after[k] = true; end
	for i, g in ipairs(ph.spells) do
		local name, icon = nm("spell", g.key);
		wanted[g.key] = true;
		v.spells[i] = { key = g.key, name = name, icon = icon, known = cat ~= nil and cat:Get("spell", g.key) ~= nil, mode = g.mode, rank = g.rank,
			after = after[g.key] or false };
		if after[g.key] then v.afterCount = v.afterCount + 1; else v.keepCount = v.keepCount + 1; end
	end
	for i, k in ipairs(ph.banish) do
		local name, icon = nm("spell", k);
		v.banish[i] = { key = k, name = name, icon = icon, known = cat ~= nil and cat:Get("spell", k) ~= nil, overlap = wanted[k] or false };
	end
	for _, group in ipairs({ "rings", "trinkets", "amulets" }) do
		local kind = group == "amulets" and "amulet" or "jewel";
		for i = 1, #ph[group] do
			local k = ph[group][i];
			local name, icon = nm(kind, k);
			v[group][i] = { key = k, name = name, icon = icon, known = k == "" or (cat ~= nil and cat:Get(kind, k) ~= nil), main = i <= BM.MAIN_SLOTS[group],
				rarity = (k ~= "" and cat and cat:Get(kind, k)) and (cat:Get(kind, k).rarity or (cat:Get(kind, k).spell and "legendary")) or nil };
		end
	end
	return v;
end

-- what the draft holds that this editor cannot edit yet: shown, never dropped
function Controller:HiddenData()
	local e = self.state.editor;
	local out = {};
	if not e then return out; end
	local function add(fmt, ...) out[#out + 1] = string.format(L(fmt), ...); end
	local statN, rankN, extN = 0, 0, 0;
	for _, ph in ipairs(e.draft.phases) do
		for _ in pairs(ph.stats) do statN = statN + 1; end
		for _, g in ipairs(ph.spells) do if g.mode ~= "acquire" then rankN = rankN + 1; end end
		if next(ph.ext) then extN = extN + 1; end
	end
	if statN > 0 then add("%d statistic objective(s) kept (no editor yet)", statN); end
	if rankN > 0 then add("%d rank / unlimited target(s) kept (no editor yet)", rankN); end
	if extN > 0 then add("Extra data in %d phase(s) kept", extN); end
	if next(e.draft.ext) then add("Extra build data kept: %s", table.concat(Util.SortedKeys(e.draft.ext), ", ")); end
	return out;
end

-- ------------------------------------------------------------------ tooltips (pure data; the UI draws them on hover)
-- kind: "spell" | "jewel" | "amulet". Returns { title, icon, spellId, lines = { {text, tone} } } or nil.
-- Only what the embedded catalogue really holds is stated: names, class, slot, rarity, the base game spell id.
-- Descriptions are NOT in the catalogue: for spells the UI asks the game's own spell tooltip (by id, on hover only);
-- anything else says "Detailed effect unavailable". No value is ever computed or guessed.
local RARITY = { common = "Common", uncommon = "Uncommon", rare = "Rare", epic = "Epic", legendary = "Legendary" };
function Controller:TooltipData(kind, key)
	local cat, e = self:Catalog(), self.state.editor;
	if not cat or type(key) ~= "string" or key == "" then return nil; end
	local lang = self:Lang();
	local entry = cat:Get(kind, key);
	local ph = e and e.draft.phases[e.phase];
	local d = { lines = {}, state = {}, facts = {} };
	local function line(text, tone, isState)
		local l = { text = text, tone = tone };
		d.lines[#d.lines + 1] = l;
		if isState then d.state[#d.state + 1] = l; else d.facts[#d.facts + 1] = l; end
	end
	if not entry then
		d.title = key;
		line(L("Unknown to this catalogue"), "warn");
		line(L("Detailed effect unavailable"), "dim");
		return d;
	end
	d.title = cat:Name(kind, key, lang);
	d.icon = entry.icon;
	if kind == "spell" then
		d.spellId = type(entry.id) == "number" and entry.id or nil;
		d.subtitle = L("Spell") .. " | " .. self:ClassName(entry.class);
		line(L("Class:") .. " " .. self:ClassName(entry.class));
		if ph then
			for i, g in ipairs(ph.spells) do
				if g.key == key then
					line(string.format(L("Wanted: priority %d"), i), "ok", true);
					if g.mode == "rank" then
						line(string.format(L("Target rank: %d"), g.rank or 0));
					elseif g.mode == "unlimited" then
						line(L("Target: no limit"));
					end
					if ph.banishAfter and Util.IndexOf(ph.banishAfter, key) then
						line(L("Planned: banish after acquisition (nothing is banished automatically)"), "warn", true);
					else
						line(L("Planned: keep"), "ok", true);
					end
				end
			end
			if Util.IndexOf(ph.banish, key) then line(L("In the avoid list: banish if offered"), "warn", true); end
		end
		if not d.spellId then line(L("Detailed effect unavailable"), "dim"); end
	elseif kind == "jewel" then
		d.subtitle = entry.slot == "ring" and L("Ring") or L("Trinket");
		line(L("Type:") .. " " .. (entry.slot == "ring" and L("Ring") or L("Trinket")));
		if ph then
			local group = entry.slot == "ring" and "rings" or "trinkets";
			for i, k in ipairs(ph[group]) do
				if k == key then
					line(i <= BM.MAIN_SLOTS[group] and string.format(L("Placed: main %d"), i)
						or string.format(L("Placed: alternative %d"), i - BM.MAIN_SLOTS[group]), "ok", true);
				end
			end
		end
		-- Prefer explicitly sourced client metadata. Never turn a base value into a live stat.
		local localSections = ns.JewelryEffects and ns.JewelryEffects.Sections(key, entry.slot, lang == "frFR") or nil;
		local liveSections = ns.JewelryEffects and ns.JewelryEffects.LiveSections(cat, key, entry.slot, lang == "frFR") or nil;
		if liveSections then
			-- Native equipped-item text is the player's actual benefit in this run.
			-- Never stack an unscaled base coefficient beside a different rarity value:
			-- that looked contradictory (e.g. 1% vs 1.5% lifesteal).
			d.sections = liveSections;
			d.sourceKind = "jewelry_live";
		else
			d.sections = localSections;
			if d.sections then d.sourceKind = "jewelry_local"; end
		end
		if d.sections then
			-- The first line is now the meaningful bonus, not a technical label.
			d.preview = ns.Describe and ns.Describe.Preview(d.sections, 2) or {};
		else
			line(L("Detailed effect unavailable"), "dim");
			line(L("The Reborn catalogue gives no statistics for this piece."), "dim");
			local count = ns.JewelryEffects and ns.JewelryEffects.MetadataStatus() or 0;
			if count == 0 then
				line(lang == "frFR" and "Cette recette n'inclut pas les mécaniques locales. Consultez /rbp diag." or
					"This recipe has no local jewelry mechanics. See /rbp diag.", "warn");
			end
		end
	else
		local isLegend = entry.spell ~= nil;
		d.subtitle = isLegend and (L("Legendary amulet") .. " | " .. self:ClassName(entry.class)) or (L("Amulet") .. " | " .. L(RARITY[entry.rarity or ""] or "Unknown"));
		line(isLegend and L("Legendary amulet") or (L("Rarity:") .. " " .. L(RARITY[entry.rarity or ""] or "Unknown")));
		if isLegend then
			if entry.head then line(L("Series:") .. " " .. entry.head); end
			line(L("Linked spell:") .. " " .. cat:Name("spell", entry.spell, lang));
			local lp = cat:LegendParts(key, lang);
			if lp and lp.headOrigin == "community" then line(L("Title: community translation, not official"), "dim"); end
			line(L("Class:") .. " " .. self:ClassName(entry.class));
		elseif entry.classes and #entry.classes > 0 then
			local names = {};
			for _, k in ipairs(entry.classes) do names[#names + 1] = self:ClassName(k); end
			line(L("Class:") .. " " .. table.concat(names, ", "));
		end
		if ph then
			for i, k in ipairs(ph.amulets) do
				if k == key then
					line(i <= BM.MAIN_SLOTS.amulets and string.format(L("Placed: main %d"), i)
						or string.format(L("Placed: alternative %d"), i - BM.MAIN_SLOTS.amulets), "ok", true);
				end
			end
		end
		-- effects come from the PUBLISHED data (Describe.lua); without them the piece says so
		d.sections = ns.Describe and ns.Describe.Amulet(cat, entry, lang) or nil;
		if not d.sections then line(L("Detailed effect unavailable"), "dim"); end
		d.preview = ns.Describe and ns.Describe.Preview(d.sections, 3) or {};
	end
	d.rarity = entry.rarity or (entry.spell and "legendary") or nil;
	return d;
end

-- Data for the inspector: the tooltip data of the last selected element (nil when nothing is selected).
function Controller:InspectorData()
	local i = self.state.inspect;
	if not i then return nil; end
	return self:TooltipData(i.kind, i.key);
end

-- ------------------------------------------------------------------ import
function Controller:AnalyzeImport(text)
	local cat = self:Catalog();
	local pv = ns.PlannerCodec.Decode(text, cat);
	self.state.import = { preview = pv, name = "", class = pv.class, page = 1, done = false };
	self:Notify();
	return pv;
end

function Controller:ImportState() return self.state.import; end

function Controller:SetImportClass(class) local i = self.state.import; if i then i.class = class; self:Notify(); end end
function Controller:SetImportName(name) local i = self.state.import; if i then i.name = name; end end
function Controller:SetImportPage(p)
	local i = self.state.import;
	if i then i.page = math.max(1, math.min(self:ImportPageCount(), p)); self:Notify(); end
end

function Controller:ImportIssues()
	local i = self.state.import;
	return i and i.preview.issues.list or {};
end

function Controller:ImportPageCount()
	return math.max(1, math.ceil(#self:ImportIssues() / Controller.ISSUE_PAGE));
end

function Controller:ImportReady()
	local i = self.state.import;
	if not i or not i.preview.ok or i.done or self:ReadOnly() then return false; end
	if i.preview.kind == "talents" then
		return (i.preview.class or i.class) ~= nil;
	end
	return true;
end

function Controller:CommitImport()
	local i = self.state.import;
	if not self:ImportReady() then
		self:Say("error", self:ReadOnly() and L("Read only") or L("Nothing to import"));
		return nil;
	end
	local id, rep = ns.PlannerCodec.CommitImport(self:Handle(), i.preview, { name = i.name ~= "" and i.name or nil, class = i.class });
	if not id then
		self:Say("error", explain(rep));
		return nil;
	end
	i.done = true;
	self.state.selectedId = id;
	self.state.classFilter = nil;
	self.state.trashMode = false;
	self:Say(i.preview.status == "needs_repair" and "warn" or "info",
		i.preview.status == "needs_repair" and L("Imported (not active): the build needs repair") or L("Imported (not active)"));
	return id;
end

function Controller:ClearImport() self.state.import = nil; self:Notify(); end

-- ------------------------------------------------------------------ export
-- source = "saved" (the persisted build) or "draft" (what the editor shows)
function Controller:PrepareExport(id, source)
	local h = self:Handle();
	local b;
	if source == "draft" and self.state.editor and self.state.editor.id == id then
		b = BM.Clone(self.state.editor.draft);
	else
		b = h and h:Get(id);
	end
	if not b then self:Say("error", L("Not found")); return nil; end
	local report = ns.PlannerCodec.PlanExport(b, self:Catalog());
	local x = { id = id, source = source, build = b, report = report, accepted = false, page = 1 };
	if report.ok and report.intentLosses == 0 then
		x.code = ns.PlannerCodec.Encode(b, self:Catalog());
	end
	self.state.export = x;
	self:Notify();
	return x;
end

function Controller:AcceptLosses()
	local x = self.state.export;
	if not x or not x.report.ok then return false; end
	local code = ns.PlannerCodec.Encode(x.build, self:Catalog(), { acceptLosses = true });
	if not code then return false; end
	x.accepted, x.code = true, code;
	self:Notify();
	return true;
end

function Controller:ExportLosses()
	local x = self.state.export;
	local out = {};
	if not x then return out; end
	for _, l in ipairs(x.report.losses) do
		if l.severity == "intent" then out[#out + 1] = l; end
	end
	for _, l in ipairs(x.report.losses) do
		if l.severity ~= "intent" then out[#out + 1] = l; end
	end
	return out;
end

function Controller:ExportPageCount() return math.max(1, math.ceil(#self:ExportLosses() / Controller.ISSUE_PAGE)); end
function Controller:SetExportPage(p) local x = self.state.export; if x then x.page = math.max(1, math.min(self:ExportPageCount(), p)); self:Notify(); end end
function Controller:ClearExport() self.state.export = nil; self:Notify(); end

-- ------------------------------------------------------------------ views
function Controller:SetView(view, keepMessage)
	if view == "library" then view = "editor"; end      -- the library is always on screen; the centre shows the editor
	self.state.view = view;
	if not keepMessage then self.state.message = nil; end
	self:Notify();
end
