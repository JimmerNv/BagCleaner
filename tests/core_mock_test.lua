-- Run: texlua tests/core_mock_test.lua
local BC = {}
local t, popup, cursor = 0, nil, nil
local bags, dbInfo, quest = {}, {}, {}
local errors, notices = {}, {}
local function item(bag,slot,id,quality,count,price,name,questFlag)
  bags[bag] = bags[bag] or {}
  local data = {id=id,quality=quality,count=count,price=price,name=name or 'Item'..id,
                link='|Hitem:'..id..':0|h[Item'..id..']|h',icon='Texture'..id}
  bags[bag][slot]=data
  dbInfo[id]=data
  if questFlag then quest[bag..':'..slot]=true end
end
local function reset()
  for i=0,4 do bags[i]={} end
  for k in pairs(dbInfo) do dbInfo[k]=nil end
  for k in pairs(quest) do quest[k]=nil end
  t=0;popup=nil;cursor=nil;BC.job=nil;BC.pending=nil
  BC.db.protectWhite=true
  BC.db.sortBy='stack'
end
function CreateFrame() return { RegisterEvent=function() end, SetScript=function() end } end
function GetTime() return t end
function GetContainerNumSlots(bag) return bag==0 and 8 or 0 end
function GetContainerItemInfo(bag,slot)
 local i=bags[bag][slot]; if not i then return nil end
 return i.icon,i.count,false,i.quality,false,false,i.link
end
function GetContainerItemLink(bag,slot) local i=bags[bag][slot];return i and i.link end
function GetContainerItemID(bag,slot) local i=bags[bag][slot];return i and i.id end
function GetItemInfo(link)
 local id=tonumber(link:match('item:(%d+)'))
 local i=dbInfo[id]
 if not i then return nil end
 return i.name, i.link, i.quality, 1,1,'','','',nil,i.icon,i.price
end
function GetContainerItemQuestInfo(bag,slot) return quest[bag..':'..slot] end
function GetContainerNumFreeSlots(bag)
 if bag~=0 then return 0 end
 local n=0;for slot=1,8 do if not bags[bag][slot] then n=n+1 end end
 return n
end
function PickupContainerItem(bag,slot)
 local i=bags[bag][slot]
 if cursor==nil then cursor=i; bags[bag][slot]=nil
 elseif i==nil then bags[bag][slot]=cursor;cursor=nil
 else bags[bag][slot]=cursor;cursor=i end
end
function DeleteCursorItem() cursor=nil end
function GetCursorInfo() if cursor then return 'item',cursor.id,cursor.link end end
function InCombatLockdown() return false end
-- Fail the test immediately if the addon writes to Blizzard's popup registry.
StaticPopupDialogs=setmetatable({}, {__newindex=function() error('Blizzard StaticPopupDialogs modified by addon') end})
function StaticPopup_Show() error('Blizzard StaticPopup_Show invoked by addon') end
function BC:ShowDeleteConfirmation(title)
 popup={title=title}
 return true
end
function accept()
 assert(popup,'custom confirmation not shown')
 popup=nil
 BC:AcceptPending()
 if BC.job then BC:HardwareDeleteNext() end
end
function cancel()
 assert(popup,'custom confirmation not shown')
 popup=nil
 BC.pending=nil
end
function tick(seconds)
 local times=math.ceil(seconds/0.2)
 for i=1,times do t=t+0.2; BC:JobTick() end
