-- Test harness (runs under a real Lua 5.1 interpreter). Loads the REAL addon files, in .toc order, inside a
-- client-like sandbox: only the globals a 3.3.5a addon environment gives (no io, os, require, package, load*,
-- debug), every global write and every read of a non-whitelisted global is recorded.
local H = { passed = 0, failed = 0, names = {}, tests = 0 };

local function fmt(v, depth)
	depth = depth or 0;
	if type(v) == "table" then
		if depth > 3 then return "{...}"; end
		local parts = {};
		local keys = {};
		for k in pairs(v) do keys[#keys + 1] = k; end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b); end);
		for _, k in ipairs(keys) do
			parts[#parts + 1] = tostring(k) .. "=" .. fmt(v[k], depth + 1);
			if #parts > 12 then parts[#parts + 1] = "..."; break; end
		end
		return "{" .. table.concat(parts, ",") .. "}";
	end
	if type(v) == "string" then return string.format("%q", v); end
	return tostring(v);
end
H.fmt = fmt;

local function deepeq(a, b)
	if a == b then return true; end
	if type(a) ~= "table" or type(b) ~= "table" then return false; end
	for k, v in pairs(a) do if not deepeq(v, b[k]) then return false; end end
	for k in pairs(b) do if a[k] == nil then return false; end end
	return true;
end
H.deepeq = deepeq;

function H.test(name, fn)
	H.names[#H.names + 1] = name;
	H.tests = H.tests + 1;
	local ok, err = pcall(fn);
	if not ok then
		H.failed = H.failed + 1;
		print("  FAIL " .. name .. "\n       " .. tostring(err));
	end
end

local function pass() H.passed = H.passed + 1; end
local function fail(msg, level)
	H.failed = H.failed + 1;
	local where = "";
	local info = debug.getinfo((level or 2) + 1, "Sl");
	if info then where = " (" .. info.short_src:match("[^/\\]*$") .. ":" .. info.currentline .. ")"; end
	print("  FAIL " .. msg .. where);
end

function H.eq(got, want, msg)
	if deepeq(got, want) then pass(); else fail((msg or "eq") .. ": expected " .. fmt(want) .. " got " .. fmt(got)); end
end
function H.ok(cond, msg)
	if cond then pass(); else fail(msg or "expected true"); end
end
function H.no(cond, msg)
	if not cond then pass(); else fail(msg or "expected false"); end
end
function H.has(list, item, msg)
	for _, v in ipairs(list) do if v == item then pass(); return; end end
	fail((msg or "has") .. ": " .. fmt(item) .. " not in " .. fmt(list));
end
-- Reports whether `report` carries an issue with that code (any level) at that path (optional).
function H.issue(report, code, path, msg)
	for _, it in ipairs(report.issues or {}) do
		if it.code == code and (path == nil or it.path == path) then pass(); return it; end
	end
	fail((msg or "issue") .. ": " .. code .. " " .. tostring(path) .. " not in " .. fmt(report.issues));
end
function H.noissue(report, code)
	for _, it in ipairs(report.issues or {}) do
		if it.code == code then fail("unexpected issue " .. code .. " at " .. tostring(it.path)); return; end
	end
	pass();
end
function H.raises(fn, msg)
	local ok = pcall(fn);
	if not ok then pass(); else fail(msg or "expected an error"); end
end

-- ----------------------------------------------------------------- file access (test side only)
local function readFile(path)
	local fh = assert(io.open(path, "rb"));
	local s = fh:read("*a");
	fh:close();
	return s;
end
H.readFile = readFile;

local function tocFiles(root)
	local files = {};
	for line in (readFile(root .. "/addon/RebornBuildPlanner/RebornBuildPlanner.toc") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
		if line ~= "" and line:sub(1, 1) ~= "#" then files[#files + 1] = line; end
	end
	return files;
end
H.tocFiles = tocFiles;

local WHITELIST = { "string", "table", "math", "type", "pairs", "ipairs", "next", "select", "tostring", "tonumber", "pcall",
	"xpcall", "error", "assert", "setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "unpack" };

-- opts: time (function), CreateFrame (function), only (list of toc files to load), extra (table of extra globals),
-- catalogData (replaces ns.GeneratedCatalog after load)
function H.loadAddon(opts)
	opts = opts or {};
	local root = H.root;
	local ns = {};
	local base = {};
	for _, k in ipairs(WHITELIST) do base[k] = _G[k]; end
	for k, v in pairs(opts.extra or {}) do base[k] = v; end
	if opts.time then base.time = opts.time; end
	if opts.CreateFrame then base.CreateFrame = opts.CreateFrame; end
	local sandbox = { writes = {}, reads = {}, ns = ns };
	local env = setmetatable({}, {
		__index = function(_, k)
			if base[k] ~= nil then return base[k]; end
			sandbox.reads[k] = true;
			return nil;
		end,
		__newindex = function(t, k, v)
			sandbox.writes[k] = true;
			rawset(base, k, v);
		end,
	});
	sandbox.env = env;
	local files = opts.only or tocFiles(root);
	for _, f in ipairs(files) do
		local src = readFile(root .. "/addon/RebornBuildPlanner/" .. f);
		local fn, err = loadstring(src, "@" .. f);
		if not fn then error("syntax error: " .. tostring(err)); end
		setfenv(fn, env);
		fn("RebornBuildPlanner", ns);
	end
	sandbox.base = base;
	return ns, sandbox;
end

-- ----------------------------------------------------------------- SavedVariables simulation
local function ser(v, indent, out)
	local t = type(v);
	if t == "table" then
		out[#out + 1] = "{\n";
		local keys = {};
		for k in pairs(v) do keys[#keys + 1] = k; end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b); end
			return a < b;
		end);
		for _, k in ipairs(keys) do
			out[#out + 1] = indent .. "  [";
			ser(k, indent .. "  ", out);
			out[#out + 1] = "] = ";
			ser(v[k], indent .. "  ", out);
			out[#out + 1] = ",\n";
		end
		out[#out + 1] = indent .. "}";
	elseif t == "string" then
		out[#out + 1] = string.format("%q", v);
	elseif t == "number" then
		out[#out + 1] = string.format("%.17g", v);
	elseif t == "boolean" then
		out[#out + 1] = tostring(v);
	else
		error("cannot serialise " .. t);
	end
end

-- Text exactly like the client's SavedVariables file: `Name = {...}`; fails on functions/userdata.
function H.serialize(name, value)
	local out = { name .. " = " };
	ser(value, "", out);
	out[#out + 1] = "\n";
	return table.concat(out);
end

-- Simulates the client reloading the file: executes it in an EMPTY environment and returns the global.
function H.reload(name, text)
	local env = {};
	local fn = assert(loadstring(text, "@sv"));
	setfenv(fn, env);
	fn();
	return env[name];
end

function H.roundtrip(value)
	return H.reload("X", H.serialize("X", value));
end

return H;
