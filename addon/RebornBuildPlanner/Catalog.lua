-- Read-only access layer over the generated catalogue (GeneratedCatalog.lua). Keys are the official
-- catalogue keys; names/icons are display data and never identify anything. Lua 5.1.
local ADDON, ns = ...;
ns = ns or {};
local Catalog = { SUPPORTED_SCHEMA = 1 };
ns.Catalog = Catalog;
Catalog.__index = Catalog;

local type, pairs, ipairs, setmetatable = type, pairs, ipairs, setmetatable;

-- list name -> what it holds
Catalog.LISTS = {
	spells = { kind = "spell" },
	banish = { kind = "spell" },
	rings = { kind = "jewel", slot = "ring" },
	trinkets = { kind = "jewel", slot = "trinket" },
	amulets = { kind = "amulet" },
};

local function index(rows, label)
	local map = {};
	for i = 1, #rows do
		local r = rows[i];
		if type(r) ~= "table" or type(r.key) ~= "string" then
			return nil, label .. " row " .. i .. " has no string key";
		end
		if map[r.key] then
			return nil, label .. " duplicate key " .. r.key;
		end
		map[r.key] = r;
	end
	return map;
end

-- Returns catalogue, nil or nil, code, message. Refuses future/incompatible schemas and structural damage;
-- nothing is repaired or guessed.
function Catalog.New(data)
	if type(data) ~= "table" or type(data.meta) ~= "table" then
		return nil, "NO_CATALOG", "no catalogue data";
	end
	local schema = data.meta.schema;
	if type(schema) ~= "number" then
		return nil, "INVALID_CATALOG", "meta.schema missing";
	end
	if schema > Catalog.SUPPORTED_SCHEMA then
		return nil, "FUTURE_SCHEMA", "catalogue schema " .. schema .. " is newer than supported " .. Catalog.SUPPORTED_SCHEMA;
	end
	if schema < 1 or type(data.meta.content) ~= "string" then
		return nil, "INVALID_CATALOG", "meta.content missing or schema below 1";
	end
	local self = setmetatable({ data = data, meta = data.meta }, Catalog);
	local err;
	self.classes, err = index(data.classes or {}, "classes");
	if not self.classes then return nil, "INVALID_CATALOG", err; end
	self.spells, err = index(data.spells or {}, "spells");
	if not self.spells then return nil, "INVALID_CATALOG", err; end
	self.jewels, err = index(data.jewelry or {}, "jewelry");
	if not self.jewels then return nil, "INVALID_CATALOG", err; end
	self.amulets, err = index(data.amulets or {}, "amulets");
	if not self.amulets then return nil, "INVALID_CATALOG", err; end
	self.legends, err = index(data.legends or {}, "legends");
	if not self.legends then return nil, "INVALID_CATALOG", err; end
	self.tokens = {};
	self.classOrder = {};
	for i, c in ipairs(data.classes or {}) do
		self.tokens[string.upper(c.token or "")] = c.key;
		self.classOrder[i] = c.key;
	end
	self.idx = data.index or {};
	self.anomalies = data.anomalies or {};
	self.i18n = data.i18n or {};
	return self;
end

function Catalog:Content()
	return self.meta.content;
end

-- "same" / "different" for a build's recorded catalogue hash; "unknown" when the build has none.
function Catalog:Compare(content)
	if type(content) ~= "string" or content == "" then
		return "unknown";
	end
	return content == self.meta.content and "same" or "different";
end

function Catalog:ClassKeys()
	local out = {};
	for i = 1, #self.classOrder do
		out[i] = self.classOrder[i];
	end
	return out;
end

function Catalog:IsClass(key)
	return type(key) == "string" and self.classes[key] ~= nil;
end

