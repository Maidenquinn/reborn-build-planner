-- Entry point (Lua 5.1). Expects global ROOT (project root, forward slashes) set by tools/run_lua_tests.py.
local H = dofile(ROOT .. "/tests/lua/harness.lua");
H.root = ROOT;
H.catalogDir = CATALOG_DIR;
local suites = { "test_standalone", "test_catalog", "test_model", "test_storage", "test_storage_hardening", "test_codec", "test_ui", "test_lot31", "test_lot32", "test_lot33", "test_lot34", "test_lot35", "test_lot36", "test_lot4", "test_sandbox" };
if ONLY then suites = { ONLY }; end
for _, name in ipairs(suites) do
	print("[" .. name .. "]");
	local before = H.passed;
	dofile(ROOT .. "/tests/lua/" .. name .. ".lua")(H);
	print("  " .. (H.passed - before) .. " assertions passed so far in this suite");
end
print(string.format("\nLua tests: %d test cases, %d assertions passed, %d failed (%s)", H.tests, H.passed, H.failed, _VERSION));
return H.failed;
