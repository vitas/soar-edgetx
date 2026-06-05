local roots = { "src", "tests", "tools" }
local banned = { "f3k", "f3j", "f5k", "f3r", "f3res", "bw" }

local function sh_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function lines(cmd)
  local pipe = assert(io.popen(cmd))
  local out = {}
  for line in pipe:lines() do
    out[#out + 1] = line
  end
  local ok = pipe:close()
  if not ok then
    error("command failed: " .. cmd, 0)
  end
  table.sort(out)
  return out
end

local function shell_ok(result)
  return result == true or result == 0
end

local files = {}
for _, root in ipairs(roots) do
  local out = lines("find " .. sh_quote(root) .. " -type f -name '*.lua' 2>/dev/null")
  for _, file in ipairs(out) do
    files[#files + 1] = file
  end
end

local failed = false
for _, file in ipairs(files) do
  if not shell_ok(os.execute("luac -p " .. sh_quote(file) .. " >/dev/null 2>&1")) then
    io.stderr:write("syntax failed: " .. file .. "\n")
    failed = true
  end

  local lower = file:lower()
  if lower:match("^src/soarf5j/") then
    for _, word in ipairs(banned) do
      if lower:find(word, 1, true) then
        io.stderr:write("banned non-F5J path: " .. file .. "\n")
        failed = true
      end
    end
  end
end

if failed then
  os.exit(1)
end

print("lint ok")