end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,m) notices[#notices+1]=m end}
YES='Yes';NO='No'
assert(loadfile('Core.lua'))('BagCleaner',BC)
BC:InitDB()
reset()
item(0,1,101,0,1,15,'cheap')
item(0,2,102,0,20,8,'bulkCheapEach') -- 160 total
item(0,3,103,0,1,19,'second')
item(0,4,104,1,1,1,'white')
item(0,5,105,0,1,1,'quest',true)
local list=BC:Scan('stack')
assert(#list==4,'quest filtered')
assert(list[1].id==104 and list[1].protected,'white protected and sorted')
assert(list[2].id==101 and list[3].id==103 and list[4].id==102,'stack-value order')
BC:Cleanup(2)
assert(BC.pending and #BC.pending.items==2 and BC.pending.items[1].id==101 and BC.pending.items[2].id==103,'protect white when auto')
assert(bags[0][1] and bags[0][3],'nothing deleted before confirmation')
accept(); tick(1)
assert(bags[0][1]==nil and bags[0][3], "only one stack per actual click")
BC:HardwareDeleteNext(); tick(1)
assert(bags[0][1]==nil and bags[0][3]==nil and bags[0][2] and bags[0][4] and bags[0][5],'correct stacks deleted')
assert(not BC.job,'queue finishes')
reset()
item(0,1,201,1,1,1,'white')
item(0,2,202,0,1,25,'gray')
BC.db.protectWhite=false
BC:Cleanup(1)
assert(BC.pending and BC.pending.items[1].id==201,'white chosen when unprotected')
accept();tick(1);assert(bags[0][1]==nil,'unprotected white removed')
reset()
item(0,1,301,0,1,2,'bait')
BC:Cleanup(1)
item(0,1,302,0,1,1,'swap')
accept()
assert(BC.job==nil and bags[0][1].id==302,'inventory-changed blocks deletion')
reset()
item(0,1,401,0,1,10,'one')
item(0,2,402,0,1,20,'two')
BC:Cleanup(2);accept();
tick(0.25)
item(0,2,403,0,1,1,'moved')
tick(0.5);BC:HardwareDeleteNext(); tick(2)
assert(bags[0][1]==nil and bags[0][2].id==403,'mid-queue swap aborts')
assert(not BC.job,'mid-queue abort finishes')
reset()
item(0,1,501,0,1,10,'one')
BC:Cleanup(1)
assert(BC.pending and bags[0][1], 'popup without auto-deletion')
cancel()
assert(not BC.pending, 'cancel discards pending selection')
assert(bags[0][1], 'cancel leaves bag untouched')
print('PASS: item scan, item sorting, white-protection, quest exclusion, confirmation, batch queue, stale slot safety, cancellation')
-- 1.1 regression scenarios: optional confirmation, blacklist, slash commands and /clean all.
reset()
BC.db.blacklist = {}
BC.db.confirmDelete = false
BC.db.protectWhite = false
item(0,1,901,1,1,1,'white_blacklist')
item(0,2,902,0,1,10,'gray')
item(0,3,903,1,1,15,'white_allowed')
item(0,4,904,1,1,2,'quest',true)
assert(BC:AddBlacklist('901'),'blacklist accepts id')
assert(BC.db.blacklist['901'],'blacklist stored')
BC:Cleanup(2)
assert(BC.job and not BC.pending and popup==nil,'confirmation disabled: direct queue')
assert(BC.job.items[1].id==902 and BC.job.items[2].id==903,'blacklist and quest excluded, selected by total')
BC:HardwareDeleteNext();tick(1)
BC:HardwareDeleteNext();tick(1)
assert(bags[0][1] and not bags[0][2] and not bags[0][3] and bags[0][4],'protect exclusion holds even with confirm off')
reset()
BC.db.confirmDelete = false
BC.db.protectWhite = true
item(0,1,910,0,1,100,'gray_big')
item(0,2,911,0,2,1,'gray_small')
item(0,3,912,1,1,0,'white_protected')
SlashCmdList.BAGCLEANER('all')
assert(BC.job and #BC.job.items==2,'/clean all queues all eligible and excludes whites')
assert(BC.job.items[1].id==911 and BC.job.items[2].id==910,'all sorted by stack cost')
BC:HardwareDeleteNext();tick(1)
BC:HardwareDeleteNext();tick(1)
assert(bags[0][3] and not bags[0][1] and not bags[0][2],'/clean all removed only eligible')
reset()
BC.db.confirmDelete = true
item(0,1,920,0,1,1,'first')
item(0,2,921,0,1,2,'second')
SlashCmdList.BAGCLEANER('2')
assert(popup and not BC.job,'/clean 2 honors confirmation setting')
assert(BC.pending and #BC.pending.items==2,'/clean 2 queued correct count')
cancel()
SlashCmdList.BAGCLEANER('confirm')
assert(BC.db.confirmDelete==false,'/clean confirm toggles confirmation')
SlashCmdList.BAGCLEANER('')
assert(BC.job and #BC.job.items==2,'/clean uses remembered count when no argument')
tick(2)
reset()
BC.db.blacklist={}
SlashCmdList.BAGCLEANER('blacklist add 923')
assert(BC.db.blacklist['923'],'slash blacklist add')
SlashCmdList.BAGCLEANER('blacklist remove 923')
assert(not BC.db.blacklist['923'],'slash blacklist remove')
print('PASS: /clean, /clean count, /clean all, optional confirmation, white blacklist, quest exclusion')

-- 1.4.1: old unit-price preference must not reorder the UI or auto-clean.
reset()
BC.db.sortBy='single'
BC:InitDB()
assert(BC.db.sortBy=='stack', 'migrates previously saved unit-price sort')
item(0,1,1801,0,40,1,'bulk-cheap-single')   -- 40c total
item(0,2,1802,0,1,6,'cheap-stack')           -- 6c total
item(0,3,1803,0,5,2,'middle-stack')          -- 10c total
local priority = BC:Scan('single')             -- even legacy arg cannot change the priority
assert(priority[1].id==1802 and priority[2].id==1803 and priority[3].id==1801,
  'display priority always follows total stack vendor value')
BC.panel={offset=4,IsShown=function() return true end}
BC:Refresh()
assert(BC.items[1].id==1802 and BC.panel.offset==0,
  'refresh shows the cheapest stack first, even after earlier scrolling')
BC.db.confirmDelete=false
BC:Cleanup(2)
assert(BC.job and BC.job.items[1].id==1802 and BC.job.items[2].id==1803,
  'automatic cleanup chooses lowest total stack value, not lowest unit price')
print('PASS: strict total-stack priority, legacy sort migration and start-from-top refresh')
-- 1.4.2: the confirmation must fail closed without its own UI and must never
-- invoke Blizzard's protected popup registry, even when it is present.
reset()
BC.db.confirmDelete=true
item(0,1,1999,0,1,11,'taint_guard')
local show = BC.ShowDeleteConfirmation
BC.ShowDeleteConfirmation=nil
BC:Cleanup(1)
assert(not BC.pending and not BC.job and bags[0][1],
  'missing custom dialog aborts without deleting the item')
BC.ShowDeleteConfirmation=function() error('custom UI failed') end
BC:Cleanup(1)
assert(not BC.pending and not BC.job and bags[0][1],
  'failing custom dialog aborts without deleting the item')
BC.ShowDeleteConfirmation=show
assert(next(StaticPopupDialogs)==nil, 'Blizzard popup registry remains unmodified')
print('PASS: no Blizzard popup registry taint, missing/failed confirmation fails closed')

