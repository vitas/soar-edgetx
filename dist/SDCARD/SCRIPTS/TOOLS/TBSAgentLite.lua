-------------------------------------------------------------------------------
-- TBS Agent Lite 0.99
-- release date: 2025-01
-- author: JimB40
-------------------------------------------------------------------------------
local toolName = "TNS|TBS Agent 0.99|TNE"
local SP = '/SCRIPTS/TOOLS/TBSAGENTLITE/'

local clcd = lcd.RGB
local err = {}

local erun = function(evt)
  local lh = clcd and 20 or 8
  local f = CENTER+(clcd and 0 or SMLSIZE)
  lcd.clear()
  lcd.drawText(LCD_W/2,1,'TBS Agent Lite error!',f)
  if #err > 0 then
    for i,v in ipairs(err) do
      lcd.drawText(LCD_W/2,lh*(i+1), v,f)
    end
  end
  lcd.drawText(LCD_W/2,LCD_H-lh,'Press EXIT',f)
  return (evt == EVT_EXIT_BREAK and 1 or 0)
end

local ec = function()
  local luav = '5.2'
  luav = _VERSION and string.sub(_VERSION,5) or luav
  local fh = io.open(SP..'loader.luac')
  if fh then
    local b = io.read(fh,5)
    io.close(fh)
    if string.len(b) < 5 then
      err[1] = 'Loader corrupted'
      err[2] = 'Install again'
      return true -- change to true in distro
    else
      local lbh = string.format('%02X',string.byte(string.sub(b,5,5)))
      local binv = string.format('%d.%d',string.sub(lbh,1,1),string.sub(lbh,2,2))
      if luav ~= binv then
        err[1] = 'System using LUA '..luav
        err[2] = 'Application for LUA '..binv
        err[3] = 'Install proper version'
        return true
      else
        return false 
      end
    end
  else
    err[1] = 'Loader not found'
    err[2] = 'Install again'
    return true
  end
  return true
 end

if ec() then
  return {run=erun}
end

clcd = nil
err = nil
erun = nil
ec = nil
collectgarbage()

return {run=(loadScript(SP..'loader','bx')('SA',SP)).run}
