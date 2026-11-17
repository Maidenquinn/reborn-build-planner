-- Codec for the official Reborn planner format (azsb1:), Lua 5.1. Original code, written from the observed
-- contract in docs/CONTRACTS.md §4 (not copied from the site's minified script).
--
--   Decode(text, catalog)          -> preview   (no persistent mutation, ever)
--   CommitImport(handle, preview)  -> id        (adds a NEW build; never activates, never overwrites)
--   PlanExport(build, catalog)     -> report    (what the site format cannot carry, BEFORE exporting)
--   Encode(build, catalog, opts)   -> code, report | nil, report (refused until losses are accepted)
--
-- Differences from the site's own importer, by design (product decision of Lot 2):
--   * the site silently drops unknown / other-class / duplicate keys; this codec KEEPS them and reports them
--     (the build is then "needs repair": storable, never activatable);
--   * text limits are the site's (UTF-16 units) and are applied with a visible TRUNCATED warning;
--   * input is only ever parsed as data: no load/loadstring/dofile, bounded size, depth and node count.
local ADDON, ns = ...;
ns = ns or {};
local Json, Utf8, B64, BM, Util, Locale = ns.Json, ns.Utf8, ns.Base64Url, ns.BuildModel, ns.Util, ns.Locale;
assert(Json and Utf8 and B64 and BM and Util and Locale, "RebornBuildPlanner: PlannerCodec needs Utf8, Base64Url, Json, BuildModel");
local C = {};
ns.PlannerCodec = C;

local sub, find, match, lower, gsub = string.sub, string.find, string.match, string.lower, string.gsub;

C.PREFIX = "azsb1:";
C.VERSION = 1;
C.LIMITS = { encodedChars = 131080,   -- = base64 length of decodedBytes + slack, so PAYLOAD_TOO_LARGE is reachable
	 decodedBytes = 98304, jsonDepth = 8, jsonNodes = 5000, sourceKeep = 4096, className = 64 };
C.SITE = { name = 60, label = 24, notes = 2000, link = 300, talents = 400 };   -- UTF-16 units / characters
C.OFFICIAL_HOSTS = { ["azreborn.com"] = true, ["www.azreborn.com"] = true };

local MESSAGES = {
	EMPTY_INPUT = "Nothing to import",
	INPUT_TOO_LARGE = "The code is larger than the supported limit",
	URL_SCHEME_UNSUPPORTED = "Only http(s) links are read",
	URL_NO_PAYLOAD = "The link carries neither a build (p) nor talents (b)",
	BASE64_INVALID = "The code is not valid base64url",
	PAYLOAD_TOO_LARGE = "The decoded build is larger than the supported limit",
	INVALID_UTF8 = "The build text is not valid UTF-8",
	JSON_INVALID = "The build data is malformed",
	NOT_A_PLAN = "Not a planner build (a JSON array was expected)",
	UNSUPPORTED_VERSION = "Unsupported planner format version",
	MISSING_CLASS = "The build does not name a class",
	TYPE_MISMATCH = "A value has the wrong type",
	TALENTS_INVALID = "Not a talent string (digits and dashes only)",
	UNKNOWN_CLASS = "Unknown class (kept as is; no advice will be given)",
	CLASS_NORMALIZED = "Class name was normalised to its catalogue key",
	TRUNCATED = "Text cut to the official planner's limit",
	EMPTY_KEY_DROPPED = "An empty entry was ignored",
	OVERFLOW_PRESERVED = "More entries than the planner allows: the extra ones were kept aside",
	STAT_REJECTED = "A statistic could not be used and was kept aside",
	LINK_REJECTED = "The link is not a valid http(s) address and was kept aside",
	TALENTS_REJECTED = "The talent string is not valid and was kept aside",
	EXTRA_DATA_PRESERVED = "Unknown extra data was kept aside",
	NON_OFFICIAL_HOST = "The link does not come from the official planner site",
	UNKNOWN_KEY = "Unknown catalogue key (kept)",
	WRONG_CLASS = "This entry belongs to another class (kept, build needs repair)",
	WRONG_SLOT = "This entry does not fit this slot (kept, build needs repair)",
	DUPLICATE_ENTRY = "Duplicate entry (kept, build needs repair)",
	DUPLICATE_PIECE = "Same piece in several slots (kept, build needs repair)",
	CONFLICT_SPELL_BANISH = "Spell is both wanted and banished (kept, build needs repair)",
	CATALOG_DIFFERS = "Catalogue version differs",
	TOO_MANY = "Too many entries",
	PARTIAL = "A missing part was filled with an empty value",
	GOAL_MODE_NOT_REPRESENTABLE = "Rank / unlimited targets do not exist in the official format",
	EXT_NOT_REPRESENTABLE = "Extra data of this build has no place in the official format",
	SITE_DROPS_KEY = "The official planner will drop this entry",
	SITE_DROPS_DUPLICATE = "The official planner will drop this duplicate",
	SITE_DROPS_BANISH_OVERLAP = "The official planner will drop this banish (it is also a wanted spell)",
	SITE_REJECTS_CLASS = "The official planner will reject a build of an unknown class",
	SITE_TRUNCATES = "The official planner will cut this text",
	SITE_DROPS_LINK = "The official planner will drop this link",
	SITE_DROPS_TALENTS = "The official planner will drop these talents",
	SITE_ROUNDS_STAT = "The official planner rounds statistics to one decimal",
	SITE_CAPS_STAT = "The official planner caps statistics at 999",
	STAT_NOT_REPRESENTABLE = "This statistic cannot be exported",
	STAT_ZERO_OMITTED = "A zero statistic is omitted (the official planner treats it as unset)",
	METADATA_OMITTED = "Internal metadata is not part of the official format",
	CATALOG_UNAVAILABLE = "No catalogue: keys could not be checked for the official planner",
};
C.MESSAGES = MESSAGES;
Locale.Register({
	["Nothing to import"] = "Rien à importer",
	["The code is not valid base64url"] = "Le code n'est pas du base64url valide",
	["The build data is malformed"] = "Les données du build sont mal formées",
	["Unsupported planner format version"] = "Version du format non prise en charge",
	["Unknown catalogue key (kept)"] = "Clé de catalogue inconnue (conservée)",
	["This entry belongs to another class (kept, build needs repair)"] = "Cette entrée appartient à une autre classe (conservée, build à réparer)",
	["Duplicate entry (kept, build needs repair)"] = "Entrée en double (conservée, build à réparer)",
	["Spell is both wanted and banished (kept, build needs repair)"] = "Sort à la fois souhaité et banni (conservé, build à réparer)",
	["Text cut to the official planner's limit"] = "Texte coupé à la limite du planner officiel",
	["Rank / unlimited targets do not exist in the official format"] = "Les objectifs de rang / sans limite n'existent pas dans le format officiel",
	["Extra data of this build has no place in the official format"] = "Les données supplémentaires de ce build n'ont pas de place dans le format officiel",
	["The official planner will drop this entry"] = "Le planner officiel supprimera cette entrée",
	["Internal metadata is not part of the official format"] = "Les métadonnées internes ne font pas partie du format officiel",
});

-- ------------------------------------------------------------------ issue helpers
local function newIssues()
	return { list = {}, errors = 0, conflicts = 0, warnings = 0 };
end

local function add(iss, level, code, path, key, detail)
	local it = { level = level, code = code, path = path, key = key, detail = detail, message = Locale.T(MESSAGES[code] or code) };
	iss.list[#iss.list + 1] = it;
	if level == "error" then iss.errors = iss.errors + 1; elseif level == "conflict" then iss.conflicts = iss.conflicts + 1; else iss.warnings = iss.warnings + 1; end
	return it;
end

function C.Message(code)
	return Locale.T(MESSAGES[code] or code);
end

-- ------------------------------------------------------------------ small validators (site parity)
local function talentsOk(s)
	return type(s) == "string" and #s <= C.SITE.talents and find(s, "^[0-9%-]*$") ~= nil;
end
C.TalentsOk = talentsOk;

-- ^https?://\S+$ then `new URL(...)` with an http(s) protocol. The URL half is an APPROXIMATION of WHATWG
-- parsing (host non-empty, no forbidden host characters, numeric port <= 65535); it is exercised by the
-- golden cases but not proven equal to a browser (documented in docs/REPORT_LOT2.md).
local function linkOk(t)
	local scheme = match(t, "^[hH][tT][tT][pP][sS]?://");
	if not scheme then return false; end
	local rest = sub(t, #scheme + 1);
	if rest == "" or Utf8.HasSpace(rest) then return false; end
	rest = gsub(rest, "^[/\]+", "");          -- special schemes ignore extra slashes
	local auth = match(rest, "^([^/?#\]*)");
	local host = match(auth, "([^@]*)$");
	if sub(host, 1, 1) == "[" then
		local inner, tail = match(host, "^%[([%x:%.]+)%](.*)$");
		return inner ~= nil and (tail == "" or find(tail, "^:%d*$") ~= nil);
	end
	local port;
	local h, p = match(host, "^(.-):(%d*)$");
	if h then host, port = h, p; end
	if host == "" or find(host, "[%z-#%%/:<>%?@%[\%]%^|]") then return false; end
	if port and port ~= "" and tonumber(port) > 65535 then return false; end
	return true;
end
C.LinkOk = linkOk;

local function cut(s, limit, iss, path)
	local out, truncated, total = Utf8.Slice16(s, limit);
	if truncated and iss then
		add(iss, "warning", "TRUNCATED", path, nil, total .. " > " .. limit .. " UTF-16 units");
	end
	return out, truncated, total;
end

-- JSON value -> plain Lua data (for keeping rejected data aside)
local function plain(v, depth)
	depth = depth or 0;
	if v == Json.null then return false; end
	if type(v) ~= "table" then return v; end
	if depth > 6 then return false; end
	local o = {};
	for k, x in pairs(v) do o[k] = plain(x, depth + 1); end
	return o;
end

-- ------------------------------------------------------------------ input parsing
local function pctDecode(s)
	s = gsub(s, "%+", " ");
	return (gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)); end));
