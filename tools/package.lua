local source = "src/SoarF5J"
local install_root = "dist/SDCARD"
local target = install_root .. "/WIDGETS/SoarF5J"

local function sh_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function shell_ok(result)
  return result == true or result == 0
end

local function run(cmd)
  if not shell_ok(os.execute(cmd)) then
    error("command failed: " .. cmd, 0)
  end
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

if not shell_ok(os.execute("[ -d " .. sh_quote(source) .. " ]")) then
  error("missing source directory: " .. source, 0)
end

run("rm -rf " .. sh_quote(target))
run("mkdir -p " .. sh_quote(target))

local files = lines("find " .. sh_quote(source) .. " -type f -name '*.lua' 2>/dev/null")
for _, file in ipairs(files) do
  local relative = file:sub(#source + 2)
  local destination = target .. "/" .. relative
  local directory = destination:match("^(.*)/[^/]+$")

  if directory then
    run("mkdir -p " .. sh_quote(directory))
  end
  run("cp " .. sh_quote(file) .. " " .. sh_quote(destination))
end

print("package ok")
