-- Description of amulets from the PUBLISHED data (azreborn.com/data/v1: amulets.json, legends.json), nothing else.
-- Rules come from the official guide (https://azreborn.com/guides/data-api, "Amulet numbers"):
--   multiplier(rank) = 3 - 2 * (1 - growth / 2) ^ (rank - 1)          (growth from the record)
--   fixed amulets : effects = { stat, value }; a value is a share (0.15 = 15%) except regen, kill_heal, lives, targets
--   legends       : effects as the game writes them (name + numbers); a piece with `fixed` grows only in damage and area,
--                   linearly: (fixed + 0.05 * min(rank - 1, 10)) / fixed, and is not offered past rank 11
-- Nothing is invented: a number is shown only when a record carries it; where the guide gives no unit the raw number is
-- shown as published and a note says so. Jewelry (rings, trinkets) has NO effect data in the published files: the
-- caller gets nil and says "Detailed effect unavailable". Pure functions, no widget, no global. Lua 5.1.
local ADDON, ns = ...;
ns = ns or {};
local Locale = ns.Locale;
assert(Locale, "RebornBuildPlanner: Locale.lua must load before Describe.lua");
local D = {};
ns.Describe = D;

local L = function(s) return Locale.T(s); end
local floor, format = math.floor, string.format;

-- statistic names of fixed amulets (English keys; the French text is in UIStrings)
D.STAT = { damage = "Damage", cooldown = "Cooldown", crit = "Crit chance", max_health = "Max health", speed = "Speed",
	reduction = "Reduction", regen = "Regeneration", echo = "Echo", luck = "Luck", gold = "Gold", lifesteal = "Lifesteal",
	kill_heal = "Heal on kill", thorns = "Thorns", targets = "Targets", crit_damage = "Crit damage" };
-- values that are NOT shares (official guide)
local RAW_STAT = { regen = true, kill_heal = true, lives = true, targets = true };

-- legendary effect names that can be translated without guessing; every other name is shown as the game writes it
D.EFFECT = { damage = "Damage", targets = "Targets", area = "Area", duration = "Duration", power = "Power", cooldown = "Cooldown",
	burn = "Burn", jump = "Jump", stun = "Stun", splash = "Splash", slow = "Slow", weaken = "Weaken" };
D.PARAM = { secs = "duration", share = "share", chance = "chance", radius = "radius", n = "count", pct = "percent", below = "below" };
local PARAM_PCT = { share = true, chance = true };
local PARAM_UNIT = { secs = " s" };
D.WORLD = { outland = "Outland", northrend = "Northrend", cataclysm = "Cataclysm" };

local function comma(s)
	if Locale.lang == "frFR" then s = string.gsub(s, "%.", ","); end
	return s;
end

-- number text: integers as is, others with at most two decimals
local function num(n)
	if n == floor(n) then return format("%d", n); end
	local s = format("%.2f", n);
	s = string.gsub(s, "0+$", "");
	s = string.gsub(s, "%.$", "");
	return comma(s);
end
D.Num = num;

local function pct(n)
	local v = n * 100;
	local s;
	if v == floor(v) then s = format("%d", v); else s = string.gsub(string.gsub(format("%.1f", v), "0+$", ""), "%.$", ""); end
	return comma(s) .. (Locale.lang == "frFR" and " %" or "%");
end
D.Pct = pct;

-- official multiplier for growth-type amulets
function D.Multiplier(growth, rank)
	return 3 - 2 * (1 - growth / 2) ^ (rank - 1);
end

-- multiplier of a `fixed` legendary (damage and area only)
function D.FixedMultiplier(fixed, rank)
	local r = rank - 1;
	if r > 10 then r = 10; end
	return (fixed + 0.05 * r) / fixed;
end

local function x(m) return comma(format("x%.2f", m)); end

local function humanize(key)
	local s = string.gsub(tostring(key), "_", " ");
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2);
end

local function effectName(key)
	if D.EFFECT[key] then return L(D.EFFECT[key]), true; end
	return humanize(key), false;       -- the game's own name, not translated, not guessed
end

local function paramText(k, v)
	local label = D.PARAM[k] and L(D.PARAM[k]) or k;
	if type(v) ~= "number" then return label .. " " .. tostring(v); end
	if PARAM_PCT[k] then return label .. " " .. pct(v); end
	if k == "pct" then return label .. " " .. num(v) .. (Locale.lang == "frFR" and " %" or "%"); end
	return label .. " " .. num(v) .. (PARAM_UNIT[k] or "");
end