-- key, token (any case) -> canonical catalogue key, else nil. Never invents a class.
function Catalog:NormalizeClass(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil;
	end
	local low = string.lower(raw);
	if self.classes[low] then
		return low;
	end
	return self.tokens[string.upper(raw)];
end

function Catalog:Get(kind, key)
	if type(key) ~= "string" then
		return nil;
	end
	if kind == "spell" then
		return self.spells[key];
	elseif kind == "jewel" then
		return self.jewels[key];
	elseif kind == "amulet" then
		return self.amulets[key] or self.legends[key];
	end
	return nil;
end

-- Localized class name with English fallback; an unknown class shows as itself.
function Catalog:ClassName(key, lang)
	local c = self.classes[key];
	if not c then
		return key;
	end
	local tr = lang and self.i18n[lang];
	return (tr and tr[c.name]) or c.name;
end

function Catalog:SpellsOfClass(class)
	local c = self.classes[class];
	return c and c.spells or {};
end

function Catalog:LegendsOfClass(class)
	return self.idx.legendsByClass and self.idx.legendsByClass[class] or {};
end

function Catalog:AmuletsForClass(class)
	return self.idx.amuletsByClass and self.idx.amuletsByClass[class] or {};
end

function Catalog:JewelsBySlot(slot)
	return self.idx.jewelryBySlot and self.idx.jewelryBySlot[slot] or {};
end

-- Is `key` acceptable in list `listName` for `class` (class may be nil = not checked)?
-- Returns "ok"|"unknown"|"wrongclass"|"wrongslot", entry.
function Catalog:CheckKey(listName, key, class)
	local spec = Catalog.LISTS[listName];
	if not spec or type(key) ~= "string" or key == "" then
		return "unknown";
	end
	if spec.kind == "spell" then
		local s = self.spells[key];
		if not s then
			return "unknown";
		end
		if class and s.class ~= class then
			return "wrongclass", s;
		end
		return "ok", s;
	elseif spec.kind == "jewel" then
		local j = self.jewels[key];
		if not j then
			return "unknown";
		end
		if j.slot ~= spec.slot then
			return "wrongslot", j;
		end
		return "ok", j;
	end
	local a = self.amulets[key];
	if a then
		if class and #a.classes > 0 then
			for i = 1, #a.classes do
				if a.classes[i] == class then
					return "ok", a;
				end
			end
			return "wrongclass", a;
		end
		return "ok", a;
	end
	local g = self.legends[key];
	if g then
		if class and g.class ~= class then
			return "wrongclass", g;
		end
		return "ok", g;
	end
	return "unknown";
end

-- Localized display name with English fallback; an unknown key shows as itself.
function Catalog:Name(kind, key, lang)
	local e = self:Get(kind, key);
	if not e then
		return key;
	end
	local tr = lang and self.i18n[lang];
	if tr and tr[e.name] then return tr[e.name]; end
	-- a legendary has no official translation (the heads are English only in the published data): keep the canonical
	-- head and localize only the spell part, when the spell name IS translated; otherwise the English title as is
	if tr and e.head and e.spell and self.spells[e.spell] and tr[self.spells[e.spell].name] then
		return e.head .. ": " .. tr[self.spells[e.spell].name];
	end
	return e.name;
end

-- Candidates whose English or localized name equals `name` (exact). Several results = ambiguous; the
-- caller decides (legendary homonyms need `class`). Display-name matching is a lookup aid, not an identity.
function Catalog:FindByName(listName, name, lang, class)
	local spec = Catalog.LISTS[listName];
	local out = {};
	if not spec or type(name) ~= "string" then
		return out;
	end
	local tr = lang and self.i18n[lang] or {};
	local function consider(e)
		if e.name == name or tr[e.name] == name then
			out[#out + 1] = e;
		end
	end
	if spec.kind == "spell" then
		for _, s in ipairs(self.data.spells) do
			if not class or s.class == class then consider(s); end
		end
	elseif spec.kind == "jewel" then
		for _, j in ipairs(self.data.jewelry) do
			if j.slot == spec.slot then consider(j); end
		end
	else
		for _, a in ipairs(self.data.amulets) do
			if self:CheckKey("amulets", a.key, class) == "ok" then consider(a); end
		end
		for _, g in ipairs(self.data.legends) do
			if not class or g.class == class then consider(g); end
		end
	end
	return out;
end

function Catalog:Homonyms(name)
	return self.idx.homonyms and self.idx.homonyms[name] or nil;
end

function Catalog:SharedIcon(icon)
	return self.idx.sharedIcons and self.idx.sharedIcons[icon] or nil;
end

function Catalog:Anomalies()
	return self.anomalies;
end
