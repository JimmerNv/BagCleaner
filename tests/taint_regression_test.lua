-- Prevent accidental use of Blizzard's protected popup registry in runtime files.
-- Run from BagCleaner/ as part of the CI's Lua test suite.
local function read(name)
  local f=assert(io.open(name, 'rb'))
  local source=assert(f:read('*a'))
  f:close()
  return source
end
for _,name in ipairs({'Core.lua','UI.lua','Titan.lua'}) do
  local source=read(name)
  assert(not source:find('StaticPopupDialogs', 1, true),
    name .. ' must not access the Blizzard popup table')
  assert(not source:find('StaticPopup_Show', 1, true),
    name .. ' must not call the Blizzard popup manager')
end
print('PASS: no use of Blizzard popup registry in runtime source')
