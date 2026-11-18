-- Storage around RebornBuildPlannerDB (our SavedVariables, the only global this addon owns).
-- The module never touches a global: the caller passes the loaded table and assigns the result.
--
-- Safety rules (see docs/REPORT_LOT1.md):
--   * a migration runs on a deep COPY; the original table is replaced only after the copy is validated, and a
--     backup of the original travels inside the new table (db.backups[1]);
--   * a future/unreadable schema is refused: the handle is read-only, the table is returned untouched and the
--     caller must not assign it;
--   * a record that cannot be understood is moved to db.quarantine (raw data kept), never dropped;
--   * unknown fields (db.ext, build.ext, phase.ext, unknown settings) are preserved;
--   * every mutation validates first and commits at the end: on any refusal nothing changed.
local ADDON, ns = ...;
ns = ns or {};
local Util, BM, Locale = ns.Util, ns.BuildModel, ns.Locale;
assert(Util and BM and Locale, "RebornBuildPlanner: Util, Locale and BuildModel must load before Storage.lua");
local S = { SCHEMA = 1 };
ns.Storage = S;

local type, pairs, ipairs, pcall, tostring, tonumber, string, table = type, pairs, ipairs, pcall, tostring, tonumber, string, table;

-- Documented, tested, tunable: not universal. 200 builds is the official planner's own library size.
S.LIMITS = { builds = 200, trash = 20, quarantine = 50, dbNodes = 400000, dbDepth = 12 };
S.SETTING_DEFAULTS = { lang = "auto", advancedPhases = false, scale = 1, lastClass = "", libSort = "name", libFilter = "all" };
local SETTING_CHECK = {
	lang = function(v) return Locale.IsSupportedSelection(v); end,
	advancedPhases = function(v) return type(v) == "boolean"; end,
	scale = function(v) return type(v) == "number" and v >= 0.6 and v <= 1.5; end,
	lastClass = function(v) return type(v) == "string" and #v <= 64; end,
	libSort = function(v) return v == "name" or v == "used" or v == "modified" or v == "created" or v == "class"; end,
	libFilter = function(v) return v == "all" or v == "favorites" or v == "recent"; end,
	-- window position: anchor point, offsets from that point of UIParent (persistent, validated on use)
	window = function(v)
		return type(v) == "table" and type(v.point) == "string" and #v.point <= 16 and type(v.x) == "number" and type(v.y) == "number"
			and v.x == v.x and v.y == v.y and math.abs(v.x) < 1e5 and math.abs(v.y) < 1e5;
	end,
};

local H = {};
H.__index = H;

local function issue(code, msg, extra)
	return { code = code, message = msg, detail = extra };
end

-- ------------------------------------------------------------------ fresh DB
function S.NewDB()
	return { schema = S.SCHEMA, addon = "RebornBuildPlanner", counter = 0, settings = {}, builds = {}, library = {},
		active = {}, trash = {}, quarantine = {}, backups = {}, ext = {} };
end

local function isTable(v)
	return type(v) == "table";
end

local function cut(s, n)
	if #s <= n then
		return s;
	end
	local i = n;
	while i > 0 do
		local b = string.byte(s, i + 1);
		if not b or b < 128 or b >= 192 then
			break;
		end
		i = i - 1;
	end
	return string.sub(s, 1, i);
end

-- ------------------------------------------------------------------ id generation
local function newId(h)
	local db = h.db;
	while true do
		db.counter = (tonumber(db.counter) or 0) + 1;
		-- %x goes through a C long (32 bits on the Windows client, cf. AZS.Fmt in AzerothSurvivors/Core.lua): keep it below 2^31
		local id = string.format("b%08x-%d", math.floor(h.now()) % 2147483648, db.counter);
		if not db.builds[id] then
			local inTrash = false;
			for _, t in ipairs(db.trash) do
				if t.build and t.build.id == id then inTrash = true; end
			end
			if not inTrash then
				return id;
			end
		end
	end
end