end

local function parseUrl(t)
	local scheme, rest = match(t, "^([%a][%w+.%-]*)://(.*)$");
	local sl = lower(scheme);
	if sl ~= "http" and sl ~= "https" then
		return nil, "URL_SCHEME_UNSUPPORTED";
	end
	rest = gsub(rest, "#.*$", "");
	local before, query = match(rest, "^([^?]*)%??(.*)$");
	local host, path = match(before, "^([^/]*)(.*)$");
	host = lower(match(host, "([^@]*)$") or host);
	host = gsub(host, ":%d*$", "");
	local params = {};
	for pair in string.gmatch(query, "[^&]+") do
		local k, v = match(pair, "^([^=]*)=?(.*)$");
		k = pctDecode(k);
		if params[k] == nil then params[k] = pctDecode(v); end
	end
	local segment;
	for seg in string.gmatch(path, "[^/]+") do segment = seg; end
	return { host = host, params = params, lastSegment = segment and lower(pctDecode(segment)) };
end

-- -> { kind = "payload"|"talents", payload|talents, url = {...}? } | nil, code
local function parseInput(text)
	if type(text) ~= "string" then return nil, "EMPTY_INPUT"; end
	if #text > C.LIMITS.encodedChars + 2048 then return nil, "INPUT_TOO_LARGE"; end
	if not Utf8.Validate(text) then return nil, "INVALID_UTF8"; end
	local t = Utf8.Trim(text);
	if t == "" then return nil, "EMPTY_INPUT"; end
	local payload = gsub(t, "^[aA][zZ][sS][bB]1[%.:]", "");
	local url;
	if find(t, "^[%a][%w+.%-]*://") then
		local u, err = parseUrl(t);
		if not u then return nil, err; end
		url = u;
		if u.params.p and u.params.p ~= "" then
			payload = u.params.p;
		elseif u.params.b ~= nil then
			return { kind = "talents", talents = u.params.b, url = u };
		else
			return nil, "URL_NO_PAYLOAD";
		end
	end
	-- same test as the site: /^[0-9]+(-[0-9]+)*$/ and at least one dash
	if find(payload, "^%d[%d%-]*$") and find(payload, "%-") and not find(payload, "%-%-") and sub(payload, -1) ~= "-" then
		return { kind = "talents", talents = payload, url = url };
	end
	if #payload > C.LIMITS.encodedChars then return nil, "INPUT_TOO_LARGE"; end
	return { kind = "payload", payload = payload, url = url };
