-- Build domain model: pure data + pure functions, no widgets, no AZS runtime, no globals. Lua 5.1.
--
-- build = { model=1, id, name, class, revision, catalog, talents, phases={4 x phase}, ext={} }
-- phase = { label, spells={ {key, mode="acquire"|"rank"|"unlimited", rank?} ... },   -- ordered, wanted
--           banish={key...},                                                           -- separate list
--           rings={4}, trinkets={4}, amulets={4},   -- positions kept, "" = empty; main first, then alternatives
--           stats={statkey=number}, notes, link, ext={} }
--
-- Editing functions never mutate their input: they return a new build (revision + 1) or nil + issues.
-- Severity: error (cannot be stored), conflict (storable, flagged, never advised on), warning.
local ADDON, ns = ...;
ns = ns or {};
local Util = ns.Util;
assert(Util, "RebornBuildPlanner: Util.lua must load before BuildModel.lua");
local M = { MODEL_VERSION = 1 };
ns.BuildModel = M;

local type, pairs, ipairs, tostring, tonumber, string, table = type, pairs, ipairs, tostring, tonumber, string, table;

-- Limits: spells/banish/slot counts mirror the official planner (Z = {spells 6, banish 3, rings 2+2,
-- trinkets 2+2, amulets 1+3}); text limits are BYTES here (the site counts UTF-16 units: the codec of
-- Lot 2 enforces those on exchange). All are tunable data, none is assumed universal.
M.LIMITS = { phases = 4, spells = 6, banish = 3, rings = 4, trinkets = 4, amulets = 4, name = 240, label = 96,
	notes = 8000, link = 300, talents = 400, stats = 32, statValue = 999, maxRank = 99, extNodes = 2000, extDepth = 8 };
M.MAIN_SLOTS = { rings = 2, trinkets = 2, amulets = 1 };
M.LIST_NAMES = { "spells", "banish", "rings", "trinkets", "amulets" };
M.SLOT_LISTS = { "rings", "trinkets", "amulets" };
M.STAT_KEYS = { "damage", "cooldown", "crit", "critdmg", "area", "speed", "armor", "lifesteal", "pickup", "luck", "gold" };
M.DEFAULT_LABELS = { "Early Game", "Mid Game", "End Game", "Endless" };
M.MODES = { acquire = true, rank = true, unlimited = true };
M.STATUS = { UNKNOWN = "UNKNOWN", PENDING = "PENDING", ACHIEVED = "ACHIEVED", BLOCKED = "BLOCKED" };

local L = M.LIMITS;

-- ------------------------------------------------------------------ issues
local function newReport()
	return { errors = {}, conflicts = {}, warnings = {}, issues = {} };
end