-- ------------------------------------------------------------------ structural repair (non-destructive)
-- Quarantine policy (Lot 1.1): lossless or refused. Items are collected first; if they do not all fit under
-- S.LIMITS.quarantine the whole operation is refused (error table {code="QUARANTINE_FULL"}), nothing is truncated.
local function pend(list, reason, raw, key)
	list[#list + 1] = { reason = reason, key = key, raw = raw };
end

local function commitQuarantine(db, list)
	local have, add, cap = #db.quarantine, #list, S.LIMITS.quarantine;
	if have + add > cap then
		error({ code = "QUARANTINE_FULL", message = string.format(
			"QUARANTINE_FULL: %d unreadable record(s) to set aside, %d already in quarantine, capacity %d; nothing was changed or removed",
			add, have, cap) }, 0);
	end
	for i = 1, add do
		db.quarantine[have + i] = list[i];
	end
end

-- Brings a table of the CURRENT schema to a consistent state. Returns a list of issues. Never throws away a
-- record: what it cannot read goes to db.quarantine.
local function settle(db, catalog)
	local out = {};
	local pending = {};
	if not isTable(db.quarantine) then
		local old = db.quarantine;
		db.quarantine = {};
		if old ~= nil then
			pend(pending, "FIELD_NOT_A_TABLE:quarantine", old, "quarantine");
		end
	end
	for _, f in ipairs({ "settings", "builds", "library", "active", "trash", "backups", "ext" }) do
		if not isTable(db[f]) then
			if db[f] ~= nil then
				pend(pending, "FIELD_NOT_A_TABLE:" .. f, db[f], f);
				out[#out + 1] = issue("FIELD_RESET", f .. " was not a table (kept in quarantine)");
			end
			db[f] = {};
		end
	end
	if type(db.counter) ~= "number" then
		db.counter = 0;
	end
	local ids = {};
	for k in pairs(db.builds) do
		ids[#ids + 1] = k;
	end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b); end);
	for _, k in ipairs(ids) do
		local rec = db.builds[k];
		local b, rep = BM.Normalize(rec, catalog, { id = type(k) == "string" and k or nil });
		if not b then
			db.builds[k] = nil;
			pend(pending, "INVALID_BUILD", rec, tostring(k));
			out[#out + 1] = issue("BUILD_QUARANTINED", "build " .. tostring(k) .. " is invalid", rep.errors);
		elseif b.id ~= k then
			db.builds[k] = nil;
			pend(pending, "ID_MISMATCH", rec, tostring(k));
			out[#out + 1] = issue("BUILD_QUARANTINED", "build key " .. tostring(k) .. " differs from its id " .. tostring(b.id));
		else
			db.builds[k] = b;
		end
	end
	-- library: ordered ids per class, rebuilt from the builds without losing the existing order
	local lib, seen = {}, {};
	for class, list in pairs(db.library) do
		if isTable(list) then
			for _, id in ipairs(list) do
				local b = db.builds[id];
				if b and b.class == class and not seen[id] then
					lib[class] = lib[class] or {};
					lib[class][#lib[class] + 1] = id;
					seen[id] = true;
				end
			end
		end
	end
	local rest = {};
	for id in pairs(db.builds) do
		if not seen[id] then rest[#rest + 1] = id; end
	end
	table.sort(rest);
	for _, id in ipairs(rest) do
		local class = db.builds[id].class;
		lib[class] = lib[class] or {};
		lib[class][#lib[class] + 1] = id;
	end
	db.library = lib;
	for class, id in pairs(db.active) do
		local b = type(id) == "string" and db.builds[id];
		if not b or b.class ~= class then
			db.active[class] = nil;
			out[#out + 1] = issue("ACTIVE_CLEARED", "active build of " .. tostring(class) .. " pointed to nothing valid");
		end
	end
	local trash = {};
	for _, t in ipairs(db.trash) do
		if isTable(t) and isTable(t.build) and type(t.build.id) == "string" then
			trash[#trash + 1] = t;
		else
			pend(pending, "INVALID_TRASH", t, nil);
		end
	end
	db.trash = trash;
	commitQuarantine(db, pending);
	return out;
end

-- Invariants of a settled copy; returns nil or a message.
local function invariants(work, src)
	if work.schema ~= S.SCHEMA then
		return "schema is " .. tostring(work.schema);
	end
	local seen = {};
	for id, b in pairs(work.builds) do
		local rep = BM.Validate(b, nil);
		if not rep.ok or b.id ~= id then
			return "build " .. tostring(id) .. " is not valid after repair";
		end
	end
	for class, list in pairs(work.library) do
		for _, id in ipairs(list) do
			local b = work.builds[id];
			if not b or b.class ~= class or seen[id] then
				return "library entry " .. tostring(id) .. " is inconsistent";
			end
			seen[id] = true;
		end
	end
	for id in pairs(work.builds) do
		if not seen[id] then
			return "build " .. tostring(id) .. " is missing from the library";
		end
	end
	for class, id in pairs(work.active) do
		local b = work.builds[id];
		if not b or b.class ~= class then
			return "active pointer of " .. tostring(class) .. " is dangling";
		end
	end
	if #work.quarantine > S.LIMITS.quarantine then
		return "quarantine over capacity";
	end
	local srcBuilds = isTable(src.builds) and Util.Len(src.builds) or 0;
	local srcQ = isTable(src.quarantine) and #src.quarantine or 0;
	if Util.Len(work.builds) + (#work.quarantine - srcQ) < srcBuilds then
		return "records were lost: " .. Util.Len(work.builds) .. " kept + " .. (#work.quarantine - srcQ) .. " quarantined of " .. srcBuilds;
	end
	return nil;
end
S._hooks = {};      -- test seam (afterSettle); empty in production

-- ------------------------------------------------------------------ migrations
-- Each step turns a COPY of schema v into schema v+1. `count(db)` says how many builds the source holds, so a
-- step that silently loses records is detected.
-- Schema 0 = an internal pre-release prototype layout (never shipped): a flat array of loose build tables
-- (name, class, spells, banish, notes ...) plus an optional `active[class] = index`. It exists so that the
-- migration path is real and tested.
local MIGRATIONS = {};
MIGRATIONS[0] = {
	count = function(db)
		return isTable(db.builds) and Util.Len(db.builds) or 0;
	end,
	step = function(src, ctx)
		local out = S.NewDB();
		local pending = {};
		out.settings = isTable(src.settings) and Util.DeepCopy(src.settings) or {};
		local mapped = {};
		for i = 1, Util.Len(src.builds or {}) do
			local old = src.builds[i];
			if isTable(old) then
				local raw = { name = old.name, class = old.class or old.cls, talents = old.talents, revision = 1, catalog = "",
					phases = { { spells = old.spells, banish = old.banish, notes = old.notes, link = old.link } } };
				for k, v in pairs(old) do
					if k ~= "name" and k ~= "class" and k ~= "cls" and k ~= "talents" and k ~= "spells" and k ~= "banish"
						and k ~= "notes" and k ~= "link" then
						raw[k] = v;       -- unknown prototype fields travel into ext through Normalize
					end
				end
				ctx.h.db = out;
				raw.id = newId(ctx.h);
				out.builds[raw.id] = raw;
				mapped[i] = raw.id;
			else
				pend(pending, "NOT_A_BUILD", old, tostring(i));
			end
		end
		if isTable(src.active) then
			for class, idx in pairs(src.active) do
				if mapped[idx] then out.active[class] = mapped[idx]; end
			end
		end
		for k, v in pairs(src) do
			if k ~= "builds" and k ~= "settings" and k ~= "active" and k ~= "schema" then
				out.ext[tostring(k)] = Util.DeepCopy(v);
			end
		end
		commitQuarantine(out, pending);
		return out;
	end,
};
S._MIGRATIONS = MIGRATIONS;

local function migrate(handle, rawdb)
	local from = type(rawdb.schema) == "number" and rawdb.schema or 0;
	local ctx = { h = handle };
	local ok, res = pcall(function()
		local work = Util.DeepCopy(rawdb);                    -- the original is never touched
		local expected = 0;
		local v = from;
		while v < S.SCHEMA do
			local m = MIGRATIONS[v];
			if not m then
				error("no migration from schema " .. v);
			end
			expected = (v == from) and m.count(work) or expected;
			work = m.step(work, ctx);
			if not isTable(work) then
				error("migration " .. v .. " returned no table");
			end
			work.schema = v + 1;
			v = v + 1;
		end
		handle.db = work;
		local issues = settle(work, handle.catalog);
		local have = Util.Len(work.builds) + #work.quarantine;
		if have < expected then
			error("migration lost records: " .. have .. " of " .. expected);
		end
		local ok2, why = Util.Measure(work, S.LIMITS.dbNodes, S.LIMITS.dbDepth);
		if not ok2 then
			error("migrated table rejected: " .. tostring(why));
		end
		work.backups = { { schema = from, data = Util.DeepCopy(rawdb) } };
		return { db = work, issues = issues };
	end);
	if not ok then
		handle.db = rawdb;
		return nil, type(res) == "table" and (res.message or res.code) or tostring(res);
	end
	return res.db, res.issues;
end

-- Current-schema open is transactional: the loaded table is only ever READ. Limits are checked on it, a deep
-- copy is repaired and verified, and the result is accepted as a whole or refused as a whole (read-only handle
-- over the untouched original).
local function refuse(h, existing, code, message)
	h.db, h.readOnly, h.status = existing, true, "REPAIR_REFUSED";
	h.issues = { issue(code, message) };
	return h;
end

local function openCurrent(h, existing)
	local fine, why = Util.Measure(existing, S.LIMITS.dbNodes, S.LIMITS.dbDepth);
	if not fine then
		return refuse(h, existing, "SOURCE_REJECTED", "saved data rejected before any repair: " .. tostring(why));
	end
	local ok, res = pcall(function()
		local work = Util.DeepCopy(existing);
		local issues = settle(work, h.catalog);
		if S._hooks.afterSettle then
			S._hooks.afterSettle(work);
		end
		local bad = invariants(work, existing);
		if bad then
			error({ code = "INVARIANT", message = "INVARIANT: " .. bad }, 0);
		end
		return { work = work, issues = issues };
	end);
	if not ok then
		if type(res) == "table" and res.code then
			return refuse(h, existing, res.code, res.message);
		end
		return refuse(h, existing, "REPAIR_ERROR", tostring(res));
	end
	h.status = "OK";
	h.issues = res.issues;
	if Util.DeepEqual(res.work, existing) then
		h.db = existing;            -- nothing to repair: keep the loaded table, no churn
	else
		h.db = res.work;
	end
	return h;
end

-- ------------------------------------------------------------------ open
-- opts: catalog (Catalog object, optional), now (function, default time()), existing table from the client.
-- Returns a handle: h.status ∈ CREATED | OK | MIGRATED | FUTURE_SCHEMA | INVALID_DB | MIGRATION_FAILED
-- and h.readOnly. The caller assigns `RebornBuildPlannerDB = h.db` ONLY when h.readOnly is false.
function S.Open(existing, opts)
	opts = opts or {};
	local h = setmetatable({ catalog = opts.catalog, issues = {}, readOnly = false,
		now = opts.now or (type(time) == "function" and time) or function() return 0; end }, H);
	if existing == nil then
		h.db = S.NewDB();
		h.status = "CREATED";
		return h;
	end
	if not isTable(existing) then
		h.db, h.readOnly, h.status = existing, true, "INVALID_DB";
		h.issues[1] = issue("INVALID_DB", "SavedVariables is not a table");
		return h;
	end
	local schema = existing.schema;
	if schema ~= nil and type(schema) ~= "number" then
		h.db, h.readOnly, h.status = existing, true, "INVALID_DB";
		h.issues[1] = issue("INVALID_DB", "schema is not a number");
		return h;
	end
	if schema and schema > S.SCHEMA then
		h.db, h.readOnly, h.status = existing, true, "FUTURE_SCHEMA";
		h.issues[1] = issue("FUTURE_SCHEMA", "saved data uses schema " .. schema .. ", this addon supports " .. S.SCHEMA);
		return h;
	end
	if schema == S.SCHEMA then
		return openCurrent(h, existing);
	end
	local db, issues = migrate(h, existing);
	if not db then
		h.db, h.readOnly, h.status = existing, true, "MIGRATION_FAILED";
		h.issues[1] = issue("MIGRATION_FAILED", issues);
		return h;
	end
	h.db, h.status, h.issues = db, "MIGRATED", issues;
	return h;
end

-- ------------------------------------------------------------------ helpers
local function guard(h)
	if h.readOnly then
		return false, issue("READ_ONLY", "storage is read-only (" .. h.status .. ")");
	end
	return true;
end

local function libAdd(db, b)
	db.library[b.class] = db.library[b.class] or {};
	table.insert(db.library[b.class], b.id);
end

local function libRemove(db, class, id)
	local list = db.library[class];
	if not list then return; end
	local i = Util.IndexOf(list, id);
	if i then table.remove(list, i); end
	if #list == 0 then db.library[class] = nil; end
end

local function room(h)
	if Util.Len(h.db.builds) >= S.LIMITS.builds then
		return false, issue("LIBRARY_FULL", "limit of " .. S.LIMITS.builds .. " builds reached");
	end
	return true;
end

-- ------------------------------------------------------------------ CRUD
-- opts: name, class (required), talents. The new build gets a fresh local id.
function H:Create(opts)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	ok, err = room(self);
	if not ok then return nil, err; end
	opts = opts or {};
	local snap = self.db.counter;
	local id = newId(self);
	local b, rep = BM.New({ id = id, name = opts.name, class = opts.class, talents = opts.talents }, self.catalog);
	if not b then
		self.db.counter = snap;
		return nil, issue("INVALID_BUILD", "build refused", rep);
	end
	self.db.builds[id] = b;
	libAdd(self.db, b);
	self:stamp(id, "created");
	return id, Util.DeepCopy(b);
end

-- Adds a prepared build (e.g. decoded by the import lots) under a NEW id; never overwrites.
function H:Add(build)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	ok, err = room(self);
	if not ok then return nil, err; end
	local b, rep = BM.Normalize(build, self.catalog, { id = "pending" });
	if not b then
		return nil, issue("INVALID_BUILD", "build refused", rep);
	end
	local snap = self.db.counter;
	b.id = newId(self);
	local v = BM.Validate(b, self.catalog);
	if not v.ok then
		self.db.counter = snap;
		return nil, issue("INVALID_BUILD", "build refused", v);
	end
	self.db.builds[b.id] = b;
	libAdd(self.db, b);
	self:stamp(b.id, "created");
	return b.id, Util.DeepCopy(b), rep;
end

local EMPTY = {};
-- Read access that tolerates a read-only handle over data of an unknown shape (future/invalid schema).
local function part(self, field)
	local t = self.db[field];
	return type(t) == "table" and t or EMPTY;
end

function H:Get(id)
	local b = part(self, "builds")[id];
	return b and Util.DeepCopy(b) or nil;
end

function H:List(class)
	local out = {};
	local function one(c)
		for _, id in ipairs(part(self, "library")[c] or EMPTY) do
			local b = part(self, "builds")[id];
			if b then
				local rep = BM.Validate(b, self.catalog);
				out[#out + 1] = { id = id, name = b.name, class = b.class, revision = b.revision, clean = rep.clean };
			end
		end
	end
	if class then
		one(class);
	else
		for _, c in ipairs(Util.SortedKeys(part(self, "library"))) do one(c); end
	end
	return out;
end

-- candidate comes from the BuildModel edit functions applied to a copy returned by Get. It must carry the
-- same id and a HIGHER revision than the stored one (a stale editor is refused, nothing is overwritten).
function H:Update(id, candidate)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	local cur = self.db.builds[id];
	if not cur then return nil, issue("NOT_FOUND", "no build " .. tostring(id)); end
	if type(candidate) ~= "table" or candidate.id ~= id then
		return nil, issue("ID_MISMATCH", "candidate has another id");
	end
	if type(candidate.revision) ~= "number" or candidate.revision <= cur.revision then
		return nil, issue("STALE_REVISION", "stored revision " .. cur.revision .. ", candidate " .. tostring(candidate.revision));
	end
	local rep = BM.Validate(candidate, self.catalog);
	if not rep.ok then
		return nil, issue("INVALID_BUILD", "build refused", rep);
	end
	local copy = Util.DeepCopy(candidate);
	if not rep.clean and self.db.active[cur.class] == id then
		self.db.active[cur.class] = nil;      -- an active build must stay conflict-free
	end
	if copy.class ~= cur.class then
		libRemove(self.db, cur.class, id);
		if self.db.active[cur.class] == id then
			self.db.active[cur.class] = nil;
		end
		self.db.builds[id] = copy;
		libAdd(self.db, copy);
	else
		self.db.builds[id] = copy;
	end
	self:stamp(id, "modified");
	return true, rep;
end

function H:Duplicate(id, name)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	local cur = self.db.builds[id];
	if not cur then return nil, issue("NOT_FOUND", "no build " .. tostring(id)); end
	ok, err = room(self);
	if not ok then return nil, err; end
	local copy = Util.DeepCopy(cur);
	local suffix = Locale and Locale.lang == "frFR" and " (copie)" or " (copy)";
	copy.name = name or (cut(cur.name, BM.LIMITS.name - #suffix) .. suffix);
	copy.revision = 1;
	copy.ext = copy.ext or {};
	return self:Add(copy);
end

-- Deletion is a move to the trash (undoable). Only an overflow of the trash drops the oldest entry for good.
function H:Delete(id)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	local b = self.db.builds[id];
	if not b then return nil, issue("NOT_FOUND", "no build " .. tostring(id)); end
	local entry = { build = b, wasActive = (self.db.active[b.class] == id) and b.class or nil, seq = self.db.counter };
	table.insert(self.db.trash, entry);
	local evicted;
	while #self.db.trash > S.LIMITS.trash do
		local old = table.remove(self.db.trash, 1);
		evicted = { id = old.build.id, name = old.build.name, class = old.build.class };   -- reported, never silent
		if type(self.db.meta) == "table" then self.db.meta[old.build.id] = nil; end
	end
	self.db.builds[id] = nil;
	libRemove(self.db, b.class, id);
	if entry.wasActive then
		self.db.active[b.class] = nil;
	end
	return true, evicted;
end

function H:Trash()
	local out = {};
	for i, t in ipairs(part(self, "trash")) do
		out[i] = { id = t.build.id, name = t.build.name, class = t.build.class };
	end
	return out;
end

function H:Restore(id)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	for i, t in ipairs(self.db.trash) do
		if t.build.id == id then
			ok, err = room(self);
			if not ok then return nil, err; end
			table.remove(self.db.trash, i);
			self.db.builds[id] = t.build;
			libAdd(self.db, t.build);
			if t.wasActive and not self.db.active[t.wasActive] then
				self.db.active[t.wasActive] = id;
			end
			return true;
		end
	end
	return nil, issue("NOT_FOUND", "not in the trash: " .. tostring(id));
end

function H:SetActive(class, id)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	local b = self.db.builds[id];
	if not b or b.class ~= class then
		return nil, issue("NOT_FOUND", "no build " .. tostring(id) .. " for class " .. tostring(class));
	end
	-- A build that holds conflicts (imported with a wrong-class key, a duplicate...) may be stored and repaired
	-- but never drives advice: it cannot be made active.
	local rep = BM.Validate(b, self.catalog);
	if not rep.clean then
		return nil, issue("NOT_ACTIVATABLE", "the build has " .. #rep.conflicts .. " conflict(s) to repair first", rep);
	end
	if self.catalog and not self.catalog:IsClass(b.class) then
		return nil, issue("NOT_ACTIVATABLE", "unknown class " .. tostring(b.class) .. ": no advice can be given");
	end
	self.db.active[class] = id;
	return true;
end

function H:GetActive(class)
	return part(self, "active")[class];
end

function H:ClearActive(class)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	self.db.active[class] = nil;
	return true;
end

-- All-or-nothing: either every record is accepted (new ids) or the library is unchanged.
function H:ImportBuilds(list)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	if type(list) ~= "table" or not Util.IsArray(list) then
		return nil, issue("INVALID_IMPORT", "array of builds expected");
	end
	if Util.Len(self.db.builds) + #list > S.LIMITS.builds then
		return nil, issue("LIBRARY_FULL", "import would exceed " .. S.LIMITS.builds .. " builds");
	end
	local staged, problems = {}, {};
	local snap = self.db.counter;
	for i = 1, #list do
		local b, rep = BM.Normalize(list[i], self.catalog, { id = "pending" });
		if not b then
			problems[#problems + 1] = { index = i, report = rep };
		else
			b.id = newId(self);
			staged[#staged + 1] = b;
		end
	end
	if #problems > 0 then
		self.db.counter = snap;
		return nil, issue("INVALID_IMPORT", "import refused, nothing was added", problems);
	end
	local ids = {};
	for i = 1, #staged do
		self.db.builds[staged[i].id] = staged[i];
		libAdd(self.db, staged[i]);
		ids[i] = staged[i].id;
	end
	return ids;
end

-- ------------------------------------------------------------------ library metadata (Lot 3.2)
-- db.meta[id] = { fav = bool, used = unix time, modified = unix time, created = unix time }. Kept OUTSIDE the build
-- record on purpose: favourites and dates never bump a build's revision, never reach an export, and an older
-- addon that does not know db.meta leaves it alone. Absent = unknown (never an invented date). No schema change.
local function metaTable(self, create)
	local m = self.db.meta;
	if m == nil then
		if not create then return EMPTY; end
		m = {};
		self.db.meta = m;
	end
	if type(m) ~= "table" then return nil; end
	return m;
end

-- internal: called by the mutators; silent on a read-only handle or unreadable meta (metadata is never worth an error)
function H:stamp(id, what)
	if self.readOnly then return; end
	local m = metaTable(self, true);
	if not m or not self.db.builds[id] then return; end
	local e = m[id];
	if type(e) ~= "table" then e = {}; m[id] = e; end
	e[what] = math.floor(self.now());
	if what == "created" then e.modified = e.created; end      -- a new build counts as modified when it is made
end

function H:Meta(id)
	local m = metaTable(self, false);
	local e = m and m[id];
	if type(e) ~= "table" then return { fav = false }; end
	return { fav = e.fav == true, used = type(e.used) == "number" and e.used or nil,
		modified = type(e.modified) == "number" and e.modified or nil, created = type(e.created) == "number" and e.created or nil };
end

function H:SetFavorite(id, on)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	if not self.db.builds[id] then return nil, issue("NOT_FOUND", "no build " .. tostring(id)); end
	local m = metaTable(self, true);
	if not m then return nil, issue("INVALID_DB", "meta is not a table; left untouched"); end
	local e = m[id];
	if type(e) ~= "table" then e = {}; m[id] = e; end
	e.fav = on and true or nil;
	return true;
end

-- "used" = opened in the editor or followed by the player
function H:Touch(id)
	if self.readOnly or not self.db.builds[id] then return nil; end
	self:stamp(id, "used");
	return true;
end

-- ------------------------------------------------------------------ settings, quarantine, backups
function H:GetSetting(key)
	local v = part(self, "settings")[key];
	if v == nil then
		return S.SETTING_DEFAULTS[key];
	end
	return v;
end

function H:SetSetting(key, value)
	local ok, err = guard(self);
	if not ok then return nil, err; end
	local check = SETTING_CHECK[key];
	if not check then return nil, issue("UNKNOWN_SETTING", tostring(key)); end
	if not check(value) then return nil, issue("INVALID_VALUE", tostring(key)); end
	self.db.settings[key] = value;
	return true;
end

function H:Quarantined()
	return part(self, "quarantine");
end

function H:Backups()
	return part(self, "backups");
end

function H:DropBackups()
	local ok, err = guard(self);
	if not ok then return nil, err; end
	self.db.backups = {};
	return true;
end

function H:Counts()
	return { builds = Util.Len(part(self, "builds")), trash = #part(self, "trash"), quarantine = #part(self, "quarantine"), backups = #part(self, "backups") };
end