end
C.ParseInput = parseInput;

-- ------------------------------------------------------------------ decoding of the positional array
local function typeName(v)
	if v == Json.null then return "null"; end
	if Json.IsArray(v) then return "array"; end
	if Json.IsObject(v) then return "object"; end
	return type(v);
end

local function textField(v, iss, path, optional)
	if v == nil or v == Json.null then return ""; end
	if type(v) ~= "string" then
		add(iss, "error", "TYPE_MISMATCH", path, nil, "string expected, got " .. typeName(v));
		return "";
	end
	return v;
end

local function keyList(v, iss, path, limit, ph, listName)
	local out = {};
	if v == nil or v == Json.null then return out; end
	if not Json.IsArray(v) then
		add(iss, "error", "TYPE_MISMATCH", path, nil, "array expected, got " .. typeName(v));
		return out;
	end
	local overflow = {};
	for i = 1, #v do
		local k = v[i];
		if type(k) ~= "string" then
			add(iss, "error", "TYPE_MISMATCH", path .. "[" .. i .. "]", nil, "string expected, got " .. typeName(k));
		elseif k == "" then
			add(iss, "warning", "EMPTY_KEY_DROPPED", path .. "[" .. i .. "]");
		elseif #out < limit then
			out[#out + 1] = k;
		else
			overflow[#overflow + 1] = k;
		end
	end
	if #overflow > 0 then
		ph.ext.import = ph.ext.import or {};
		ph.ext.import["overflow_" .. listName] = overflow;
		add(iss, "warning", "OVERFLOW_PRESERVED", path, nil, #overflow .. " extra entries");
	end
	return out;
end

local function slotList(v, iss, path)
	if v == nil or v == Json.null then return {}; end
	if not Json.IsArray(v) then
		add(iss, "error", "TYPE_MISMATCH", path, nil, "array expected, got " .. typeName(v));
		return {};
	end
	local out = {};
	for i = 1, #v do
		local k = v[i];
		if k == Json.null then
			out[i] = "";
		elseif type(k) ~= "string" then
			add(iss, "error", "TYPE_MISMATCH", path .. "[" .. i .. "]", nil, "string expected, got " .. typeName(k));
			out[i] = "";
		else
			out[i] = k;
		end
	end
	return out;
end

local function decodePhase(v, p, iss, stash)
	local base = "phases[" .. p .. "]";
	local ph = { label = "", spells = {}, banish = {}, notes = "", link = "", stats = {}, ext = {} };
	if v == nil or v == Json.null then
		return ph;
	end
	if not Json.IsArray(v) then
		add(iss, "error", "TYPE_MISMATCH", base, nil, "array or null expected, got " .. typeName(v));
		return ph;
	end
	-- label
	local label = textField(v[1], iss, base .. ".label");
	label = Utf8.Trim(label);
	label = cut(label, C.SITE.label, iss, base .. ".label");
	if label == BM.DEFAULT_LABELS[p] then label = ""; end
	ph.label = label;
	-- spells / banish
	local spells = keyList(v[2], iss, base .. ".spells", BM.LIMITS.spells, ph, "spells");
	for i = 1, #spells do ph.spells[i] = { key = spells[i], mode = "acquire" }; end
	ph.banish = keyList(v[3], iss, base .. ".banish", BM.LIMITS.banish, ph, "banish");
	ph.rings = slotList(v[4], iss, base .. ".rings");
	ph.trinkets = slotList(v[5], iss, base .. ".trinkets");
	ph.amulets = slotList(v[6], iss, base .. ".amulets");
	-- stats: [[index, value], ...], index 0-based in BM.STAT_KEYS order
	local sv = v[7];
	if sv ~= nil and sv ~= Json.null then
		if not Json.IsArray(sv) then
			add(iss, "error", "TYPE_MISMATCH", base .. ".stats", nil, "array expected, got " .. typeName(sv));
		else
			for i = 1, #sv do
				local e = sv[i];
				local idx, val = Json.IsArray(e) and e[1], Json.IsArray(e) and e[2];
				local key = type(idx) == "number" and idx == math.floor(idx) and BM.STAT_KEYS[idx + 1] or nil;
				if key and type(val) == "number" and val > 0 and val <= BM.LIMITS.statValue then
					if ph.stats[key] ~= nil then
						add(iss, "warning", "STAT_REJECTED", base .. ".stats", key, "repeated; the last value wins");
					end
					ph.stats[key] = val;
				else
					ph.ext.import = ph.ext.import or {};
					local list = ph.ext.import.rejectedStats or {};
					list[#list + 1] = plain(e);
					ph.ext.import.rejectedStats = list;
					add(iss, "warning", "STAT_REJECTED", base .. ".stats[" .. i .. "]", key);
				end
			end
		end
	end
	-- notes
	local notes = textField(v[8], iss, base .. ".notes");
	ph.notes = cut(notes, C.SITE.notes, iss, base .. ".notes");
	-- link
	local link = textField(v[9], iss, base .. ".link");
	link = cut(Utf8.Trim(link), C.SITE.link, iss, base .. ".link");
	if link ~= "" and not linkOk(link) then
		ph.ext.import = ph.ext.import or {};
		ph.ext.import.rejectedLink = link;
		add(iss, "warning", "LINK_REJECTED", base .. ".link");
		link = "";
	end
	ph.link = link;
	-- positions beyond the nine known ones
	if #v > 9 then
		local extra = {};
		for i = 10, #v do extra[#extra + 1] = plain(v[i]); end
		ph.ext.import = ph.ext.import or {};
		ph.ext.import.extraFields = extra;
		add(iss, "warning", "EXTRA_DATA_PRESERVED", base, nil, (#v - 9) .. " extra fields");
	end
	return ph;
end

local function decodeArray(arr, catalog, iss)
	if not Json.IsArray(arr) then
		add(iss, "error", "NOT_A_PLAN", "root", nil, "got " .. typeName(arr));
		return nil;
	end
	local ver = arr[1];
	if type(ver) ~= "number" then
		add(iss, "error", "NOT_A_PLAN", "root[1]", nil, "version number expected");
		return nil;
	end
	if ver ~= C.VERSION then
		add(iss, "error", "UNSUPPORTED_VERSION", "root[1]", nil, "version " .. tostring(ver) .. (ver > C.VERSION and " (newer than this addon)" or ""));
		return nil;
	end
	local name = Utf8.Trim(textField(arr[2], iss, "name"));
	name = cut(name, C.SITE.name, iss, "name");
	local cls = arr[3];
	if type(cls) ~= "string" or cls == "" then
		add(iss, "error", "MISSING_CLASS", "class", nil, typeName(cls));
		return nil;
	end
	if #cls > C.LIMITS.className or not Utf8.Validate(cls) then
		add(iss, "error", "TYPE_MISMATCH", "class", nil, "class name unusable");
		return nil;
	end
	local canon = catalog and catalog:NormalizeClass(cls);
	if canon and canon ~= cls then
		add(iss, "warning", "CLASS_NORMALIZED", "class", cls, canon);
		cls = canon;
	end
	local stash = {};
	local talents = textField(arr[4], iss, "talents");
	local ext = {};
	if talents ~= "" and not talentsOk(talents) then
		ext.import = { rejectedTalents = talents };
		add(iss, "warning", "TALENTS_REJECTED", "talents");
		talents = "";
	end
	local phases = {};
	for p = 1, 4 do
		phases[p] = decodePhase(arr[4 + p], p, iss, stash);
	end
	if #arr > 8 then
		local extra = {};
		for i = 9, #arr do extra[#extra + 1] = plain(arr[i]); end
		ext.import = ext.import or {};
		ext.import.extraPhases = extra;
		add(iss, "warning", "EXTRA_DATA_PRESERVED", "root", nil, (#arr - 8) .. " extra element(s)");
	end
	return { id = "pending", name = name, class = cls, talents = talents, revision = 1,
		catalog = catalog and catalog:Content() or "", phases = phases, ext = ext };
end

local function summary(build)
	local rows = {};
	for p, ph in ipairs(build.phases) do
		local function count(list) local n = 0; for _, k in ipairs(list) do if k ~= "" then n = n + 1; end end return n; end
		local stats = 0;
		for _ in pairs(ph.stats) do stats = stats + 1; end
		local n = #ph.spells + #ph.banish + count(ph.rings) + count(ph.trinkets) + count(ph.amulets) + stats;
		rows[p] = { index = p, label = ph.label, defaultLabel = BM.DEFAULT_LABELS[p], empty = (n == 0 and ph.notes == "" and ph.link == ""),
			spells = #ph.spells, banish = #ph.banish, rings = count(ph.rings), trinkets = count(ph.trinkets), amulets = count(ph.amulets),
			stats = stats, hasNotes = ph.notes ~= "", hasLink = ph.link ~= "" };
	end
	return rows;
end

-- ------------------------------------------------------------------ public: preview
-- Returns a preview table (never raises, never touches storage):
--   ok, kind ("plan"|"talents"), issues{list,errors,conflicts,warnings}, errorCode, source{...},
--   plan: build (model, id "pending"), class, classKnown, name, phases (summary), status ("ready"|"needs_repair"),
--         canActivate, exportReport (what a re-export to the site would lose)
--   talents: talents, class (from the link path, or nil), needsClass
function C.Decode(text, catalog, opts)
	opts = opts or {};
	local iss = newIssues();
	local pv = { ok = false, issues = iss };
	local trimmed = type(text) == "string" and sub(text, 1, C.LIMITS.sourceKeep) or "";
	pv.source = { chars = type(text) == "string" and #text or 0, text = trimmed, truncated = type(text) == "string" and #text > C.LIMITS.sourceKeep };
	local inp, code = parseInput(text);
	if not inp then
		pv.errorCode = code;
		add(iss, "error", code, "input");
		return pv;
	end
	if inp.url and not C.OFFICIAL_HOSTS[inp.url.host] then
		add(iss, "warning", "NON_OFFICIAL_HOST", "url", inp.url.host);
	end
	pv.official = inp.url and C.OFFICIAL_HOSTS[inp.url.host] or false;
	if inp.kind == "talents" then
		pv.kind = "talents";
		if not talentsOk(inp.talents) then
			pv.errorCode = "TALENTS_INVALID";
			add(iss, "error", "TALENTS_INVALID", "talents");
			return pv;
		end
		pv.talents = inp.talents;
		local cls = inp.url and inp.url.lastSegment and catalog and catalog:NormalizeClass(inp.url.lastSegment) or nil;
		pv.class, pv.needsClass = cls, cls == nil;
		pv.ok = true;
		return pv;
	end
	local bytes, why = B64.Decode(inp.payload, C.LIMITS.encodedChars);
	if not bytes then
		pv.errorCode = (why == "too long") and "INPUT_TOO_LARGE" or "BASE64_INVALID";
		add(iss, "error", pv.errorCode, "payload", nil, why);
		return pv;
	end
	if #bytes > C.LIMITS.decodedBytes then
		pv.errorCode = "PAYLOAD_TOO_LARGE";
		add(iss, "error", "PAYLOAD_TOO_LARGE", "payload", nil, #bytes .. " bytes");
		return pv;
	end
	if sub(bytes, 1, 3) == "\239\187\191" then bytes = sub(bytes, 4); end      -- a TextDecoder drops a BOM too
	local fine, pos, reason = Utf8.Validate(bytes);
	if not fine then
		pv.errorCode = "INVALID_UTF8";
		add(iss, "error", "INVALID_UTF8", "payload", nil, "byte " .. tostring(pos) .. ": " .. tostring(reason));
		return pv;
	end
	local value, err = Json.Decode(bytes, { maxBytes = C.LIMITS.decodedBytes, maxDepth = C.LIMITS.jsonDepth, maxNodes = C.LIMITS.jsonNodes });
	if err then
		pv.errorCode = "JSON_INVALID";
		add(iss, "error", "JSON_INVALID", "payload", nil, tostring(err.code) .. (err.pos and (" at " .. err.pos) or ""));
		return pv;
	end
	local raw = decodeArray(value, catalog, iss);
	if not raw or iss.errors > 0 then
		pv.errorCode = pv.errorCode or (iss.list[#iss.list] and iss.list[#iss.list].code) or "NOT_A_PLAN";
		return pv;
	end
	local build, rep = BM.Normalize(raw, catalog);
	if not build then
		for _, it in ipairs(rep.errors) do add(iss, "error", it.code, it.path, it.key, it.detail); end
		pv.errorCode = rep.errors[1] and rep.errors[1].code or "NOT_A_PLAN";
		return pv;
	end
	for _, it in ipairs(rep.issues) do
		if it.code ~= "PARTIAL" then add(iss, it.level, it.code, it.path, it.key, it.detail); end
	end
	pv.ok, pv.kind = true, "plan";
	pv.build = build;
	pv.name, pv.class = build.name, build.class;
	pv.classKnown = catalog ~= nil and catalog:IsClass(build.class);
	pv.phases = summary(build);
	pv.canActivate = rep.clean and pv.classKnown;
	pv.status = rep.clean and "ready" or "needs_repair";
	pv.exportReport = C.PlanExport(build, catalog);
	return pv;
end
C.PreviewImport = C.Decode;

-- ------------------------------------------------------------------ public: commit
-- Adds a NEW build (fresh id) from an accepted preview. Never activates, never overwrites, no change on refusal.
function C.CommitImport(handle, preview, opts)
	opts = opts or {};
	local function refuse(code, msg) return nil, { code = code, message = msg }; end
	if type(preview) ~= "table" or not preview.ok then
		return refuse("PREVIEW_NOT_OK", "the preview was refused");
	end
	if handle.readOnly then
		return refuse("READ_ONLY", "storage is read-only (" .. tostring(handle.status) .. ")");
	end
	local build;
	if preview.kind == "plan" then
		build = Util.DeepCopy(preview.build);
	else
		local class = handle.catalog and handle.catalog:NormalizeClass(opts.class or preview.class or "");
		if not class then
			return refuse("NEED_CLASS", "the talent string needs an explicit class");
		end
		local b, rep = BM.New({ id = "pending", name = "", class = class, talents = preview.talents }, handle.catalog);
		if not b then return refuse("INVALID_BUILD", "talent build refused"); end
		build = b;
	end
	if opts.name then build.name = Utf8.Trim(opts.name); end
	if build.name == "" then
		build.name = Locale.T("Imported build");
	end
	local id, copy, rep = handle:Add(build);
	if not id then
		return nil, copy;
	end
	return id, rep;
end
Locale.Register({ ["Imported build"] = "Build importé" });

-- ------------------------------------------------------------------ export
local function loss(list, severity, code, path, key, detail)
	list[#list + 1] = { severity = severity, code = code, path = path, key = key, detail = detail, message = Locale.T(MESSAGES[code] or code) };
end

local function isEmptyField(x)
	if x == "" then return true; end
	if type(x) == "table" then
		for i = 1, #x do
			if x[i] ~= "" then return false; end
		end
		return true;
	end
	return false;
end

local function hasKeys(t)
	return type(t) == "table" and next(t) ~= nil;
end

-- Projects a build onto the official format and lists everything that does not survive. Pure.
-- Returns report { ok, fatal, losses, intentLosses, lossless, array, notes }.
function C.PlanExport(build, catalog)
	local losses = {};
	local rep = { losses = losses, ok = false };
	local v = BM.Validate(build, catalog);
	if not v.ok then
		loss(losses, "intent", "TYPE_MISMATCH", "build", nil, "the build is invalid and cannot be exported");
		rep.fatal = true;
		rep.intentLosses = 1;
		return rep;
	end
	local class = build.class;
	local classKnown = catalog and catalog:IsClass(class);
	if catalog and not classKnown then
		loss(losses, "intent", "SITE_REJECTS_CLASS", "class", class);
		rep.fatal = true;
	elseif not catalog then
		loss(losses, "info", "CATALOG_UNAVAILABLE", "catalog");
	end
	loss(losses, "info", "METADATA_OMITTED", "build", nil, "id, revision, catalog, model");
	if hasKeys(build.ext) then
		loss(losses, "intent", "EXT_NOT_REPRESENTABLE", "ext", nil, table.concat(Util.SortedKeys(build.ext), ","));
	end
	local name, nt, nlen = Utf8.Trim(build.name), nil, nil;
	name, nt, nlen = Utf8.Slice16(name, C.SITE.name);
	if nt then loss(losses, "intent", "SITE_TRUNCATES", "name", nil, nlen .. ">" .. C.SITE.name); end
	local talents = build.talents;
	if talents ~= "" and not talentsOk(talents) then
		loss(losses, "intent", "SITE_DROPS_TALENTS", "talents");
		talents = "";
	end
	local root = Json.Array({ C.VERSION, name, class, talents });
	local phases = {};
	for p, ph in ipairs(build.phases) do
		local base = "phases[" .. p .. "]";
		if hasKeys(ph.ext) then
			loss(losses, "intent", "EXT_NOT_REPRESENTABLE", base .. ".ext", nil, table.concat(Util.SortedKeys(ph.ext), ","));
		end
		-- label
		local label = Utf8.Trim(ph.label);
		local lt, llen;
		label, lt, llen = Utf8.Slice16(label, C.SITE.label);
		if lt then loss(losses, "intent", "SITE_TRUNCATES", base .. ".label", nil, llen .. ">" .. C.SITE.label); end
		local custom = label ~= "" and label ~= BM.DEFAULT_LABELS[p];
		-- spells
		local spells, seen = {}, {};
		for i, g in ipairs(ph.spells) do
			local path = base .. ".spells[" .. i .. "]";
			if g.mode ~= "acquire" then
				loss(losses, "intent", "GOAL_MODE_NOT_REPRESENTABLE", path, g.key, g.mode .. (g.rank and (" " .. g.rank) or ""));
			end
			if catalog and catalog:CheckKey("spells", g.key, classKnown and class or nil) ~= "ok" then
				loss(losses, "intent", "SITE_DROPS_KEY", path, g.key);
			elseif seen[g.key] then
				loss(losses, "intent", "SITE_DROPS_DUPLICATE", path, g.key);
			end
			seen[g.key] = true;
			spells[#spells + 1] = g.key;
		end
		local banish, bseen = {}, {};
		for i, k in ipairs(ph.banish) do
			local path = base .. ".banish[" .. i .. "]";
			if catalog and catalog:CheckKey("banish", k, classKnown and class or nil) ~= "ok" then
				loss(losses, "intent", "SITE_DROPS_KEY", path, k);
			elseif bseen[k] then
				loss(losses, "intent", "SITE_DROPS_DUPLICATE", path, k);
			elseif seen[k] then
				loss(losses, "intent", "SITE_DROPS_BANISH_OVERLAP", path, k);
			end
			bseen[k] = true;
			banish[#banish + 1] = k;
		end
		local function slots(listName)
			local out, sseen = {}, {};
			for i = 1, #ph[listName] do
				local k = ph[listName][i];
				out[i] = k;
				if k ~= "" then
					local path = base .. "." .. listName .. "[" .. i .. "]";
					if catalog and catalog:CheckKey(listName, k, classKnown and class or nil) ~= "ok" then
						loss(losses, "intent", "SITE_DROPS_KEY", path, k);
					elseif sseen[k] then
						loss(losses, "intent", "SITE_DROPS_DUPLICATE", path, k);
					end
					sseen[k] = true;
				end
			end
			return Json.Array(out);
		end
		local rings, trinkets, amulets = slots("rings"), slots("trinkets"), slots("amulets");
		-- stats
		local pairsOut = {};
		for i, key in ipairs(BM.STAT_KEYS) do
			local val = ph.stats[key];
			if val ~= nil then
				if val <= 0 then
					loss(losses, "info", "STAT_ZERO_OMITTED", base .. ".stats." .. key, key);
				else
					if val > BM.LIMITS.statValue then
						loss(losses, "intent", "SITE_CAPS_STAT", base .. ".stats." .. key, key, tostring(val));
						val = BM.LIMITS.statValue;
					end
					if math.abs(val * 10 - math.floor(val * 10 + 0.5)) > 1e-9 * math.max(1, val * 10) then
						loss(losses, "intent", "SITE_ROUNDS_STAT", base .. ".stats." .. key, key, tostring(val));
					end
					pairsOut[#pairsOut + 1] = Json.Array({ i - 1, val });
				end
			end
		end
		for key in pairs(ph.stats) do
			if not Util.IndexOf(BM.STAT_KEYS, key) then
				loss(losses, "intent", "STAT_NOT_REPRESENTABLE", base .. ".stats." .. tostring(key), key);
			end
		end
		-- notes / link
		local notes, nt2, nl = Utf8.Slice16(ph.notes, C.SITE.notes);
		if nt2 then loss(losses, "intent", "SITE_TRUNCATES", base .. ".notes", nil, nl .. ">" .. C.SITE.notes); end
		local link = Utf8.Trim(ph.link);
		local ltr, ll;
		link, ltr, ll = Utf8.Slice16(link, C.SITE.link);
		if ltr then loss(losses, "intent", "SITE_TRUNCATES", base .. ".link", nil, ll .. ">" .. C.SITE.link); end
		if link ~= "" and not linkOk(link) then
			loss(losses, "intent", "SITE_DROPS_LINK", base .. ".link");
			link = "";
		end
		local content = #spells > 0 or #banish > 0 or not isEmptyField(rings) or not isEmptyField(trinkets) or not isEmptyField(amulets)
			or #pairsOut > 0 or notes ~= "" or link ~= "";
		if not content and not custom then
			phases[p] = Json.null;
		else
			local a = { custom and label or "", Json.Array(spells), Json.Array(banish), rings, trinkets, amulets, Json.Array(pairsOut), notes, link };
			while #a > 0 and isEmptyField(a[#a]) do a[#a] = nil; end
			phases[p] = Json.Array(a);
		end
	end
	local n = 4;
	while n > 0 and phases[n] == Json.null do n = n - 1; end
	for p = 1, n do root[#root + 1] = phases[p]; end
	rep.array = root;
	local intent = 0;
	for _, l in ipairs(losses) do if l.severity == "intent" then intent = intent + 1; end end
	rep.intentLosses = intent;
	rep.lossless = intent == 0;
	rep.ok = not rep.fatal;
	return rep;
end

-- Export compatible with the official planner. Refuses (nil + report) while an intent loss is unaccepted:
-- call PlanExport first, show the losses, then pass opts.acceptLosses = true.
function C.Encode(build, catalog, opts)
	opts = opts or {};
	local rep = C.PlanExport(build, catalog);
	if not rep.ok then
		return nil, rep;
	end
	if rep.intentLosses > 0 and not opts.acceptLosses then
		rep.needsConfirmation = true;
		return nil, rep;
	end
	local text, err = Json.Encode(rep.array);
	if not text then
		rep.ok = false;
		rep.error = err;
		return nil, rep;
	end
	rep.code = C.PREFIX .. B64.Encode(text);
	return rep.code, rep;
end