-- one effect of a legend ("reset" | { name = number } | { name = { k = v, ... } })
local function legendEffect(e)
	if type(e) == "string" then
		local name, known = effectName(e);
		return name, known;
	end
	for name, v in pairs(e) do
		local label, known = effectName(name);
		if type(v) == "table" then
			local keys = {};
			for k in pairs(v) do keys[#keys + 1] = k; end
			table.sort(keys);
			local parts = {};
			for _, k in ipairs(keys) do parts[#parts + 1] = paramText(k, v[k]); end
			return label .. ": " .. table.concat(parts, ", "), known;
		elseif type(v) == "number" then
			return label .. ": " .. num(v), known;
		end
		return label, known;
	end
	return "?", false;
end

local function section(title, lines)
	return { title = title, lines = lines };
end

local function line(text, tone) return { text = text, tone = tone }; end

local function growthLines(growth, fixed)
	local out = {};
	if growth then
		out[#out + 1] = line(string.format(L("Growth %s: %s at rank 2, %s at rank 3, %s at rank 5."), num(growth),
			x(D.Multiplier(growth, 2)), x(D.Multiplier(growth, 3)), x(D.Multiplier(growth, 5))));
		out[#out + 1] = line(L("Official rule: 3 - 2 x (1 - growth / 2) ^ (rank - 1). Rank 1 is x1.00."), "dim");
	elseif fixed then
		out[#out + 1] = line(string.format(L("Fixed value %s: damage and area grow by (%s + 0.05 x (rank - 1)) / %s, x%s at rank 5 and %s at rank 11."),
			num(fixed), num(fixed), num(fixed), num(D.FixedMultiplier(fixed, 5)), x(D.FixedMultiplier(fixed, 11))));
		out[#out + 1] = line(L("This piece is not offered past rank 11."), "dim");
	end
	return out;
end

-- Sections { { title, lines = { {text, tone} } } } for an amulet entry ("amulet" kind of the catalogue: a fixed amulet or
-- a legendary), or nil when the record carries no effect data (then the caller says so).
function D.Amulet(catalog, entry, lang)
	if type(entry) ~= "table" then return nil; end
	local out = {};
	if entry.spell then                                   -- legendary
		if not entry.effects then return nil; end
		local lines = {};
		for _, e in ipairs(entry.effects) do
			local text, known = legendEffect(e);
			lines[#lines + 1] = line(text, known and nil or nil);
		end
		out[#out + 1] = section(L("Effects (rank 1)"), lines);
		local note = L("Numbers as published by the game at rank 1. Where the official guide gives no unit, the plain number is shown.");
		out[#out + 1] = section(L("Growth"), growthLines(entry.growth, entry.fixed));
		out[#out].lines[#out[#out].lines + 1] = line(note, "dim");
		local origin = {};
		if entry.form then origin[#origin + 1] = line(string.format(L("Generic entry for the shape \"%s\" (template %s)."), entry.form, tostring(entry.template))); end
		if entry.template and not entry.form then origin[#origin + 1] = line(string.format(L("Entry written for this spell (%s)."), tostring(entry.template))); end
		if #origin > 0 then out[#out + 1] = section(L("Origin"), origin); end
		return out;
	end
	if not entry.effects then return nil; end
	local lines = {};
	local g = entry.growth;
	for _, e in ipairs(entry.effects) do
		local label = D.STAT[e.stat] and L(D.STAT[e.stat]) or humanize(e.stat);
		local raw = RAW_STAT[e.stat];
		local base = raw and num(e.value) or pct(e.value);
		local text = label .. ": " .. base;
		if g and e.stat ~= "targets" then
			local m = D.Multiplier(g, 5);
			text = text .. string.format(L(" (rank 5: %s)"), raw and num(e.value * m) or pct(e.value * m));
		end
		lines[#lines + 1] = line(text);
	end
	out[#out + 1] = section(L("Effects (rank 1)"), lines);
	if entry.special ~= nil then
		local sp = {};
		if type(entry.special) == "string" then
			sp[1] = line(humanize(entry.special));
		else
			for k, v in pairs(entry.special) do
				sp[#sp + 1] = line(humanize(k) .. ": " .. (type(v) == "number" and pct(v) or tostring(v)) .. " " .. L("(grows with the same multiplier)"));
			end
		end
		out[#out + 1] = section(L("Special"), sp);
	end
	if g then out[#out + 1] = section(L("Growth"), growthLines(g, nil)); end
	local offered = {};
	if catalog and entry.classes and #entry.classes > 0 then
		local names = {};
		for _, k in ipairs(entry.classes) do names[#names + 1] = catalog:ClassName(k, lang); end
		offered[#offered + 1] = line(L("Classes:") .. " " .. table.concat(names, ", "));
	else
		offered[#offered + 1] = line(L("Classes:") .. " " .. L("every class"));
	end
	offered[#offered + 1] = line(L("World:") .. " " .. (entry.world and (D.WORLD[entry.world] and L(D.WORLD[entry.world]) or humanize(entry.world)) or L("every world")));
	if entry.needs == "heal" then offered[#offered + 1] = line(L("Offered only to a hero who knows a heal."), "warn"); end
	out[#out + 1] = section(L("Availability"), offered);
	return out;
end

-- up to `max` short lines for a floating tooltip: the effects only, never the whole description
function D.Preview(sections, max)
	local out = {};
	if not sections or not sections[1] then return out; end
	for _, ln in ipairs(sections[1].lines) do
		if #out >= (max or 3) then break; end
		out[#out + 1] = ln.text;
	end
	return out;
end
