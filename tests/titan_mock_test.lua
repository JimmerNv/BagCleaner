-- Run: luatex --luaonly tests/titan_mock_test.lua
UIParent={}
local now, calls = 0, 0
function GetTime() return now end
local broker = {}
function broker:GetDataObjectByName(id) return self[id] end
function broker:NewDataObject(id, tbl) self[id]=tbl; calls=calls+1; return tbl end
LibStub=setmetatable({}, {__call=function(_,name,quiet) if name=='LibDataBroker-1.1' then return broker end end})
local BC={db={lastSlots=4},GetFreeSlots=function()return 9 end,
 ToggleOptions=function(self)self.didOptions=true end,
 OpenAndTogglePanel=function(self)self.didPanel=true end }
assert(loadfile('Titan.lua'))('BagCleaner',BC)
assert(BC.titanRegistered and BC.titanMode=='LDB','broker registration works')
assert(calls==1 and broker.BagCleaner,'one data object')
broker.BagCleaner.OnClick(nil,'LeftButton')
assert(BC.didPanel,'left click')
broker.BagCleaner.OnClick(nil,'RightButton')
assert(BC.didOptions,'right click')
BC:RegisterTitan()
assert(calls==1,'no duplicate')
print('PASS: Titan LDB data source registration, click actions, dedupe')
