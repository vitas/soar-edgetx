local tests = {}

function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
  end
end

local test_files = {}
local find_tests = "find tests -type f -name 'test_*.lua'"
local pipe = assert(io.popen(find_tests))
for file in pipe:lines() do
  test_files[#test_files + 1] = file
end
local ok = pipe:close()
if not ok then
  error("command failed: " .. find_tests, 0)
end
table.sort(test_files)

for _, file in ipairs(test_files) do
  dofile(file)
end

local failures = 0
for _, registered in ipairs(tests) do
  local ok, err = pcall(registered.fn)
  if ok then
    print("ok - " .. registered.name)
  else
    failures = failures + 1
    print("not ok - " .. registered.name .. ": " .. err)
  end
end

if failures > 0 then
  os.exit(1)
end

print(string.format("%d tests ok", #tests))