local function add(rep, level, code, path, key, extra)
	local it = { level = level, code = code, path = path, key = key, detail = extra };
	local bucket = (level == "error" and rep.errors) or (level == "conflict" and rep.conflicts) or rep.warnings;
	bucket[#bucket + 1] = it;
	rep.issues[#rep.issues + 1] = it;
end

local function finish(rep)
	rep.ok = #rep.errors == 0;
	rep.clean = rep.ok and #rep.conflicts == 0;
	return rep;
end

local function idOf(it)
	return it.code .. "|" .. tostring(it.path) .. "|" .. tostring(it.key);
end

-- ------------------------------------------------------------------ constructors
local function emptyList(n)
	local t = {};
	for i = 1, n do
		t[i] = "";
	end
	return t;
end

function M.NewPhase(label)
	return { label = label or "", spells = {}, banish = {}, rings = emptyList(L.rings), trinkets = emptyList(L.trinkets),
		amulets = emptyList(L.amulets), stats = {}, notes = "", link = "", ext = {} };
end

-- opts: id (required, unique local id from the storage), name, class, catalog (content hash), talents
function M.New(opts, catalog)
	opts = opts or {};
	local b = { model = M.MODEL_VERSION, id = opts.id, name = opts.name or "", class = opts.class, revision = 1,
		catalog = opts.catalog or (catalog and catalog:Content()) or "", talents = opts.talents or "", phases = {}, ext = {} };
	for i = 1, L.phases do
		b.phases[i] = M.NewPhase("");
	end
	local rep = M.Validate(b, catalog);
	if not rep.ok then
		return nil, rep;
	end
	return b, rep;
end

function M.Clone(build)
	return Util.DeepCopy(build);
end

-- ------------------------------------------------------------------ validation
local function isStr(v)
	return type(v) == "string";
end

local function isInt(v)
	return type(v) == "number" and v == v and v >= 1 and v == math.floor(v) and v < 2 ^ 31;
end

local function checkText(rep, v, limit, path, allowEmpty)
	if not isStr(v) then
		add(rep, "error", "INVALID_VALUE", path, nil, "string expected");
	elseif #v > limit then
		add(rep, "error", "TOO_LONG", path, nil, #v .. ">" .. limit);
	elseif not allowEmpty and v == "" then
		add(rep, "error", "INVALID_VALUE", path, nil, "empty");
	end
end

local function checkExt(rep, ext, path)
	if type(ext) ~= "table" then
		add(rep, "error", "INVALID_VALUE", path, nil, "table expected");
		return;
	end
	local ok, why = Util.Measure(ext, L.extNodes, L.extDepth);
	if not ok then
		add(rep, "error", "EXT_REJECTED", path, nil, why);
	end
end

local function checkKeyIn(rep, catalog, class, listName, key, path)
	if not catalog or key == "" then
		return;
	end
	local st = catalog:CheckKey(listName, key, class);
	if st == "unknown" then
		add(rep, "warning", "UNKNOWN_KEY", path, key);
	elseif st == "wrongclass" then
		add(rep, "conflict", "WRONG_CLASS", path, key);
	elseif st == "wrongslot" then
		add(rep, "conflict", "WRONG_SLOT", path, key);
	end
end

local function validatePhase(rep, ph, p, catalog, class)
	local base = "phases[" .. p .. "]";
	if type(ph) ~= "table" then
		add(rep, "error", "INVALID_VALUE", base, nil, "table expected");
		return;
	end
	checkText(rep, ph.label, L.label, base .. ".label", true);
	checkText(rep, ph.notes, L.notes, base .. ".notes", true);
	checkText(rep, ph.link, L.link, base .. ".link", true);
	checkExt(rep, ph.ext, base .. ".ext");
	-- spells (wanted)
	if type(ph.spells) ~= "table" or not Util.IsArray(ph.spells) then
		add(rep, "error", "INVALID_VALUE", base .. ".spells", nil, "array expected");
	else
		if #ph.spells > L.spells then
			add(rep, "error", "TOO_MANY", base .. ".spells", nil, #ph.spells .. ">" .. L.spells);
		end
		local seen = {};
		for i = 1, #ph.spells do
			local g, path = ph.spells[i], base .. ".spells[" .. i .. "]";
			if type(g) ~= "table" or not isStr(g.key) or g.key == "" then
				add(rep, "error", "INVALID_VALUE", path, nil, "goal with key expected");
			else
				if not M.MODES[g.mode] then
					add(rep, "error", "INVALID_VALUE", path .. ".mode", g.key, "mode");
				elseif g.mode == "rank" then
					if not isInt(g.rank) or g.rank > L.maxRank then
						add(rep, "error", "INVALID_VALUE", path .. ".rank", g.key, "rank 1.." .. L.maxRank);
					end
				elseif g.rank ~= nil then
					add(rep, "error", "INVALID_VALUE", path .. ".rank", g.key, "rank only with mode=rank");
				end
				if seen[g.key] then
					add(rep, "conflict", "DUPLICATE_ENTRY", path, g.key);
				end
				seen[g.key] = true;
				checkKeyIn(rep, catalog, class, "spells", g.key, path);
			end
		end
		if type(ph.banish) == "table" and Util.IsArray(ph.banish) then
			for i = 1, #ph.banish do
				if isStr(ph.banish[i]) and seen[ph.banish[i]] then
					add(rep, "conflict", "CONFLICT_SPELL_BANISH", base .. ".banish[" .. i .. "]", ph.banish[i]);
				end
			end
		end
	end
	-- banish (separate; never consumes a wanted slot)
	if type(ph.banish) ~= "table" or not Util.IsArray(ph.banish) then
		add(rep, "error", "INVALID_VALUE", base .. ".banish", nil, "array expected");
	else
		if #ph.banish > L.banish then
			add(rep, "error", "TOO_MANY", base .. ".banish", nil, #ph.banish .. ">" .. L.banish);
		end
		local seen = {};
		for i = 1, #ph.banish do
			local k, path = ph.banish[i], base .. ".banish[" .. i .. "]";
			if not isStr(k) or k == "" then
				add(rep, "error", "INVALID_VALUE", path, nil, "key expected");
			else
				if seen[k] then
					add(rep, "conflict", "DUPLICATE_ENTRY", path, k);
				end
				seen[k] = true;
				checkKeyIn(rep, catalog, class, "banish", k, path);
			end
		end
	end
	-- slot lists: fixed length, positions kept
	for _, name in ipairs(M.SLOT_LISTS) do
		local list, path = ph[name], base .. "." .. name;
		if type(list) ~= "table" or not Util.IsArray(list) or #list ~= L[name] then
			add(rep, "error", "INVALID_VALUE", path, nil, "array of exactly " .. L[name] .. " strings expected");
		else
			local seen = {};
			for i = 1, #list do
				local k = list[i];
				if not isStr(k) then
					add(rep, "error", "INVALID_VALUE", path .. "[" .. i .. "]", nil, "string expected");
				elseif k ~= "" then
					if seen[k] then
						add(rep, "conflict", "DUPLICATE_PIECE", path .. "[" .. i .. "]", k);
					end
					seen[k] = true;
					checkKeyIn(rep, catalog, class, name, k, path .. "[" .. i .. "]");
				end
			end
		end
	end
	-- stats
	if type(ph.stats) ~= "table" then
		add(rep, "error", "INVALID_VALUE", base .. ".stats", nil, "table expected");
	else
		local n = 0;
		for k, v in pairs(ph.stats) do
			n = n + 1;
			if not isStr(k) or type(v) ~= "number" or v ~= v or v < 0 or v > L.statValue then
				add(rep, "error", "INVALID_VALUE", base .. ".stats." .. tostring(k), nil, "number 0.." .. L.statValue);
			end
		end
		if n > L.stats then
			add(rep, "error", "TOO_MANY", base .. ".stats", nil, n .. ">" .. L.stats);
		end
	end
end

function M.Validate(b, catalog)
	local rep = newReport();
	if type(b) ~= "table" then
		add(rep, "error", "INVALID_VALUE", "build", nil, "table expected");
		return finish(rep);
	end
	checkText(rep, b.id, 64, "id", false);
	checkText(rep, b.name, L.name, "name", true);
	checkText(rep, b.talents, L.talents, "talents", true);
	if b.model ~= M.MODEL_VERSION then
		add(rep, "error", "INVALID_VALUE", "model", nil, "model version " .. tostring(b.model));
	end
	if not isInt(b.revision) then
		add(rep, "error", "INVALID_VALUE", "revision", nil, "positive integer expected");
	end
	if not isStr(b.catalog) then
		add(rep, "error", "INVALID_VALUE", "catalog", nil, "string expected");
	end
	if not isStr(b.class) or b.class == "" then
		add(rep, "error", "INVALID_VALUE", "class", nil, "class key expected");
	end
	if isStr(b.talents) and b.talents ~= "" and not string.find(b.talents, "^[0-9%-]*$") then
		add(rep, "warning", "TALENTS_FORMAT", "talents", nil, "digits and dashes expected; kept as is");
	end
	checkExt(rep, b.ext, "ext");
	local class;
	if catalog and isStr(b.class) then
		if catalog:IsClass(b.class) then
			class = b.class;
		else
			add(rep, "warning", "UNKNOWN_CLASS", "class", b.class);
		end
		if catalog:Compare(b.catalog) == "different" then
			add(rep, "warning", "CATALOG_DIFFERS", "catalog", b.catalog);
		end
	end
	if type(b.phases) ~= "table" or not Util.IsArray(b.phases) or #b.phases ~= L.phases then
		add(rep, "error", "INVALID_VALUE", "phases", nil, L.phases .. " phases expected");
	else
		for p = 1, #b.phases do
			validatePhase(rep, b.phases[p], p, catalog, class);
		end
	end
	return finish(rep);
end

-- ------------------------------------------------------------------ editing (functional)
-- Applies fn to a copy. Refused (nil, report) when the copy has errors or gains a conflict the source did
-- not have. Existing conflicts do not block an edit: the user must be able to repair them.
local function edit(build, catalog, fn)
	local before = M.Validate(build, catalog);
	if not before.ok then
		return nil, before;
	end
	local c = M.Clone(build);
	local rep0 = newReport();
	local ok = fn(c, rep0);
	if ok == false then
		return nil, finish(rep0);
	end
	local after = M.Validate(c, catalog);
	local had = {};
	for _, it in ipairs(before.conflicts) do
		had[idOf(it)] = true;
	end
	local refused = not after.ok;
	for _, it in ipairs(after.conflicts) do
		if not had[idOf(it)] then
			refused = true;
		end
	end
	if refused then
		for _, it in ipairs(rep0.issues) do
			after.issues[#after.issues + 1] = it;
		end
		return nil, after;
	end
	c.revision = build.revision + 1;
	return c, after;
end

local function phaseOf(c, rep, p)
	if type(p) ~= "number" or not c.phases[p] then
		add(rep, "error", "INVALID_VALUE", "phase", nil, "no such phase");
		return nil;
	end
	return c.phases[p];
end

local function textSetter(field, limit)
	return function(build, p, value, catalog)
		return edit(build, catalog, function(c, rep)
			local ph = phaseOf(c, rep, p);
			if not ph then return false; end
			ph[field] = value;
		end);
	end;
end

function M.SetName(build, name, catalog)
	return edit(build, catalog, function(c) c.name = name; end);
end

function M.SetTalents(build, talents, catalog)
	return edit(build, catalog, function(c) c.talents = talents; end);
end

function M.SetClass(build, class, catalog)
	return edit(build, catalog, function(c) c.class = class; end);
end

M.SetNotes = textSetter("notes");
M.SetLink = textSetter("link");
M.SetLabel = textSetter("label");

function M.SetStat(build, p, statKey, value, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		ph.stats[statKey] = value;
	end);
end

-- opts: mode ("acquire" default | "rank" | "unlimited"), rank, index (insert position)
function M.AddSpell(build, p, key, opts, catalog)
	opts = opts or {};
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		local g = { key = key, mode = opts.mode or "acquire", rank = opts.rank };
		table.insert(ph.spells, math.min(opts.index or (#ph.spells + 1), #ph.spells + 1), g);
	end);
end

function M.RemoveSpell(build, p, key, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		for i = 1, #ph.spells do
			if ph.spells[i].key == key then
				table.remove(ph.spells, i);
				return true;
			end
		end
		add(rep, "error", "NOT_FOUND", "phases[" .. p .. "].spells", key);
		return false;
	end);
end

-- Moves one entry; every other entry keeps its relative order (stable).
local function moveIn(list, from, to)
	if type(from) ~= "number" or type(to) ~= "number" or from < 1 or to < 1 or from > #list or to > #list then
		return false;
	end
	local v = table.remove(list, from);
	table.insert(list, to, v);
	return true;
end

function M.MoveSpell(build, p, from, to, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		if not moveIn(ph.spells, from, to) then
			add(rep, "error", "INVALID_VALUE", "move", nil, "index out of range");
			return false;
		end
	end);
end

function M.SetSpellTarget(build, p, key, mode, rank, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		for i = 1, #ph.spells do
			if ph.spells[i].key == key then
				ph.spells[i].mode = mode;
				ph.spells[i].rank = (mode == "rank") and rank or nil;
				return true;
			end
		end
		add(rep, "error", "NOT_FOUND", "phases[" .. p .. "].spells", key);
		return false;
	end);
end

function M.AddBanish(build, p, key, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		ph.banish[#ph.banish + 1] = key;
	end);
end

function M.RemoveBanish(build, p, key, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		local i = Util.IndexOf(ph.banish, key);
		if not i then
			add(rep, "error", "NOT_FOUND", "phases[" .. p .. "].banish", key);
			return false;
		end
		table.remove(ph.banish, i);
	end);
end

function M.MoveBanish(build, p, from, to, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		if not moveIn(ph.banish, from, to) then
			add(rep, "error", "INVALID_VALUE", "move", nil, "index out of range");
			return false;
		end
	end);
end

-- Sets one position of rings/trinkets/amulets; empty positions elsewhere are untouched.
function M.SetSlot(build, p, listName, pos, key, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		local list = ph[listName];
		if not M.MAIN_SLOTS[listName] or type(pos) ~= "number" or not list or pos < 1 or pos > #list then
			add(rep, "error", "INVALID_VALUE", "slot", nil, "no such slot");
			return false;
		end
		list[pos] = key or "";
	end);
end

function M.ClearSlot(build, p, listName, pos, catalog)
	return M.SetSlot(build, p, listName, pos, "", catalog);
end

function M.SwapSlots(build, p, listName, i, j, catalog)
	return edit(build, catalog, function(c, rep)
		local ph = phaseOf(c, rep, p);
		if not ph then return false; end
		local list = ph[listName];
		if not M.MAIN_SLOTS[listName] or type(i) ~= "number" or type(j) ~= "number" or i < 1 or j < 1 or i > #list or j > #list then
			add(rep, "error", "INVALID_VALUE", "slot", nil, "no such slot");
			return false;
		end
		list[i], list[j] = list[j], list[i];
	end);
end

-- ------------------------------------------------------------------ lenient normalisation
local KNOWN_TOP = { model = true, id = true, name = true, class = true, revision = true, catalog = true, talents = true,
	phases = true, ext = true };
local KNOWN_PHASE = { label = true, spells = true, banish = true, rings = true, trinkets = true, amulets = true,
	stats = true, notes = true, link = true, ext = true };

-- Copies plain data out of a raw record; anything that is not plain data (function, cycle...) is an error
-- issue, never an exception: Normalize must be safe on arbitrary input.
local function safeCopy(v, rep, path)
	local ok, res = pcall(Util.DeepCopy, v);
	if ok then
		return res;
	end
	add(rep, "error", "EXT_REJECTED", path, nil, "not plain data");
	return nil;
end

local function keepUnknown(raw, known, ext, rep, path)
	for k, v in pairs(raw) do
		if not known[k] then
			local name = isStr(k) and k or ("_n" .. tostring(k));
			if ext[name] ~= nil then
				name = "_dup_" .. name;
			end
			ext[name] = safeCopy(v, rep, path .. "." .. name);
		end
	end
end

local function normList(rawList, size, rep, path, ph)
	local out = emptyList(size);
	if rawList == nil then
		add(rep, "warning", "PARTIAL", path, nil, "missing, padded");
		return out;
	end
	if type(rawList) ~= "table" then
		add(rep, "error", "INVALID_VALUE", path, nil, "array expected");
		return out;
	end
	local overflow = {};
	for i = 1, Util.Len(rawList) do
		local v = rawList[i];
		if v == nil then
			add(rep, "error", "INVALID_VALUE", path, nil, "holes in array");
			break;
		end
		if i <= size then
			out[i] = v;
		elseif v ~= "" then
			overflow[#overflow + 1] = v;
		end
	end
	if #overflow > 0 then
		ph.ext["overflow_" .. string.gsub(path, "[^%w]", "_")] = overflow;
		add(rep, "warning", "OVERFLOW_PRESERVED", path, nil, #overflow .. " entries kept in ext");
	end
	return out;
end

local function normPhase(raw, p, rep)
	local base = "phases[" .. p .. "]";
	local ph = M.NewPhase("");
	if type(raw) ~= "table" then
		add(rep, "error", "INVALID_VALUE", base, nil, "table expected");
		return ph;
	end
	if raw.ext ~= nil then
		if type(raw.ext) == "table" then
			ph.ext = safeCopy(raw.ext, rep, base .. ".ext") or {};
		else
			add(rep, "error", "INVALID_VALUE", base .. ".ext", nil, "table expected");
		end
	end
	keepUnknown(raw, KNOWN_PHASE, ph.ext, rep, base);
	for _, f in ipairs({ "label", "notes", "link" }) do
		if raw[f] ~= nil then ph[f] = raw[f]; end
	end
	if raw.stats ~= nil then
		ph.stats = type(raw.stats) == "table" and (safeCopy(raw.stats, rep, base .. ".stats") or {}) or raw.stats;
	end
	if raw.spells == nil then
		add(rep, "warning", "PARTIAL", base .. ".spells", nil, "missing");
	elseif type(raw.spells) ~= "table" then
		ph.spells = raw.spells;
	else
		ph.spells = {};
		for i = 1, Util.Len(raw.spells) do
			local g = raw.spells[i];
			if type(g) == "string" then
				ph.spells[i] = { key = g, mode = "acquire" };
			elseif type(g) == "table" then
				ph.spells[i] = safeCopy(g, rep, base .. ".spells[" .. i .. "]") or {};
				if g.mode == nil then ph.spells[i].mode = "acquire"; end
			else
				ph.spells[i] = g;
			end
		end
	end
	if raw.banish == nil then
		add(rep, "warning", "PARTIAL", base .. ".banish", nil, "missing");
	else
		ph.banish = type(raw.banish) == "table" and (safeCopy(raw.banish, rep, base .. ".banish") or {}) or raw.banish;
	end
	for _, name in ipairs(M.SLOT_LISTS) do
		ph[name] = normList(raw[name], L[name], rep, base .. "." .. name, ph);
	end
	return ph;
end

-- raw: any table (stored record, decoded import...). Never mutates raw. Returns build, report or nil, report
-- when it contains an error (the caller keeps the raw record untouched / quarantines it).
function M.Normalize(raw, catalog, opts)
	opts = opts or {};
	local rep = newReport();
	if type(raw) ~= "table" then
		add(rep, "error", "INVALID_VALUE", "build", nil, "table expected");
		return nil, finish(rep);
	end
	local b = { model = raw.model or M.MODEL_VERSION, id = raw.id or opts.id, name = raw.name, class = raw.class,
		revision = raw.revision, catalog = raw.catalog, talents = raw.talents, phases = {}, ext = {} };
	if raw.name == nil then b.name = ""; add(rep, "warning", "PARTIAL", "name", nil, "missing"); end
	if raw.revision == nil then b.revision = 1; add(rep, "warning", "PARTIAL", "revision", nil, "missing"); end
	if raw.catalog == nil then b.catalog = ""; add(rep, "warning", "PARTIAL", "catalog", nil, "missing"); end
	if raw.talents == nil then b.talents = ""; end
	if isStr(b.class) and catalog then
		b.class = catalog:NormalizeClass(b.class) or b.class;
	end
	if raw.ext ~= nil then
		if type(raw.ext) == "table" then
			b.ext = safeCopy(raw.ext, rep, "ext") or {};
		else
			add(rep, "error", "INVALID_VALUE", "ext", nil, "table expected");
		end
	end
	keepUnknown(raw, KNOWN_TOP, b.ext, rep, "ext");
	local rawPhases = raw.phases;
	if rawPhases == nil then
		add(rep, "warning", "PARTIAL", "phases", nil, "missing, four empty phases created");
		rawPhases = {};
	elseif type(rawPhases) ~= "table" then
		add(rep, "error", "INVALID_VALUE", "phases", nil, "array expected");
		return nil, finish(rep);
	end
	local n = Util.Len(rawPhases);
	for p = 1, L.phases do
		if rawPhases[p] == nil then
			b.phases[p] = M.NewPhase("");
			if rawPhases ~= nil and n > 0 then
				add(rep, "warning", "PARTIAL", "phases[" .. p .. "]", nil, "missing, empty phase created");
			end
		else
			b.phases[p] = normPhase(rawPhases[p], p, rep);
		end
	end
	if n > L.phases then
		local extra = {};
		for p = L.phases + 1, n do
			extra[#extra + 1] = safeCopy(rawPhases[p], rep, "phases[" .. p .. "]");
		end
		b.ext.extraPhases = extra;
		add(rep, "warning", "OVERFLOW_PRESERVED", "phases", nil, (n - L.phases) .. " extra phases kept in ext");
	end
	local v = M.Validate(b, catalog);
	for _, it in ipairs(v.issues) do
		add(rep, it.level, it.code, it.path, it.key, it.detail);
	end
	finish(rep);
	if not rep.ok then
		return nil, rep;
	end
	return b, rep;
end

-- ------------------------------------------------------------------ read helpers
-- Flat view of a phase's slot lists: { list, pos, key, role = "main"|"alt" } for non-empty positions.
function M.Slots(ph, listName)
	local out, list = {}, ph[listName] or {};
	for i = 1, #list do
		if list[i] ~= "" then
			out[#out + 1] = { list = listName, pos = i, key = list[i], role = (i <= (M.MAIN_SLOTS[listName] or 0)) and "main" or "alt" };
		end
	end
	return out;
end

-- Matches worn pieces to planned positions, each worn piece used AT MOST ONCE (a piece never satisfies two
-- positions). Returns { matched = {pos -> key}, missing = {pos -> key}, extra = {keys not planned} }.
function M.AssignOwned(ph, listName, owned)
	local pool = {};
	for i = 1, #owned do
		pool[#pool + 1] = { key = owned[i], used = false };
	end
	local res = { matched = {}, missing = {}, extra = {} };
	local list = ph[listName] or {};
	for pos = 1, #list do
		local k = list[pos];
		if k ~= "" then
			local found;
			for i = 1, #pool do
				if not pool[i].used and pool[i].key == k then
					found = pool[i];
					break;
				end
			end
			if found then
				found.used = true;
				res.matched[pos] = k;
			else
				res.missing[pos] = k;
			end
		end
	end
	for i = 1, #pool do
		if not pool[i].used then
			res.extra[#res.extra + 1] = pool[i].key;
		end
	end
	return res;
end

-- Status of one wanted-spell goal against what the game reported. The four statuses stay distinct:
--   UNKNOWN  the data is not known (state.known ~= true, or rank needed but unknown)
--   BLOCKED  cannot happen as planned (state.blocked[key] = reason)
--   ACHIEVED the condition holds
--   PENDING  known, possible, not yet reached (also the permanent state of an "unlimited" goal)
-- state = { known = bool, spells = { [key] = rank | true (owned, rank unknown) }, blocked = { [key] = reason } }
function M.EvaluateGoal(goal, state)
	local S = M.STATUS;
	if type(state) ~= "table" or state.known ~= true then
		return S.UNKNOWN, "data not known";
	end
	local have = state.spells and state.spells[goal.key];
	if state.blocked and state.blocked[goal.key] and not have then
		return S.BLOCKED, state.blocked[goal.key];
	end
	if goal.mode == "unlimited" then
		return S.PENDING, "no upper target";
	end
	if goal.mode == "rank" then
		if not have then
			return S.PENDING, "not acquired";
		end
		if type(have) ~= "number" then
			return S.UNKNOWN, "rank unknown";
		end
		return have >= goal.rank and S.ACHIEVED or S.PENDING, "rank " .. have .. "/" .. goal.rank;
	end
	return have and S.ACHIEVED or S.PENDING, have and "acquired" or "not acquired";
end

-- Does this goal count toward a phase being complete? (unlimited never blocks a transition.)
function M.CountsForCompletion(goal)
	return goal.mode ~= "unlimited";
end
